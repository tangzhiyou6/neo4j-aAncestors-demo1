package com.example.neo4jdemo.dto;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 经典邻接表结构对象
 * key 为顶点 NodeId，value 为该顶点出发的邻接点及边信息列表
 */
public class AdjacencyListDTO {
    private String startNodeId;
    private int totalNodes;
    private int totalEdges;
    private Map<String, List<AdjacencyItemDTO>> adjacencies = new HashMap<>();
    private Map<String, GraphNodeDTO> nodeDetails = new HashMap<>();

    public AdjacencyListDTO() {
    }

    public AdjacencyListDTO(String startNodeId) {
        this.startNodeId = startNodeId;
    }

    public String getStartNodeId() {
        return startNodeId;
    }

    public void setStartNodeId(String startNodeId) {
        this.startNodeId = startNodeId;
    }

    public int getTotalNodes() {
        return totalNodes;
    }

    public void setTotalNodes(int totalNodes) {
        this.totalNodes = totalNodes;
    }

    public int getTotalEdges() {
        return totalEdges;
    }

    public void setTotalEdges(int totalEdges) {
        this.totalEdges = totalEdges;
    }

    public Map<String, List<AdjacencyItemDTO>> getAdjacencies() {
        return adjacencies;
    }

    public void setAdjacencies(Map<String, List<AdjacencyItemDTO>> adjacencies) {
        this.adjacencies = adjacencies;
    }

    public Map<String, GraphNodeDTO> getNodeDetails() {
        return nodeDetails;
    }

    public void setNodeDetails(Map<String, GraphNodeDTO> nodeDetails) {
        this.nodeDetails = nodeDetails;
    }
}
