package com.example.neo4jdemo.dto;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 树形/层级结构传输对象 (支持子孙展开与祖先回溯的多叉树呈现)
 */
public class TreeNodeDTO {
    private String id;
    private String name;
    private String type;
    private int depth;
    private String relationshipToParent;
    private boolean isCycle;
    private Map<String, Object> properties = new HashMap<>();
    private List<TreeNodeDTO> children = new ArrayList<>();

    public TreeNodeDTO() {
    }

    public TreeNodeDTO(String id, String name, String type, int depth) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.depth = depth;
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

    public int getDepth() {
        return depth;
    }

    public void setDepth(int depth) {
        this.depth = depth;
    }

    public String getRelationshipToParent() {
        return relationshipToParent;
    }

    public void setRelationshipToParent(String relationshipToParent) {
        this.relationshipToParent = relationshipToParent;
    }

    public boolean isCycle() {
        return isCycle;
    }

    public void setCycle(boolean cycle) {
        isCycle = cycle;
    }

    public Map<String, Object> getProperties() {
        return properties;
    }

    public void setProperties(Map<String, Object> properties) {
        this.properties = properties;
    }

    public List<TreeNodeDTO> getChildren() {
        return children;
    }

    public void setChildren(List<TreeNodeDTO> children) {
        this.children = children;
    }

    public void addChild(TreeNodeDTO child) {
        this.children.add(child);
    }
}
