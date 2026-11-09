// =============================================================================
// 20 SPIC-CW-0107 疑似人为增加交易环节 · 优化版（6 段路径）
// -----------------------------------------------------------------------------
// 相对 17 号文件 / 你贴的版本的改动：
//   [1] 合同 ↔ 物料 不再写死单一关系：
//         · 物料侧：领用物料 或 消耗物料 都可
//         · 合同侧：采购合同(c1)  = 按采购合同入库
//                   中间销售合同(c2) = 按采购合同入库 或 按销售合同出库
//                   销售合同(c3)  = 按销售合同出库
//       说明：c1/c3 保留方向，避免无向签约把整条链反向再算一遍。
//   [2] 签订合同 改为无向匹配：
//         (企业)-[:签订合同]-(合同)-[:签订合同]-(企业)
//       企业→合同、合同→企业 两种落库方向都支持。
//   [3] 去掉未使用的 riskTypes 变量；保留"同一 (s1,gA,gB,s2,m) 取最早"。
//   [4] 中间两段单据要求 w2 <> w3，避免同一出/入库单被复用为两段销售。
//   [5] 物料-单据-合同先去重，再做签约方匹配，减少笛卡尔积。
//   [6] 新增"锚点版"：从指定国电投企业出发（见 一（B）），
//       锚点可落成 gA 或 gB；另附严格 gA 版。
//
// 配套模拟数据：本文件第四节（MOCK11_ 前缀）。
//
// 如需叠加 17 号文件的 0101 风险线索过滤，在"取最早"之后补：
//   MATCH (s1)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rl)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(gA)
//   MATCH (gB)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rr)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(s2)
//   WHERE rl.risk_type IN ['交易双方存在异常关联关系','企业电话相同','注册地址相同',
//                          '高管姓名相同','股东相同（自然人）','股东相同（企业）','股东与高管姓名相同']
//     AND rr.risk_type IN [...同上...]
// 本文件 A/B/C 已带 0101 线索，叠加后仍应命中这三组。
// =============================================================================

MATCH (m:dws_dsjsj_zstp_vertex_wl)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w1)
      <-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(c1:dws_dsjsj_zstp_vertex_ht)
MATCH (m)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w2)
      <-[:dws_dsjsj_zstp_edge_ht_acghtrk|dws_dsjsj_zstp_edge_ht_axshtck]-(c2:dws_dsjsj_zstp_vertex_ht)
MATCH (m)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w3)
      <-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c3:dws_dsjsj_zstp_vertex_ht)
WHERE c1 <> c2 AND c1 <> c3 AND c2 <> c3
  AND w2 <> w3
WITH DISTINCT m, w1, c1, w2, c2, w3, c3

// 外-内-内-外 签约链：签订合同按无向匹配
MATCH (s1:dws_dsjsj_zstp_vertex_qy)-[rq1:dws_dsjsj_zstp_edge_qy_qd]-(c1)-[rq2:dws_dsjsj_zstp_edge_qy_qd]-(gA:dws_dsjsj_zstp_vertex_qy)
MATCH (gA)-[rq3:dws_dsjsj_zstp_edge_qy_qd]-(c2)-[rq4:dws_dsjsj_zstp_edge_qy_qd]-(gB:dws_dsjsj_zstp_vertex_qy)
MATCH (gB)-[rq5:dws_dsjsj_zstp_edge_qy_qd]-(c3)-[rq6:dws_dsjsj_zstp_edge_qy_qd]-(s2:dws_dsjsj_zstp_vertex_qy)
WHERE s1 <> gA AND s1 <> gB AND s1 <> s2
  AND gA <> gB AND gA <> s2 AND gB <> s2
  AND s1.flag_gdtqy = '否' AND s2.flag_gdtqy = '否'
  AND gA.flag_gdtqy = '是' AND gB.flag_gdtqy = '是'

// 同一 (s1,gA,gB,s2,m) 只取三份合同签订时间最早的一组证据
WITH s1, gA, gB, s2, m, c1, c2, c3, w1, w2, w3,
     coalesce(rq1.sign_time, rq2.sign_time, c1.sign_time) AS t1,
     coalesce(rq3.sign_time, rq4.sign_time, c2.sign_time) AS t2,
     coalesce(rq5.sign_time, rq6.sign_time, c3.sign_time) AS t3
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH s1, gA, gB, s2, m,
     collect({c1: c1, c2: c2, c3: c3, w1: w1, w2: w2, w3: w3})[0] AS ev
WITH s1, gA, gB, s2, m,
     ev.c1 AS c1, ev.c2 AS c2, ev.c3 AS c3,
     ev.w1 AS w1, ev.w2 AS w2, ev.w3 AS w3

// 还原 6 段路径
MATCH p0 = (s1)-[:dws_dsjsj_zstp_edge_qy_qd]-(c1)-[:dws_dsjsj_zstp_edge_qy_qd]-(gA)
MATCH p1 = (gA)-[:dws_dsjsj_zstp_edge_qy_qd]-(c2)-[:dws_dsjsj_zstp_edge_qy_qd]-(gB)
MATCH p2 = (gB)-[:dws_dsjsj_zstp_edge_qy_qd]-(c3)-[:dws_dsjsj_zstp_edge_qy_qd]-(s2)
MATCH p3 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w1)<-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(c1)
MATCH p4 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w2)<-[:dws_dsjsj_zstp_edge_ht_acghtrk|dws_dsjsj_zstp_edge_ht_axshtck]-(c2)
MATCH p5 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w3)<-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c3)
RETURN DISTINCT p0, p1, p2, p3, p4, p5;


// =============================================================================
// 一（B）、锚点版：从指定国电投企业出发
// -----------------------------------------------------------------------------
// gA / gB 是链上两家国电投企业的"位置名"，二者角色对称：
// 同一个国电投节点既可能落在 gA，也可能落在 gB。
//   · B1（推荐）：锚点自动判断角色，锚在任一内部节点都能命中；
//   · B2：严格锚定 gA（锚点必须是左侧内部节点）。
// 把 object_key 换成目标企业即可；也可改用 org_credit_code：
//   MATCH (anchor:dws_dsjsj_zstp_vertex_qy {org_credit_code:'91320000134763504L'})
// =============================================================================

// -----------------------------------------------------------------------------
// B1 锚点可担任 gA 或 gB —— 用 MOCK11_QY_GDTB_B 也能命中 B 组
// -----------------------------------------------------------------------------
MATCH (anchor:dws_dsjsj_zstp_vertex_qy {object_key: 'MOCK11_QY_GDTB_B'})
WHERE anchor.flag_gdtqy = '是'

// 锚点相邻的两份不同合同：内侧合同(c2) + 锚点侧外围合同(c1 或 c3)
MATCH (anchor)-[rqNeighbor:dws_dsjsj_zstp_edge_qy_qd]-(cInner:dws_dsjsj_zstp_vertex_ht)
MATCH (anchor)-[rqOuterNear:dws_dsjsj_zstp_edge_qy_qd]-(cOuterAnchor:dws_dsjsj_zstp_vertex_ht)
WHERE cInner <> cOuterAnchor

// 内侧合同另一端 = 另一家国电投企业
MATCH (cInner)-[rqInnerFar:dws_dsjsj_zstp_edge_qy_qd]-(otherInner:dws_dsjsj_zstp_vertex_qy)
WHERE otherInner <> anchor AND otherInner.flag_gdtqy = '是'

// 锚点侧外围合同另一端 = 外部企业
MATCH (cOuterAnchor)-[rqOuterNearFar:dws_dsjsj_zstp_edge_qy_qd]-(outerAnchor:dws_dsjsj_zstp_vertex_qy)
WHERE outerAnchor.flag_gdtqy = '否'

// 另一侧外围合同 + 外部企业
MATCH (otherInner)-[rqOuterFarNear:dws_dsjsj_zstp_edge_qy_qd]-(cOuterOther:dws_dsjsj_zstp_vertex_ht)
MATCH (cOuterOther)-[rqOuterFar:dws_dsjsj_zstp_edge_qy_qd]-(outerOther:dws_dsjsj_zstp_vertex_qy)
WHERE outerOther.flag_gdtqy = '否'
  AND outerOther <> outerAnchor
  AND outerOther <> otherInner
  AND cOuterOther <> cInner
  AND cOuterOther <> cOuterAnchor

// 物流：同一物料贯穿三份合同（采购侧固定入库、销售侧固定出库、中间两者皆可）
MATCH (m:dws_dsjsj_zstp_vertex_wl)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w1)
      <-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(cPurchase:dws_dsjsj_zstp_vertex_ht)
MATCH (m)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w2)
      <-[:dws_dsjsj_zstp_edge_ht_acghtrk|dws_dsjsj_zstp_edge_ht_axshtck]-(cInner)
MATCH (m)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w3)
      <-[:dws_dsjsj_zstp_edge_ht_axshtck]-(cSales:dws_dsjsj_zstp_vertex_ht)
WHERE w2 <> w3
  AND cPurchase <> cSales
  AND ((cPurchase = cOuterAnchor AND cSales = cOuterOther)
    OR (cPurchase = cOuterOther  AND cSales = cOuterAnchor))

// 角色归一化，还原成 s1-c1-gA-c2-gB-c3-s2
WITH anchor, cInner, cOuterAnchor, cOuterOther, cPurchase, cSales,
     outerAnchor, outerOther, otherInner, m, w1, w2, w3,
     coalesce(rqNeighbor.sign_time, rqInnerFar.sign_time, cInner.sign_time) AS t2,
     coalesce(rqOuterNear.sign_time, rqOuterNearFar.sign_time, cOuterAnchor.sign_time) AS tOuterAnchor,
     coalesce(rqOuterFarNear.sign_time, rqOuterFar.sign_time, cOuterOther.sign_time) AS tOuterOther
WITH CASE WHEN cPurchase = cOuterAnchor
          THEN {s1: outerAnchor, gA: anchor,      gB: otherInner, s2: outerOther,
                c1: cPurchase,   c3: cSales,      t1: tOuterAnchor, t3: tOuterOther}
          ELSE {s1: outerOther,  gA: otherInner, gB: anchor,     s2: outerAnchor,
                c1: cPurchase,   c3: cSales,      t1: tOuterOther,  t3: tOuterAnchor}
     END AS r,
     m, cInner AS c2, w1, w2, w3, t2
WITH r.s1 AS s1, r.gA AS gA, r.gB AS gB, r.s2 AS s2,
     r.c1 AS c1, c2, r.c3 AS c3,
     r.t1 AS t1, t2, r.t3 AS t3,
     m, w1, w2, w3

// 同一 (s1,gA,gB,s2,m) 取最早
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH s1, gA, gB, s2, m,
     collect({c1: c1, c2: c2, c3: c3, w1: w1, w2: w2, w3: w3})[0] AS ev
WITH s1, gA, gB, s2, m,
     ev.c1 AS c1, ev.c2 AS c2, ev.c3 AS c3,
     ev.w1 AS w1, ev.w2 AS w2, ev.w3 AS w3

MATCH p0 = (s1)-[:dws_dsjsj_zstp_edge_qy_qd]-(c1)-[:dws_dsjsj_zstp_edge_qy_qd]-(gA)
MATCH p1 = (gA)-[:dws_dsjsj_zstp_edge_qy_qd]-(c2)-[:dws_dsjsj_zstp_edge_qy_qd]-(gB)
MATCH p2 = (gB)-[:dws_dsjsj_zstp_edge_qy_qd]-(c3)-[:dws_dsjsj_zstp_edge_qy_qd]-(s2)
MATCH p3 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w1)<-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(c1)
MATCH p4 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w2)<-[:dws_dsjsj_zstp_edge_ht_acghtrk|dws_dsjsj_zstp_edge_ht_axshtck]-(c2)
MATCH p5 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w3)<-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c3)
RETURN DISTINCT p0, p1, p2, p3, p4, p5;


// -----------------------------------------------------------------------------
// B2 严格 gA 版：锚点必须位于左侧内部节点（gA）
// -----------------------------------------------------------------------------
MATCH (gA:dws_dsjsj_zstp_vertex_qy {object_key: 'MOCK11_QY_GDTA_B'})
WHERE gA.flag_gdtqy = '是'

MATCH (gA)-[rq1:dws_dsjsj_zstp_edge_qy_qd]-(c1:dws_dsjsj_zstp_vertex_ht)
      -[rq2:dws_dsjsj_zstp_edge_qy_qd]-(s1:dws_dsjsj_zstp_vertex_qy)
WHERE s1.flag_gdtqy = '否'

MATCH (gA)-[rq3:dws_dsjsj_zstp_edge_qy_qd]-(c2:dws_dsjsj_zstp_vertex_ht)
      -[rq4:dws_dsjsj_zstp_edge_qy_qd]-(gB:dws_dsjsj_zstp_vertex_qy)
WHERE gB.flag_gdtqy = '是' AND gB <> gA

MATCH (gB)-[rq5:dws_dsjsj_zstp_edge_qy_qd]-(c3:dws_dsjsj_zstp_vertex_ht)
      -[rq6:dws_dsjsj_zstp_edge_qy_qd]-(s2:dws_dsjsj_zstp_vertex_qy)
WHERE s2.flag_gdtqy = '否'
  AND s1 <> s2
  AND c1 <> c2 AND c1 <> c3 AND c2 <> c3

MATCH (m:dws_dsjsj_zstp_vertex_wl)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w1)
      <-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(c1)
MATCH (m)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w2)
      <-[:dws_dsjsj_zstp_edge_ht_acghtrk|dws_dsjsj_zstp_edge_ht_axshtck]-(c2)
MATCH (m)
      -[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w3)
      <-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c3)
WHERE w2 <> w3
WITH DISTINCT s1, gA, gB, s2, m, c1, c2, c3, w1, w2, w3,
     coalesce(rq1.sign_time, rq2.sign_time, c1.sign_time) AS t1,
     coalesce(rq3.sign_time, rq4.sign_time, c2.sign_time) AS t2,
     coalesce(rq5.sign_time, rq6.sign_time, c3.sign_time) AS t3
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH s1, gA, gB, s2, m,
     collect({c1: c1, c2: c2, c3: c3, w1: w1, w2: w2, w3: w3})[0] AS ev
WITH s1, gA, gB, s2, m,
     ev.c1 AS c1, ev.c2 AS c2, ev.c3 AS c3,
     ev.w1 AS w1, ev.w2 AS w2, ev.w3 AS w3

MATCH p0 = (s1)-[:dws_dsjsj_zstp_edge_qy_qd]-(c1)-[:dws_dsjsj_zstp_edge_qy_qd]-(gA)
MATCH p1 = (gA)-[:dws_dsjsj_zstp_edge_qy_qd]-(c2)-[:dws_dsjsj_zstp_edge_qy_qd]-(gB)
MATCH p2 = (gB)-[:dws_dsjsj_zstp_edge_qy_qd]-(c3)-[:dws_dsjsj_zstp_edge_qy_qd]-(s2)
MATCH p3 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w1)<-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(c1)
MATCH p4 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w2)<-[:dws_dsjsj_zstp_edge_ht_acghtrk|dws_dsjsj_zstp_edge_ht_axshtck]-(c2)
MATCH p5 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl|dws_dsjsj_zstp_edge_wl_xhwl]->(w3)<-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c3)
RETURN DISTINCT p0, p1, p2, p3, p4, p5;


// =============================================================================
// 二、明细输出版（把上面最后 6 行 MATCH/RETURN 替换为下面这段）
// =============================================================================
// RETURN DISTINCT
//     s1.org_name           AS 外部采购相对方,
//     gA.org_name           AS 国电投企业A,
//     gB.org_name           AS 国电投企业B,
//     s2.org_name           AS 外部销售相对方,
//     m.matnr               AS 物料编码,
//     m.maktx               AS 物料名称,
//     c1.contract_code      AS 合同1, c1.sign_time AS 合同1签订时间,
//     c2.contract_code      AS 合同2, c2.sign_time AS 合同2签订时间,
//     c3.contract_code      AS 合同3, c3.sign_time AS 合同3签订时间,
//     coalesce(w1.mblnr, w1.vbeln) AS 单据1,
//     coalesce(w2.mblnr, w2.vbeln) AS 单据2,
//     coalesce(w3.mblnr, w3.vbeln) AS 单据3,
//     '疑似人为增加交易环节' AS 命中规则;


// =============================================================================
// 三、模拟数据说明（MOCK11_ 前缀）
// -----------------------------------------------------------------------------
// A 正例：标准有向签约 + 标准出入库              → 命中
// B 正例：签订合同全部反向落库（合同→企业）      → 命中（验证无向匹配）
// C 正例：混合签约方向 + c2 走"入库/领用"路径 → 命中
//         （与 A/B 的 c2"出库/消耗"路径合起来覆盖四种组合）
// D 反例：入库物料 104A、最终出库物料 104B       → 不命中（物料不贯通）
// E 反例：中间 gB 为非国电投企业                 → 不命中
// F 反例：采购合同只有一方签约                   → 不命中（缺签约方）
// =============================================================================

// =============================================================================
// 四、模拟数据 · 顶点
// =============================================================================

// —— 企业 ——
// A 标准正例
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_A'})  ON CREATE SET n.org_name='华能物资（北京）有限公司', n.flag_gdtqy='否', n.org_credit_code='91110108MA01AA1B2C', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_A'}) ON CREATE SET n.org_name='国家电投集团数字科技有限公司', n.flag_gdtqy='是', n.org_credit_code='91110000710935214M', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_A'}) ON CREATE SET n.org_name='国家电投集团信息技术有限公司', n.flag_gdtqy='是', n.org_credit_code='91110000100001234X', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_A'})  ON CREATE SET n.org_name='中电科汇智（天津）贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91120116MA05R7KQ8L', n.schema_name='dws_dsjsj_zstp_vertex_qy';
// B 签约反向正例
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_B'})  ON CREATE SET n.org_name='江苏远东特种电缆有限公司', n.flag_gdtqy='否', n.org_credit_code='91320282250216789K', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_B'}) ON CREATE SET n.org_name='国家电投集团江苏电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91320000134763504L', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_B'}) ON CREATE SET n.org_name='国家电投集团能源科技工程有限公司', n.flag_gdtqy='是', n.org_credit_code='91310115MA1K3X8F2P', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_B'})  ON CREATE SET n.org_name='上海申能物资贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91310101132234567T', n.schema_name='dws_dsjsj_zstp_vertex_qy';
// C 交叉关系正例
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_C'})  ON CREATE SET n.org_name='山东鲁电电气设备有限公司', n.flag_gdtqy='否', n.org_credit_code='91370100789123456D', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_C'}) ON CREATE SET n.org_name='国家电投集团山东电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91370000163001234E', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_C'}) ON CREATE SET n.org_name='国家电投集团山东能源有限公司', n.flag_gdtqy='是', n.org_credit_code='91370000163005678F', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_C'})  ON CREATE SET n.org_name='青岛海纳电气贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91370200123456789G', n.schema_name='dws_dsjsj_zstp_vertex_qy';
// D 物料不贯通反例
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_D'})  ON CREATE SET n.org_name='浙江晨光管业有限公司', n.flag_gdtqy='否', n.org_credit_code='91330500123456789H', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_D'}) ON CREATE SET n.org_name='国家电投集团浙江电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91330000142901234J', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_D'}) ON CREATE SET n.org_name='国家电投集团浙江新能源有限公司', n.flag_gdtqy='是', n.org_credit_code='91330000MA2A12345K', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_D'})  ON CREATE SET n.org_name='宁波甬能物资有限公司', n.flag_gdtqy='否', n.org_credit_code='91330200123456789L', n.schema_name='dws_dsjsj_zstp_vertex_qy';
// E 非国电投中间主体反例
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_E'})  ON CREATE SET n.org_name='广东南粤机电设备有限公司', n.flag_gdtqy='否', n.org_credit_code='91440101123456789M', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_E'}) ON CREATE SET n.org_name='国家电投集团广东电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91440000123456789N', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_E'}) ON CREATE SET n.org_name='广东粤电工程有限公司', n.flag_gdtqy='否', n.org_credit_code='91440101123456789P', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_E'})  ON CREATE SET n.org_name='深圳前海能源贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91440300123456789Q', n.schema_name='dws_dsjsj_zstp_vertex_qy';
// F 缺签约方反例
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_F'})  ON CREATE SET n.org_name='四川蜀能电力设备有限公司', n.flag_gdtqy='否', n.org_credit_code='91510100123456789R', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_F'}) ON CREATE SET n.org_name='国家电投集团四川电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91510000123456789S', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_F'}) ON CREATE SET n.org_name='国家电投集团西南能源有限公司', n.flag_gdtqy='是', n.org_credit_code='91510000MA6A12345T', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_F'})  ON CREATE SET n.org_name='成都锦江物资有限公司', n.flag_gdtqy='否', n.org_credit_code='91510100123456789U', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— 物料 ——
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_A'})  ON CREATE SET n.matnr='MOCK11-MAT-101',  n.maktx='MOCK11_服务器整机',        n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_B'})  ON CREATE SET n.matnr='MOCK11-MAT-102',  n.maktx='MOCK11_高压电缆',          n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_C'})  ON CREATE SET n.matnr='MOCK11-MAT-103',  n.maktx='MOCK11_干式变压器',        n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_DA'}) ON CREATE SET n.matnr='MOCK11-MAT-104A', n.maktx='MOCK11_无缝管（入库）',    n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_DB'}) ON CREATE SET n.matnr='MOCK11-MAT-104B', n.maktx='MOCK11_无缝管（出库）',    n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_E'})  ON CREATE SET n.matnr='MOCK11-MAT-105',  n.maktx='MOCK11_燃机备件',          n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_F'})  ON CREATE SET n.matnr='MOCK11-MAT-106',  n.maktx='MOCK11_断路器',            n.schema_name='dws_dsjsj_zstp_vertex_wl';

// —— 合同 ——
// A
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P01'}) ON CREATE SET n.contract_code='HT-2024-CG-1101', n.contract_name='MOCK11_服务器采购合同',     n.payment_direction='采购', n.sign_time='2024-03-05', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M01'}) ON CREATE SET n.contract_code='HT-2024-XS-1158', n.contract_name='MOCK11_服务器中间销售合同', n.payment_direction='销售', n.sign_time='2024-04-12', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S01'}) ON CREATE SET n.contract_code='HT-2024-XS-1233', n.contract_name='MOCK11_服务器销售合同',     n.payment_direction='销售', n.sign_time='2024-05-20', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// B
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P02'}) ON CREATE SET n.contract_code='HT-2024-CG-1202', n.contract_name='MOCK11_电缆采购合同',       n.payment_direction='采购', n.sign_time='2024-06-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M02'}) ON CREATE SET n.contract_code='HT-2024-XS-1268', n.contract_name='MOCK11_电缆中间销售合同',   n.payment_direction='销售', n.sign_time='2024-06-25', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S02'}) ON CREATE SET n.contract_code='HT-2024-XS-1299', n.contract_name='MOCK11_电缆销售合同',       n.payment_direction='销售', n.sign_time='2024-07-10', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// C
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P03'}) ON CREATE SET n.contract_code='HT-2024-CG-1303', n.contract_name='MOCK11_变压器采购合同',     n.payment_direction='采购', n.sign_time='2024-08-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M03'}) ON CREATE SET n.contract_code='HT-2024-XS-1345', n.contract_name='MOCK11_变压器中间销售合同', n.payment_direction='销售', n.sign_time='2024-08-15', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S03'}) ON CREATE SET n.contract_code='HT-2024-XS-1388', n.contract_name='MOCK11_变压器销售合同',     n.payment_direction='销售', n.sign_time='2024-09-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// D
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P04'}) ON CREATE SET n.contract_code='HT-2024-CG-1404', n.contract_name='MOCK11_无缝管采购合同',     n.payment_direction='采购', n.sign_time='2024-02-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M04'}) ON CREATE SET n.contract_code='HT-2024-XS-1466', n.contract_name='MOCK11_无缝管中间销售合同', n.payment_direction='销售', n.sign_time='2024-02-15', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S04'}) ON CREATE SET n.contract_code='HT-2024-XS-1499', n.contract_name='MOCK11_无缝管销售合同',     n.payment_direction='销售', n.sign_time='2024-03-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// E
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P05'}) ON CREATE SET n.contract_code='HT-2024-CG-1505', n.contract_name='MOCK11_燃机备件采购合同',   n.payment_direction='采购', n.sign_time='2024-10-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M05'}) ON CREATE SET n.contract_code='HT-2024-XS-1566', n.contract_name='MOCK11_燃机备件中间销售合同', n.payment_direction='销售', n.sign_time='2024-10-15', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S05'}) ON CREATE SET n.contract_code='HT-2024-XS-1599', n.contract_name='MOCK11_燃机备件销售合同',   n.payment_direction='销售', n.sign_time='2024-11-01', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// F
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P06'}) ON CREATE SET n.contract_code='HT-2025-CG-1606', n.contract_name='MOCK11_断路器采购合同',     n.payment_direction='采购', n.sign_time='2025-01-05', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M06'}) ON CREATE SET n.contract_code='HT-2025-XS-1666', n.contract_name='MOCK11_断路器中间销售合同', n.payment_direction='销售', n.sign_time='2025-01-20', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S06'}) ON CREATE SET n.contract_code='HT-2025-XS-1699', n.contract_name='MOCK11_断路器销售合同',     n.payment_direction='销售', n.sign_time='2025-02-10', n.schema_name='dws_dsjsj_zstp_vertex_ht';

// —— 入库 / 出库 ——
// A
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_A1'}) ON CREATE SET n.mblnr='RK-2024-0315', n.menge='120',  n.budat='2024-03-18', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_A2'}) ON CREATE SET n.vbeln='CK-2024-0420', n.meins='PC',   n.wadat_ist='2024-04-22', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_A3'}) ON CREATE SET n.vbeln='CK-2024-0528', n.meins='PC',   n.wadat_ist='2024-05-28', n.schema_name='dws_dsjsj_zstp_vertex_ck';
// B
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_B1'}) ON CREATE SET n.mblnr='RK-2024-0605', n.menge='3000', n.budat='2024-06-05', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_B2'}) ON CREATE SET n.vbeln='CK-2024-0628', n.meins='M',    n.wadat_ist='2024-06-28', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_B3'}) ON CREATE SET n.vbeln='CK-2024-0712', n.meins='M',    n.wadat_ist='2024-07-12', n.schema_name='dws_dsjsj_zstp_vertex_ck';
// C：第一/二段用入库、第三段用出库；物料侧混用领用/消耗
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_C1'}) ON CREATE SET n.mblnr='RK-2024-0805', n.menge='40',   n.budat='2024-08-05', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_C2'}) ON CREATE SET n.mblnr='RK-2024-0818', n.menge='40',   n.budat='2024-08-18', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_C3'}) ON CREATE SET n.vbeln='CK-2024-0903', n.meins='TAI',  n.wadat_ist='2024-09-03', n.schema_name='dws_dsjsj_zstp_vertex_ck';
// D
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_D1'}) ON CREATE SET n.mblnr='RK-2024-0205', n.menge='600',  n.budat='2024-02-05', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_D2'}) ON CREATE SET n.vbeln='CK-2024-0218', n.meins='M',    n.wadat_ist='2024-02-18', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_D3'}) ON CREATE SET n.vbeln='CK-2024-0304', n.meins='M',    n.wadat_ist='2024-03-04', n.schema_name='dws_dsjsj_zstp_vertex_ck';
// E
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_E1'}) ON CREATE SET n.mblnr='RK-2024-1003', n.menge='12',   n.budat='2024-10-03', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_E2'}) ON CREATE SET n.vbeln='CK-2024-1018', n.meins='SET',  n.wadat_ist='2024-10-18', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_E3'}) ON CREATE SET n.vbeln='CK-2024-1105', n.meins='SET',  n.wadat_ist='2024-11-05', n.schema_name='dws_dsjsj_zstp_vertex_ck';
// F
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_F1'}) ON CREATE SET n.mblnr='RK-2025-0108', n.menge='30',   n.budat='2025-01-08', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_F2'}) ON CREATE SET n.vbeln='CK-2025-0123', n.meins='TAI',  n.wadat_ist='2025-01-23', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_F3'}) ON CREATE SET n.vbeln='CK-2025-0212', n.meins='TAI',  n.wadat_ist='2025-02-12', n.schema_name='dws_dsjsj_zstp_vertex_ck';

// —— 0101 风险线索（A/B/C 各一对，供 17 号完整口径复用）——
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_A'}) ON CREATE SET n.risk_type='企业电话相同',       n.risk_desc='MOCK11: 华能物资与国电投数字科技登记电话一致',   n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_A'}) ON CREATE SET n.risk_type='注册地址相同',       n.risk_desc='MOCK11: 国电投信息技术与中电科汇智登记地址一致', n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_B'}) ON CREATE SET n.risk_type='股东相同（自然人）', n.risk_desc='MOCK11: 江苏远东与江苏电力自然人股东重合',       n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_B'}) ON CREATE SET n.risk_type='高管姓名相同',       n.risk_desc='MOCK11: 能源科技工程与上海申能高管同名',         n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_C'}) ON CREATE SET n.risk_type='股东相同（企业）',   n.risk_desc='MOCK11: 山东鲁电与山东电力股东重合',             n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_C'}) ON CREATE SET n.risk_type='企业电话相同',       n.risk_desc='MOCK11: 山东能源与青岛海纳登记电话一致',         n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';

// =============================================================================
// 五、模拟数据 · 关系
// =============================================================================

// ===== A 正例：标准有向签约 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_A01'}]->(b) ON CREATE SET e.sign_time='2024-03-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_A02'}]->(b) ON CREATE SET e.sign_time='2024-03-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_A03'}]->(b) ON CREATE SET e.sign_time='2024-04-12', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_A04'}]->(b) ON CREATE SET e.sign_time='2024-04-12', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_A05'}]->(b) ON CREATE SET e.sign_time='2024-05-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_A06'}]->(b) ON CREATE SET e.sign_time='2024-05-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// A 物流：采购入库 + 两次销售出库
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P01'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_A1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_A'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_A1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M01'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_A2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_A'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_A2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S01'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_A3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_A'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_A3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// A 风险线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_A03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_A04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== B 正例：签订合同全部反向（合同→企业）=====
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P02'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_B01'}]->(b) ON CREATE SET e.sign_time='2024-06-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P02'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_B02'}]->(b) ON CREATE SET e.sign_time='2024-06-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M02'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_B03'}]->(b) ON CREATE SET e.sign_time='2024-06-25', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M02'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_B04'}]->(b) ON CREATE SET e.sign_time='2024-06-25', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S02'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_B05'}]->(b) ON CREATE SET e.sign_time='2024-07-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S02'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_B06'}]->(b) ON CREATE SET e.sign_time='2024-07-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// B 物流
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P02'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_B1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_B'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_B1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M02'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_B2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_B'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_B2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S02'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_B3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_B02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_B'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_B3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_B02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// B 风险线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_B02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_B03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_B04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== C 正例：混合签约方向 + c2 走入库/领用（与 A/B 互补）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_C01'}]->(b) ON CREATE SET e.sign_time='2024-08-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P03'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_C02'}]->(b) ON CREATE SET e.sign_time='2024-08-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_C03'}]->(b) ON CREATE SET e.sign_time='2024-08-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M03'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_C04'}]->(b) ON CREATE SET e.sign_time='2024-08-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_C05'}]->(b) ON CREATE SET e.sign_time='2024-09-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S03'}),(b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_C06'}]->(b) ON CREATE SET e.sign_time='2024-09-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// C 第一段：采购合同 ↔ 入库 ↔ 消耗物料
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P03'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_C1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_C'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_C1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// C 第二段：中间销售合同 ↔ 入库 ↔ 领用物料（c2 走入库的替代路径）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M03'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_C2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_C02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_C'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_C2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
// C 第三段：销售合同 ↔ 出库 ↔ 领用物料
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S03'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_C3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_C'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_C3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_C02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
// C 风险线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_C'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_C'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_L_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_C02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_C'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_C03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_C'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK11_FXXS_R_C'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK11_E_FX_C04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== D 反例：物料不贯通（入库 104A，最终出库 104B）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_D01'}]->(b) ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_D02'}]->(b) ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_D03'}]->(b) ON CREATE SET e.sign_time='2024-02-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_D04'}]->(b) ON CREATE SET e.sign_time='2024-02-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_D05'}]->(b) ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_D06'}]->(b) ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P04'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_D1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_DA'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_D1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M04'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_D2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_DA'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_D2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S04'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_D3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_D02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_DB'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_D3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_D02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';

// ===== E 反例：中间 gB 为非国电投企业 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_E01'}]->(b) ON CREATE SET e.sign_time='2024-10-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_E02'}]->(b) ON CREATE SET e.sign_time='2024-10-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_E03'}]->(b) ON CREATE SET e.sign_time='2024-10-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_E04'}]->(b) ON CREATE SET e.sign_time='2024-10-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_E05'}]->(b) ON CREATE SET e.sign_time='2024-11-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_E06'}]->(b) ON CREATE SET e.sign_time='2024-11-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P05'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_E1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_E'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_E1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M05'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_E2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_E'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_E2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S05'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_E3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_E02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_E'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_E3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_E02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';

// ===== F 反例：采购合同只有一方签约（缺 GDTA_F）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_SUP_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_F01'}]->(b) ON CREATE SET e.sign_time='2025-01-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTA_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_F02'}]->(b) ON CREATE SET e.sign_time='2025-01-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_F03'}]->(b) ON CREATE SET e.sign_time='2025-01-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_GDTB_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_F04'}]->(b) ON CREATE SET e.sign_time='2025-02-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK11_QY_BUY_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK11_E_QD_F05'}]->(b) ON CREATE SET e.sign_time='2025-02-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_P06'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_F1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK11_E_AC_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_F'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK11_RK_F1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK11_E_LY_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_M06'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_F2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_F'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_F2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK11_HT_S06'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_F3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK11_E_AX_F02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK11_WL_F'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK11_CK_F3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK11_E_XH_F02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';


// =============================================================================
// 六、验证与清理
// =============================================================================
// 6.1 灌数后跑上面的主查询，应返回 3 组（A/B/C），D/E/F 不出现。
// 6.2 锚点版验证：
//     · B1 把 object_key 换成下面任一节点，均应各返回 1 组：
//         MOCK11_QY_GDTA_A / MOCK11_QY_GDTB_A  → A 组
//         MOCK11_QY_GDTA_B / MOCK11_QY_GDTB_B  → B 组
//         MOCK11_QY_GDTA_C / MOCK11_QY_GDTB_C  → C 组
//     · B1 换成 MOCK11_QY_GDTA_D / _E / _F 或外部企业 → 0 组
//     · B2 只认左侧 gA：MOCK11_QY_GDTA_B 命中，MOCK11_QY_GDTB_B 为 0
// 6.3 快速核对各用例节点数量：
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK11_'
// RETURN labels(n) AS 标签, count(*) AS 数量 ORDER BY 数量 DESC;
//
// 6.4 清理本文件数据：
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK11_' DETACH DELETE n;
