// =============================================================================
// 隐性关联关系识别 · 企业电话相同 + 注册地址相同（≤3 层关联）
// -----------------------------------------------------------------------------
// 适用模型 : 本图谱（顶点统一带 :ZSTP 标签，业务标签中文）
// 涉及属性 : 企业.phonenumber（联系电话）、企业.reglocation（注册地址）
// 对应规则 : 风险线索【企业电话相同 / 注册地址相同】
//            图中"股东持股（%）企业（3层）"→ 两企业间最多 3 跳可达
//
// 性能提示 :
//   · same-property 比较无法走索引，勿在百万级节点上直接跑 O(n²) 笛卡尔积，
//     请用"按电话/地址分组聚合"的写法（见第三节）
//   · 变长路径 [*1..3] 在稠密图上会爆炸，务必用 shortestPath 限定
// =============================================================================


// =============================================================================
// 一、基础版：两企业电话相同（不要求图上有路径）
// =============================================================================

// 1.1 电话相同的企业对（object_key 排序去重，避免 A-B / B-A 重复）
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber  IS NOT NULL AND trim(a.phonenumber) <> ''
  AND a.phonenumber = b.phonenumber
RETURN a.org_name    AS 企业A,
       b.org_name    AS 企业B,
       a.phonenumber AS 共同电话;

// 1.2 注册地址相同的企业对
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.reglocation  IS NOT NULL AND trim(a.reglocation) <> ''
  AND a.reglocation = b.reglocation
RETURN a.org_name    AS 企业A,
       b.org_name    AS 企业B,
       a.reglocation AS 共同注册地址;

// 1.3 电话相同 OR 注册地址相同（一张表看全）
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND (
        (a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> '' AND a.phonenumber = b.phonenumber)
     OR (a.reglocation IS NOT NULL AND trim(a.reglocation) <> '' AND a.reglocation = b.reglocation)
      )
WITH a, b,
     CASE WHEN a.phonenumber = b.phonenumber
          AND trim(coalesce(a.phonenumber,'')) <> '' THEN a.phonenumber END AS 同电话,
     CASE WHEN a.reglocation = b.reglocation
          AND trim(coalesce(a.reglocation,'')) <> '' THEN a.reglocation END AS 同地址
WHERE 同电话 IS NOT NULL OR 同地址 IS NOT NULL
RETURN a.org_name AS 企业A, b.org_name AS 企业B, 同电话, 同地址;


// =============================================================================
// 二、核心版：属性相同 且 两企业在图上 ≤3 层可达
// -----------------------------------------------------------------------------
// "最多 3 层" 用 shortestPath 表达：只在真正存在 1~3 跳路径时才命中，
// 避免无路径的企业对白白做笛卡尔积。
// =============================================================================

// 2.1 电话相同 + ≤3 跳关联
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND a.phonenumber = b.phonenumber
MATCH p = shortestPath((a)-[*1..3]-(b))
RETURN a.org_name   AS 企业A,
       b.org_name   AS 企业B,
       a.phonenumber AS 共同电话,
       length(p)    AS 关联跳数,
       [n IN nodes(p) | coalesce(n.org_name, n.name, labels(n)[0])] AS 关联路径;

// 2.2 注册地址相同 + ≤3 跳关联
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.reglocation IS NOT NULL AND trim(a.reglocation) <> ''
  AND a.reglocation = b.reglocation
MATCH p = shortestPath((a)-[*1..3]-(b))
RETURN a.org_name    AS 企业A,
       b.org_name    AS 企业B,
       a.reglocation AS 共同注册地址,
       length(p)     AS 关联跳数,
       [n IN nodes(p) | coalesce(n.org_name, n.name, labels(n)[0])] AS 关联路径;

// 2.3 电话与注册地址【同时】相同 + ≤3 跳（规则强度最高，命中即可重点核查）
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> '' AND a.phonenumber = b.phonenumber
  AND a.reglocation IS NOT NULL AND trim(a.reglocation) <> '' AND a.reglocation = b.reglocation
MATCH p = shortestPath((a)-[*1..3]-(b))
RETURN a.org_name AS 企业A, b.org_name AS 企业B,
       a.phonenumber AS 共同电话, a.reglocation AS 共同注册地址,
       length(p) AS 关联跳数;


// =============================================================================
// 三、大数据量版：先按电话/地址分组，再做路径判定（推荐生产使用）
// -----------------------------------------------------------------------------
// 思路：把"比较 O(n²)"降为"分组 O(n) + 组内配对"，
//       然后只对配对结果做 shortestPath。
// =============================================================================

// 3.1 按电话分组找共享同一电话的企业组
MATCH (a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
WITH a.phonenumber AS 共同电话, collect(a) AS 企业组
WHERE size(企业组) > 1
UNWIND 企业组[0..] AS b
WITH 企业组[0] AS a, b, 共同电话
WHERE a.object_key < b.object_key
OPTIONAL MATCH p = shortestPath((a)-[*1..3]-(b))
RETURN a.org_name AS 企业A, b.org_name AS 企业B, 共同电话,
       CASE WHEN p IS NULL THEN '无图上关联' ELSE toString(length(p)) + ' 跳' END AS 关联度
ORDER BY 关联度, 企业A;

// 3.2 按注册地址分组找共享同一地址的企业组
MATCH (a:ZSTP:`企业`)
WHERE a.reglocation IS NOT NULL AND trim(a.reglocation) <> ''
WITH a.reglocation AS 共同地址, collect(a) AS 企业组
WHERE size(企业组) > 1
UNWIND 企业组[0..] AS b
WITH 企业组[0] AS a, b, 共同地址
WHERE a.object_key < b.object_key
OPTIONAL MATCH p = shortestPath((a)-[*1..3]-(b))
RETURN a.org_name AS 企业A, b.org_name AS 企业B, 共同地址,
       CASE WHEN p IS NULL THEN '无图上关联' ELSE toString(length(p)) + ' 跳' END AS 关联度
ORDER BY 关联度, 企业A;


// =============================================================================
// 四、限定路径只走"股权/人事"边（对应图中"股东持股（%）企业（3层）"）
// -----------------------------------------------------------------------------
// 若"3 层"特指股权穿透链路（而非任意关系），请限定关系类型，
// 避免被"签订合同""开票"这类业务边稀释结果。
// =============================================================================
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> '' AND a.phonenumber = b.phonenumber
MATCH p = shortestPath(
  (a)-[:`股东持股（%）企业-企业`
     |`股东持股（%）企业-自然人`
     |`担任/曾任企业法人`
     |`担任/曾任企业高管`*1..3]-(b)
)
RETURN a.org_name AS 企业A, b.org_name AS 企业B, a.phonenumber AS 共同电话,
       length(p) AS 股权人事链跳数,
       [r IN relationships(p) | type(r)] AS 链路构成;


// =============================================================================
// 五、地址归一化（可选）：真实地址常因省市区/空格/全半角差异判不等
// -----------------------------------------------------------------------------
// 生产建议在 ETL 阶段归一化并落一个 reglocation_norm 属性 + 建索引；
// 下面是查询期临时归一化的写法（去空格、全角括号转半角、去省市区后缀）。
// =============================================================================
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
WITH a, b,
     trim(replace(replace(replace(replace(a.reglocation,'（','('),'）',')'),'省',''),'市','')) AS 地址A,
     trim(replace(replace(replace(replace(b.reglocation,'（','('),'）',')'),'省',''),'市','')) AS 地址B
WHERE 地址A IS NOT NULL AND trim(地址A) <> '' AND 地址A = 地址B
RETURN a.org_name AS 企业A, b.org_name AS 企业B, 地址A AS 归一化后共同地址;


// =============================================================================
// 六、把命中结果落成"风险线索"节点（对应图中右侧五边形）
// -----------------------------------------------------------------------------
// 复用模型里的 :风险线索 顶点与 触发风险_企业 边，幂等可重复执行。
// =============================================================================
MATCH (a:ZSTP:`企业`), (b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> '' AND a.phonenumber = b.phonenumber
  AND a.reglocation IS NOT NULL AND trim(a.reglocation) <> '' AND a.reglocation = b.reglocation
MATCH p = shortestPath((a)-[*1..3]-(b))
MERGE (f:ZSTP:`风险线索` {
         object_key: 'FXXS_TELADDR_' + a.object_key + '_' + b.object_key })
  ON CREATE SET f.risk_type    = '隐性关联关系',
                f.risk_desc    = 'IF 企业电话相同 AND 注册地址相同 AND 3层内存在关联 THEN 命中隐性关联风险',
                f.risk_summary = a.org_name + ' 与 ' + b.org_name
                                 + ' 电话与注册地址相同，且 ' + toString(length(p)) + ' 跳内存在关联',
                f.schema_name  = 'dws_dsjsj_zstp_vertex_fxxs'
MERGE (a)-[ra:`触发风险_企业` {
         object_key: 'E_FXXS_TELADDR_A_' + a.object_key + '_' + b.object_key }]->(f)
  ON CREATE SET ra.schema_name = 'dws_dsjsj_zstp_edge_qy_cffx'
MERGE (b)-[rb:`触发风险_企业` {
         object_key: 'E_FXXS_TELADDR_B_' + a.object_key + '_' + b.object_key }]->(f)
  ON CREATE SET rb.schema_name = 'dws_dsjsj_zstp_edge_qy_cffx'
RETURN a.org_name AS 企业A, b.org_name AS 企业B, f.risk_summary AS 生成的风险线索;


// =============================================================================
// 七、附：图中另外四条隐性关联规则的 Cypher（同源模型的配套写法）
// =============================================================================

// 7.1 股东相同（自然人）—— 同一自然人是两家企业的股东
MATCH (z:ZSTP:`自然人`)-[:`股东持股（%）企业-自然人`]->(a:ZSTP:`企业`)
MATCH (z)-[:`股东持股（%）企业-自然人`]->(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
RETURN a.org_name AS 企业A, b.org_name AS 企业B, z.name AS 共同自然人股东;

// 7.2 股东相同（企业）—— 同一企业是两家企业的股东
MATCH (sh:ZSTP:`企业`)-[:`股东持股（%）企业-企业`]->(a:ZSTP:`企业`)
MATCH (sh)-[:`股东持股（%）企业-企业`]->(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
RETURN a.org_name AS 企业A, b.org_name AS 企业B, sh.org_name AS 共同企业股东;

// 7.3 高管姓名相同 —— 同一自然人（或同名自然人）在两家任高管
MATCH (z:ZSTP:`自然人`)-[:`担任/曾任企业高管`]->(a:ZSTP:`企业`)
MATCH (z)-[:`担任/曾任企业高管`]->(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
RETURN a.org_name AS 企业A, b.org_name AS 企业B, z.name AS 共同高管;

// 7.4 股东与高管姓名相同 —— 甲企业的股东 与 乙企业的高管 同名（含同一人）
MATCH (z1:ZSTP:`自然人`)-[:`股东持股（%）企业-自然人`]->(a:ZSTP:`企业`)
MATCH (z2:ZSTP:`自然人`)-[:`担任/曾任企业高管`]->(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND z1.name IS NOT NULL AND trim(z1.name) <> '' AND z1.name = z2.name
RETURN a.org_name AS 企业A, b.org_name AS 企业B, z1.name AS 同名自然人,
       z1.object_key = z2.object_key AS 是否同一人;


// =============================================================================
// 八、验证（用 02_neo4j_init_data.cypher 的种子数据应能命中）
// =============================================================================
// 种子数据里 QY_HXJS（华信建设）与 QY_BJDL（北京电力）没有相同电话/地址，
// 属于"有图上关联但属性不同"；想验证本脚本，可先把两家企业的
// phonenumber / reglocation 改成相同值再跑第二、三节：
//
// MATCH (n:ZSTP:`企业`) WHERE n.object_key IN ['QY_BJDL','QY_HXJS']
// SET n.phonenumber='010-88886666', n.reglocation='北京市西城区金融大街';
// 然后执行 2.3，应返回 1 条命中（3 跳内可达）。
// =============================================================================
