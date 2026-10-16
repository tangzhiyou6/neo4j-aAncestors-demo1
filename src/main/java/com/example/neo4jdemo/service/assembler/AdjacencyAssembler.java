package com.example.neo4jdemo.service.assembler;

import com.example.neo4jdemo.constant.ResultFormat;
import com.example.neo4jdemo.dto.*;
import org.neo4j.driver.types.Node;
import org.neo4j.driver.types.Path;
import org.neo4j.driver.types.Relationship;
import org.springframework.stereotype.Component;

import java.util.*;

/**
 * 邻接表与多维图结构组装器
 *
 * 负责将 Neo4j Driver 返回的原生 Path/Record 集合，
 * 高性能转换为业务所需的四种形式：
 * 1. 经典邻接表结构 (Adjacency List: Map<NodeId, List<AdjacencyItem>>)
 * 2. 树形/祖先继承结构 (TreeNode 嵌套层级树)
 * 3. 扁平去重节点列表 (Flat List)
 * 4. 拓扑路径明细列表 (Path List)
 */
@Component
public class AdjacencyAssembler {

    public TraversalResultDTO assemble(TraversalRequest request, List<Path> paths, String cypher, long executionTimeMs) {
        TraversalResultDTO result = new TraversalResultDTO();
        result.setStartNodeId(request.getStartNodeId());
        result.setFormat(request.getResultFormat());
        result.setGeneratedCypher(cypher);
        result.setExecutionTimeMs(executionTimeMs);

        Map<String, GraphNodeDTO> nodeDetails = new HashMap<>();
        Map<String, List<AdjacencyItemDTO>> adjacencyMap = new LinkedHashMap<>();
        Set<String> edgeSignatures = new HashSet<>();
        List<PathDTO> pathDTOs = new ArrayList<>();

        int totalEdges = 0;

        for (Path p : paths) {
            // 1. 组装路径明细
            PathDTO pathDTO = new PathDTO();
            String pStartId = extractNodeId(p.start());
            String pEndId = extractNodeId(p.end());
            pathDTO.setStartNodeId(pStartId);
            pathDTO.setEndNodeId(pEndId);
            pathDTO.setLength(p.length());

            for (Node n : p.nodes()) {
                GraphNodeDTO nodeDTO = mapNode(n);
                nodeDetails.putIfAbsent(nodeDTO.getId(), nodeDTO);
                pathDTO.getNodes().add(nodeDTO);
            }
            for (Relationship r : p.relationships()) {
                pathDTO.getRelationships().add(r.type());
            }
            pathDTOs.add(pathDTO);

            // 2. 组装邻接表
            int depth = 1;
            for (Path.Segment segment : p) {
                Node u = segment.start();
                Node v = segment.end();
                Relationship r = segment.relationship();

                String uId = extractNodeId(u);
                String vId = extractNodeId(v);

                nodeDetails.putIfAbsent(uId, mapNode(u));
                nodeDetails.putIfAbsent(vId, mapNode(v));

                String edgeKey = uId + "->" + r.type() + "->" + vId;
                if (!edgeSignatures.contains(edgeKey)) {
                    edgeSignatures.add(edgeKey);
                    totalEdges++;

                    AdjacencyItemDTO item = new AdjacencyItemDTO(
                            vId,
                            extractNodeProperty(v, "name"),
                            extractNodeProperty(v, "type"),
                            r.type(),
                            depth
                    );
                    item.setEdgeProperties(new HashMap<>(r.asMap()));

                    adjacencyMap.computeIfAbsent(uId, k -> new ArrayList<>()).add(item);
                }
                depth++;
            }
        }

        result.setNodeDetails(nodeDetails);
        result.setTotalNodes(nodeDetails.size());
        result.setTotalEdges(totalEdges);

        // 根据请求格式填充数据
        ResultFormat format = request.getResultFormat();
        result.setAdjacencyList(adjacencyMap);

        if (format == ResultFormat.PATH_LIST) {
            result.setPaths(pathDTOs);
        } else if (format == ResultFormat.FLAT_LIST) {
            // 返回所有触达的目标节点（去重）
            List<GraphNodeDTO> flatList = nodeDetails.values().stream()
                    .filter(n -> !n.getId().equals(request.getStartNodeId()))
                    .toList();
            result.setFlatNodes(flatList);
        } else if (format == ResultFormat.TREE) {
            // 组装多叉树形结构
            TreeNodeDTO treeRoot = buildTree(request.getStartNodeId(), adjacencyMap, nodeDetails);
            result.setTree(treeRoot);
        }

        return result;
    }

    private TreeNodeDTO buildTree(String rootId, Map<String, List<AdjacencyItemDTO>> adjacencyMap, Map<String, GraphNodeDTO> nodeDetails) {
        GraphNodeDTO rootNode = nodeDetails.get(rootId);
        String name = rootNode != null ? rootNode.getName() : rootId;
        String type = rootNode != null ? rootNode.getType() : "UNKNOWN";

        TreeNodeDTO root = new TreeNodeDTO(rootId, name, type, 0);
        if (rootNode != null) {
            root.setProperties(rootNode.getProperties());
        }

        Set<String> visitedInCurrentBranch = new HashSet<>();
        visitedInCurrentBranch.add(rootId);

        buildTreeRecursive(root, adjacencyMap, nodeDetails, visitedInCurrentBranch, 1);
        return root;
    }

    private void buildTreeRecursive(TreeNodeDTO current,
                                    Map<String, List<AdjacencyItemDTO>> adjacencyMap,
                                    Map<String, GraphNodeDTO> nodeDetails,
                                    Set<String> visitedInCurrentBranch,
                                    int depth) {
        List<AdjacencyItemDTO> childrenEdges = adjacencyMap.get(current.getId());
        if (childrenEdges == null || childrenEdges.isEmpty()) {
            return;
        }

        for (AdjacencyItemDTO edge : childrenEdges) {
            String childId = edge.getTargetNodeId();
            GraphNodeDTO childNode = nodeDetails.get(childId);

            TreeNodeDTO childTree = new TreeNodeDTO(
                    childId,
                    edge.getTargetNodeName(),
                    edge.getTargetNodeType(),
                    depth
            );
            childTree.setRelationshipToParent(edge.getRelationshipType());
            if (childNode != null) {
                childTree.setProperties(childNode.getProperties());
            }

            // 环检测保护：若当前分支已包含该节点，标记为环并停止继续深入
            if (visitedInCurrentBranch.contains(childId)) {
                childTree.setCycle(true);
                current.addChild(childTree);
                continue;
            }

            visitedInCurrentBranch.add(childId);
            buildTreeRecursive(childTree, adjacencyMap, nodeDetails, visitedInCurrentBranch, depth + 1);
            visitedInCurrentBranch.remove(childId);

            current.addChild(childTree);
        }
    }

    private GraphNodeDTO mapNode(Node node) {
        String id = extractNodeId(node);
        String name = extractNodeProperty(node, "name");
        String type = extractNodeProperty(node, "type");

        Integer level = null;
        if (node.containsKey("level") && !node.get("level").isNull()) {
            level = node.get("level").asInt();
        }

        String status = extractNodeProperty(node, "status");

        GraphNodeDTO dto = new GraphNodeDTO(id, name, type, level, status);
        dto.setProperties(new HashMap<>(node.asMap()));
        return dto;
    }

    private String extractNodeId(Node node) {
        if (node.containsKey("id") && !node.get("id").isNull()) {
            return node.get("id").asString();
        }
        return node.elementId();
    }

    private String extractNodeProperty(Node node, String key) {
        if (node.containsKey(key) && !node.get(key).isNull()) {
            return node.get(key).asString();
        }
        return null;
    }
}
