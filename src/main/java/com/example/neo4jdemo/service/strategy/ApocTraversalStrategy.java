package com.example.neo4jdemo.service.strategy;

import com.example.neo4jdemo.constant.TraversalStrategyType;
import com.example.neo4jdemo.dto.TraversalRequest;
import org.neo4j.driver.types.Path;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 方案三：基于 Neo4j APOC 过程 (apoc.path.expandConfig) 的动态图遍历
 *
 * 核心机制：
 * APOC 是 Neo4j 官方扩展包，其路径扩展函数原生支持将关系过滤表达式、深度区间、剪枝条件完全作为参数 Map 传入。
 *
 * 关系语法 (relationshipFilter):
 * - OUTGOING: "PARENT_OF>|REPORTS_TO>"
 * - INCOMING: "<PARENT_OF|<REPORTS_TO" (用于 Ancestors 追溯)
 * - BOTH:     "PARENT_OF|REPORTS_TO"
 */
@Component
public class ApocTraversalStrategy implements DynamicTraversalStrategy {

    private static final Logger log = LoggerFactory.getLogger(ApocTraversalStrategy.class);

    private final Neo4jClient neo4jClient;

    public ApocTraversalStrategy(Neo4jClient neo4jClient) {
        this.neo4jClient = neo4jClient;
    }

    @Override
    public TraversalStrategyType getStrategyType() {
        return TraversalStrategyType.APOC_EXPAND;
    }

    @Override
    public TraversalExecutionResult execute(TraversalRequest request) {
        String label = StringUtils.hasText(request.getNodeLabel()) ? request.getNodeLabel() : "GraphNode";

        // 构建 APOC relationshipFilter 字符串
        String relFilter = buildApocRelationshipFilter(request);

        Map<String, Object> config = new HashMap<>();
        if (StringUtils.hasText(relFilter)) {
            config.put("relationshipFilter", relFilter);
        }
        config.put("minLevel", request.getMinHops());
        config.put("maxLevel", request.getMaxHops());
        config.put("bfs", true);
        config.put("uniqueness", "NODE_GLOBAL");
        config.put("limit", request.getLimit());

        Map<String, Object> parameters = new HashMap<>();
        parameters.put("startId", request.getStartNodeId());
        parameters.put("config", config);

        String cypher = String.format("""
                MATCH (s:%s {id: $startId})
                CALL apoc.path.expandConfig(s, $config) YIELD path
                RETURN path AS p
                """, label);

        log.debug("APOC expandConfig query: {}, config: {}", cypher, config);

        List<Path> paths = neo4jClient.query(cypher)
                .bindAll(parameters)
                .fetchAs(Path.class)
                .mappedBy((typeSystem, record) -> record.get("p").asPath())
                .all()
                .stream()
                .toList();

        return new TraversalExecutionResult(cypher, parameters, paths);
    }

    private String buildApocRelationshipFilter(TraversalRequest request) {
        List<String> types = request.getRelationshipTypes();
        if (types == null || types.isEmpty()) {
            return switch (request.getDirection()) {
                case OUTGOING -> ">";
                case INCOMING -> "<";
                case BOTH -> "";
            };
        }

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < types.size(); i++) {
            if (i > 0) sb.append("|");
            String t = types.get(i);
            switch (request.getDirection()) {
                case OUTGOING -> sb.append(t).append(">");
                case INCOMING -> sb.append("<").append(t);
                case BOTH -> sb.append(t);
            }
        }
        return sb.toString();
    }
}
