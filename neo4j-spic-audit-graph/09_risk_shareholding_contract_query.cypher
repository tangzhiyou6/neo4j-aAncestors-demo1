// =============================================================================
// 09 风险线索 → 3 层控股穿透 → 电话相同 → 【且 a、b 同签一份合同】
// -----------------------------------------------------------------------------
// 在原查询基础上新增条件：
//   a、b 之间还可能通过【合同】实体相连 —— 即两家企业都签订同一份合同：
//       (a)-[:`签订合同`]->(c:合同)<-[:`签订合同`]-(b)
//   若存在多份共同合同，只取其中一条（按签订时间最早的优先）。
//
// 模型依据（01_neo4j_ddl.cypher）：
//   (:企业)-[:`签订合同`]->(:合同)     方向：企业 → 合同（双方各自指向同一合同节点）
//   :合同 { contract_code, contract_name, gategory_name, contract_amount,
//           sign_time, status_name, payment_direction, ... }
//   (:企业)-[:`签订合同`]->(:合同) 边属性：contract_amount, contract_status, sign_time
//
// 配套数据：08_mock_data_risk_type.cypher + 10_mock_data_contract_extra.cypher
// =============================================================================


// =============================================================================
// 一、核心查询：在原语句上追加"同签一份合同"条件，多份合同只取一条
// =============================================================================
// 多合同取一条的写法：ORDER BY 之后用 collect(...)[0] 取首条
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

// ★ 新增条件：a、b 通过同一份合同实体相连（签订合同 边，方向均为 企业→合同）
MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)

// 多份共同合同时按签订时间升序，只保留第一条
WITH p0, p1, a, b, c, p2
ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH p0, p1, a, b,
     collect(p2)[0] AS p2,
     collect(c)[0]  AS 合同
RETURN p0,
       p1,
       p2,
       合同.contract_code   AS 合同编号,
       合同.contract_name   AS 合同名称,
       合同.contract_amount AS 合同金额,
       合同.sign_time       AS 签订时间,
       合同.status_name     AS 合同状态,
       a.org_name           AS 风险企业,
       b.org_name           AS 被控股企业,
       a.phonenumber        AS 共同电话,
       length(p1)           AS 持股穿透层数;


// =============================================================================
// 二、等价写法：子查询 LIMIT 1（Cypher 25 / Neo4j 5.23+，语义更直观）
// =============================================================================
// 每个 (a,b) 组合独立取一份最早签订的共同合同；无共同合同的组合直接不返回
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

CALL (a, b) {
  MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
  RETURN p2, c ORDER BY coalesce(c.sign_time, ''), c.object_key LIMIT 1
}
RETURN p0, p1, p2, c.contract_code AS 合同编号, c.sign_time AS 签订时间,
       a.org_name AS 风险企业, b.org_name AS 被控股企业;


// =============================================================================
// 三、宽松版：共同合同作为【可选证据】，不因缺少合同而丢掉控股关系
// =============================================================================
// 写法 A：OPTIONAL MATCH + collect（各版本通用，本文件采用）
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

OPTIONAL MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH p0, p1, a, b, c, p2
ORDER BY coalesce(c.sign_time, '') DESC, c.object_key
WITH p0, p1, a, b,
     collect(p2)[0] AS p2,
     collect(c)[0]  AS 合同
RETURN p0, p1, p2,
       coalesce(合同.contract_code, '（无共同合同）') AS 合同编号,
       合同.sign_time AS 签订时间,
       CASE WHEN 合同 IS NULL THEN '仅有控股关系' ELSE '控股关系 + 同签合同' END AS 证据类型,
       a.org_name AS 风险企业, b.org_name AS 被控股企业;


// 写法 B（等价，Neo4j 5.24+）：用 OPTIONAL CALL 子查询，空结果返回 null 而不丢行
// MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
// WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
// MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
// WHERE b <> a
//   AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
//   AND b.phonenumber = a.phonenumber
// OPTIONAL CALL (a, b) {
//   MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
//   RETURN p2, c ORDER BY coalesce(c.sign_time, ''), c.object_key LIMIT 1
// }
// RETURN p0, p1, p2,
//        coalesce(c.contract_code, '（无共同合同）') AS 合同编号,
//        a.org_name AS 风险企业, b.org_name AS 被控股企业;


// =============================================================================
// 四、对照版：不做"取一条"，把全部共同合同都列出来（核对用）
// =============================================================================
// 用来确认"取一条"到底丢掉了哪些合同
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
RETURN a.org_name AS 风险企业, b.org_name AS 被控股企业,
       c.contract_code AS 合同编号, c.sign_time AS 签订时间,
       count(*) OVER (PARTITION BY a.object_key, b.object_key) AS 该组合共同合同数
ORDER BY 风险企业, 签订时间;


// =============================================================================
// 五、把结果落图：为"控股 + 同签合同"的命中创建风险线索（可选）
// =============================================================================
MATCH (r0:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH a, b, c ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH a, b, collect(c)[0] AS c
MERGE (nr:ZSTP:`风险线索` {object_key: 'FX_AUTO_HT_' + a.object_key + '_' + b.object_key})
  ON CREATE SET nr.risk_type    = '企业电话相同',
                nr.risk_desc    = a.org_name + ' 与 ' + b.org_name + ' 电话相同（' + a.phonenumber +
                                  '），存在 ≤3 层控股关系，且双方共同签订合同 ' + c.contract_code,
                nr.risk_summary = '控股关系 + 同签合同 + 电话相同',
                nr.schema_name  = '风险线索'
MERGE (a)-[:`触发风险_企业` {object_key: 'FX_AUTO_HT_' + a.object_key + '_' + b.object_key + '_A'}]->(nr)
MERGE (b)-[:`触发风险_企业` {object_key: 'FX_AUTO_HT_' + a.object_key + '_' + b.object_key + '_B'}]->(nr)
RETURN nr.object_key AS 新增风险线索, nr.risk_desc AS 线索描述;


// =============================================================================
// 六、变体：合同条件放在两条链的【末端企业】之间
// =============================================================================
// 对应示意图的另一种解读：风险企业各自控股链的末端企业（如"某国电投企业"与
// "外部企业"）共签 1 号合同。此时合同不发生在 a 与 b 之间，而发生在 b 与另一条
// 链的末端 b2 之间。写法：把 b 的控股链结果两两配对后，再看它们是否同签合同。
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

WITH collect(DISTINCT b) AS 末端池
UNWIND 末端池 AS b1
UNWIND 末端池 AS b2
WITH b1, b2 WHERE b1.object_key < b2.object_key
MATCH p2 = (b1)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b2)
WITH b1, b2, c, p2 ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH b1, b2, collect(c)[0] AS 合同, collect(p2)[0] AS p2
RETURN b1.org_name AS 末端企业A, b2.org_name AS 末端企业B,
       合同.contract_code AS 合同编号, 合同.sign_time AS 签订时间,
       p2;


// =============================================================================
// 七、清理本文件产生的落图数据
// =============================================================================
// MATCH (n:ZSTP:`风险线索`) WHERE n.object_key STARTS WITH 'FX_AUTO_HT_' DETACH DELETE n;
