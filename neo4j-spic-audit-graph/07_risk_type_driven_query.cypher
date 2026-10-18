// =============================================================================
// 07 风险线索驱动的隐性关联查询
// -----------------------------------------------------------------------------
// ⚠ 语义已被 12_pair_risk_shareholding_contract.cypher 修正：
//    本文件取"风险企业 a + 由 a 穿透到的企业 b"；业务上更准确的口径是
//    "同一条风险线索下电话相同的两家企业 a、b，彼此在 3 层内存在控股关系"。
//    请以 12 为准，本文件保留作对照。
// =============================================================================
//
// 业务语义（对应审计图谱示意图）：
//   1. 从【风险线索】节点的 risk_type 出发（如 risk_type = '企业电话相同'）
//   2. 通过 (:企业)-[:触发风险_企业]->(:风险线索) 反向找到"有问题的企业"
//   3. 从这些企业出发，沿股东持股边最多穿透 3 层，找到其控股的企业
//   4. 验证/显示：风险企业与被控股企业之间的【电话相同】
//
// 模型依据（见 01_neo4j_ddl.cypher）：
//   (:企业)-[:`触发风险_企业`]->(:风险线索)          方向：企业 → 风险线索
//   (:企业)-[:`股东持股（%）企业-企业`]->(:企业)     方向：股东 → 被控股企业
//   :风险线索 { object_key, risk_type, risk_desc, risk_summary }
//
// 配套模拟数据：08_mock_data_risk_type.cypher（object_key 前缀 MOCK2_）
// =============================================================================


// =============================================================================
// 一、核心查询：risk_type 驱动 + 3 层控股穿透 + 电话相同
// =============================================================================
// 有向穿透：风险企业作为股东，沿持股边向下找它控股的企业，
//           且被控股企业电话与风险企业相同 → 命中
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
RETURN r.risk_type                              AS 风险类型,
       r.risk_desc                              AS 风险描述,
       a.org_name                               AS 风险企业,
       b.org_name                               AS 被控股企业,
       a.phonenumber                            AS 共同电话,
       length(p)                                AS 持股穿透层数,
       [n IN nodes(p) | coalesce(n.org_name, labels(n)[0])] AS 控股链路
ORDER BY 风险企业, 持股穿透层数;


// =============================================================================
// 二、参数化版本（Browser 中先执行 :param，再执行查询；适合接入应用）
// =============================================================================
// :param risk_type => '企业电话相同';
//
// MATCH (r:ZSTP:`风险线索` {risk_type: $risk_type})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
// WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
// MATCH p = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
// WHERE b <> a
//   AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
//   AND b.phonenumber = a.phonenumber
// RETURN r.risk_type AS 风险类型,
//        a.org_name  AS 风险企业, b.org_name AS 被控股企业,
//        a.phonenumber AS 共同电话, length(p) AS 持股穿透层数,
//        [n IN nodes(p) | coalesce(n.org_name, labels(n)[0])] AS 控股链路;


// =============================================================================
// 三、先看全景：风险线索 → 涉事企业 → 3 层控股链（不做电话过滤，先审链路）
// =============================================================================
// 调试/核对用：把每条风险线索牵出的企业及其 3 层控股链完整铺开
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
OPTIONAL MATCH p = (a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`)
RETURN r.risk_type    AS 风险类型,
       a.org_name     AS 风险企业,
       a.phonenumber  AS 风险企业电话,
       b.org_name     AS 链路末端企业,
       b.phonenumber  AS 末端企业电话,
       length(p)      AS 穿透层数,
       CASE WHEN b.phonenumber = a.phonenumber THEN '✔ 电话相同' ELSE '× 电话不同' END AS 判定
ORDER BY 风险企业, 穿透层数;


// =============================================================================
// 四、变体写法
// =============================================================================

// 4.1 无向穿透：不限定持股方向，3 层内任意相连即算关联（覆盖"该企业是被控股方"的场景）
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
RETURN a.org_name AS 风险企业, b.org_name AS 关联企业, a.phonenumber AS 共同电话,
       length(p) AS 穿透层数,
       [n IN nodes(p) | coalesce(n.org_name, labels(n)[0])] AS 关联链路;

// 4.2 风险类型不写死：把 6 类隐性关联线索全部拉出来逐一穿透（risk_type 作驱动游标）
MATCH (r:ZSTP:`风险线索`)<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
RETURN r.risk_type AS 风险类型, a.org_name AS 风险企业, b.org_name AS 被控股企业,
       a.phonenumber AS 共同电话, length(p) AS 持股穿透层数;

// 4.3 换个 risk_type 值即可复用同一查询骨架，例如注册地址相同：
//     把 {risk_type: '企业电话相同'} 换成 {risk_type: '注册地址相同'}，
//     并把 a.phonenumber / b.phonenumber 换成 a.reglocation / b.reglocation。
//     示意图中的 6 类 risk_type 取值：
//       '企业电话相同'、'注册地址相同'、'高管姓名相同'、
//       '股东相同（自然人）'、'股东相同（企业）'、'股东与高管姓名相同'


// =============================================================================
// 五、追问一层：两条控股链的"末端企业"之间是否也电话相同
// =============================================================================
// 对应示意图的故事：某国电投企业 与 外部企业 分属两条控股链末端，
// 二者电话也相同 —— 把它们配对找出来（穿透结果再两两比对）
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH (a)-[:`股东持股（%）企业-企业`*1..3]->(end1:ZSTP:`企业`)
WHERE end1.phonenumber = a.phonenumber
WITH collect(DISTINCT end1) AS 末端企业池
UNWIND 末端企业池 AS e1
UNWIND 末端企业池 AS e2
WITH e1, e2 WHERE e1.object_key < e2.object_key
RETURN e1.org_name AS 末端企业A, e2.org_name AS 末端企业B,
       e1.phonenumber AS 共同电话,
       [(a)-[:`股东持股（%）企业-企业`]->(m) | m.org_name] AS 备注_中间层示例;


// =============================================================================
// 六、把命中结果落成风险线索（可选，审计闭环）
// =============================================================================
// 将穿透命中写成新的风险线索节点 + 触发风险_企业 边（幂等，可重复执行）
MATCH (r0:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MERGE (nr:ZSTP:`风险线索` {object_key: 'FX_AUTO_PHONE_' + a.object_key + '_' + b.object_key})
  ON CREATE SET nr.risk_type    = '企业电话相同',
                nr.risk_desc    = a.org_name + ' 通过 ≤3 层控股链控制 ' + b.org_name +
                                  '，且两家企业登记电话相同（' + a.phonenumber + '）',
                nr.risk_summary = '控股链穿透 + 电话相同',
                nr.schema_name  = '风险线索'
MERGE (a)-[e1:`触发风险_企业` {object_key: 'FX_AUTO_PHONE_' + a.object_key + '_' + b.object_key + '_A'}]->(nr)
MERGE (b)-[e2:`触发风险_企业` {object_key: 'FX_AUTO_PHONE_' + a.object_key + '_' + b.object_key + '_B'}]->(nr)
RETURN nr.object_key AS 新增风险线索, nr.risk_desc AS 线索描述;


// =============================================================================
// 七、清理本查询的自动落图数据（不删模拟数据本身）
// =============================================================================
// MATCH (n:ZSTP:`风险线索`) WHERE n.object_key STARTS WITH 'FX_AUTO_PHONE_' DETACH DELETE n;
