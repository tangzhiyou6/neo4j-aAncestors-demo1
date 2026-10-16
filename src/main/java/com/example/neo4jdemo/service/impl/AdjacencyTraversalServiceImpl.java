package com.example.neo4jdemo.service.impl;

import com.example.neo4jdemo.constant.ResultFormat;
import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.constant.TraversalStrategyType;
import com.example.neo4jdemo.dto.AdjacencyListDTO;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.dto.TraversalResultDTO;
import com.example.neo4jdemo.service.AdjacencyTraversalService;
import com.example.neo4jdemo.service.assembler.AdjacencyAssembler;
import com.example.neo4jdemo.service.strategy.DynamicTraversalStrategy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * 邻接表纯动态遍历服务实现
 */
@Service
public class AdjacencyTraversalServiceImpl implements AdjacencyTraversalService {

    private static final Logger log = LoggerFactory.getLogger(AdjacencyTraversalServiceImpl.class);

    private final Map<TraversalStrategyType, DynamicTraversalStrategy> strategyMap = new EnumMap<>(TraversalStrategyType.class);
    private final AdjacencyAssembler adjacencyAssembler;

    public AdjacencyTraversalServiceImpl(List<DynamicTraversalStrategy> strategies,
                                         AdjacencyAssembler adjacencyAssembler) {
        this.adjacencyAssembler = adjacencyAssembler;
        for (DynamicTraversalStrategy strategy : strategies) {
            strategyMap.put(strategy.getStrategyType(), strategy);
        }
    }

    @Override
    public TraversalResultDTO traverse(TraversalRequest request) {
        long startTime = System.currentTimeMillis();

        TraversalStrategyType strategyType = request.getStrategyType() != null ?
                request.getStrategyType() : TraversalStrategyType.CYPHER_DSL;

        DynamicTraversalStrategy strategy = strategyMap.get(strategyType);
        if (strategy == null) {
            throw new IllegalArgumentException("Unsupported traversal strategy: " + strategyType);
        }

        // 执行动态遍历
        DynamicTraversalStrategy.TraversalExecutionResult executionResult = strategy.execute(request);

        long duration = System.currentTimeMillis() - startTime;

        // 组装结果结构 (邻接表 / 树 / 扁平列表 / 路径明细)
        return adjacencyAssembler.assemble(
                request,
                executionResult.paths(),
                executionResult.cypher(),
                duration
        );
    }

    @Override
    public TraversalResultDTO findAncestors(String nodeId, List<String> relationshipTypes, int maxHops) {
        TraversalRequest request = new TraversalRequest();
        request.setStartNodeId(nodeId);
        request.setRelationshipTypes(relationshipTypes != null ? relationshipTypes : List.of("PARENT_OF"));
        // 关系为 (Parent)-[:PARENT_OF]->(Child)，向上找祖先需使用 INCOMING 反向遍历
        request.setDirection(TraversalDirection.INCOMING);
        request.setMinHops(1);
        request.setMaxHops(maxHops > 0 ? maxHops : 5);
        request.setResultFormat(ResultFormat.TREE);
        request.setStrategyType(TraversalStrategyType.CYPHER_DSL);

        return traverse(request);
    }

    @Override
    public TraversalResultDTO findDescendants(String nodeId, List<String> relationshipTypes, int maxHops) {
        TraversalRequest request = new TraversalRequest();
        request.setStartNodeId(nodeId);
        request.setRelationshipTypes(relationshipTypes != null ? relationshipTypes : List.of("PARENT_OF"));
        // 向下展开子孙使用 OUTGOING 正向遍历
        request.setDirection(TraversalDirection.OUTGOING);
        request.setMinHops(1);
        request.setMaxHops(maxHops > 0 ? maxHops : 5);
        request.setResultFormat(ResultFormat.TREE);
        request.setStrategyType(TraversalStrategyType.CYPHER_DSL);

        return traverse(request);
    }

    @Override
    public AdjacencyListDTO getDirectAdjacency(String nodeId, TraversalDirection direction) {
        TraversalRequest request = new TraversalRequest();
        request.setStartNodeId(nodeId);
        request.setDirection(direction != null ? direction : TraversalDirection.OUTGOING);
        request.setMinHops(1);
        request.setMaxHops(1);
        request.setResultFormat(ResultFormat.ADJACENCY_LIST);
        request.setStrategyType(TraversalStrategyType.CYPHER_DSL);

        TraversalResultDTO resultDTO = traverse(request);

        AdjacencyListDTO dto = new AdjacencyListDTO(nodeId);
        dto.setTotalNodes(resultDTO.getTotalNodes());
        dto.setTotalEdges(resultDTO.getTotalEdges());
        dto.setAdjacencies(resultDTO.getAdjacencyList());
        dto.setNodeDetails(resultDTO.getNodeDetails());
        return dto;
    }
}
