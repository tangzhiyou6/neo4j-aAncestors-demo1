# Spring Data Neo4j 邻接表纯动态遍历方案与工程实战

本项目演示了在 **Spring Boot 3.x + Spring Data Neo4j (SDN 7.x)** 体系下，如何实现**邻接表（Adjacency List）纯动态图遍历**。

涵盖：
- 运行时动态指定**关系类型**（打破 `@Relationship` 静态注解绑定）
- 运行时动态指定**遍历方向**（`OUTGOING` 正向向下展开、`INCOMING` 反向溯源祖先 Ancestors、`BOTH` 双向网络）
- 运行时动态指定**跳数步长**（`*minHops..maxHops`）
- 运行时动态指定**节点/边属性过滤条件与边界保护**
- 多维结果组装（**经典邻接表结构**、**多叉树/祖先层级结构**、**扁平去重节点集合**、**完整路径链条**）
- 附带可直接导入初始化的全场景 Cypher 数据脚本

---

## 一、技术背景与核心痛点

### 1. 传统 SDN 的局限性
在传统的 Spring Data Neo4j 实体定义中，通常使用 `@Relationship` 注解：
```java
@Node("Department")
public class Department {
    @Relationship(type = "PARENT_OF", direction = Direction.OUTGOING)
    private List<Department> children;
}
```
**痛点**：
- **无法运行时改变关系类型**：如果系统有 `PARENT_OF`、`REPORTS_TO`、`DEPENDS_ON`、`COMPOSED_OF` 等多种关系，或者用户在前端自定义关系类型，注解在编译期已经写死。
- **无法动态反向追溯**：同一张图谱，查“下级所有部门”是正向，查“上级所有祖先”是反向。静态映射必须写两套反向实体，冗余且繁琐。
- **动态变长多跳失控**：声明式实体映射深层级联时容易引发 N+1 查询与内存雪崩。

### 2. Cypher 原生语法的硬限制
Neo4j 的 Cypher 语句**不支持**将关系类型和变长步长作为命名参数绑定：
```cypher
// ❌ 错误！Neo4j 会抛出 SyntaxError，不支持关系类型参数化
MATCH (n)-[:$relType*1..$maxDepth]->(m) RETURN m;
```

---

## 二、三种纯动态遍历落地方案对比

| 方案 | 技术核心 | 优点 | 缺点 / 适用场景 |
| :--- | :--- | :--- | :--- |
| **方案 1：Cypher-DSL + Neo4jClient (强烈推荐)** | Neo4j 官方 AST 构建器 (`neo4j-cypher-dsl`) | 强类型安全、编译期校验、零 Cypher 注入风险、无需外部依赖 | **企业级首选**，SDN 深度集成 |
| **方案 2：动态模板 + 白名单校验 + Neo4jClient** | 正则白名单过滤 + 预编译参数安全绑定 | 代码简单直观、支持特殊模式扩展 | 需要严格防范注入漏洞 |
| **方案 3：APOC 路径扩展 (`apoc.path.expandConfig`)** | Neo4j APOC 存储过程 | 原生参数支持关系过滤表达式、深度，支持复杂剪枝/BFS/DFS | 依赖 Neo4j 安装 APOC 插件 |

本项目完整实现了上述三种策略，并通过策略模式（Strategy Pattern）解耦，支持客户端按需一键切换。

---

## 三、项目核心架构设计

```
com.example.neo4jdemo
├── Neo4jAdjacencyDemoApplication.java   # Spring Boot 主启动类
├── constant
│   ├── ResultFormat.java              # 结果展现格式 (ADJACENCY_LIST, TREE, FLAT_LIST, PATH_LIST)
│   ├── TraversalDirection.java        # 遍历方向 (OUTGOING, INCOMING, BOTH)
│   └── TraversalStrategyType.java     # 策略枚举 (CYPHER_DSL, DYNAMIC_TEMPLATE, APOC_EXPAND)
├── dto
│   ├── TraversalRequest.java          # 动态遍历入参
│   ├── TraversalResultDTO.java        # 统一出参容器
│   ├── AdjacencyListDTO.java          # 经典邻接表结构
│   ├── TreeNodeDTO.java               # 多叉树/祖先层级结构 (含环检测保护)
│   ├── PathDTO.java                   # 完整路径明细
│   ├── GraphNodeDTO.java              # 通用节点 DTO
│   └── GraphEdgeDTO.java              # 通用边 DTO
├── entity
│   └── GraphNode.java                 # 基础图节点实体
├── repository
│   └── GraphNodeRepository.java       # SDN 基础仓库
├── service
│   ├── AdjacencyTraversalService.java # 业务门面接口
│   ├── impl
│   │   └── AdjacencyTraversalServiceImpl.java
│   ├── strategy                       # 动态遍历核心策略
│   │   ├── DynamicTraversalStrategy.java
│   │   ├── CypherDslTraversalStrategy.java
│   │   ├── TemplateTraversalStrategy.java
│   │   └── ApocTraversalStrategy.java
│   └── assembler
│       └── AdjacencyAssembler.java    # 图数据 -> 邻接表/树/路径转换组装器
└── controller
    └── AdjacencyTraversalController.java # REST API 控制器
```

---

## 四、核心代码实现剖析

### 1. 方案一：基于 Cypher-DSL 的纯动态 AST 构建
```java
// 1. 动态节点与标签
Node startNode = Cypher.node(label).named("s");
Node targetNode = Cypher.node(targetLabel).named("t");

// 2. 动态关系与方向 (OUTGOING / INCOMING / BOTH)
RelationshipPattern relPattern;
switch (request.getDirection()) {
    case OUTGOING -> relPattern = startNode.relationshipTo(targetNode, relTypes).length(min, max);
    case INCOMING -> relPattern = startNode.relationshipFrom(targetNode, relTypes).length(min, max);
    case BOTH     -> relPattern = startNode.relationshipBetween(targetNode, relTypes).length(min, max);
}

// 3. 命名路径与条件绑定
NamedPath namedPath = Cypher.path("p").definedBy(relPattern);
Condition condition = startNode.property("id").isEqualTo(Cypher.parameter("startId"));

// 4. 构建并由 Neo4jClient 执行
Statement statement = Cypher.match(namedPath)
        .where(condition)
        .returning(namedPath)
        .limit(Cypher.parameter("limit"))
        .build();

List<Path> paths = neo4jClient.query(statement.getCypher())
        .bindAll(parameters)
        .fetchAs(Path.class)
        .mappedBy((typeSystem, record) -> record.get("p").asPath())
        .all();
```

### 2. 数据转换层：图路径组装为邻接表与树
Neo4j Driver 返回的 `Path` 对象原生包含 `Iterable<Path.Segment>`：
- `segment.start()`: 当前跳起点
- `segment.relationship()`: 关系名及边属性
- `segment.end()`: 当前跳终点
组装器直接将连续段映射为 `Map<SourceId, List<AdjacencyItem>>`，并在构建多叉树时加入深度优先遍历与 `visited` 环检测，避免死循环。

---

## 五、初始化 Cypher 脚本说明

脚本位置：`src/main/resources/cypher/init-adjacency-data.cypher`

包含三大典型测试场景：
1. **组织架构邻接表**（集团 -> 业务中心 -> 部门 -> 小组 -> 人员，涵盖 `PARENT_OF`、`REPORTS_TO`、`BELONGS_TO` 虚实汇报线）
2. **物料清单与依赖拓扑 (BOM / DAG)**（成品 -> 动力电池/底盘/座舱 -> BMS/电芯/芯片，体现**多父节点**邻接）
3. **族谱与血缘关系 (Ancestors)**（曾祖父/母 -> 祖父/母/外祖父/母 -> 父母 -> 本人 -> 儿子，深度演示向上溯源 Ancestors）

### 导入方式：
- **方式 1（推荐）**：启动 Spring Boot 应用后，直接调用 REST 接口执行一键初始化：
  ```bash
  curl -X POST http://localhost:8080/api/graph/init-data
  ```
- **方式 2**：打开 Neo4j Browser，将 `src/main/resources/cypher/init-adjacency-data.cypher` 中的内容粘贴执行。
- **方式 3**：通过 `cypher-shell` 命令行执行：
  ```bash
  cypher-shell -u neo4j -p password -f src/main/resources/cypher/init-adjacency-data.cypher
  ```

---

## 六、REST API 调用示例

### 1. 核心接口：万能动态遍历 (`POST /api/graph/traverse`)

#### 场景 A：向上追溯祖先 (Ancestors) 并返回多叉树
```bash
curl -X POST http://localhost:8080/api/graph/traverse \
  -H "Content-Type: application/json" \
  -d '{
    "startNodeId": "PERSON_CHILD",
    "relationshipTypes": ["PARENT_OF"],
    "direction": "INCOMING",
    "minHops": 1,
    "maxHops": 4,
    "resultFormat": "TREE",
    "strategyType": "CYPHER_DSL"
  }'
```

#### 场景 B：向下展开组织架构子孙，返回经典邻接表
```bash
curl -X POST http://localhost:8080/api/graph/traverse \
  -H "Content-Type: application/json" \
  -d '{
    "startNodeId": "CORP_001",
    "relationshipTypes": ["PARENT_OF"],
    "direction": "OUTGOING",
    "minHops": 1,
    "maxHops": 3,
    "resultFormat": "ADJACENCY_LIST",
    "strategyType": "CYPHER_DSL"
  }'
```

#### 场景 C：多关系复合动态遍历 (同时遍历汇报线与归属线)
```bash
curl -X POST http://localhost:8080/api/graph/traverse \
  -H "Content-Type: application/json" \
  -d '{
    "startNodeId": "EMP_1002",
    "relationshipTypes": ["REPORTS_TO", "BELONGS_TO"],
    "direction": "BOTH",
    "minHops": 1,
    "maxHops": 2,
    "resultFormat": "PATH_LIST",
    "strategyType": "CYPHER_DSL"
  }'
```

### 2. 便捷查询接口
- **查询祖先**：`GET http://localhost:8080/api/graph/ancestors?nodeId=PERSON_CHILD&relType=PARENT_OF&maxHops=4`
- **展开子孙**：`GET http://localhost:8080/api/graph/descendants?nodeId=CORP_001&relType=PARENT_OF&maxHops=3`
- **1跳直接邻居**：`GET http://localhost:8080/api/graph/adjacency?nodeId=CORP_001&direction=OUTGOING`
