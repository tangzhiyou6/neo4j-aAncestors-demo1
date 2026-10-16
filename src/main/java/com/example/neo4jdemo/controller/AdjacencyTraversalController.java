package com.example.neo4jdemo.controller;

import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.dto.AdjacencyListDTO;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.dto.TraversalResultDTO;
import com.example.neo4jdemo.entity.GraphNode;
import com.example.neo4jdemo.repository.GraphNodeRepository;
import com.example.neo4jdemo.service.AdjacencyTraversalService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * 邻接表纯动态图遍历 REST 控制器
 */
@RestController
@RequestMapping("/api/graph")
public class AdjacencyTraversalController {

    private static final Logger log = LoggerFactory.getLogger(AdjacencyTraversalController.class);

    private final AdjacencyTraversalService traversalService;
    private final GraphNodeRepository nodeRepository;
    private final Neo4jClient neo4jClient;

    public AdjacencyTraversalController(AdjacencyTraversalService traversalService,
                                        GraphNodeRepository nodeRepository,
                                        Neo4jClient neo4jClient) {
        this.traversalService = traversalService;
        this.nodeRepository = nodeRepository;
        this.neo4jClient = neo4jClient;
    }

    /**
     * 1. 核心接口：万能纯动态邻接表遍历
     * 支持动态配置关系名列表、方向(OUT/IN/BOTH)、跳数区间(min..max)、结果格式(ADJACENCY_LIST/TREE/FLAT_LIST/PATH_LIST)与策略
     */
    @PostMapping("/traverse")
    public ResponseEntity<TraversalResultDTO> traverse(@RequestBody TraversalRequest request) {
        if (request.getStartNodeId() == null || request.getStartNodeId().isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        TraversalResultDTO result = traversalService.traverse(request);
        return ResponseEntity.ok(result);
    }

    /**
     * 2. 便捷接口：向上追溯祖先 (Ancestors)
     * 示例：/api/graph/ancestors?nodeId=PERSON_CHILD&relType=PARENT_OF&maxHops=4
     */
    @GetMapping("/ancestors")
    public ResponseEntity<TraversalResultDTO> getAncestors(
            @RequestParam String nodeId,
            @RequestParam(defaultValue = "PARENT_OF") String relType,
            @RequestParam(defaultValue = "4") int maxHops) {
        TraversalResultDTO result = traversalService.findAncestors(nodeId, List.of(relType), maxHops);
        return ResponseEntity.ok(result);
    }

    /**
     * 3. 便捷接口：向下展开子孙 (Descendants)
     * 示例：/api/graph/descendants?nodeId=CORP_001&relType=PARENT_OF&maxHops=3
     */
    @GetMapping("/descendants")
    public ResponseEntity<TraversalResultDTO> getDescendants(
            @RequestParam String nodeId,
            @RequestParam(defaultValue = "PARENT_OF") String relType,
            @RequestParam(defaultValue = "3") int maxHops) {
        TraversalResultDTO result = traversalService.findDescendants(nodeId, List.of(relType), maxHops);
        return ResponseEntity.ok(result);
    }

    /**
     * 4. 便捷接口：获取单跳直接邻接表 (1-hop)
     * 示例：/api/graph/adjacency?nodeId=CORP_001&direction=OUTGOING
     */
    @GetMapping("/adjacency")
    public ResponseEntity<AdjacencyListDTO> getDirectAdjacency(
            @RequestParam String nodeId,
            @RequestParam(defaultValue = "OUTGOING") TraversalDirection direction) {
        AdjacencyListDTO result = traversalService.getDirectAdjacency(nodeId, direction);
        return ResponseEntity.ok(result);
    }

    /**
     * 5. 节点详情查询
     */
    @GetMapping("/node/{id}")
    public ResponseEntity<GraphNode> getNodeById(@PathVariable String id) {
        return nodeRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * 6. 一键初始化演示数据 (执行 init-adjacency-data.cypher)
     */
    @PostMapping("/init-data")
    public ResponseEntity<Map<String, Object>> initData() {
        Map<String, Object> response = new HashMap<>();
        try {
            ClassPathResource resource = new ClassPathResource("cypher/init-adjacency-data.cypher");
            String content = StreamUtils.copyToString(resource.getInputStream(), StandardCharsets.UTF_8);

            // 过滤单行注释并按分号切分语句
            String[] statements = content.split(";");
            int count = 0;
            for (String rawStmt : statements) {
                String stmt = cleanCypherStatement(rawStmt);
                if (!stmt.isBlank()) {
                    neo4jClient.query(stmt).run();
                    count++;
                }
            }

            response.put("status", "success");
            response.put("message", "初始化测试数据完成，成功执行 Cypher 语句条数: " + count);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Failed to initialize Neo4j test data", e);
            response.put("status", "error");
            response.put("message", e.getMessage());
            return ResponseEntity.internalServerError().body(response);
        }
    }

    private String cleanCypherStatement(String raw) {
        StringBuilder sb = new StringBuilder();
        for (String line : raw.split("\n")) {
            String trimmed = line.trim();
            if (!trimmed.startsWith("//") && !trimmed.isBlank()) {
                sb.append(line).append("\n");
            }
        }
        return sb.toString().trim();
    }
}
