package com.example.neo4jdemo.dto;

import java.util.HashMap;
import java.util.Map;

/**
 * 边/关系数据传输对象 (DTO)
 */
public class GraphEdgeDTO {
    private String sourceId;
    private String targetId;
    private String relationshipType;
    private int depth;
    private Map<String, Object> properties = new HashMap<>();

    public GraphEdgeDTO() {
    }

    public GraphEdgeDTO(String sourceId, String targetId, String relationshipType, int depth) {
        this.sourceId = sourceId;
        this.targetId = targetId;
        this.relationshipType = relationshipType;
        this.depth = depth;
    }

    public String getSourceId() {
        return sourceId;
    }

    public void setSourceId(String sourceId) {
        this.sourceId = sourceId;
    }

    public String getTargetId() {
        return targetId;
    }

    public void setTargetId(String targetId) {
        this.targetId = targetId;
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

    public Map<String, Object> getProperties() {
        return properties;
    }

    public void setProperties(Map<String, Object> properties) {
        this.properties = properties;
    }
}
