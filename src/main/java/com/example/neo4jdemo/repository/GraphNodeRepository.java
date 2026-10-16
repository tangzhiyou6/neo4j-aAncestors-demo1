package com.example.neo4jdemo.repository;

import com.example.neo4jdemo.entity.GraphNode;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 基础节点 Spring Data Neo4j Repository
 */
@Repository
public interface GraphNodeRepository extends Neo4jRepository<GraphNode, String> {

    Optional<GraphNode> findById(String id);

    List<GraphNode> findByType(String type);

    List<GraphNode> findByLevel(Integer level);
}
