package com.example.neo4jdemo;

import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.service.strategy.TemplateTraversalStrategy;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.neo4j.core.Neo4jClient;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;

@DisplayName("动态模板策略及安全白名单测试")
public class TemplateTraversalGenerationTest {

    @Test
    @DisplayName("测试正常动态 Cypher 生成")
    void testTemplateNormalGeneration() {
        Neo4jClient client = mock(Neo4jClient.class, RETURNS_DEEP_STUBS);
        TemplateTraversalStrategy strategy = new TemplateTraversalStrategy(client);

        TraversalRequest request = new TraversalRequest("CORP_001");
        request.setRelationshipTypes(List.of("PARENT_OF", "SUB_DEPT"));
        request.setDirection(TraversalDirection.OUTGOING);
        request.setMinHops(1);
        request.setMaxHops(3);
        request.setNodeFilters(Map.of("level", 2));

        var result = strategy.execute(request);

        String cypher = result.cypher();
        System.out.println("Template Generated Cypher: " + cypher);

        assertThat(cypher).contains("MATCH p = (s:GraphNode {id: $startId})-[:PARENT_OF|SUB_DEPT*1..3]->(t:GraphNode)");
        assertThat(cypher).contains("WHERE t.level = $filter_level");
        assertThat(cypher).contains("RETURN p LIMIT $limit");
        assertThat(result.parameters()).containsEntry("startId", "CORP_001");
        assertThat(result.parameters()).containsEntry("filter_level", 2);
    }

    @Test
    @DisplayName("测试 Cypher 注入防御：非法字符必须被拦截并抛出异常")
    void testCypherInjectionPrevention() {
        Neo4jClient client = mock(Neo4jClient.class, RETURNS_DEEP_STUBS);
        TemplateTraversalStrategy strategy = new TemplateTraversalStrategy(client);

        TraversalRequest request = new TraversalRequest("CORP_001");
        // 尝试恶意注入 Cypher
        request.setRelationshipTypes(List.of("PARENT_OF]->(m); MATCH (n) DETACH DELETE n; //"));

        assertThatThrownBy(() -> strategy.execute(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid relationship type name");
    }
}
