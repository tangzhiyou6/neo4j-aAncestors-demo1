package com.example.neo4jdemo.constant;

/**
 * 动态遍历实现策略
 */
public enum TraversalStrategyType {
    /**
     * Spring Data Neo4j 官方推荐方案：Cypher-DSL AST 强类型动态构建
     * 特点：零Cypher注入风险，原生驱动集成，无需额外插件
     */
    CYPHER_DSL,

    /**
     * 安全参数化 Cypher 模板动态拼接
     * 特点：灵活直观，针对动态关系和变长路径做严格白名单校验
     */
    DYNAMIC_TEMPLATE,

    /**
     * Neo4j APOC 路径扩展函数过程 (apoc.path.expandConfig)
     * 特点：支持超大规模图、复杂无环校验、BFS/DFS修剪算法
     */
    APOC_EXPAND
}
