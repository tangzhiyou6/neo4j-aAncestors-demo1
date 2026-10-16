package com.example.neo4jdemo;

import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.constant.TraversalStrategyType;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.service.strategy.CypherDslTraversalStrategy;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.neo4j.driver.types.Path;
import org.springframework.data.neo4j.core.Neo4jClient;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@DisplayName("Cypher-DSL 纯动态 Cypher 生成与策略测试")
public class CypherDslGenerationTest {

    @Test
    @DisplayName("测试1：单关系正向向下展开 (Descendants)")
    void testOutgoingSingleRel() {
        Neo4jClient neo4jClient = mock(Neo4jClient.class, RETURNS_DEEP_STUBS);

        CypherDslTraversalStrategy strategy = new CypherDslTraversalStrategy(neo4jClient);

        TraversalRequest request = new TraversalRequest("CORP_001");
        request.setRelationshipTypes(List.of("PARENT_OF"));
        request.setDirection(TraversalDirection.OUTGOING);
        request.setMinHops(1);
        request.setMaxHops(3);
        request.setLimit(50);

        var result = strategy.execute(request);

        String cypher = result.cypher();
        System.out.println("Generated Outgoing Cypher: " + cypher);

        assertThat(cypher).contains("PARENT_OF");
        assertThat(cypher).contains("*1..3");
        assertThat(cypher).contains("s.id = $startId");
        assertThat(cypher).contains("RETURN p");
        assertThat(cypher).contains("LIMIT $limit");

        assertThat(result.parameters()).containsEntry("startId", "CORP_001");
        assertThat(result.parameters()).containsEntry("limit", 50);
    }

    @Test
    @DisplayName("测试2：向上回溯祖先 (Ancestors / Incoming)")
    void testIncomingAncestors() {
        Neo4jClient neo4jClient = mock(Neo4jClient.class, RETURNS_DEEP_STUBS);
        CypherDslTraversalStrategy strategy = new CypherDslTraversalStrategy(neo4jClient);

        TraversalRequest request = new TraversalRequest("PERSON_CHILD");
        request.setRelationshipTypes(List.of("PARENT_OF"));
        request.setDirection(TraversalDirection.INCOMING);
        request.setMinHops(1);
        request.setMaxHops(4);

        var result = strategy.execute(request);

        String cypher = result.cypher();
        System.out.println("Generated Ancestors Cypher: " + cypher);

        assertThat(cypher).contains("PARENT_OF");
        assertThat(cypher).contains("*1..4");
        assertThat(cypher).contains("<-[");
        assertThat(cypher).contains("s.id = $startId");
        assertThat(result.parameters()).containsEntry("startId", "PERSON_CHILD");
    }

    @Test
    @DisplayName("测试3：多关系组合与属性过滤 (Multi-Relationship & Filters)")
    void testMultiRelationshipsWithFilters() {
        Neo4jClient neo4jClient = mock(Neo4jClient.class, RETURNS_DEEP_STUBS);
        CypherDslTraversalStrategy strategy = new CypherDslTraversalStrategy(neo4jClient);

        TraversalRequest request = new TraversalRequest("EMP_1002");
        request.setRelationshipTypes(List.of("REPORTS_TO", "BELONGS_TO"));
        request.setDirection(TraversalDirection.BOTH);
        request.setMinHops(1);
        request.setMaxHops(2);
        request.setNodeFilters(Map.of("status", "ACTIVE"));

        var result = strategy.execute(request);

        String cypher = result.cypher();
        System.out.println("Generated Multi-Rel Cypher: " + cypher);

        // Cypher-DSL 生成 [:`REPORTS_TO`|`BELONGS_TO`*1..2]
        assertThat(cypher).contains("REPORTS_TO");
        assertThat(cypher).contains("BELONGS_TO");
        assertThat(cypher).contains("*1..2");
        assertThat(cypher).contains("filter_status");
        assertThat(result.parameters()).containsEntry("filter_status", "ACTIVE");
    }

    @Test
    @DisplayName("测试4：任意关系类型动态遍历 (无类型限制)")
    void testAnyRelationshipType() {
        Neo4jClient neo4jClient = mock(Neo4jClient.class, RETURNS_DEEP_STUBS);
        CypherDslTraversalStrategy strategy = new CypherDslTraversalStrategy(neo4jClient);

        TraversalRequest request = new TraversalRequest("ITEM_EV_CAR");
        request.setRelationshipTypes(List.of()); // 空，代表任意关系
        request.setDirection(TraversalDirection.OUTGOING);
        request.setMinHops(1);
        request.setMaxHops(5);

        var result = strategy.execute(request);

        String cypher = result.cypher();
        System.out.println("Generated Any-Rel Cypher: " + cypher);

        // 无关系类型时生成 -[*1..5]->
        assertThat(cypher).contains("-[*1..5]->");
        assertThat(cypher).contains("s.id = $startId");
    }
}
