package com.example.neo4jdemo.dto;

import java.util.HashMap;
import java.util.Map;

/**
 * 邻接表中的邻接项 (目标节点及关联关系信息)
 */
public class AdjacencyItemDTO {
    private String targetNodeId;
    private String targetNodeName;
    private String targetNodeType;
    private String relationshipType;
    private int depth;
    private Map<String, Object> edgeProperties = new HashMap<>();

    public AdjacencyItemDTO() {
    }

    public AdjacencyItemDTO(String targetNodeId, String targetNodeName, String targetNodeType, String relationshipType, int depth) {
        this.targetNodeId = targetNodeId;
        this.targetNodeName = targetNodeName;
        this.targetNodeType = targetNodeType;
        this.relationshipType = relationshipType;
        this.depth = depth;
    }

    public String getTargetNodeId() {
        return targetNodeId;
    }

    public void setTargetNodeId(String targetNodeId) {
        this.targetNodeId = targetNodeId;
    }

    public String getTargetNodeName() {
        return targetNodeName;
    }

    public void setTargetNodeName(String targetNodeName) {
        this.targetNodeName = targetNodeName;
    }

    public String getTargetNodeType() {
        return targetNodeType;
    }

    public void setTargetNodeType(String targetNodeType) {
        this.targetNodeType = targetNodeType;
    }

    public String getRelationshipType() {
        return relationshipType;
    }

    public void setRelationshipType(String relationshipType) {
        this.relationshipType = relationshipType;
    }

    public int getDepth() {
        return depth;
    }

    public void setDepth(int depth) {
        this.depth = depth;
    }

    public Map<String, Object> getEdgeProperties() {
        return edgeProperties;
    }

    public void setEdgeProperties(Map<String, Object> edgeProperties) {
        this.edgeProperties = edgeProperties;
    }
}
