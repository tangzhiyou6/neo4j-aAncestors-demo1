// =============================================================================
// 17 SPIC-CW-0107 疑似人为增加交易环节 · 外-内-内-外 交易链条提取
// -----------------------------------------------------------------------------
// 对应流程图（基于 0101 结果数据）:
//
//   判断条件一（合同）：根据同一物料编码关联不同合同标的物，提取 外-内-内-外 交易链条。
//   例：国电投企业A 和外部采购相对方采购电脑 → A 销售电脑至国电投企业B →
//       国电投企业B 销售电脑至外部企业（同一批电脑在图上体现为同一物料节点的
//       入库/出库记录，即"同一物料编码关联不同合同标的物"）。
//
//   (采购合同相对方 s1)-[:签订合同]->(采购合同 c1)<-[:签订合同]-(国电投企业A gA)
//   (国电投企业A gA)  -[:签订合同]->(销售合同 c2)<-[:签订合同]-(国电投企业B gB)
//   (国电投企业B gB)  -[:签订合同]->(销售合同 c3)<-[:签订合同]-(销售合同相对方 s2)
//
//   (c1)-[:按采购合同入库]->(入库 rk)<-[:领用物料]-(物料 m)
//   (c2)-[:按销售合同出库]->(出库 ck2)<-[:消耗物料]-(m)      ← A 卖给 B 的出库
//   (c3)-[:按销售合同出库]->(出库 ck3)<-[:消耗物料]-(m)      ← B 卖给外部的出库
//
//   (s1)-[:触发风险_企业]->(风险线索 rl)<-[:触发风险_企业]-(gA)   ← 0101 左侧命中
//   (gB)-[:触发风险_企业]->(风险线索 rr)<-[:触发风险_企业]-(s2)   ← 0101 右侧命中
//     线索类型 ∈【交易双方存在异常关联关系（规则6 主类型）及 6 种具体关联类型】
//
// 口径:
//   1. 物流驱动：同一物料节点 m 串起 c1 的入库与 c2/c3 的出库（三种出入库边均为
//      物料 ←→ 出入库记录，方向见上方模式），构成"同一物料编码关联不同合同标的物"。
//   2. 签约链 s1→c1→gA→c2→gB→c3→s2 方向为 企业-[:签订合同]->合同，两侧 s1/s2
//      为外部企业（flag_gdtqy='否'），中间 gA/gB 为国电投企业（flag_gdtqy='是'）。
//      s1 与 s2 允许相同（闭环贸易本身即疑点，不做排除）。
//   3. 同一 (s1,gA,gB,s2,m) 组合存在多组合同证据时，按三份合同签订时间取最早一组
//      （边 sign_time 优先，回落合同节点 sign_time）。
//   4. 0101 结果：两对交易主体（s1,gA）与（gB,s2）各自通过 触发风险_企业 挂到
//      「交易双方存在异常关联关系」类风险线索（类型清单见查询开头，可按落图口径增减）。
//
// 标签使用生产原始 schema 名，中文标签对照见 01_neo4j_ddl.cypher:
//   dws_dsjsj_zstp_vertex_qy=企业  _ht=合同  _wl=物料  _rk=入库  _ck=出库  _fxxs=风险线索
//   dws_dsjsj_zstp_edge_qy_qd=签订合同          dws_dsjsj_zstp_edge_ht_acghtrk=按采购合同入库
//   dws_dsjsj_zstp_edge_ht_axshtck=按销售合同出库
//   dws_dsjsj_zstp_edge_wl_lywl=领用物料(物料→入库)
//   dws_dsjsj_zstp_edge_wl_xhwl=消耗物料(物料→出库)
//   dws_dsjsj_zstp_edge_qy_cffx=触发风险_企业
// =============================================================================


// =============================================================================
// 一、主查询：返回 6 段路径（三段签约链 + 三段物流链 
// =============================================================================
// 线索类型清单：0101（规则6「交易双方存在异常关联关系」）落图的线索类型，
// 主类型 + 6 种具体关联类型（与 16 号文件口径一致），按实际落图口径增减

// 1. 物流证据：同一物料 m 串起 c1 的入库与 c2/c3 的出库
MATCH (m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk:dws_dsjsj_zstp_vertex_rk)
MATCH (c1:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck2:dws_dsjsj_zstp_vertex_ck)
MATCH (c2:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck2)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck3:dws_dsjsj_zstp_vertex_ck)
MATCH (c3:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck3)
WHERE c1 <> c2 AND c1 <> c3 AND c2 <> c3
  AND ck2 <> ck3
// 如需锚定某一国电投主体（与参考查询输入方式一致），放开下一行注释并替换信用代码：
// MATCH (gA:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})

// 2. 外-内-内-外 签约链
MATCH (s1:dws_dsjsj_zstp_vertex_qy)-[rq1:dws_dsjsj_zstp_edge_qy_qd]->(c1)<-[rq2:dws_dsjsj_zstp_edge_qy_qd]-(gA:dws_dsjsj_zstp_vertex_qy)
MATCH (gA)-[rq3:dws_dsjsj_zstp_edge_qy_qd]->(c2)<-[rq4:dws_dsjsj_zstp_edge_qy_qd]-(gB:dws_dsjsj_zstp_vertex_qy)
MATCH (gB)-[rq5:dws_dsjsj_zstp_edge_qy_qd]->(c3)<-[rq6:dws_dsjsj_zstp_edge_qy_qd]-(s2:dws_dsjsj_zstp_vertex_qy)
WHERE s1 <> gA AND s1 <> gB AND s1 <> s2
  AND gA <> gB AND gA <> s2 AND gB <> s2
  AND s1.flag_gdtqy = '否' AND s2.flag_gdtqy = '否'
  AND gA.flag_gdtqy = '是' AND gB.flag_gdtqy = '是'

// 3. 同一 (s1,gA,gB,s2,m) 只取三份合同签订时间最早的一组证据
WITH s1, gA, gB, s2, m, c1, c2, c3, rk, ck2, ck3,
     coalesce(rq1.sign_time, rq2.sign_time, c1.sign_time) AS t1,
     coalesce(rq3.sign_time, rq4.sign_time, c2.sign_time) AS t2,
     coalesce(rq5.sign_time, rq6.sign_time, c3.sign_time) AS t3
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH s1, gA, gB, s2, m,
     collect({c1: c1, c2: c2, c3: c3, rk: rk, ck2: ck2, ck3: ck3})[0] AS ev

// 4. 解包证据并还原 8 段路径
WITH s1, gA, gB, s2, m, 
     ev.c1 AS c1, ev.c2 AS c2, ev.c3 AS c3, ev.rk AS rk, ev.ck2 AS ck2, ev.ck3 AS ck3
MATCH p0 = (s1)-[:dws_dsjsj_zstp_edge_qy_qd]->(c1)<-[:dws_dsjsj_zstp_edge_qy_qd]-(gA)
MATCH p1 = (gA)-[:dws_dsjsj_zstp_edge_qy_qd]->(c2)<-[:dws_dsjsj_zstp_edge_qy_qd]-(gB)
MATCH p2 = (gB)-[:dws_dsjsj_zstp_edge_qy_qd]->(c3)<-[:dws_dsjsj_zstp_edge_qy_qd]-(s2)
MATCH p3 = (m)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk)<-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(c1)
MATCH p4 = (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck2)<-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c2)
MATCH p5 = (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck3)<-[:dws_dsjsj_zstp_edge_ht_axshtck]-(c3)
RETURN DISTINCT p0, p1, p2, p3, p4, p5


// =============================================================================
// 二、明细输出版（核查字段，不返回路径）：替换主查询第 5 步之后的 MATCH/RETURN
// =============================================================================
// MATCH p0 = (s1)-[:dws_dsjsj_zstp_edge_qy_qd]->(c1)<-[:dws_dsjsj_zstp_edge_qy_qd]-(gA)
// RETURN DISTINCT
//     s1.org_name           AS 外部采购相对方,
//     gA.org_name           AS 国电投企业A,
//     gB.org_name           AS 国电投企业B,
//     s2.org_name           AS 外部销售相对方,
//     m.matnr               AS 物料编码, m.maktx AS 物料名称,
//     c1.contract_code      AS 采购合同, c1.sign_time AS 采购合同签订时间,
//     c2.contract_code      AS 中间销售合同, c2.sign_time AS 中间合同签订时间,
//     c3.contract_code      AS 销售合同, c3.sign_time AS 销售合同签订时间,
//     rk.mblnr              AS 入库单号, ck2.vbeln AS 中间出库单号, ck3.vbeln AS 销售出库单号,
//     rl.risk_type          AS 左侧线索类型, rr.risk_type AS 右侧线索类型,
//     '疑似人为增加交易环节'  AS 命中规则;


// =============================================================================
// 三、变体 A：宽松版 —— 0101 线索作为可选证据（无线索链条也返回，并标注命中情况）
// =============================================================================
WITH ['交易双方存在异常关联关系',
      '企业电话相同', '注册地址相同', '高管姓名相同',
      '股东相同（自然人）', '股东相同（企业）', '股东与高管姓名相同'] AS riskTypes
MATCH (m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk:dws_dsjsj_zstp_vertex_rk)
MATCH (c1:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck2:dws_dsjsj_zstp_vertex_ck)
MATCH (c2:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck2)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck3:dws_dsjsj_zstp_vertex_ck)
MATCH (c3:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck3)
WHERE c1 <> c2 AND c1 <> c3 AND c2 <> c3 AND ck2 <> ck3
MATCH (s1:dws_dsjsj_zstp_vertex_qy)-[rq1:dws_dsjsj_zstp_edge_qy_qd]->(c1)<-[rq2:dws_dsjsj_zstp_edge_qy_qd]-(gA:dws_dsjsj_zstp_vertex_qy)
MATCH (gA)-[rq3:dws_dsjsj_zstp_edge_qy_qd]->(c2)<-[rq4:dws_dsjsj_zstp_edge_qy_qd]-(gB:dws_dsjsj_zstp_vertex_qy)
MATCH (gB)-[rq5:dws_dsjsj_zstp_edge_qy_qd]->(c3)<-[rq6:dws_dsjsj_zstp_edge_qy_qd]-(s2:dws_dsjsj_zstp_vertex_qy)
WHERE s1 <> gA AND s1 <> gB AND s1 <> s2 AND gA <> gB AND gA <> s2 AND gB <> s2
  AND s1.flag_gdtqy = '否' AND s2.flag_gdtqy = '否'
  AND gA.flag_gdtqy = '是' AND gB.flag_gdtqy = '是'
WITH riskTypes, s1, gA, gB, s2, m, c1, c2, c3, rk, ck2, ck3,
     coalesce(rq1.sign_time, rq2.sign_time, c1.sign_time) AS t1,
     coalesce(rq3.sign_time, rq4.sign_time, c2.sign_time) AS t2,
     coalesce(rq5.sign_time, rq6.sign_time, c3.sign_time) AS t3
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH riskTypes, s1, gA, gB, s2, m,
     collect({c1: c1, c2: c2, c3: c3})[0] AS ev
OPTIONAL MATCH (s1)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rl:dws_dsjsj_zstp_vertex_fxxs)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(gA)
WHERE rl.risk_type IN riskTypes
OPTIONAL MATCH (gB)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rr:dws_dsjsj_zstp_vertex_fxxs)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(s2)
WHERE rr.risk_type IN riskTypes
WITH DISTINCT s1, gA, gB, s2, m, rl, rr, ev
RETURN DISTINCT
    s1.org_name      AS 外部采购相对方,
    gA.org_name      AS 国电投企业A,
    gB.org_name      AS 国电投企业B,
    s2.org_name      AS 外部销售相对方,
    ev.c1.contract_code AS 采购合同,
    ev.c2.contract_code AS 中间销售合同,
    ev.c3.contract_code AS 销售合同,
    CASE WHEN rl IS NOT NULL AND rr IS NOT NULL THEN '双侧线索命中'
         WHEN rl IS NULL AND rr IS NULL THEN '无线索'
         ELSE '单侧线索' END AS 风险线索命中情况;


// =============================================================================
// 四、变体 B：物料主数据未对齐版 —— 不要求同一物料节点，按物料编码属性比对
// -----------------------------------------------------------------------------
// ETL 未合并物料主数据时，入库与两笔出库挂在三个不同 物料 节点上，
// 以 matnr（物料编码）相等替代"同一节点"：
// =============================================================================
// MATCH (m1:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk:dws_dsjsj_zstp_vertex_rk)
// MATCH (c1:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk)
// MATCH (m2:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck2:dws_dsjsj_zstp_vertex_ck)
// MATCH (c2:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck2)
// MATCH (m3:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck3:dws_dsjsj_zstp_vertex_ck)
// MATCH (c3:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck3)
// WHERE trim(coalesce(m1.matnr, '')) <> ''
//   AND m1.matnr = m2.matnr AND m2.matnr = m3.matnr
//   （其余签约链、风险条件与主查询一致，把 m 换成 m1/m2/m3 即可）


// =============================================================================
// 五、自包含验证数据（MOCK8_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 正例:  s1→c1→gA→c2→gB→c3→s2，物料 m 贯通 rk/ck2/ck3；左右两对均挂线索
//        另有一条同组合、同物料但更晚的合同链（P02/M02/S02）→ 应取最早的 P01/M01/S01
// 反例1: 链条完整但两对均无风险线索（不应命中）
// 反例2: 仅左侧挂线索（不应命中）
// 反例3: 入库物料 m6a 与出库物料 m6b 不同（物料不贯通，不应命中）
// =============================================================================

// ---- 5.1 顶点 ----
// 正例四方
MERGE (s1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP'})
  ON CREATE SET s1.org_name='MOCK8_外部采购相对方', s1.flag_gdtqy='否', s1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gA:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA'})
  ON CREATE SET gA.org_name='MOCK8_国电投企业A', gA.flag_gdtqy='是',
                gA.org_credit_code='913402003950006371', gA.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gB:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB'})
  ON CREATE SET gB.org_name='MOCK8_国电投企业B', gB.flag_gdtqy='是', gB.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY'})
  ON CREATE SET s2.org_name='MOCK8_外部销售相对方', s2.flag_gdtqy='否', s2.schema_name='dws_dsjsj_zstp_vertex_qy';
// 正例物料与出入库（链条一：早；链条二：晚，用于验证取最早）
MERGE (m:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
  ON CREATE SET m.matnr='MOCK8-MAT-001', m.maktx='MOCK8_电脑', m.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (rk:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_01'})
  ON CREATE SET rk.mblnr='MOCK8_RK_01', rk.budat='2024-01-15', rk.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck2:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_01'})
  ON CREATE SET ck2.vbeln='MOCK8_CK_01', ck2.wadat_ist='2024-02-05', ck2.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (ck3:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_02'})
  ON CREATE SET ck3.vbeln='MOCK8_CK_02', ck3.wadat_ist='2024-03-05', ck3.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (rk2:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_02'})
  ON CREATE SET rk2.mblnr='MOCK8_RK_02', rk2.budat='2024-06-15', rk2.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck2b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_03'})
  ON CREATE SET ck2b.vbeln='MOCK8_CK_03', ck2b.wadat_ist='2024-06-25', ck2b.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (ck3b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_04'})
  ON CREATE SET ck3b.vbeln='MOCK8_CK_04', ck3b.wadat_ist='2024-06-28', ck3b.schema_name='dws_dsjsj_zstp_vertex_ck';
// 正例合同（链条一 P01/M01/S01 早；链条二 P02/M02/S02 晚）
MERGE (c1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P01'})
  ON CREATE SET c1.contract_code='MOCK8_HT_P01', c1.contract_name='MOCK8_采购合同P01',
                c1.sign_time='2024-01-10', c1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M01'})
  ON CREATE SET c2.contract_code='MOCK8_HT_M01', c2.contract_name='MOCK8_中间销售合同M01',
                c2.sign_time='2024-02-01', c2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S01'})
  ON CREATE SET c3.contract_code='MOCK8_HT_S01', c3.contract_name='MOCK8_销售合同S01',
                c3.sign_time='2024-03-01', c3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c1b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P02'})
  ON CREATE SET c1b.contract_code='MOCK8_HT_P02', c1b.contract_name='MOCK8_采购合同P02',
                c1b.sign_time='2024-06-10', c1b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c2b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M02'})
  ON CREATE SET c2b.contract_code='MOCK8_HT_M02', c2b.contract_name='MOCK8_中间销售合同M02',
                c2b.sign_time='2024-06-20', c2b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c3b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S02'})
  ON CREATE SET c3b.contract_code='MOCK8_HT_S02', c3b.contract_name='MOCK8_销售合同S02',
                c3b.sign_time='2024-06-30', c3b.schema_name='dws_dsjsj_zstp_vertex_ht';
// 正例风险线索（0101 结果，左右各一条）
MERGE (rl:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L'})
  ON CREATE SET rl.risk_type='交易双方存在异常关联关系', rl.risk_desc='MOCK8: 0101 左侧命中',
                rl.risk_summary='交易双方存在异常关联关系', rl.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (rr:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_R'})
  ON CREATE SET rr.risk_type='交易双方存在异常关联关系', rr.risk_desc='MOCK8: 0101 右侧命中',
                rr.risk_summary='交易双方存在异常关联关系', rr.schema_name='dws_dsjsj_zstp_vertex_fxxs';
// 反例1：链条完整、无线索
MERGE (s3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP3'})
  ON CREATE SET s3.org_name='MOCK8_反例1_外部采购相对方', s3.flag_gdtqy='否', s3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gA3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA3'})
  ON CREATE SET gA3.org_name='MOCK8_反例1_国电投企业A', gA3.flag_gdtqy='是', gA3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gB3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB3'})
  ON CREATE SET gB3.org_name='MOCK8_反例1_国电投企业B', gB3.flag_gdtqy='是', gB3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY3'})
  ON CREATE SET s4.org_name='MOCK8_反例1_外部销售相对方', s4.flag_gdtqy='否', s4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (m4:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_04'})
  ON CREATE SET m4.matnr='MOCK8-MAT-004', m4.maktx='MOCK8_反例1_物料', m4.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (rk4:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_04'})
  ON CREATE SET rk4.mblnr='MOCK8_RK_04', rk4.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck4a:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_05'})
  ON CREATE SET ck4a.vbeln='MOCK8_CK_05', ck4a.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (ck4b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_06'})
  ON CREATE SET ck4b.vbeln='MOCK8_CK_06', ck4b.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (c4a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P04'})
  ON CREATE SET c4a.contract_code='MOCK8_HT_P04', c4a.sign_time='2024-04-01', c4a.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c4b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M04'})
  ON CREATE SET c4b.contract_code='MOCK8_HT_M04', c4b.sign_time='2024-04-02', c4b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c4c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S04'})
  ON CREATE SET c4c.contract_code='MOCK8_HT_S04', c4c.sign_time='2024-04-03', c4c.schema_name='dws_dsjsj_zstp_vertex_ht';
// 反例2：仅左侧挂线索
MERGE (s5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP5'})
  ON CREATE SET s5.org_name='MOCK8_反例2_外部采购相对方', s5.flag_gdtqy='否', s5.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gA5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA5'})
  ON CREATE SET gA5.org_name='MOCK8_反例2_国电投企业A', gA5.flag_gdtqy='是', gA5.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gB5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB5'})
  ON CREATE SET gB5.org_name='MOCK8_反例2_国电投企业B', gB5.flag_gdtqy='是', gB5.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s6:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY5'})
  ON CREATE SET s6.org_name='MOCK8_反例2_外部销售相对方', s6.flag_gdtqy='否', s6.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (m5:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_05'})
  ON CREATE SET m5.matnr='MOCK8-MAT-005', m5.maktx='MOCK8_反例2_物料', m5.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (rk5:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_05'})
  ON CREATE SET rk5.mblnr='MOCK8_RK_05', rk5.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck5a:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_07'})
  ON CREATE SET ck5a.vbeln='MOCK8_CK_07', ck5a.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (ck5b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_08'})
  ON CREATE SET ck5b.vbeln='MOCK8_CK_08', ck5b.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (c5a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P05'})
  ON CREATE SET c5a.contract_code='MOCK8_HT_P05', c5a.sign_time='2024-05-01', c5a.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c5b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M05'})
  ON CREATE SET c5b.contract_code='MOCK8_HT_M05', c5b.sign_time='2024-05-02', c5b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c5c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S05'})
  ON CREATE SET c5c.contract_code='MOCK8_HT_S05', c5c.sign_time='2024-05-03', c5c.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (rl5:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L5'})
  ON CREATE SET rl5.risk_type='交易双方存在异常关联关系', rl5.risk_desc='MOCK8: 反例2 仅左侧',
                rl5.risk_summary='交易双方存在异常关联关系', rl5.schema_name='dws_dsjsj_zstp_vertex_fxxs';
// 反例3：入库与出库挂不同物料（物料不贯通）
MERGE (s7:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP7'})
  ON CREATE SET s7.org_name='MOCK8_反例3_外部采购相对方', s7.flag_gdtqy='否', s7.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gA7:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA7'})
  ON CREATE SET gA7.org_name='MOCK8_反例3_国电投企业A', gA7.flag_gdtqy='是', gA7.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (gB7:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB7'})
  ON CREATE SET gB7.org_name='MOCK8_反例3_国电投企业B', gB7.flag_gdtqy='是', gB7.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s8:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY7'})
  ON CREATE SET s8.org_name='MOCK8_反例3_外部销售相对方', s8.flag_gdtqy='否', s8.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (m6a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_06A'})
  ON CREATE SET m6a.matnr='MOCK8-MAT-006A', m6a.maktx='MOCK8_反例3_入库物料', m6a.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (m6b:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_06B'})
  ON CREATE SET m6b.matnr='MOCK8-MAT-006B', m6b.maktx='MOCK8_反例3_出库物料', m6b.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (rk6:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_06'})
  ON CREATE SET rk6.mblnr='MOCK8_RK_06', rk6.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck6a:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_09'})
  ON CREATE SET ck6a.vbeln='MOCK8_CK_09', ck6a.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (ck6b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_10'})
  ON CREATE SET ck6b.vbeln='MOCK8_CK_10', ck6b.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (c6a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P06'})
  ON CREATE SET c6a.contract_code='MOCK8_HT_P06', c6a.sign_time='2024-07-01', c6a.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c6b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M06'})
  ON CREATE SET c6b.contract_code='MOCK8_HT_M06', c6b.sign_time='2024-07-02', c6b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c6c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S06'})
  ON CREATE SET c6c.contract_code='MOCK8_HT_S06', c6c.sign_time='2024-07-03', c6c.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (rl6:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L6'})
  ON CREATE SET rl6.risk_type='交易双方存在异常关联关系', rl6.risk_desc='MOCK8: 反例3 左侧',
                rl6.risk_summary='交易双方存在异常关联关系', rl6.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (rr6:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_R6'})
  ON CREATE SET rr6.risk_type='交易双方存在异常关联关系', rr6.risk_desc='MOCK8: 反例3 右侧',
                rr6.risk_summary='交易双方存在异常关联关系', rr6.schema_name='dws_dsjsj_zstp_vertex_fxxs';

// ---- 5.2 边（MATCH 端点 + MERGE 关系，幂等可重复执行；勿用匿名节点全模式 MERGE，会重建端点） ----
// 正例：签约链（链条一，早）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_1'}]->(b)
  ON CREATE SET e.sign_time='2024-01-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_2'}]->(b)
  ON CREATE SET e.sign_time='2024-01-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_3'}]->(b)
  ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_4'}]->(b)
  ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_5'}]->(b)
  ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_6'}]->(b)
  ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// 正例：签约链（链条二，晚）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_7'}]->(b)
  ON CREATE SET e.sign_time='2024-06-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_8'}]->(b)
  ON CREATE SET e.sign_time='2024-06-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_9'}]->(b)
  ON CREATE SET e.sign_time='2024-06-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_10'}]->(b)
  ON CREATE SET e.sign_time='2024-06-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_11'}]->(b)
  ON CREATE SET e.sign_time='2024-06-30', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_12'}]->(b)
  ON CREATE SET e.sign_time='2024-06-30', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// 正例：物流（链条一：m 贯通 rk/ck2/ck3）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P01'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK8_E_RK_1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK8_E_LY_1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M01'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S01'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 正例：物流（链条二：同一物料 m 的第二套出入库）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P02'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK8_E_RK_2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK8_E_LY_2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M02'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_03'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_03'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S02'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_01'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 正例：0101 风险线索（左对 s1+gA，右对 gB+s2）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_R'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_R'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
// 反例1：链条完整、无线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_13'}]->(b)
  ON CREATE SET e.sign_time='2024-04-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_14'}]->(b)
  ON CREATE SET e.sign_time='2024-04-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_15'}]->(b)
  ON CREATE SET e.sign_time='2024-04-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_16'}]->(b)
  ON CREATE SET e.sign_time='2024-04-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_17'}]->(b)
  ON CREATE SET e.sign_time='2024-04-03', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_18'}]->(b)
  ON CREATE SET e.sign_time='2024-04-03', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P04'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK8_E_RK_4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_04'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK8_E_LY_4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M04'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_5'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_04'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_5'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S04'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_04'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 反例2：仅左侧挂线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_19'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_20'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_21'}]->(b)
  ON CREATE SET e.sign_time='2024-05-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_22'}]->(b)
  ON CREATE SET e.sign_time='2024-05-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_23'}]->(b)
  ON CREATE SET e.sign_time='2024-05-03', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_24'}]->(b)
  ON CREATE SET e.sign_time='2024-05-03', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P05'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK8_E_RK_5'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_05'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_05'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK8_E_LY_5'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M05'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_07'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_7'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_05'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_07'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_7'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S05'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_08'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_8'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_05'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_08'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_8'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP5'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L5'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_5'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA5'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L5'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
// 反例3：入库物料 m6a 与出库物料 m6b 不同，两对均挂线索但链条不贯通
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP7'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_25'}]->(b)
  ON CREATE SET e.sign_time='2024-07-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA7'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_26'}]->(b)
  ON CREATE SET e.sign_time='2024-07-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA7'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_27'}]->(b)
  ON CREATE SET e.sign_time='2024-07-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB7'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_28'}]->(b)
  ON CREATE SET e.sign_time='2024-07-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB7'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_29'}]->(b)
  ON CREATE SET e.sign_time='2024-07-03', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY7'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK8_E_QD_30'}]->(b)
  ON CREATE SET e.sign_time='2024-07-03', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_P06'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK8_E_RK_6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_06A'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK8_RK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK8_E_LY_6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_M06'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_09'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_9'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_06B'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_09'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_9'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK8_HT_S06'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_10'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK8_E_CK_10'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK8_WL_06B'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK8_CK_10'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK8_E_XH_10'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_SUP7'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_7'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTA7'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_L6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_8'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_GDTB7'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_R6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_9'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK8_QY_BUY7'})
MATCH (b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK8_FXXS_R6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK8_E_FX_10'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';


// =============================================================================
// 六、断言校验（先跑第五节灌数据，再跑本节，应全部 PASS）
// =============================================================================
// 断言 1~4：主查询仅命中正例；证据取最早链条；左右线索类型正确；反例全部排除
WITH ['交易双方存在异常关联关系',
      '企业电话相同', '注册地址相同', '高管姓名相同',
      '股东相同（自然人）', '股东相同（企业）', '股东与高管姓名相同'] AS riskTypes
MATCH (m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk:dws_dsjsj_zstp_vertex_rk)
MATCH (c1:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck2:dws_dsjsj_zstp_vertex_ck)
MATCH (c2:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck2)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck3:dws_dsjsj_zstp_vertex_ck)
MATCH (c3:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck3)
WHERE c1 <> c2 AND c1 <> c3 AND c2 <> c3 AND ck2 <> ck3
MATCH (s1:dws_dsjsj_zstp_vertex_qy)-[rq1:dws_dsjsj_zstp_edge_qy_qd]->(c1)<-[rq2:dws_dsjsj_zstp_edge_qy_qd]-(gA:dws_dsjsj_zstp_vertex_qy)
MATCH (gA)-[rq3:dws_dsjsj_zstp_edge_qy_qd]->(c2)<-[rq4:dws_dsjsj_zstp_edge_qy_qd]-(gB:dws_dsjsj_zstp_vertex_qy)
MATCH (gB)-[rq5:dws_dsjsj_zstp_edge_qy_qd]->(c3)<-[rq6:dws_dsjsj_zstp_edge_qy_qd]-(s2:dws_dsjsj_zstp_vertex_qy)
WHERE s1 <> gA AND s1 <> gB AND s1 <> s2 AND gA <> gB AND gA <> s2 AND gB <> s2
  AND s1.flag_gdtqy = '否' AND s2.flag_gdtqy = '否'
  AND gA.flag_gdtqy = '是' AND gB.flag_gdtqy = '是'
WITH riskTypes, s1, gA, gB, s2, m, c1, c2, c3, rk, ck2, ck3,
     coalesce(rq1.sign_time, rq2.sign_time, c1.sign_time) AS t1,
     coalesce(rq3.sign_time, rq4.sign_time, c2.sign_time) AS t2,
     coalesce(rq5.sign_time, rq6.sign_time, c3.sign_time) AS t3
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH riskTypes, s1, gA, gB, s2, m,
     collect({c1: c1, c2: c2, c3: c3})[0] AS ev
MATCH (s1)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rl:dws_dsjsj_zstp_vertex_fxxs)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(gA)
MATCH (gB)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rr:dws_dsjsj_zstp_vertex_fxxs)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(s2)
WHERE rl.risk_type IN riskTypes AND rr.risk_type IN riskTypes
WITH DISTINCT s1, gA, gB, s2, m, rl, rr, ev
WITH collect(DISTINCT s1.org_name + '+' + gA.org_name + '+' + gB.org_name + '+' + s2.org_name) AS 命中组合,
     collect(DISTINCT ev.c1.contract_code + '/' + ev.c2.contract_code + '/' + ev.c3.contract_code) AS 证据链,
     collect(DISTINCT rl.risk_type) AS 左侧类型,
     collect(DISTINCT rr.risk_type) AS 右侧类型
RETURN CASE WHEN 命中组合 = ['MOCK8_外部采购相对方+MOCK8_国电投企业A+MOCK8_国电投企业B+MOCK8_外部销售相对方']
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 命中组合 | a + v + '; ') END AS 断言1_仅正例四方组合命中,
       CASE WHEN 证据链 = ['MOCK8_HT_P01/MOCK8_HT_M01/MOCK8_HT_S01']
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 证据链 | a + v + '; ') END AS 断言2_证据取最早链条,
       CASE WHEN 左侧类型 = ['交易双方存在异常关联关系'] AND 右侧类型 = ['交易双方存在异常关联关系']
            THEN 'PASS' ELSE 'FAIL' END AS 断言3_左右线索类型正确,
       CASE WHEN NOT any(x IN 命中组合 WHERE x CONTAINS '反例')
            THEN 'PASS' ELSE 'FAIL' END AS 断言4_三个反例均未命中;

// 断言 5：宽松版（变体 A）应返回 正例=双侧线索命中、反例1=无线索、反例2=单侧线索
WITH ['交易双方存在异常关联关系',
      '企业电话相同', '注册地址相同', '高管姓名相同',
      '股东相同（自然人）', '股东相同（企业）', '股东与高管姓名相同'] AS riskTypes
MATCH (m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk:dws_dsjsj_zstp_vertex_rk)
MATCH (c1:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck2:dws_dsjsj_zstp_vertex_ck)
MATCH (c2:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck2)
MATCH (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck3:dws_dsjsj_zstp_vertex_ck)
MATCH (c3:dws_dsjsj_zstp_vertex_ht)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck3)
WHERE c1 <> c2 AND c1 <> c3 AND c2 <> c3 AND ck2 <> ck3
MATCH (s1:dws_dsjsj_zstp_vertex_qy)-[rq1:dws_dsjsj_zstp_edge_qy_qd]->(c1)<-[rq2:dws_dsjsj_zstp_edge_qy_qd]-(gA:dws_dsjsj_zstp_vertex_qy)
MATCH (gA)-[rq3:dws_dsjsj_zstp_edge_qy_qd]->(c2)<-[rq4:dws_dsjsj_zstp_edge_qy_qd]-(gB:dws_dsjsj_zstp_vertex_qy)
MATCH (gB)-[rq5:dws_dsjsj_zstp_edge_qy_qd]->(c3)<-[rq6:dws_dsjsj_zstp_edge_qy_qd]-(s2:dws_dsjsj_zstp_vertex_qy)
WHERE s1 <> gA AND s1 <> gB AND s1 <> s2 AND gA <> gB AND gA <> s2 AND gB <> s2
  AND s1.flag_gdtqy = '否' AND s2.flag_gdtqy = '否'
  AND gA.flag_gdtqy = '是' AND gB.flag_gdtqy = '是'
WITH riskTypes, s1, gA, gB, s2, m, c1, c2, c3,
     coalesce(rq1.sign_time, rq2.sign_time, c1.sign_time) AS t1,
     coalesce(rq3.sign_time, rq4.sign_time, c2.sign_time) AS t2,
     coalesce(rq5.sign_time, rq6.sign_time, c3.sign_time) AS t3
ORDER BY t1 ASC, t2 ASC, t3 ASC,
         c1.object_key ASC, c2.object_key ASC, c3.object_key ASC
WITH riskTypes, s1, gA, gB, s2, m, collect({c1: c1, c2: c2, c3: c3})[0] AS ev
OPTIONAL MATCH (s1)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rl:dws_dsjsj_zstp_vertex_fxxs)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(gA)
WHERE rl.risk_type IN riskTypes
OPTIONAL MATCH (gB)-[:dws_dsjsj_zstp_edge_qy_cffx]->(rr:dws_dsjsj_zstp_vertex_fxxs)<-[:dws_dsjsj_zstp_edge_qy_cffx]-(s2)
WHERE rr.risk_type IN riskTypes
WITH DISTINCT s1, gA, gB, s2, m, rl, rr, ev
WITH collect(DISTINCT CASE WHEN s1.org_name CONTAINS '反例1' THEN '反例1:无线索'
                           WHEN s1.org_name CONTAINS '反例2' THEN '反例2:单侧线索'
                           ELSE '正例:双侧线索命中' END) AS 宽松版命中情况
RETURN CASE WHEN 宽松版命中情况 = ['正例:双侧线索命中', '反例1:无线索', '反例2:单侧线索']
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 宽松版命中情况 | a + v + '; ') END AS 断言5_宽松版三态正确;


// =============================================================================
// 七、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK8_' DETACH DELETE n;
