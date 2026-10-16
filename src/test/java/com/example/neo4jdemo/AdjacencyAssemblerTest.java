package com.example.neo4jdemo;

import com.example.neo4jdemo.constant.ResultFormat;
import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.dto.AdjacencyItemDTO;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.dto.TraversalResultDTO;
import com.example.neo4jdemo.service.assembler.AdjacencyAssembler;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.neo4j.driver.Value;
import org.neo4j.driver.types.Node;
import org.neo4j.driver.types.Path;
import org.neo4j.driver.types.Relationship;

import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@DisplayName("邻接表与树形结构组装测试")
public class AdjacencyAssemblerTest {

    private final AdjacencyAssembler assembler = new AdjacencyAssembler();

    @Test
    @DisplayName("测试组装经典邻接表与多叉树结构")
    void testAssembleAdjacencyAndTree() {
        // 构造模拟数据：Node1 (root) -> Node2 (child1) -> Node3 (grandchild)
        Node n1 = mockNode("CORP_001", "总公司", "DEPARTMENT", 0);
        Node n2 = mockNode("DEPT_TECH", "研发中心", "DEPARTMENT", 1);
        Node n3 = mockNode("DEPT_AI", "AI实验室", "DEPARTMENT", 2);

        Relationship r1 = mockRel("PARENT_OF", Map.of("weight", 1.0));
        Relationship r2 = mockRel("PARENT_OF", Map.of("weight", 1.0));

        Path.Segment s1 = mockSegment(n1, r1, n2);
        Path.Segment s2 = mockSegment(n2, r2, n3);

        Path path = mock(Path.class);
        when(path.start()).thenReturn(n1);
        when(path.end()).thenReturn(n3);
        when(path.length()).thenReturn(2);
        when(path.nodes()).thenReturn(List.of(n1, n2, n3));
        when(path.relationships()).thenReturn(List.of(r1, r2));
        when(path.iterator()).thenAnswer(inv -> List.of(s1, s2).iterator());

        // 1. 测试 ADJACENCY_LIST 格式
        TraversalRequest reqAdjacency = new TraversalRequest("CORP_001");
        reqAdjacency.setResultFormat(ResultFormat.ADJACENCY_LIST);

        TraversalResultDTO resultAdj = assembler.assemble(reqAdjacency, List.of(path), "CYPHER...", 10L);

        assertThat(resultAdj.getStartNodeId()).isEqualTo("CORP_001");
        assertThat(resultAdj.getTotalNodes()).isEqualTo(3);
        assertThat(resultAdj.getTotalEdges()).isEqualTo(2);

        Map<String, List<AdjacencyItemDTO>> adjMap = resultAdj.getAdjacencyList();
        assertThat(adjMap).containsKey("CORP_001");
        assertThat(adjMap.get("CORP_001")).hasSize(1);
        assertThat(adjMap.get("CORP_001").get(0).getTargetNodeId()).isEqualTo("DEPT_TECH");
        assertThat(adjMap.get("CORP_001").get(0).getRelationshipType()).isEqualTo("PARENT_OF");

        assertThat(adjMap).containsKey("DEPT_TECH");
        assertThat(adjMap.get("DEPT_TECH")).hasSize(1);
        assertThat(adjMap.get("DEPT_TECH").get(0).getTargetNodeId()).isEqualTo("DEPT_AI");

        // 2. 测试 TREE 格式
        TraversalRequest reqTree = new TraversalRequest("CORP_001");
        reqTree.setResultFormat(ResultFormat.TREE);

        TraversalResultDTO resultTree = assembler.assemble(reqTree, List.of(path), "CYPHER...", 12L);
        assertThat(resultTree.getTree()).isNotNull();
        assertThat(resultTree.getTree().getId()).isEqualTo("CORP_001");
        assertThat(resultTree.getTree().getChildren()).hasSize(1);

        var child1 = resultTree.getTree().getChildren().get(0);
        assertThat(child1.getId()).isEqualTo("DEPT_TECH");
        assertThat(child1.getChildren()).hasSize(1);

        var grandChild = child1.getChildren().get(0);
        assertThat(grandChild.getId()).isEqualTo("DEPT_AI");
        assertThat(grandChild.getChildren()).isEmpty();
    }

    private Node mockNode(String id, String name, String type, int level) {
        Node node = mock(Node.class);
        when(node.containsKey("id")).thenReturn(true);
        Value idVal = mock(Value.class);
        when(idVal.isNull()).thenReturn(false);
        when(idVal.asString()).thenReturn(id);
        when(node.get("id")).thenReturn(idVal);

        when(node.containsKey("name")).thenReturn(true);
        Value nameVal = mock(Value.class);
        when(nameVal.isNull()).thenReturn(false);
        when(nameVal.asString()).thenReturn(name);
        when(node.get("name")).thenReturn(nameVal);

        when(node.containsKey("type")).thenReturn(true);
        Value typeVal = mock(Value.class);
        when(typeVal.isNull()).thenReturn(false);
        when(typeVal.asString()).thenReturn(type);
        when(node.get("type")).thenReturn(typeVal);

        when(node.containsKey("level")).thenReturn(true);
        Value levelVal = mock(Value.class);
        when(levelVal.isNull()).thenReturn(false);
        when(levelVal.asInt()).thenReturn(level);
        when(node.get("level")).thenReturn(levelVal);

        when(node.asMap()).thenReturn(Map.of("id", id, "name", name, "type", type, "level", level));
        return node;
    }

    private Relationship mockRel(String type, Map<String, Object> props) {
        Relationship rel = mock(Relationship.class);
        when(rel.type()).thenReturn(type);
        when(rel.asMap()).thenReturn(props);
        return rel;
    }

    private Path.Segment mockSegment(Node u, Relationship r, Node v) {
        Path.Segment s = mock(Path.Segment.class);
        when(s.start()).thenReturn(u);
        when(s.relationship()).thenReturn(r);
        when(s.end()).thenReturn(v);
        return s;
    }
}
