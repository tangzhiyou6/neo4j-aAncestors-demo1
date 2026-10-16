package com.example.neo4jdemo;

import com.example.neo4jdemo.constant.ResultFormat;
import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.constant.TraversalStrategyType;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.dto.TraversalResultDTO;
import com.example.neo4jdemo.service.AdjacencyTraversalService;
import com.example.neo4jdemo.service.assembler.AdjacencyAssembler;
import com.example.neo4jdemo.service.impl.AdjacencyTraversalServiceImpl;
import com.example.neo4jdemo.service.strategy.DynamicTraversalStrategy;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@DisplayName("邻接表遍历服务综合测试")
public class AdjacencyTraversalServiceTest {

    @Test
    @DisplayName("测试门面服务调度与结果组装流程")
    void testServiceDelegation() {
        DynamicTraversalStrategy mockStrategy = mock(DynamicTraversalStrategy.class);
        when(mockStrategy.getStrategyType()).thenReturn(TraversalStrategyType.CYPHER_DSL);
        when(mockStrategy.execute(any())).thenReturn(
                new DynamicTraversalStrategy.TraversalExecutionResult("MATCH ...", Map.of(), List.of())
        );

        AdjacencyAssembler assembler = new AdjacencyAssembler();
        AdjacencyTraversalService service = new AdjacencyTraversalServiceImpl(List.of(mockStrategy), assembler);

        TraversalRequest request = new TraversalRequest("CORP_001");
        request.setDirection(TraversalDirection.OUTGOING);
        request.setResultFormat(ResultFormat.ADJACENCY_LIST);

        TraversalResultDTO result = service.traverse(request);

        assertThat(result).isNotNull();
        assertThat(result.getStartNodeId()).isEqualTo("CORP_001");
        assertThat(result.getFormat()).isEqualTo(ResultFormat.ADJACENCY_LIST);
    }
}
