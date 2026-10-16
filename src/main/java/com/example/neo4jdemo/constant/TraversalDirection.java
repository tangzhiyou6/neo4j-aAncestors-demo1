package com.example.neo4jdemo.constant;

/**
 * 动态遍历方向枚举
 */
public enum TraversalDirection {
    /**
     * 正向出边 (->)
     * 例如：找下级部门、找子组件、找子女
     */
    OUTGOING,

    /**
     * 反向入边 (<-)
     * 例如：找上级部门、找父级组件、向上回溯祖先 (Ancestors)
     */
    INCOMING,

    /**
     * 双向无向边 (-)
     * 例如：查找任意相连的关联网络
     */
    BOTH
}
