// ==============================================================================
// 邻接表与图谱动态遍历演示数据初始化脚本
// 涵盖场景：
// 1. 组织架构与汇报树（树形结构，多级部门）
// 2. 制造物料清单与依赖拓扑 (BOM / DAG 有向无环图，包含多父节点邻接)
// 3. 族谱血缘关系 (Ancestors 溯源，包含父系与母系祖先)
// ==============================================================================

// 1. 清理已有数据 (可选：测试环境运行)
// MATCH (n:GraphNode) DETACH DELETE n;

// 2. 创建唯一性约束与索引（提高邻接遍历起点查找性能）
CREATE CONSTRAINT constraint_graphnode_id IF NOT EXISTS
FOR (n:GraphNode) REQUIRE n.id IS UNIQUE;

CREATE INDEX index_graphnode_type IF NOT EXISTS
FOR (n:GraphNode) ON (n.type);

// ------------------------------------------------------------------------------
// 场景一：组织架构邻接表 (树形多层级结构)
// 关系类型:
//   - PARENT_OF  : 部门上下级 (从根向下为子部门，反向为上级部门/祖先部门)
//   - REPORTS_TO : 岗位或人员层级汇报
// ------------------------------------------------------------------------------

// 创建集团与子公司 (L0 -> L1)
MERGE (root:GraphNode {id: 'CORP_001'})
SET root.name = '未来科技集团总公司',
    root.type = 'DEPARTMENT',
    root.level = 0,
    root.status = 'ACTIVE';

MERGE (tech:GraphNode {id: 'DEPT_TECH'})
SET tech.name = '核心研发中心',
    tech.type = 'DEPARTMENT',
    tech.level = 1,
    tech.status = 'ACTIVE';

MERGE (ops:GraphNode {id: 'DEPT_OPS'})
SET ops.name = '全球运营中心',
    ops.type = 'DEPARTMENT',
    ops.level = 1,
    ops.status = 'ACTIVE';

MERGE (finance:GraphNode {id: 'DEPT_FIN'})
SET finance.name = '集团财务中心',
    finance.type = 'DEPARTMENT',
    finance.level = 1,
    finance.status = 'ACTIVE';

// 创建研发中心二级部门 (L1 -> L2)
MERGE (ai:GraphNode {id: 'DEPT_AI'})
SET ai.name = '人工智能实验室',
    ai.type = 'DEPARTMENT',
    ai.level = 2,
    ai.status = 'ACTIVE';

MERGE (cloud:GraphNode {id: 'DEPT_CLOUD'})
SET cloud.name = '云原生与基础架构部',
    cloud.type = 'DEPARTMENT',
    cloud.level = 2,
    cloud.status = 'ACTIVE';

MERGE (bigdata:GraphNode {id: 'DEPT_DATA'})
SET bigdata.name = '大数据平台部',
    bigdata.type = 'DEPARTMENT',
    bigdata.level = 2,
    bigdata.status = 'ACTIVE';

// 创建人工智能实验室三级团队 (L2 -> L3)
MERGE (nlp:GraphNode {id: 'TEAM_NLP'})
SET nlp.name = '大模型与NLP组',
    nlp.type = 'TEAM',
    nlp.level = 3,
    nlp.status = 'ACTIVE';

MERGE (graphTeam:GraphNode {id: 'TEAM_GRAPH'})
SET graphTeam.name = '知识图谱与图计算组',
    graphTeam.type = 'TEAM',
    graphTeam.level = 3,
    graphTeam.status = 'ACTIVE';

MERGE (cv:GraphNode {id: 'TEAM_CV'})
SET cv.name = '计算机视觉组',
    cv.type = 'TEAM',
    cv.level = 3,
    cv.status = 'ACTIVE';

// 创建关键人员 (L4)
MERGE (emp1:GraphNode {id: 'EMP_1001'})
SET emp1.name = '张三 (图算法专家)',
    emp1.type = 'EMPLOYEE',
    emp1.level = 4,
    emp1.title = 'Tech Lead',
    emp1.status = 'ACTIVE';

MERGE (emp2:GraphNode {id: 'EMP_1002'})
SET emp2.name = '李四 (图数据库工程师)',
    emp2.type = 'EMPLOYEE',
    emp2.level = 4,
    emp2.title = 'Senior Engineer',
    emp2.status = 'ACTIVE';

// 建立组织机构邻接关系 (PARENT_OF)
// 注:必须先 MATCH 绑定两端节点再 MERGE 关系。Cypher 的 MERGE 对完全未绑定的模式
//     (例如 MERGE (:A)-[:R]->(:B))在整体不匹配时会连节点一起创建,导致撞唯一约束或产生裸节点。
MATCH (root:GraphNode {id: 'CORP_001'}), (tech:GraphNode {id: 'DEPT_TECH'})
MERGE (root)-[:PARENT_OF {weight: 1.0, established: '2010-01-01'}]->(tech);
MATCH (root:GraphNode {id: 'CORP_001'}), (ops:GraphNode {id: 'DEPT_OPS'})
MERGE (root)-[:PARENT_OF {weight: 1.0, established: '2010-01-01'}]->(ops);
MATCH (root:GraphNode {id: 'CORP_001'}), (finance:GraphNode {id: 'DEPT_FIN'})
MERGE (root)-[:PARENT_OF {weight: 1.0, established: '2010-01-01'}]->(finance);

MATCH (tech:GraphNode {id: 'DEPT_TECH'}), (ai:GraphNode {id: 'DEPT_AI'})
MERGE (tech)-[:PARENT_OF {weight: 1.0, established: '2015-06-01'}]->(ai);
MATCH (tech:GraphNode {id: 'DEPT_TECH'}), (cloud:GraphNode {id: 'DEPT_CLOUD'})
MERGE (tech)-[:PARENT_OF {weight: 1.0, established: '2015-06-01'}]->(cloud);
MATCH (tech:GraphNode {id: 'DEPT_TECH'}), (bigdata:GraphNode {id: 'DEPT_DATA'})
MERGE (tech)-[:PARENT_OF {weight: 1.0, established: '2016-03-01'}]->(bigdata);

MATCH (ai:GraphNode {id: 'DEPT_AI'}), (nlp:GraphNode {id: 'TEAM_NLP'})
MERGE (ai)-[:PARENT_OF {weight: 1.0, established: '2020-01-01'}]->(nlp);
MATCH (ai:GraphNode {id: 'DEPT_AI'}), (graphTeam:GraphNode {id: 'TEAM_GRAPH'})
MERGE (ai)-[:PARENT_OF {weight: 1.0, established: '2020-01-01'}]->(graphTeam);
MATCH (ai:GraphNode {id: 'DEPT_AI'}), (cv:GraphNode {id: 'TEAM_CV'})
MERGE (ai)-[:PARENT_OF {weight: 1.0, established: '2020-01-01'}]->(cv);

// 建立员工归属与汇报邻接关系 (BELONGS_TO / REPORTS_TO)
MATCH (emp1:GraphNode {id: 'EMP_1001'}), (graphTeam:GraphNode {id: 'TEAM_GRAPH'})
MERGE (emp1)-[:BELONGS_TO {joinedDate: '2021-05-10'}]->(graphTeam);
MATCH (emp2:GraphNode {id: 'EMP_1002'}), (graphTeam:GraphNode {id: 'TEAM_GRAPH'})
MERGE (emp2)-[:BELONGS_TO {joinedDate: '2022-08-15'}]->(graphTeam);
MATCH (emp2:GraphNode {id: 'EMP_1002'}), (emp1:GraphNode {id: 'EMP_1001'})
MERGE (emp2)-[:REPORTS_TO {channel: 'DIRECT'}]->(emp1);

// 跨部门矩阵汇报（虚线汇报，展示复杂邻接网络）
MATCH (emp1:GraphNode {id: 'EMP_1001'}), (bigdata:GraphNode {id: 'DEPT_DATA'})
MERGE (emp1)-[:REPORTS_TO {channel: 'DOTTED_LINE'}]->(bigdata);


// ------------------------------------------------------------------------------
// 场景二：工业物料清单与任务依赖邻接表 (DAG 有向无环图，包含多父节点)
// 关系类型:
//   - COMPOSED_OF : 组装包含关系
//   - DEPENDS_ON  : 工艺制造/前置依赖关系
// ------------------------------------------------------------------------------

// 智能电动车总装 (成品 L0)
MERGE (car:GraphNode {id: 'ITEM_EV_CAR'})
SET car.name = '全地形智能电动车X1',
    car.type = 'PRODUCT',
    car.level = 0;

// 一级大总成 (L1)
MERGE (battery:GraphNode {id: 'ITEM_BATTERY_PACK'})
SET battery.name = '800V高压超充动力电池包',
    battery.type = 'ASSEMBLY',
    battery.level = 1;

MERGE (chassis:GraphNode {id: 'ITEM_CHASSIS'})
SET chassis.name = '一体化线控底盘',
    chassis.type = 'ASSEMBLY',
    chassis.level = 1;

MERGE (cockpit:GraphNode {id: 'ITEM_SMART_COCKPIT'})
SET cockpit.name = '全景智慧座舱',
    cockpit.type = 'ASSEMBLY',
    cockpit.level = 1;

// 二级组件与物料 (L2)
MERGE (bms:GraphNode {id: 'ITEM_BMS_MODULE'})
SET bms.name = '智能电池管理BMS核心板',
    bms.type = 'SUB_ASSEMBLY',
    bms.level = 2;

MERGE (cell:GraphNode {id: 'ITEM_LFP_CELL'})
SET cell.name = '4680规格大圆柱电芯',
    cell.type = 'RAW_MATERIAL',
    cell.level = 3;

MERGE (chip:GraphNode {id: 'ITEM_AI_SOC'})
SET chip.name = '自研5nm自动驾驶主控芯片',
    chip.type = 'RAW_MATERIAL',
    chip.level = 3;

// 建立物料邻接关系 (COMPOSED_OF 与 DEPENDS_ON)
MATCH (car:GraphNode {id: 'ITEM_EV_CAR'}), (battery:GraphNode {id: 'ITEM_BATTERY_PACK'})
MERGE (car)-[:COMPOSED_OF {quantity: 1}]->(battery);
MATCH (car:GraphNode {id: 'ITEM_EV_CAR'}), (chassis:GraphNode {id: 'ITEM_CHASSIS'})
MERGE (car)-[:COMPOSED_OF {quantity: 1}]->(chassis);
MATCH (car:GraphNode {id: 'ITEM_EV_CAR'}), (cockpit:GraphNode {id: 'ITEM_SMART_COCKPIT'})
MERGE (car)-[:COMPOSED_OF {quantity: 1}]->(cockpit);

MATCH (battery:GraphNode {id: 'ITEM_BATTERY_PACK'}), (bms:GraphNode {id: 'ITEM_BMS_MODULE'})
MERGE (battery)-[:COMPOSED_OF {quantity: 1}]->(bms);
MATCH (battery:GraphNode {id: 'ITEM_BATTERY_PACK'}), (cell:GraphNode {id: 'ITEM_LFP_CELL'})
MERGE (battery)-[:COMPOSED_OF {quantity: 192}]->(cell);

// 依赖关系 (多父邻接示例：BMS 和 智慧座舱 共同依赖 自动驾驶主控芯片)
MATCH (bms:GraphNode {id: 'ITEM_BMS_MODULE'}), (chip:GraphNode {id: 'ITEM_AI_SOC'})
MERGE (bms)-[:DEPENDS_ON {criticality: 'HIGH'}]->(chip);
MATCH (cockpit:GraphNode {id: 'ITEM_SMART_COCKPIT'}), (chip:GraphNode {id: 'ITEM_AI_SOC'})
MERGE (cockpit)-[:DEPENDS_ON {criticality: 'CRITICAL'}]->(chip);


// ------------------------------------------------------------------------------
// 场景三：族谱与血缘关系 (Ancestors 溯源演示)
// 关系类型:
//   - PARENT_OF : 父母指向子女（逆向遍历即为寻找祖先 Ancestors）
// ------------------------------------------------------------------------------

// 曾祖辈 (Great-Grandparents)
MERGE (g_gp1:GraphNode {id: 'PERSON_G_GP1'})
SET g_gp1.name = '高祖/曾祖父-陈老太爷',
    g_gp1.type = 'PERSON',
    g_gp1.gender = 'MALE';

MERGE (g_gp2:GraphNode {id: 'PERSON_G_GP2'})
SET g_gp2.name = '曾祖母-林老太君',
    g_gp2.type = 'PERSON',
    g_gp2.gender = 'FEMALE';

// 祖父辈 (Grandparents)
MERGE (gp_father:GraphNode {id: 'PERSON_GP_F'})
SET gp_father.name = '祖父-陈伯勋',
    gp_father.type = 'PERSON',
    gp_father.gender = 'MALE';

MERGE (gp_mother:GraphNode {id: 'PERSON_GP_M'})
SET gp_mother.name = '祖母-王若云',
    gp_mother.type = 'PERSON',
    gp_mother.gender = 'FEMALE';

MERGE (out_gp_f:GraphNode {id: 'PERSON_OUT_GP_F'})
SET out_gp_f.name = '外祖父-李松年',
    out_gp_f.type = 'PERSON',
    out_gp_f.gender = 'MALE';

MERGE (out_gp_m:GraphNode {id: 'PERSON_OUT_GP_M'})
SET out_gp_m.name = '外祖母-赵敏芳',
    out_gp_m.type = 'PERSON',
    out_gp_m.gender = 'FEMALE';

// 父母辈 (Parents)
MERGE (father:GraphNode {id: 'PERSON_FATHER'})
SET father.name = '父亲-陈建国',
    father.type = 'PERSON',
    father.gender = 'MALE';

MERGE (mother:GraphNode {id: 'PERSON_MOTHER'})
SET mother.name = '母亲-李晓华',
    mother.type = 'PERSON',
    mother.gender = 'FEMALE';

// 子代与孙代 (Children & Grandchildren)
MERGE (self:GraphNode {id: 'PERSON_SELF'})
SET self.name = '本人-陈志远',
    self.type = 'PERSON',
    self.gender = 'MALE';

MERGE (child:GraphNode {id: 'PERSON_CHILD'})
SET child.name = '儿子-陈子涵',
    child.type = 'PERSON',
    child.gender = 'MALE';

// 建立血缘邻接图
MATCH (g_gp1:GraphNode {id: 'PERSON_G_GP1'}), (gp_father:GraphNode {id: 'PERSON_GP_F'})
MERGE (g_gp1)-[:PARENT_OF]->(gp_father);
MATCH (g_gp2:GraphNode {id: 'PERSON_G_GP2'}), (gp_father:GraphNode {id: 'PERSON_GP_F'})
MERGE (g_gp2)-[:PARENT_OF]->(gp_father);

MATCH (gp_father:GraphNode {id: 'PERSON_GP_F'}), (father:GraphNode {id: 'PERSON_FATHER'})
MERGE (gp_father)-[:PARENT_OF]->(father);
MATCH (gp_mother:GraphNode {id: 'PERSON_GP_M'}), (father:GraphNode {id: 'PERSON_FATHER'})
MERGE (gp_mother)-[:PARENT_OF]->(father);

MATCH (out_gp_f:GraphNode {id: 'PERSON_OUT_GP_F'}), (mother:GraphNode {id: 'PERSON_MOTHER'})
MERGE (out_gp_f)-[:PARENT_OF]->(mother);
MATCH (out_gp_m:GraphNode {id: 'PERSON_OUT_GP_M'}), (mother:GraphNode {id: 'PERSON_MOTHER'})
MERGE (out_gp_m)-[:PARENT_OF]->(mother);

MATCH (father:GraphNode {id: 'PERSON_FATHER'}), (self:GraphNode {id: 'PERSON_SELF'})
MERGE (father)-[:PARENT_OF]->(self);
MATCH (mother:GraphNode {id: 'PERSON_MOTHER'}), (self:GraphNode {id: 'PERSON_SELF'})
MERGE (mother)-[:PARENT_OF]->(self);

MATCH (self:GraphNode {id: 'PERSON_SELF'}), (child:GraphNode {id: 'PERSON_CHILD'})
MERGE (self)-[:PARENT_OF]->(child);


// ==============================================================================
// 常用动态遍历 Cypher 验证样例 (供开发者测试与参考)
// ==============================================================================

// 1. 纯动态向下遍历子孙（从集团向下展开 1~3 级所有部门）
// MATCH p = (s:GraphNode {id: 'CORP_001'})-[:PARENT_OF*1..3]->(t:GraphNode)
// RETURN s.name AS root, [n IN nodes(p) | n.name] AS pathNodes, [r IN relationships(p) | type(r)] AS rels, length(p) AS depth;

// 2. 纯动态向上回溯祖先 (Ancestors)
// 从 'PERSON_CHILD' 出发逆向回溯 1~4 层所有父辈及祖先
// MATCH p = (c:GraphNode {id: 'PERSON_CHILD'})<-[:PARENT_OF*1..4]-(ancestor:GraphNode)
// RETURN c.name AS origin, ancestor.name AS ancestor, length(p) AS generationBack, [n IN nodes(p) | n.name] AS lineagePath
// ORDER BY generationBack ASC;

// 3. 多关系类型复合动态遍历 (支持 PARENT_OF 或 REPORTS_TO)
// MATCH p = (s:GraphNode {id: 'EMP_1002'})-[r:REPORTS_TO|BELONGS_TO*1..3]-(target:GraphNode)
// RETURN s.name, type(r[0]), target.name, length(p);

// 4. APOC 路径动态扩展 (支持运行时通过参数动态传入关系字符串与深度)
// CALL apoc.path.expandConfig(
//   'PERSON_CHILD',
//   {
//     relationshipFilter: '<PARENT_OF',
//     minLevel: 1,
//     maxLevel: 4,
//     bfs: true,
//     uniqueness: 'NODE_GLOBAL'
//   }
// ) YIELD path
// RETURN [n IN nodes(path) | n.name] AS ancestorPath, length(path) AS depth;
