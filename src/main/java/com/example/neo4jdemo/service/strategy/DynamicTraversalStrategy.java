package com.example.neo4jdemo.service.strategy;

import com.example.neo4jdemo.constant.TraversalStrategyType;
import com.example.neo4jdemo.dto.TraversalRequest;
import org.neo4j.driver.types.Path;

import java.util.List;
import java.util.Map;

/**
 * 邻接表动态遍历执行策略接口
 */
public interface DynamicTraversalStrategy {

    /**
     * 获取当前策略枚举标识
     */
    TraversalStrategyType getStrategyType();

    /**
     * 执行动态遍历，返回查询到的路径集合及元信息
     *
     * @param request 动态遍历参数
     * @return 遍历执行结果，包含生成的Cypher、参数和Path集合
     */
    TraversalExecutionResult execute(TraversalRequest request);

    /**
     * 策略执行结果
     */
    record TraversalExecutionResult(
            String cypher,
            Map<String, Object> parameters,
            List<Path> paths
    ) {}
}
