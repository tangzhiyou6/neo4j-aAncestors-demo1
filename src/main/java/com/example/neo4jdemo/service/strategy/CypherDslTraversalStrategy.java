package com.example.neo4jdemo.service.strategy;

import com.example.neo4jdemo.constant.TraversalStrategyType;
import com.example.neo4jdemo.dto.TraversalRequest;
import org.neo4j.cypherdsl.core.*;
import org.neo4j.driver.types.Path;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Spring Data Neo4j 官方推荐方案：基于 Cypher-DSL 强类型 AST 动态构建查询
 *
 * 核心优势：
 * 1. 动态注入任意数量的关系类型名（PARENT_OF, REPORTS_TO 等），打破静态 @Relationship 注解限制
 * 2. 动态指定任意遍历方向 (OUTGOING, INCOMING, BOTH)，支持 Ancestors 祖先向上追溯与 Descendants 向下展开
 * 3. 动态配置步长范围 (*min..max)，防止硬编码深度
 * 4. 彻底消除 SQL/Cypher 注入风险，符合企业级安全标准
 */
@Component
public class CypherDslTraversalStrategy implements DynamicTraversalStrategy {

    private static final Logger log = LoggerFactory.getLogger(CypherDslTraversalStrategy.class);

    private final Neo4jClient neo4jClient;

    public CypherDslTraversalStrategy(Neo4jClient neo4jClient) {
        this.neo4jClient = neo4jClient;
    }

    @Override
    public TraversalStrategyType getStrategyType() {
        return TraversalStrategyType.CYPHER_DSL;
    }

    @Override
    public TraversalExecutionResult execute(TraversalRequest request) {
        String startLabel = StringUtils.hasText(request.getNodeLabel()) ? request.getNodeLabel() : "GraphNode";
        String targetLabel = StringUtils.hasText(request.getTargetNodeLabel()) ? request.getTargetNodeLabel() : startLabel;

        Node startNode = Cypher.node(startLabel).named("s");
        Node targetNode = Cypher.node(targetLabel).named("t");

        List<String> types = request.getRelationshipTypes() != null ? request.getRelationshipTypes() : Collections.emptyList();
        String[] relTypesArray = types.toArray(new String[0]);

        // 动态构建变长关系模式
        RelationshipPattern relPattern;
        switch (request.getDirection()) {
            case OUTGOING -> {
                var rel = relTypesArray.length > 0 ? startNode.relationshipTo(targetNode, relTypesArray) : startNode.relationshipTo(targetNode);
                relPattern = applyLength(rel, request.getMinHops(), request.getMaxHops());
            }
            case INCOMING -> {
                var rel = relTypesArray.length > 0 ? startNode.relationshipFrom(targetNode, relTypesArray) : startNode.relationshipFrom(targetNode);
                relPattern = applyLength(rel, request.getMinHops(), request.getMaxHops());
            }
            case BOTH -> {
                var rel = relTypesArray.length > 0 ? startNode.relationshipBetween(targetNode, relTypesArray) : startNode.relationshipBetween(targetNode);
                relPattern = applyLength(rel, request.getMinHops(), request.getMaxHops());
            }
            default -> throw new IllegalArgumentException("Unsupported traversal direction: " + request.getDirection());
        }

        // 定义命名路径 MATCH p = (s)-[r*1..3]->(t)
        NamedPath namedPath = Cypher.path("p").definedBy(relPattern);

        Map<String, Object> parameters = new HashMap<>();
        parameters.put("startId", request.getStartNodeId());
        parameters.put("limit", request.getLimit());

        // 动态构建过滤条件 (起点的 id 以及可选的目标节点属性过滤)
        Condition condition = startNode.property("id").isEqualTo(Cypher.parameter("startId"));

        if (request.getNodeFilters() != null && !request.getNodeFilters().isEmpty()) {
            for (Map.Entry<String, Object> entry : request.getNodeFilters().entrySet()) {
                String paramKey = "filter_" + entry.getKey();
                condition = condition.and(targetNode.property(entry.getKey()).isEqualTo(Cypher.parameter(paramKey)));
                parameters.put(paramKey, entry.getValue());
            }
        }

        // 生成最终 AST 语句
        Statement statement = Cypher.match(namedPath)
                .where(condition)
                .returning(namedPath)
                .limit(Cypher.parameter("limit"))
                .build();

        String cypher = statement.getCypher();
        log.debug("Cypher-DSL generated query: {}, params: {}", cypher, parameters);

        // 使用 Neo4jClient 执行动态查询并提取 Path
        List<Path> paths = neo4jClient.query(cypher)
                .bindAll(parameters)
                .fetchAs(Path.class)
                .mappedBy((typeSystem, record) -> record.get("p").asPath())
                .all()
                .stream()
                .toList();

        return new TraversalExecutionResult(cypher, parameters, paths);
    }

    private RelationshipPattern applyLength(ExposesPatternLengthAccessors<?> rel, int minHops, int maxHops) {
        if (minHops <= 0 && maxHops <= 0) {
            return (RelationshipPattern) rel.unbounded();
        }
        if (minHops > 0 && maxHops > 0) {
            return (RelationshipPattern) rel.length(minHops, maxHops);
        } else if (minHops > 0) {
            return (RelationshipPattern) rel.min(minHops);
        } else {
            return (RelationshipPattern) rel.max(maxHops);
        }
    }
}
