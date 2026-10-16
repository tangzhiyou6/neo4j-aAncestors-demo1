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
import java.util.regex.Pattern;

/**
 * 方案二：安全白名单校验 + 动态 Cypher 模板拼接策略
 *
 * 核心机制：
 * 原生 Cypher 语法不支持关系类型和变长步长作为 $param 参数绑定。
 * 本策略针对动态关系名和标签采用严格正则表达式白名单校验（^[A-Za-z0-9_]+$），
 * 防止 Cypher 注入，而节点过滤条件与限制参数依然使用安全预编译参数绑定。
 */
@Component
public class TemplateTraversalStrategy implements DynamicTraversalStrategy {

    private static final Logger log = LoggerFactory.getLogger(TemplateTraversalStrategy.class);
    private static final Pattern IDENTIFIER_PATTERN = Pattern.compile("^[A-Za-z0-9_]+$");

    private final Neo4jClient neo4jClient;

    public TemplateTraversalStrategy(Neo4jClient neo4jClient) {
        this.neo4jClient = neo4jClient;
    }

    @Override
    public TraversalStrategyType getStrategyType() {
        return TraversalStrategyType.DYNAMIC_TEMPLATE;
    }

    @Override
    public TraversalExecutionResult execute(TraversalRequest request) {
        String startLabel = sanitizeIdentifier(request.getNodeLabel(), "GraphNode");
        String targetLabel = sanitizeIdentifier(request.getTargetNodeLabel(), startLabel);

        int min = Math.max(0, request.getMinHops());
        int max = Math.max(min, request.getMaxHops());
        String rangePart = String.format("*%d..%d", min, max);

        // 拼接动态关系过滤部分
        String relTypePart = "";
        if (request.getRelationshipTypes() != null && !request.getRelationshipTypes().isEmpty()) {
            StringBuilder sb = new StringBuilder(":");
            for (int i = 0; i < request.getRelationshipTypes().size(); i++) {
                String type = request.getRelationshipTypes().get(i);
                if (!IDENTIFIER_PATTERN.matcher(type).matches()) {
                    throw new IllegalArgumentException("Invalid relationship type name: " + type);
                }
                if (i > 0) {
                    sb.append("|");
                }
                sb.append(type);
            }
            relTypePart = sb.toString();
        }

        // 根据方向组装箭头
        String patternPart;
        switch (request.getDirection()) {
            case OUTGOING -> patternPart = String.format("-[%s%s]->", relTypePart, rangePart);
            case INCOMING -> patternPart = String.format("<-[%s%s]-", relTypePart, rangePart);
            case BOTH -> patternPart = String.format("-[%s%s]-", relTypePart, rangePart);
            default -> throw new IllegalArgumentException("Unknown direction: " + request.getDirection());
        }

        Map<String, Object> parameters = new HashMap<>();
        parameters.put("startId", request.getStartNodeId());
        parameters.put("limit", request.getLimit());

        StringBuilder cypher = new StringBuilder();
        cypher.append(String.format("MATCH p = (s:%s {id: $startId})%s(t:%s) ", startLabel, patternPart, targetLabel));

        // 动态节点属性过滤
        if (request.getNodeFilters() != null && !request.getNodeFilters().isEmpty()) {
            StringBuilder whereClause = new StringBuilder("WHERE ");
            int idx = 0;
            for (Map.Entry<String, Object> entry : request.getNodeFilters().entrySet()) {
                String propKey = sanitizeIdentifier(entry.getKey(), null);
                if (propKey == null) continue;
                String paramKey = "filter_" + propKey;
                if (idx > 0) whereClause.append(" AND ");
                whereClause.append(String.format("t.%s = $%s", propKey, paramKey));
                parameters.put(paramKey, entry.getValue());
                idx++;
            }
            if (idx > 0) {
                cypher.append(whereClause).append(" ");
            }
        }

        cypher.append("RETURN p LIMIT $limit");

        String query = cypher.toString();
        log.debug("Dynamic template query: {}, params: {}", query, parameters);

        List<Path> paths = neo4jClient.query(query)
                .bindAll(parameters)
                .fetchAs(Path.class)
                .mappedBy((typeSystem, record) -> record.get("p").asPath())
                .all()
                .stream()
                .toList();

        return new TraversalExecutionResult(query, parameters, paths);
    }

    private String sanitizeIdentifier(String input, String defaultValue) {
        if (!StringUtils.hasText(input)) {
            return defaultValue;
        }
        if (!IDENTIFIER_PATTERN.matcher(input).matches()) {
            throw new IllegalArgumentException("Invalid identifier: " + input);
        }
        return input;
    }
}
