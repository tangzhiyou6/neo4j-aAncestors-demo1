package com.example.neo4jdemo.service;

import com.example.neo4jdemo.constant.TraversalDirection;
import com.example.neo4jdemo.dto.AdjacencyListDTO;
import com.example.neo4jdemo.dto.TraversalRequest;
import com.example.neo4jdemo.dto.TraversalResultDTO;

import java.util.List;

/**
 * 邻接表动态遍历服务接口
 */
public interface AdjacencyTraversalService {

    /**
     * 通用纯动态邻接表图遍历
     *
     * @param request 包含动态关系、方向、步长、过滤条件等请求参数
     * @return 包含邻接表、层级树、路径链条等在内的统一结果 DTO
     */
    TraversalResultDTO traverse(TraversalRequest request);

    /**
     * 业务便捷方法：向上回溯所有祖先 (Ancestors)
     *
     * @param nodeId 起始节点 ID
     * @param relationshipTypes 动态关系类型列表（如 ["PARENT_OF"]）
     * @param maxHops 最大回溯代数/跳数
     * @return 祖先树状/列表结果
     */
    TraversalResultDTO findAncestors(String nodeId, List<String> relationshipTypes, int maxHops);

    /**
     * 业务便捷方法：向下展开所有子孙/下级 (Descendants)
     *
     * @param nodeId 起始节点 ID
     * @param relationshipTypes 动态关系类型列表
     * @param maxHops 最大展开深度
     * @return 子孙树状/列表结果
     */
    TraversalResultDTO findDescendants(String nodeId, List<String> relationshipTypes, int maxHops);

    /**
     * 获取单跳直接邻接表 (1-hop 直接邻居)
     *
     * @param nodeId 节点 ID
     * @param direction 方向
     * @return 邻接表结构
     */
    AdjacencyListDTO getDirectAdjacency(String nodeId, TraversalDirection direction);
}
