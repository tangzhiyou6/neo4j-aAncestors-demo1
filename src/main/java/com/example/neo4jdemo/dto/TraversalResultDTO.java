package com.example.neo4jdemo.dto;

import com.example.neo4jdemo.constant.ResultFormat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 遍历统一响应对象
 */
public class TraversalResultDTO {

    private String startNodeId;
    private ResultFormat format;
    private int totalNodes;
    private int totalEdges;
    private long executionTimeMs;
    private String generatedCypher;

    // 根据不同格式返回的数据
    private Map<String, List<AdjacencyItemDTO>> adjacencyList = new HashMap<>();
    private TreeNodeDTO tree;
    private List<GraphNodeDTO> flatNodes = new ArrayList<>();
    private List<PathDTO> paths = new ArrayList<>();
    private Map<String, GraphNodeDTO> nodeDetails = new HashMap<>();

    public TraversalResultDTO() {
    }

    public String getStartNodeId() {
        return startNodeId;
    }

    public void setStartNodeId(String startNodeId) {
        this.startNodeId = startNodeId;
    }

    public ResultFormat getFormat() {
        return format;
    }

    public void setFormat(ResultFormat format) {
        this.format = format;
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

    public long getExecutionTimeMs() {
        return executionTimeMs;
    }

    public void setExecutionTimeMs(long executionTimeMs) {
        this.executionTimeMs = executionTimeMs;
    }

    public String getGeneratedCypher() {
        return generatedCypher;
    }

    public void setGeneratedCypher(String generatedCypher) {
        this.generatedCypher = generatedCypher;
    }

    public Map<String, List<AdjacencyItemDTO>> getAdjacencyList() {
        return adjacencyList;
    }

    public void setAdjacencyList(Map<String, List<AdjacencyItemDTO>> adjacencyList) {
        this.adjacencyList = adjacencyList;
    }

    public TreeNodeDTO getTree() {
        return tree;
    }

    public void setTree(TreeNodeDTO tree) {
        this.tree = tree;
    }

    public List<GraphNodeDTO> getFlatNodes() {
        return flatNodes;
    }

    public void setFlatNodes(List<GraphNodeDTO> flatNodes) {
        this.flatNodes = flatNodes;
    }

    public List<PathDTO> getPaths() {
        return paths;
    }

    public void setPaths(List<PathDTO> paths) {
        this.paths = paths;
    }

    public Map<String, GraphNodeDTO> getNodeDetails() {
        return nodeDetails;
    }

    public void setNodeDetails(Map<String, GraphNodeDTO> nodeDetails) {
        this.nodeDetails = nodeDetails;
    }
}
