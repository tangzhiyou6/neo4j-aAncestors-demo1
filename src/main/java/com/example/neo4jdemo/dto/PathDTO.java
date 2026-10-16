package com.example.neo4jdemo.dto;

import java.util.ArrayList;
import java.util.List;

/**
 * 遍历路径传输对象
 */
public class PathDTO {
    private String startNodeId;
    private String endNodeId;
    private int length;
    private List<GraphNodeDTO> nodes = new ArrayList<>();
    private List<String> relationships = new ArrayList<>();

    public PathDTO() {
    }

    public PathDTO(String startNodeId, String endNodeId, int length) {
        this.startNodeId = startNodeId;
        this.endNodeId = endNodeId;
        this.length = length;
    }

    public String getStartNodeId() {
        return startNodeId;
    }

    public void setStartNodeId(String startNodeId) {
        this.startNodeId = startNodeId;
    }

    public String getEndNodeId() {
        return endNodeId;
    }

    public void setEndNodeId(String endNodeId) {
        this.endNodeId = endNodeId;
    }

    public int getLength() {
        return length;
    }

    public void setLength(int length) {
        this.length = length;
    }

    public List<GraphNodeDTO> getNodes() {
        return nodes;
    }

    public void setNodes(List<GraphNodeDTO> nodes) {
        this.nodes = nodes;
    }

    public List<String> getRelationships() {
        return relationships;
    }

    public void setRelationships(List<String> relationships) {
        this.relationships = relationships;
    }
}
