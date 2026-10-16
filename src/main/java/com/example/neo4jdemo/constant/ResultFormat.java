package com.example.neo4jdemo.constant;

/**
 * 遍历结果展现格式
 */
public enum ResultFormat {
    /**
     * 经典邻接表结构 (Map<NodeId, List<AdjacencyItem>>)
     */
    ADJACENCY_LIST,

    /**
     * 多叉树形/层级嵌套结构 (以起点为根节点的 TreeNode 层次树)
     */
    TREE,

    /**
     * 扁平节点集合 (适合仅需要获取所有触达节点或祖先清单)
     */
    FLAT_LIST,

    /**
     * 完整拓扑路径链条列表
     */
    PATH_LIST
}
