package com.example.neo4jdemo.dto;

import com.example.neo4jdemo.constant.ResultFormat;
import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.constant.TraversalStrategyType;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 邻接表动态遍历请求对象
 */
public class TraversalRequest {

    /**
     * 起始节点 ID (必填)
     */
    private String startNodeId;

    /**
     * 动态关系类型列表 (如 ["PARENT_OF", "REPORTS_TO"])
     * 为空时代表遍历任意类型关系
     */
    private List<String> relationshipTypes = new ArrayList<>();

    /**
     * 遍历方向: OUTGOING(正向), INCOMING(反向-找祖先), BOTH(双向)
     */
    private TraversalDirection direction = TraversalDirection.OUTGOING;

    /**
     * 最小遍历跳数 (默认 1)
     */
    private int minHops = 1;

    /**
     * 最大遍历跳数 (默认 3，建议不超过 10)
     */
    private int maxHops = 3;

    /**
     * 起始节点标签 (默认 GraphNode)
     */
    private String nodeLabel = "GraphNode";

    /**
     * 目标节点标签 (可选，为空时同 nodeLabel)
     */
    private String targetNodeLabel;

    /**
     * 期望的结果返回格式
     */
    private ResultFormat resultFormat = ResultFormat.ADJACENCY_LIST;

    /**
     * 动态遍历的实现策略
     */
    private TraversalStrategyType strategyType = TraversalStrategyType.CYPHER_DSL;

    /**
     * 节点过滤属性 (可选，例如 {"status": "ACTIVE"})
     */
    private Map<String, Object> nodeFilters = new HashMap<>();

    /**
     * 最大返回记录数限制 (防止超大子图压垮应用)
     */
    private int limit = 1000;

    public TraversalRequest() {
    }

    public TraversalRequest(String startNodeId) {
        this.startNodeId = startNodeId;
    }

    public String getStartNodeId() {
        return startNodeId;
    }

    public void setStartNodeId(String startNodeId) {
        this.startNodeId = startNodeId;
    }

    public List<String> getRelationshipTypes() {
        return relationshipTypes;
    }

    public void setRelationshipTypes(List<String> relationshipTypes) {
        this.relationshipTypes = relationshipTypes;
    }

    public TraversalDirection getDirection() {
        return direction;
    }

    public void setDirection(TraversalDirection direction) {
        this.direction = direction;
    }

    public int getMinHops() {
        return minHops;
    }

    public void setMinHops(int minHops) {
        this.minHops = minHops;
    }

    public int getMaxHops() {
        return maxHops;
    }

    public void setMaxHops(int maxHops) {
        this.maxHops = maxHops;
    }

    public String getNodeLabel() {
        return nodeLabel;
    }

    public void setNodeLabel(String nodeLabel) {
        this.nodeLabel = nodeLabel;
    }

    public String getTargetNodeLabel() {
        return targetNodeLabel;
    }

    public void setTargetNodeLabel(String targetNodeLabel) {
        this.targetNodeLabel = targetNodeLabel;
    }

    public ResultFormat getResultFormat() {
        return resultFormat;
    }

    public void setResultFormat(ResultFormat resultFormat) {
        this.resultFormat = resultFormat;
    }

    public TraversalStrategyType getStrategyType() {
        return strategyType;
    }

    public void setStrategyType(TraversalStrategyType strategyType) {
        this.strategyType = strategyType;
    }

    public Map<String, Object> getNodeFilters() {
        return nodeFilters;
    }

    public void setNodeFilters(Map<String, Object> nodeFilters) {
        this.nodeFilters = nodeFilters;
    }

    public int getLimit() {
        return limit;
    }

    public void setLimit(int limit) {
        this.limit = limit;
    }
}
