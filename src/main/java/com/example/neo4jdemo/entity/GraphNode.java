package com.example.neo4jdemo.entity;

import org.springframework.data.neo4j.core.schema.Id;
import org.springframework.data.neo4j.core.schema.Node;
import org.springframework.data.neo4j.core.schema.Property;

import java.util.HashMap;
import java.util.Map;

/**
 * 通用图节点实体
 * 基础映射，支持任意标签与动态遍历
 */
@Node("GraphNode")
public class GraphNode {

    @Id
    private String id;

    @Property("name")
    private String name;

    @Property("type")
    private String type;

    @Property("level")
    private Integer level;

    @Property("status")
    private String status;

    @Property("gender")
    private String gender;

    @Property("title")
    private String title;

    private Map<String, Object> extraProperties = new HashMap<>();

    public GraphNode() {
    }

    public GraphNode(String id, String name, String type) {
        this.id = id;
        this.name = name;
        this.type = type;
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

    public String getGender() {
        return gender;
    }

    public void setGender(String gender) {
        this.gender = gender;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public Map<String, Object> getExtraProperties() {
        return extraProperties;
    }

    public void setExtraProperties(Map<String, Object> extraProperties) {
        this.extraProperties = extraProperties;
    }

    @Override
    public String toString() {
        return "GraphNode{" +
                "id='" + id + '\'' +
                ", name='" + name + '\'' +
                ", type='" + type + '\'' +
                ", level=" + level +
                '}';
    }
}
