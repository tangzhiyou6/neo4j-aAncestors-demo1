// =============================================================================
// 16 交易双方存在异常关联关系 · 上下游合同同标的 + 相对方股东挂同一条风险线索
// -----------------------------------------------------------------------------
// 对应流程图（国电投企业A 居中，上游采购、下游销售，两侧相对方的股东触发同一风险线索）:
//
//   (股东企业 eS)-[:股东持股*..3]->(采购相对方 s)-[:签订合同]->(采购合同/进项发票 cS)
//   (股东企业 eB)-[:股东持股*..3]->(销售相对方 b)-[:签订合同]->(销售合同/销项发票 cB)
//   (国电投企业A g)-[:签订合同]->(cS) ,  (g)-[:签订合同]->(cB)
//   (cS)-[:同一标的物关联_合同]-(cB)              ← 上下游合同/发票为同一标的
//   (eS)-[:触发风险_企业]->(风险线索 r)<-[:触发风险_企业]-(eB)
//     r.risk_type ∈ 【企业电话相同 / 注册地址相同 / 高管姓名相同 /
//                     股东相同（自然人）/ 股东相同（企业）/ 股东与高管姓名相同】
//   ⇒ 整体命中: 风险线索「交易双方存在异常关联关系」
//
// 口径（与已实现的"风险穿透查询"同一套写法，仅把配对双方从
//   "国电投签约企业 g 的股东 vs 外部签约企业 w 的股东" 换成
//   "采购相对方 s 的股东 vs 销售相对方 b 的股东"，并新增上下游同标的条件）:
//   1. g 为国电投企业（flag_gdtqy='是'，按统一社会信用代码定位），
//      其采购侧合同 cS 与销售侧合同 cB 互为"同一标的物关联"（上下游）；
//      采购相对方 s 签 cS、销售相对方 b 签 cB，均为外部企业（flag_gdtqy='否'）。
//   2. 多组证据时按签订时间取最早一对（边 sign_time 优先，回落合同节点 sign_time）。
//   3. s、b 分别沿"股东持股（%）企业-企业"向上 ≤3 层，得到 eS、eB；
//      两者挂同一条风险线索，且风险类型属于 6 种异常关联之一。
//   4. 命中后仅为 eS/eB 补查最短持股路径，返回全部 6 段路径还原整图。
//
// 标签名使用生产原始 schema 名（与参考查询一致），中文标签体系对照见 01_neo4j_ddl.cypher:
//   dws_dsjsj_zstp_vertex_qy   = 企业          dws_dsjsj_zstp_vertex_ht  = 合同
//   dws_dsjsj_zstp_vertex_fp   = 发票          dws_dsjsj_zstp_vertex_fxxs = 风险线索
//   dws_dsjsj_zstp_edge_qy_qd  = 签订合同      dws_dsjsj_zstp_edge_qy_gdcgbfb = 股东持股（%）企业-企业
//   dws_dsjsj_zstp_edge_qy_cffx = 触发风险_企业
//   dws_dsjsj_zstp_edge_ht_tybdwgl = 同一标的物关联_合同
//   dws_dsjsj_zstp_edge_fp_tybdwgl = 同一标的物关联（发票）
//   dws_dsjsj_zstp_edge_qy_kjjsfp / dws_dsjsj_zstp_edge_qy_csfp = 开具接收发票 / 产生发票_企业
// =============================================================================


// =============================================================================
// 一、主查询：返回 6 段路径（两侧合同 + 同标的关系 + 两条持股链 + 风险线索链）
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'

// 1. 上下游合同：g 签的 cS 与 cB 互为"同一标的物关联"
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cS <> cB
  AND (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
  // 方向过滤：payment_direction 实际取值口径 '销售'/'收款'=销售合同、'采购'/'付款'=采购合同；
  // cS 限采购侧、cB 限销售侧，同时天然防角色镜像（对调组合不满足 IN 列表，无需额外条件）。
  // 若生产存在方向缺失的合同，放宽为 (cS.payment_direction IN [...] OR cS.payment_direction IS NULL)
  AND cS.payment_direction IN ['采购', '付款']
  AND cB.payment_direction IN ['销售', '收款']

// 2. 两个外部相对方：s 签采购侧 cS，b 签销售侧 cB
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH (b:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB)
WHERE s <> g AND b <> g AND s <> b
  AND s.flag_gdtqy = '否'
  AND b.flag_gdtqy = '否'

// 3. 每组 (g,s,b) 只取签订时间最早的一对上下游合同作为证据
WITH g, s, b, cS, cB,
     coalesce(rdS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, cB.sign_time) AS tB
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, s, b, collect({cS: cS, cB: cB})[0] AS ev

// 4. 两侧股东集合：s、b 各查一次（≤3 层）
CALL {
    WITH s
    MATCH (s)<-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*..3]-(d:dws_dsjsj_zstp_vertex_qy)
    RETURN collect(DISTINCT d) AS supSide
}
CALL {
    WITH b
    MATCH (b)<-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*..3]-(d:dws_dsjsj_zstp_vertex_qy)
    RETURN collect(DISTINCT d) AS buySide
}

// 5. 两侧股东两两配对，挂同一条风险线索（6 种异常关联类型）
UNWIND supSide AS eS
UNWIND buySide AS eB
MATCH p3 = (eB)-[:dws_dsjsj_zstp_edge_qy_cffx]-(r:dws_dsjsj_zstp_vertex_fxxs)-[:dws_dsjsj_zstp_edge_qy_cffx]-(eS)
WHERE eS <> eB
  AND r.risk_type IN ['企业电话相同', '注册地址相同', '高管姓名相同',
                      '股东相同（自然人）', '股东相同（企业）', '股东与高管姓名相同']
WITH DISTINCT g, s, b, ev, eS, eB, r, p3

// 6. 仅为命中的股东补查最短持股路径，并还原两侧合同路径与同标的关系
MATCH pS = shortestPath((eS)-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*..3]->(s))
MATCH pB = shortestPath((eB)-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*..3]->(b))
WITH g, s, b, eS, eB, r, pS, pB, p3, ev.cS AS cS, ev.cB AS cB
MATCH p0s = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS)<-[:dws_dsjsj_zstp_edge_qy_qd]-(s)
MATCH p0b = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB)<-[:dws_dsjsj_zstp_edge_qy_qd]-(b)
MATCH pL  = (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
RETURN DISTINCT p0s, p0b, pL, pS, pB, p3;


// =============================================================================
// 二、明细输出版（核查字段，不返回路径）：把上面的 RETURN 换成如下即可
// =============================================================================
// RETURN DISTINCT
//     g.org_name          AS 国电投企业,
//     s.org_name          AS 采购相对方,
//     b.org_name          AS 销售相对方,
//     cS.contract_code    AS 采购侧合同, cS.sign_time AS 采购侧签订时间,
//     cB.contract_code    AS 销售侧合同, cB.sign_time AS 销售侧签订时间,
//     eS.org_name         AS 采购方股东, length(pS) AS 采购侧持股层数,
//     eB.org_name         AS 销售方股东, length(pB) AS 销售侧持股层数,
//     r.risk_type         AS 风险类型,
//     r.object_key        AS 风险线索,
//     '交易双方存在异常关联关系' AS 命中规则;


// =============================================================================
// 三、变体 A：允许相对方本人参与比对（0 层，即 s/b 自己电话相同也算）
// =============================================================================
// 把第 4 步两个子查询里的 *..3 改为 *0..3 即可：
//   MATCH (s)<-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*0..3]-(d:dws_dsjsj_zstp_vertex_qy)
//   MATCH (b)<-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*0..3]-(d:dws_dsjsj_zstp_vertex_qy)
// 此时 eS 可能等于 s、eB 可能等于 b，第 6 步 shortestPath 长度可为 0。

// =============================================================================
// 四、变体 B：同标的证据改走发票侧（"同一标的物关联上下游合同/发票"的发票分支）
// =============================================================================
// 流程图左列的"销售合同/销项发票、采购合同/进项发票"若在图里体现为
// 相对方各自开具/产生的发票，用发票间的 同一标的物关联 作为上下游证据：
// 把主查询第 1 步的合同同标的条件替换为：
//   MATCH (s)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|dws_dsjsj_zstp_edge_qy_csfp]->(fS:dws_dsjsj_zstp_vertex_fp)
//   MATCH (b)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|dws_dsjsj_zstp_edge_qy_csfp]->(fB:dws_dsjsj_zstp_vertex_fp)
//   WHERE fS <> fB AND (fS)-[:dws_dsjsj_zstp_edge_fp_tybdwgl]-(fB)
//   （cS/cB 仍用于锚定 g 与相对方的签订关系，ev 里可同时携带 fS/fB）
// 完整可执行版见第六节断言 6 的查询。


// =============================================================================
// 五、自包含验证数据（MOCK7_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 正例:  g=国电投企业A；s=采购相对方(2 层股东链 eS→中间→s)；b=销售相对方(1 层股东 eB)
//        cS=P01(最早) 与 P02(较晚) 都与 cB=S01 同标的 → 证据应取最早的 P01
//        eS、eB 同挂风险线索"企业电话相同"；另有发票侧同标的证据（供变体 B）
// 反例1: 相对方股东无共同风险线索（不应命中）
// 反例2: 股东共享的风险线索类型不在 6 类之内（不应命中）
// 反例3: 上下游合同无"同一标的物关联"（不应命中）
// =============================================================================

// ---- 5.1 顶点 ----
// 正例主体
MERGE (g:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
  ON CREATE SET g.org_name='MOCK7_国电投企业A', g.org_credit_code='913402003950006371',
                g.flag_gdtqy='是', g.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP'})
  ON CREATE SET s.org_name='MOCK7_采购相对方', s.flag_gdtqy='否', s.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (b:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY'})
  ON CREATE SET b.org_name='MOCK7_销售相对方', b.flag_gdtqy='否', b.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (midS:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_MID_SUP'})
  ON CREATE SET midS.org_name='MOCK7_采购方中间控股', midS.flag_gdtqy='否', midS.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (eS:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_ES'})
  ON CREATE SET eS.org_name='MOCK7_采购方股东E', eS.flag_gdtqy='否', eS.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (eB:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_EB'})
  ON CREATE SET eB.org_name='MOCK7_销售方股东E', eB.flag_gdtqy='否', eB.schema_name='dws_dsjsj_zstp_vertex_qy';
// 正例合同（P02 用于验证"取最早"）与发票
MERGE (cS1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P01'})
  ON CREATE SET cS1.contract_code='MOCK7_HT_P01', cS1.contract_name='MOCK7_采购合同P01',
                cS1.payment_direction='采购', cS1.sign_time='2024-03-01', cS1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cS2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P02'})
  ON CREATE SET cS2.contract_code='MOCK7_HT_P02', cS2.contract_name='MOCK7_采购合同P02',
                cS2.payment_direction='采购', cS2.sign_time='2024-06-01', cS2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cB1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S01'})
  ON CREATE SET cB1.contract_code='MOCK7_HT_S01', cB1.contract_name='MOCK7_销售合同S01',
                cB1.payment_direction='销售', cB1.sign_time='2024-04-01', cB1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (fP:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK7_FP_IN'})
  ON CREATE SET fP.fp_hm='MOCK7_FP_IN', fP.kprq='2024-03-05', fP.schema_name='dws_dsjsj_zstp_vertex_fp';
MERGE (fB:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK7_FP_OUT'})
  ON CREATE SET fB.fp_hm='MOCK7_FP_OUT', fB.kprq='2024-04-05', fB.schema_name='dws_dsjsj_zstp_vertex_fp';
// 正例风险线索（6 类之内）
MERGE (r1:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_R1'})
  ON CREATE SET r1.risk_type='企业电话相同', r1.risk_desc='MOCK7: 两家股东企业电话相同',
                r1.risk_summary='企业电话相同', r1.schema_name='dws_dsjsj_zstp_vertex_fxxs';
// 反例 1：无共同风险线索
MERGE (s3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP3'})
  ON CREATE SET s3.org_name='MOCK7_反例1_采购相对方', s3.flag_gdtqy='否', s3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (b3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY3'})
  ON CREATE SET b3.org_name='MOCK7_反例1_销售相对方', b3.flag_gdtqy='否', b3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (e3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E3'})
  ON CREATE SET e3.org_name='MOCK7_反例1_采购方股东', e3.flag_gdtqy='否', e3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (e4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E4'})
  ON CREATE SET e4.org_name='MOCK7_反例1_销售方股东', e4.flag_gdtqy='否', e4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cS3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P03'})
  ON CREATE SET cS3.contract_code='MOCK7_HT_P03', cS3.sign_time='2024-05-01', cS3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cB3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S03'})
  ON CREATE SET cB3.contract_code='MOCK7_HT_S03', cB3.sign_time='2024-05-02', cB3.schema_name='dws_dsjsj_zstp_vertex_ht';
// 反例 2：风险类型不在 6 类之内
MERGE (s4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP4'})
  ON CREATE SET s4.org_name='MOCK7_反例2_采购相对方', s4.flag_gdtqy='否', s4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (b4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY4'})
  ON CREATE SET b4.org_name='MOCK7_反例2_销售相对方', b4.flag_gdtqy='否', b4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (e5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E5'})
  ON CREATE SET e5.org_name='MOCK7_反例2_采购方股东', e5.flag_gdtqy='否', e5.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (e6:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E6'})
  ON CREATE SET e6.org_name='MOCK7_反例2_销售方股东', e6.flag_gdtqy='否', e6.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cS4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P04'})
  ON CREATE SET cS4.contract_code='MOCK7_HT_P04', cS4.sign_time='2024-07-01', cS4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cB4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S04'})
  ON CREATE SET cB4.contract_code='MOCK7_HT_S04', cB4.sign_time='2024-07-02', cB4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (rX:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_RX'})
  ON CREATE SET rX.risk_type='投标报价异常', rX.risk_desc='MOCK7: 不在 6 类清单内的类型',
                rX.risk_summary='投标报价异常', rX.schema_name='dws_dsjsj_zstp_vertex_fxxs';
// 反例 3：上下游合同无同一标的物关联
MERGE (s7:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP7'})
  ON CREATE SET s7.org_name='MOCK7_反例3_采购相对方', s7.flag_gdtqy='否', s7.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (b7:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY7'})
  ON CREATE SET b7.org_name='MOCK7_反例3_销售相对方', b7.flag_gdtqy='否', b7.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (e7:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E7'})
  ON CREATE SET e7.org_name='MOCK7_反例3_采购方股东', e7.flag_gdtqy='否', e7.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (e8:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E8'})
  ON CREATE SET e8.org_name='MOCK7_反例3_销售方股东', e8.flag_gdtqy='否', e8.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cS7:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P07'})
  ON CREATE SET cS7.contract_code='MOCK7_HT_P07', cS7.sign_time='2024-08-01', cS7.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cB7:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S07'})
  ON CREATE SET cB7.contract_code='MOCK7_HT_S07', cB7.sign_time='2024-08-02', cB7.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (r2:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_R2'})
  ON CREATE SET r2.risk_type='注册地址相同', r2.risk_desc='MOCK7: 类型在清单内但合同不同标的',
                r2.risk_summary='注册地址相同', r2.schema_name='dws_dsjsj_zstp_vertex_fxxs';

// ---- 5.2 边（MATCH 端点 + MERGE 关系，幂等可重复执行） ----
// 正例：g 双向签订 + 相对方签订
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P01'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_P01'}]->(c)
  ON CREATE SET r.sign_time='2024-03-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P02'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_P02'}]->(c)
  ON CREATE SET r.sign_time='2024-06-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S01'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_S01'}]->(c)
  ON CREATE SET r.sign_time='2024-04-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P01'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_S_P01'}]->(c)
  ON CREATE SET r.sign_time='2024-03-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P02'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_S_P02'}]->(c)
  ON CREATE SET r.sign_time='2024-06-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S01'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_B_S01'}]->(c)
  ON CREATE SET r.sign_time='2024-04-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';

// 正例：上下游合同/发票 同一标的物关联
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P01'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S01'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK7_E_TY_P01_S01'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P02'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S01'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK7_E_TY_P02_S01'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP'})
MATCH (c:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK7_FP_IN'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_kjjsfp {object_key:'MOCK7_E_FP_S'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_kjjsfp';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY'})
MATCH (c:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK7_FP_OUT'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_kjjsfp {object_key:'MOCK7_E_FP_B'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_kjjsfp';
MATCH (a:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK7_FP_IN'})
MATCH (c:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK7_FP_OUT'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_fp_tybdwgl {object_key:'MOCK7_E_TY_FP'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_fp_tybdwgl';

// 正例：持股链（采购侧 2 层、销售侧 1 层）与风险线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_ES'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_MID_SUP'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_ES_MID'}]->(c)
  ON CREATE SET r.capital_percent=60.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_MID_SUP'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_MID_S'}]->(c)
  ON CREATE SET r.capital_percent=80.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_EB'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_EB_B'}]->(c)
  ON CREATE SET r.capital_percent=70.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_ES'})
MATCH (c:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_R1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK7_E_CFFX_ES'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_EB'})
MATCH (c:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_R1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK7_E_CFFX_EB'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// 反例 1：合同同标的、有股东，但股东无共同风险线索
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P03'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_P03'}]->(c)
  ON CREATE SET r.sign_time='2024-05-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S03'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_S03'}]->(c)
  ON CREATE SET r.sign_time='2024-05-02', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP3'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P03'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_S3_P03'}]->(c)
  ON CREATE SET r.sign_time='2024-05-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY3'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S03'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_B3_S03'}]->(c)
  ON CREATE SET r.sign_time='2024-05-02', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P03'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S03'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK7_E_TY_P03_S03'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E3'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_E3_S3'}]->(c)
  ON CREATE SET r.capital_percent=50.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E4'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_E4_B3'}]->(c)
  ON CREATE SET r.capital_percent=50.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';

// 反例 2：股东同挂风险线索，但类型不在 6 类之内
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P04'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_P04'}]->(c)
  ON CREATE SET r.sign_time='2024-07-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S04'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_S04'}]->(c)
  ON CREATE SET r.sign_time='2024-07-02', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP4'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P04'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_S4_P04'}]->(c)
  ON CREATE SET r.sign_time='2024-07-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY4'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S04'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_B4_S04'}]->(c)
  ON CREATE SET r.sign_time='2024-07-02', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P04'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S04'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK7_E_TY_P04_S04'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E5'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_E5_S4'}]->(c)
  ON CREATE SET r.capital_percent=40.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E6'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_E6_B4'}]->(c)
  ON CREATE SET r.capital_percent=40.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E5'})
MATCH (c:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_RX'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK7_E_CFFX_E5'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E6'})
MATCH (c:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_RX'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK7_E_CFFX_E6'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// 反例 3：股东同挂 6 类之内的风险线索，但上下游合同无同标的关系
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P07'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_P07'}]->(c)
  ON CREATE SET r.sign_time='2024-08-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_GDTA'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S07'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_G_S07'}]->(c)
  ON CREATE SET r.sign_time='2024-08-02', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP7'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_P07'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_S7_P07'}]->(c)
  ON CREATE SET r.sign_time='2024-08-01', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY7'})
MATCH (c:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK7_HT_S07'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK7_E_QD_B7_S07'}]->(c)
  ON CREATE SET r.sign_time='2024-08-02', r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E7'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_SUP7'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_E7_S7'}]->(c)
  ON CREATE SET r.capital_percent=30.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E8'})
MATCH (c:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_BUY7'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_gdcgbfb {object_key:'MOCK7_E_GD_E8_B7'}]->(c)
  ON CREATE SET r.capital_percent=30.0, r.schema_name='dws_dsjsj_zstp_edge_qy_gdcgbfb';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E7'})
MATCH (c:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_R2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK7_E_CFFX_E7'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK7_QY_E8'})
MATCH (c:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK7_FXXS_R2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK7_E_CFFX_E8'}]->(c)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_cffx';


// =============================================================================
// 六、断言校验（先跑第五节灌数据，再跑本节，应全部 PASS）
// =============================================================================
// 断言 1~5：主查询仅命中正例，证据取最早合同，风险类型在 6 类内，反例全部排除
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cS <> cB AND (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
  AND cS.payment_direction IN ['采购', '付款']
  AND cB.payment_direction IN ['销售', '收款']
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH (b:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB)
WHERE s <> g AND b <> g AND s <> b AND s.flag_gdtqy = '否' AND b.flag_gdtqy = '否'
WITH g, s, b, cS, cB,
     coalesce(rdS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, cB.sign_time) AS tB
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, s, b, collect({cS: cS, cB: cB})[0] AS ev
CALL {
    WITH s
    MATCH (s)<-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*..3]-(d:dws_dsjsj_zstp_vertex_qy)
    RETURN collect(DISTINCT d) AS supSide
}
CALL {
    WITH b
    MATCH (b)<-[:dws_dsjsj_zstp_edge_qy_gdcgbfb*..3]-(d:dws_dsjsj_zstp_vertex_qy)
    RETURN collect(DISTINCT d) AS buySide
}
UNWIND supSide AS eS
UNWIND buySide AS eB
MATCH (eB)-[:dws_dsjsj_zstp_edge_qy_cffx]-(r:dws_dsjsj_zstp_vertex_fxxs)-[:dws_dsjsj_zstp_edge_qy_cffx]-(eS)
WHERE eS <> eB
  AND r.risk_type IN ['企业电话相同', '注册地址相同', '高管姓名相同',
                      '股东相同（自然人）', '股东相同（企业）', '股东与高管姓名相同']
WITH DISTINCT g, s, b, ev, eS, eB, r
WITH collect(DISTINCT s.org_name + '→' + b.org_name) AS 命中组合,
     collect(DISTINCT ev.cS.contract_code)          AS 证据合同,
     collect(DISTINCT r.risk_type)                  AS 风险类型,
     collect(DISTINCT eS.org_name)                  AS 采购方股东,
     collect(DISTINCT eB.org_name)                  AS 销售方股东
RETURN CASE WHEN size(命中组合) = 1 AND 命中组合[0] = 'MOCK7_采购相对方→MOCK7_销售相对方'
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 命中组合 | a + v + '; ') END AS 断言1_仅正例组合命中,
       CASE WHEN 证据合同 = ['MOCK7_HT_P01'] THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 证据合同 | a + v + '; ') END AS 断言2_证据取最早合同,
       CASE WHEN 风险类型 = ['企业电话相同'] THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 风险类型 | a + v + '; ') END AS 断言3_风险类型在6类内,
       CASE WHEN 采购方股东 = ['MOCK7_采购方股东E'] AND 销售方股东 = ['MOCK7_销售方股东E']
            THEN 'PASS' ELSE 'FAIL' END AS 断言4_两侧股东正确,
       CASE WHEN NOT any(x IN 命中组合 WHERE x CONTAINS '反例') THEN 'PASS' ELSE 'FAIL' END AS 断言5_三个反例均未命中;

// 断言 6：变体 B（发票侧同标的证据）可命中正例
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)<-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy {flag_gdtqy:'否'})
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)<-[:dws_dsjsj_zstp_edge_qy_qd]-(b:dws_dsjsj_zstp_vertex_qy {flag_gdtqy:'否'})
WHERE s <> b
MATCH (s)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|dws_dsjsj_zstp_edge_qy_csfp]->(fS:dws_dsjsj_zstp_vertex_fp)
MATCH (b)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|dws_dsjsj_zstp_edge_qy_csfp]->(fB:dws_dsjsj_zstp_vertex_fp)
WHERE fS <> fB AND (fS)-[:dws_dsjsj_zstp_edge_fp_tybdwgl]-(fB)
WITH collect(DISTINCT CASE WHEN s.org_name < b.org_name
                           THEN s.org_name + '+' + b.org_name + '+' + fS.fp_hm + '~' + fB.fp_hm
                           ELSE b.org_name + '+' + s.org_name + '+' + fB.fp_hm + '~' + fS.fp_hm END) AS 发票侧命中
RETURN CASE WHEN 发票侧命中 = ['MOCK7_采购相对方+MOCK7_销售相对方+MOCK7_FP_IN~MOCK7_FP_OUT']
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 发票侧命中 | a + v + '; ') END AS 断言6_发票侧同标的有效;


// =============================================================================
// 七、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK7_' DETACH DELETE n;
