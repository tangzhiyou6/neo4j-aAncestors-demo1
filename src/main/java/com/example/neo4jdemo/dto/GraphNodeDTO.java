package com.example.neo4jdemo.dto;

import java.util.HashMap;
import java.util.Map;

/**
 * 节点数据传输对象 (DTO)
 */
public class GraphNodeDTO {
    private String id;
    private String name;
    private String type;
    private Integer level;
    private String status;
    private Map<String, Object> properties = new HashMap<>();

    public GraphNodeDTO() {
    }

    public GraphNodeDTO(String id, String name, String type, Integer level, String status) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.level = level;
        this.status = status;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public Integer getLevel() {
        return level;
    }

    public void setLevel(Integer level) {
        this.level = level;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Map<String, Object> getProperties() {
        return properties;
    }

    public void setProperties(Map<String, Object> properties) {
        this.properties = properties;
    }
}
