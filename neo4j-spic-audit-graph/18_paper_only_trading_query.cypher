// =============================================================================
// 18 SPIC-CW-0104 疑似空转走单交易 · 同标的购销合同对 + 三项空转特征判定
// -----------------------------------------------------------------------------
// 对应流程图（基于 0109 结果数据，即在"同一标的物关联上下游合同"链条上叠加空转特征）:
//
//   (销售合同相对方 sB)-[:签订合同]->(销售合同 cB)<-[:签订合同]-(国电投企业A g)
//   (国电投企业A g)   -[:签订合同]->(采购合同 cS)<-[:签订合同]-(采购合同相对方 sS)
//   (cB)-[:同一标的物关联_合同]-(cS)              ← 同一标的物关联上下游合同（0109 口径，见 16 号文件）
//   (cB)-[:按销售合同出库]->(出库 ck)<-[:消耗物料]-(物料 mOut)
//   (cS)-[:按采购合同入库]->(入库 rk)<-[:领用物料]-(物料 mIn)
//   （图中入/出库两侧的 物料 为两个独立节点，不要求同一物料，贯通关系由合同同标的承担）
//
// 判断条件一（三项任一命中即判"空转走单"特征）:
//   1. 购销合同签订时间间隔在 ±60 天内
//      （进销项发票开票时间差口径见第四节变体 B —— 模型无 合同-发票 直连边，
//        需按生产实际的开票关联落地后启用）；
//   2. 最早一条出、入库时间间隔在 ±60 天内；
//   3. 采购或销售合同内交货信息未约定交货地点（交货地点为空），或交货地点仅填写"仓库"。
//
// 口径:
//   1. 购销方向由 合同.payment_direction 区分（实际取值：'销售'/'收款'=销售合同，
//      '采购'/'付款'=采购合同）：cS 限采购侧、cB 限销售侧，天然防角色镜像；
//      若生产存在方向缺失合同，把 IN 条件放宽为 (x IN [...] OR x IS NULL)。
//   2. 同一 (g, sS, sB) 存在多对同标的购销合同时，按签订时间取最早一对作为证据；
//      入库/出库取各自最早一条参与条件 2（时间取边 sign_time 优先，回落合同节点）。
//   3. sS 与 sB 允许相同（同一外部企业一买一卖是空转走单的典型形态，不作排除）。
//   4. 时间统一转 date（left(...,10) 兼容带时分秒的字符串）；任一侧时间缺失，
//      对应条件按"不命中"处理，不影响其他条件。±60 天用 duration('P60D') 加减判定，
//      不要用 duration.between(x,y).days —— 它会把整月差归入 months 组件（days=0，恒命中）。
//   5. 条件 3 的"交货地点"按合同节点 delivery_place 属性实现 —— 01 号 DDL 的 合同
//      主字段清单未含该属性，生产按实际字段名替换；若生产合同确无此字段，条件 3 恒真，
//      应删除该条件或改用出入库记录的交货库存地点（出库.lgort / 入库.umlgo）口径。
// =============================================================================


// =============================================================================
// 一、主查询：命中任一空转特征即返回（5 段路径 + 三条件判定明细）
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位；全图扫描时注释掉本行与下一行）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'

// 1. 0109 链条：g 的采购侧合同 cS 与销售侧合同 cB 互为"同一标的物关联"
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cS <> cB
  AND (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
  // 方向过滤：'采购'/'付款'=采购合同，'销售'/'收款'=销售合同（同时天然防角色镜像）
  AND cS.payment_direction IN ['采购', '付款']
  AND cB.payment_direction IN ['销售', '收款']

// 2. 两个外部相对方：sS 签采购侧 cS，sB 签销售侧 cB
MATCH (sS:dws_dsjsj_zstp_vertex_qy)-[rS:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH (sB:dws_dsjsj_zstp_vertex_qy)-[rB:dws_dsjsj_zstp_edge_qy_qd]->(cB)
WHERE sS <> g AND sB <> g
  AND sS.flag_gdtqy = '否' AND sB.flag_gdtqy = '否'

// 3. 同一 (g, sS, sB) 只取签订时间最早的一对购销合同作为证据
WITH g, sS, sB, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, sS, sB, collect({cS: cS, cB: cB, tS: tS, tB: tB})[0] AS ev

// 4. 采购侧最早一条入库、销售侧最早一条出库（无记录返回 null，不影响其他条件）
CALL {
    WITH ev
    WITH ev.cS AS cS
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH rk ORDER BY rk.budat ASC
    WITH head(collect(rk)) AS rkMin
    RETURN rkMin
}
CALL {
    WITH ev
    WITH ev.cB AS cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH ck ORDER BY ck.wadat_ist ASC
    WITH head(collect(ck)) AS ckMin
    RETURN ckMin
}

// 5. 时间归一化 + 三项空转特征判定（任一命中即返回）
WITH g, sS, sB, ev, rkMin, ckMin,
     CASE WHEN ev.tS IS NULL OR trim(ev.tS) = '' THEN NULL ELSE date(left(ev.tS, 10)) END AS dS,
     CASE WHEN ev.tB IS NULL OR trim(ev.tB) = '' THEN NULL ELSE date(left(ev.tB, 10)) END AS dB,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL OR trim(rkMin.budat) = '' THEN NULL
          ELSE date(left(rkMin.budat, 10)) END AS dIn,
     CASE WHEN ckMin IS NULL OR ckMin.wadat_ist IS NULL OR trim(ckMin.wadat_ist) = '' THEN NULL
          ELSE date(left(ckMin.wadat_ist, 10)) END AS dOut
WITH g, sS, sB, ev, rkMin, ckMin, dS, dB, dIn, dOut,
     (dS IS NOT NULL AND dB IS NOT NULL
      AND dB >= dS - duration('P60D') AND dB <= dS + duration('P60D')) AS 条件1_签订时间差60天内,
     (dIn IS NOT NULL AND dOut IS NOT NULL
      AND dOut >= dIn - duration('P60D') AND dOut <= dIn + duration('P60D')) AS 条件2_最早出入库差60天内,
     (trim(coalesce(ev.cS.delivery_place, '')) IN ['', '仓库']
      OR trim(coalesce(ev.cB.delivery_place, '')) IN ['', '仓库']) AS 条件3_交货地点未约定
WHERE 条件1_签订时间差60天内 OR 条件2_最早出入库差60天内 OR 条件3_交货地点未约定

// 6. 解包证据，还原 5 段路径（购销合同链 ×2 + 同标的关系 + 入库/出库物流链）
WITH g, sS, sB, ev, rkMin, ckMin,
     条件1_签订时间差60天内, 条件2_最早出入库差60天内, 条件3_交货地点未约定,
     ev.cS AS cS, ev.cB AS cB
MATCH pS = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS)<-[:dws_dsjsj_zstp_edge_qy_qd]-(sS)
MATCH pB = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB)<-[:dws_dsjsj_zstp_edge_qy_qd]-(sB)
MATCH pL = (cB)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cS)
OPTIONAL MATCH pIn  = (mIn:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rkMin)
                      <-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(cS)
OPTIONAL MATCH pOut = (mOut:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ckMin)
                      <-[:dws_dsjsj_zstp_edge_ht_axshtck]-(cB)
RETURN DISTINCT pS, pB, pL, pIn, pOut,
       g.org_name  AS 国电投企业,
       sS.org_name AS 采购合同相对方,
       sB.org_name AS 销售合同相对方,
       cS.contract_code AS 采购合同, cS.sign_time AS 采购合同签订时间,
       cB.contract_code AS 销售合同, cB.sign_time AS 销售合同签订时间,
       条件1_签订时间差60天内, 条件2_最早出入库差60天内, 条件3_交货地点未约定,
       '疑似空转走单交易' AS 命中规则;


// =============================================================================
// 二、明细输出版（核查字段，不返回路径）：替换主查询第 6 步之后的 MATCH/RETURN
// =============================================================================
// RETURN DISTINCT
//     g.org_name  AS 国电投企业,
//     sS.org_name AS 采购合同相对方,
//     sB.org_name AS 销售合同相对方,
//     cS.contract_code AS 采购合同, cS.sign_time AS 采购合同签订时间,
//     cB.contract_code AS 销售合同, cB.sign_time AS 销售合同签订时间,
//     rkMin.mblnr AS 最早入库单号, rkMin.budat AS 入库时间,
//     ckMin.vbeln AS 最早出库单号, ckMin.wadat_ist AS 出库时间,
//     条件1_签订时间差60天内, 条件2_最早出入库差60天内, 条件3_交货地点未约定,
//     '疑似空转走单交易' AS 命中规则;


// =============================================================================
// 三、变体 A（宽松版）：0109 链条全量返回，标注各自命中的空转特征
// -----------------------------------------------------------------------------
// 不按三条件过滤，而是给每条同标的购销链打"空转特征"标签，便于审计排序核查
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cS <> cB
  AND (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
  AND cS.payment_direction IN ['采购', '付款']
  AND cB.payment_direction IN ['销售', '收款']
MATCH (sS:dws_dsjsj_zstp_vertex_qy)-[rS:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH (sB:dws_dsjsj_zstp_vertex_qy)-[rB:dws_dsjsj_zstp_edge_qy_qd]->(cB)
WHERE sS <> g AND sB <> g
  AND sS.flag_gdtqy = '否' AND sB.flag_gdtqy = '否'
WITH g, sS, sB, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, sS, sB, collect({cS: cS, cB: cB, tS: tS, tB: tB})[0] AS ev
CALL {
    WITH ev
    WITH ev.cS AS cS
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH rk ORDER BY rk.budat ASC
    WITH head(collect(rk)) AS rkMin
    RETURN rkMin
}
CALL {
    WITH ev
    WITH ev.cB AS cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH ck ORDER BY ck.wadat_ist ASC
    WITH head(collect(ck)) AS ckMin
    RETURN ckMin
}
WITH g, sS, sB, ev, rkMin, ckMin,
     CASE WHEN ev.tS IS NULL OR trim(ev.tS) = '' THEN NULL ELSE date(left(ev.tS, 10)) END AS dS,
     CASE WHEN ev.tB IS NULL OR trim(ev.tB) = '' THEN NULL ELSE date(left(ev.tB, 10)) END AS dB,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL OR trim(rkMin.budat) = '' THEN NULL
          ELSE date(left(rkMin.budat, 10)) END AS dIn,
     CASE WHEN ckMin IS NULL OR ckMin.wadat_ist IS NULL OR trim(ckMin.wadat_ist) = '' THEN NULL
          ELSE date(left(ckMin.wadat_ist, 10)) END AS dOut
WITH g, sS, sB, ev,
     (dS IS NOT NULL AND dB IS NOT NULL
      AND dB >= dS - duration('P60D') AND dB <= dS + duration('P60D')) AS c1,
     (dIn IS NOT NULL AND dOut IS NOT NULL
      AND dOut >= dIn - duration('P60D') AND dOut <= dIn + duration('P60D')) AS c2,
     (trim(coalesce(ev.cS.delivery_place, '')) IN ['', '仓库']
      OR trim(coalesce(ev.cB.delivery_place, '')) IN ['', '仓库']) AS c3
WITH g, sS, sB, ev, c1, c2, c3,
     trim(CASE WHEN c1 THEN '签订时间差60天内' ELSE '' END
          + CASE WHEN c2 THEN ' + 最早出入库差60天内' ELSE '' END
          + CASE WHEN c3 THEN ' + 交货地点未约定' ELSE '' END) AS 空转特征
RETURN DISTINCT g.org_name  AS 国电投企业,
       sS.org_name AS 采购合同相对方, sB.org_name AS 销售合同相对方,
       ev.cS.contract_code AS 采购合同, ev.cB.contract_code AS 销售合同,
       CASE WHEN 空转特征 = '' THEN '无空转特征'
            WHEN 空转特征 STARTS WITH '+ ' THEN substring(空转特征, 2)
            ELSE 空转特征 END AS 空转特征,
       CASE WHEN 空转特征 <> '' THEN '疑似空转走单交易' ELSE '仅0109链条' END AS 命中规则
ORDER BY 命中规则 DESC, 采购合同;


// =============================================================================
// 四、变体 B：进销项发票开票时间差口径（条件 1 的发票分支）
// -----------------------------------------------------------------------------
// 流程图条件 1 的完整表述为"购销合同签订时间 或 进销项发票开票时间间隔在±60天内"。
// 当前模型中发票通过 企业-[:开具接收发票|产生发票_企业]->发票 挂在企业上，
// 发票 与 合同 之间没有直连边，无法精确到"该合同对应的进/销项发票"，
// 只能做企业级近似：g 的销项发票与进项发票最早开票时间差 ≤60 天。
// 生产若补齐 合同-发票 关联，把 cS/cB 换成合同级发票即可：
// -----------------------------------------------------------------------------
// MATCH (g)-[:dws_dsjsj_zstp_edge_qy_kjjsfp]->(fOut:dws_dsjsj_zstp_vertex_fp)  // 销项
// MATCH (g)-[:dws_dsjsj_zstp_edge_qy_csfp]->(fIn:dws_dsjsj_zstp_vertex_fp)    // 进项
// WHERE trim(coalesce(fOut.fplx,'')) CONTAINS '销'
//   AND trim(coalesce(fIn.fplx,''))  CONTAINS '进'
// WITH min(fOut.kprq) AS 销项最早开票, min(fIn.kprq) AS 进项最早开票
// （再用与条件 1 相同的 date + duration.between ±60 天判定，与签订时间差做 OR）


// =============================================================================
// 五、自包含验证数据（MOCK9_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 正例1: 签订时间差 19 天 → 条件1 命中（出入库差 92 天、交货地点真实，均不干扰）
//        另有一对同组合更晚的合同 CS1B/CB1B（差 4 天）→ 证据应取最早的 CS1A/CB1A
// 正例2: 最早出入库差 10 天 → 条件2 命中（签订差 117 天、交货地点真实）
// 正例3: 采购合同交货地点='仓库' → 条件3 命中（签订差 90 天、出入库差 92 天）
// 反例1: 三条件均不命中（签订差 121 天、出入库差 131 天、交货地点为真实地址）
// 反例2: 两份合同方向同为'采购'（方向过滤排除；无方向过滤时会以镜像角色误命中）
// 反例3: 购销合同无"同一标的物关联"（尽管签订差仅 9 天，应被 0109 链条门槛排除）
// =============================================================================

// ---- 5.1 顶点 ----
MERGE (g:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
  ON CREATE SET g.org_name='MOCK9_国电投企业A', g.flag_gdtqy='是',
                g.org_credit_code='913402003950006371', g.schema_name='dws_dsjsj_zstp_vertex_qy';
// 正例1 相对方与合同
MERGE (ss1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS1'})
  ON CREATE SET ss1.org_name='MOCK9_外部采购相对方1', ss1.flag_gdtqy='否', ss1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sb1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB1'})
  ON CREATE SET sb1.org_name='MOCK9_外部销售相对方1', sb1.flag_gdtqy='否', sb1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cs1a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1A'})
  ON CREATE SET cs1a.contract_code='MOCK9_HT_CS1A', cs1a.payment_direction='采购',
                cs1a.sign_time='2024-03-01', cs1a.delivery_place='上海市浦东新区世纪大道88号',
                cs1a.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cb1a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1A'})
  ON CREATE SET cb1a.contract_code='MOCK9_HT_CB1A', cb1a.payment_direction='销售',
                cb1a.sign_time='2024-03-20', cb1a.delivery_place='上海市浦东新区世纪大道88号',
                cb1a.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cs1b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1B'})
  ON CREATE SET cs1b.contract_code='MOCK9_HT_CS1B', cs1b.payment_direction='采购',
                cs1b.sign_time='2024-07-01', cs1b.delivery_place='上海市浦东新区世纪大道88号',
                cs1b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cb1b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1B'})
  ON CREATE SET cb1b.contract_code='MOCK9_HT_CB1B', cb1b.payment_direction='销售',
                cb1b.sign_time='2024-07-05', cb1b.delivery_place='上海市浦东新区世纪大道88号',
                cb1b.schema_name='dws_dsjsj_zstp_vertex_ht';
// 正例2
MERGE (ss2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS2'})
  ON CREATE SET ss2.org_name='MOCK9_外部采购相对方2', ss2.flag_gdtqy='否', ss2.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sb2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB2'})
  ON CREATE SET sb2.org_name='MOCK9_外部销售相对方2', sb2.flag_gdtqy='否', sb2.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cs2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS2'})
  ON CREATE SET cs2.contract_code='MOCK9_HT_CS2', cs2.payment_direction='采购',
                cs2.sign_time='2024-01-05', cs2.delivery_place='北京市海淀区知春路1号',
                cs2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cb2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB2'})
  ON CREATE SET cb2.contract_code='MOCK9_HT_CB2', cb2.payment_direction='销售',
                cb2.sign_time='2024-05-01', cb2.delivery_place='北京市海淀区知春路1号',
                cb2.schema_name='dws_dsjsj_zstp_vertex_ht';
// 正例3（交货地点命中：'仓库' 与 空串）
MERGE (ss3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS3'})
  ON CREATE SET ss3.org_name='MOCK9_外部采购相对方3', ss3.flag_gdtqy='否', ss3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sb3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB3'})
  ON CREATE SET sb3.org_name='MOCK9_外部销售相对方3', sb3.flag_gdtqy='否', sb3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cs3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS3'})
  ON CREATE SET cs3.contract_code='MOCK9_HT_CS3', cs3.payment_direction='采购',
                cs3.sign_time='2024-02-01', cs3.delivery_place='仓库',
                cs3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cb3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB3'})
  ON CREATE SET cb3.contract_code='MOCK9_HT_CB3', cb3.payment_direction='销售',
                cb3.sign_time='2024-05-01', cb3.delivery_place='',
                cb3.schema_name='dws_dsjsj_zstp_vertex_ht';
// 反例1（三条件均不命中）
MERGE (ss4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS4'})
  ON CREATE SET ss4.org_name='MOCK9_反例1_外部采购相对方', ss4.flag_gdtqy='否', ss4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sb4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB4'})
  ON CREATE SET sb4.org_name='MOCK9_反例1_外部销售相对方', sb4.flag_gdtqy='否', sb4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cs4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS4'})
  ON CREATE SET cs4.contract_code='MOCK9_HT_CS4', cs4.payment_direction='采购',
                cs4.sign_time='2024-01-01', cs4.delivery_place='广州市天河区体育西路100号',
                cs4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cb4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB4'})
  ON CREATE SET cb4.contract_code='MOCK9_HT_CB4', cb4.payment_direction='销售',
                cb4.sign_time='2024-05-01', cb4.delivery_place='广州市天河区体育西路100号',
                cb4.schema_name='dws_dsjsj_zstp_vertex_ht';
// 反例2（两份合同方向同为采购，验证方向过滤）
MERGE (ss5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS5'})
  ON CREATE SET ss5.org_name='MOCK9_反例2_外部相对方A', ss5.flag_gdtqy='否', ss5.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sb5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB5'})
  ON CREATE SET sb5.org_name='MOCK9_反例2_外部相对方B', sb5.flag_gdtqy='否', sb5.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cp5a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5A'})
  ON CREATE SET cp5a.contract_code='MOCK9_HT_P5A', cp5a.payment_direction='采购',
                cp5a.sign_time='2024-02-01', cp5a.delivery_place='仓库',
                cp5a.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cp5b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5B'})
  ON CREATE SET cp5b.contract_code='MOCK9_HT_P5B', cp5b.payment_direction='采购',
                cp5b.sign_time='2024-02-15', cp5b.delivery_place='仓库',
                cp5b.schema_name='dws_dsjsj_zstp_vertex_ht';
// 反例3（无同一标的物关联，签订差 9 天也不得命中）
MERGE (ss6:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS6'})
  ON CREATE SET ss6.org_name='MOCK9_反例3_外部采购相对方', ss6.flag_gdtqy='否', ss6.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sb6:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB6'})
  ON CREATE SET sb6.org_name='MOCK9_反例3_外部销售相对方', sb6.flag_gdtqy='否', sb6.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (cs6:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS6'})
  ON CREATE SET cs6.contract_code='MOCK9_HT_CS6', cs6.payment_direction='采购',
                cs6.sign_time='2024-03-01', cs6.delivery_place='仓库',
                cs6.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (cb6:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB6'})
  ON CREATE SET cb6.contract_code='MOCK9_HT_CB6', cb6.payment_direction='销售',
                cb6.sign_time='2024-03-10', cb6.delivery_place='仓库',
                cb6.schema_name='dws_dsjsj_zstp_vertex_ht';
// 出入库与物料
MERGE (rk1:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_01'})
  ON CREATE SET rk1.mblnr='MOCK9_RK_01', rk1.budat='2024-06-01', rk1.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck1:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_01'})
  ON CREATE SET ck1.vbeln='MOCK9_CK_01', ck1.wadat_ist='2024-09-01', ck1.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (rk2:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_02'})
  ON CREATE SET rk2.mblnr='MOCK9_RK_02', rk2.budat='2024-05-10', rk2.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck2:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_02'})
  ON CREATE SET ck2.vbeln='MOCK9_CK_02', ck2.wadat_ist='2024-05-20', ck2.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (rk3:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_03'})
  ON CREATE SET rk3.mblnr='MOCK9_RK_03', rk3.budat='2024-05-02', rk3.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck3:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_03'})
  ON CREATE SET ck3.vbeln='MOCK9_CK_03', ck3.wadat_ist='2024-08-02', ck3.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (rk4:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_04'})
  ON CREATE SET rk4.mblnr='MOCK9_RK_04', rk4.budat='2024-05-02', rk4.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck4:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_04'})
  ON CREATE SET ck4.vbeln='MOCK9_CK_04', ck4.wadat_ist='2024-09-10', ck4.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (rk6:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_06'})
  ON CREATE SET rk6.mblnr='MOCK9_RK_06', rk6.budat='2024-03-05', rk6.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck6:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_06'})
  ON CREATE SET ck6.vbeln='MOCK9_CK_06', ck6.wadat_ist='2024-03-08', ck6.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (w1a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN1'})
  ON CREATE SET w1a.matnr='MOCK9-MAT-IN1', w1a.maktx='MOCK9_入库物料1', w1a.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w1b:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT1'})
  ON CREATE SET w1b.matnr='MOCK9-MAT-OUT1', w1b.maktx='MOCK9_出库物料1', w1b.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w2a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN2'})
  ON CREATE SET w2a.matnr='MOCK9-MAT-IN2', w2a.maktx='MOCK9_入库物料2', w2a.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w2b:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT2'})
  ON CREATE SET w2b.matnr='MOCK9-MAT-OUT2', w2b.maktx='MOCK9_出库物料2', w2b.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w3a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN3'})
  ON CREATE SET w3a.matnr='MOCK9-MAT-IN3', w3a.maktx='MOCK9_入库物料3', w3a.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w3b:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT3'})
  ON CREATE SET w3b.matnr='MOCK9-MAT-OUT3', w3b.maktx='MOCK9_出库物料3', w3b.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w4a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN4'})
  ON CREATE SET w4a.matnr='MOCK9-MAT-IN4', w4a.maktx='MOCK9_入库物料4', w4a.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w4b:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT4'})
  ON CREATE SET w4b.matnr='MOCK9-MAT-OUT4', w4b.maktx='MOCK9_出库物料4', w4b.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w6a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN6'})
  ON CREATE SET w6a.matnr='MOCK9-MAT-IN6', w6a.maktx='MOCK9_入库物料6', w6a.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w6b:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT6'})
  ON CREATE SET w6b.matnr='MOCK9-MAT-OUT6', w6b.maktx='MOCK9_出库物料6', w6b.schema_name='dws_dsjsj_zstp_vertex_wl';

// ---- 5.2 边（MATCH 端点 + MERGE 关系，幂等可重复执行；勿用匿名节点全模式 MERGE，会重建端点） ----
// 正例1 签约（g 双向 + 两对外部相对方；早/晚两对）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_01'}]->(b)
  ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_02'}]->(b)
  ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_03'}]->(b)
  ON CREATE SET e.sign_time='2024-03-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_04'}]->(b)
  ON CREATE SET e.sign_time='2024-03-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_05'}]->(b)
  ON CREATE SET e.sign_time='2024-07-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_06'}]->(b)
  ON CREATE SET e.sign_time='2024-07-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_07'}]->(b)
  ON CREATE SET e.sign_time='2024-07-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_08'}]->(b)
  ON CREATE SET e.sign_time='2024-07-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// 正例1 同标的 + 物流（挂早对 CS1A/CB1A）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1A'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK9_E_TY1A'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1B'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK9_E_TY1B'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS1A'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK9_E_RK1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK9_E_LY1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB1A'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK9_E_CK1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT1'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_01'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK9_E_XH1'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 正例2 签约 + 同标的 + 物流（入库/出库差 10 天）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS2'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_09'}]->(b)
  ON CREATE SET e.sign_time='2024-01-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS2'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_10'}]->(b)
  ON CREATE SET e.sign_time='2024-01-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB2'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_11'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB2'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_12'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS2'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK9_E_TY2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK9_E_RK2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK9_E_LY2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK9_E_CK2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_02'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK9_E_XH2'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 正例3 签约 + 同标的 + 物流（时间均不命中，靠交货地点）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS3'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_13'}]->(b)
  ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS3'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_14'}]->(b)
  ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB3'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_15'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB3'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_16'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS3'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK9_E_TY3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS3'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_03'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK9_E_RK3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN3'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_03'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK9_E_LY3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB3'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_03'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK9_E_CK3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT3'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_03'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK9_E_XH3'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 反例1 签约 + 同标的 + 物流（三条件均不命中）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS4'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_17'}]->(b)
  ON CREATE SET e.sign_time='2024-01-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS4'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_18'}]->(b)
  ON CREATE SET e.sign_time='2024-01-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB4'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_19'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB4'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_20'}]->(b)
  ON CREATE SET e.sign_time='2024-05-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS4'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK9_E_TY4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK9_E_RK4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK9_E_LY4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB4'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK9_E_CK4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT4'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_04'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK9_E_XH4'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// 反例2 签约 + 同标的（方向同为采购）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_21'}]->(b)
  ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_22'}]->(b)
  ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_23'}]->(b)
  ON CREATE SET e.sign_time='2024-02-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5B'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_24'}]->(b)
  ON CREATE SET e.sign_time='2024-02-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5B'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_P5A'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK9_E_TY5'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';
// 反例3 签约 + 物流（无同标的；签订差 9 天、出入库差 3 天，若无门槛即命中）
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SS6'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_25'}]->(b)
  ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_26'}]->(b)
  ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_SB6'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_27'}]->(b)
  ON CREATE SET e.sign_time='2024-03-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK9_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB6'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK9_E_28'}]->(b)
  ON CREATE SET e.sign_time='2024-03-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CS6'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK9_E_RK6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_IN6'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK9_RK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK9_E_LY6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK9_HT_CB6'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK9_E_CK6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK9_WL_OUT6'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK9_CK_06'})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK9_E_XH6'}]->(b)
  ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';


// =============================================================================
// 六、断言校验（先跑第五节灌数据，再跑本节，应全部 PASS）
// =============================================================================
// 断言 1：主查询恰好命中 3 个正例，各自命中的特征正确，证据取最早一对（CS1A 而非 CS1B）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cS <> cB AND (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
  AND cS.payment_direction IN ['采购', '付款']
  AND cB.payment_direction IN ['销售', '收款']
MATCH (sS:dws_dsjsj_zstp_vertex_qy)-[rS:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH (sB:dws_dsjsj_zstp_vertex_qy)-[rB:dws_dsjsj_zstp_edge_qy_qd]->(cB)
WHERE sS <> g AND sB <> g AND sS.flag_gdtqy = '否' AND sB.flag_gdtqy = '否'
WITH g, sS, sB, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, sS, sB, collect({cS: cS, cB: cB, tS: tS, tB: tB})[0] AS ev
CALL {
    WITH ev
    WITH ev.cS AS cS
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH rk ORDER BY rk.budat ASC
    WITH head(collect(rk)) AS rkMin
    RETURN rkMin
}
CALL {
    WITH ev
    WITH ev.cB AS cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH ck ORDER BY ck.wadat_ist ASC
    WITH head(collect(ck)) AS ckMin
    RETURN ckMin
}
WITH g, sS, sB, ev,
     CASE WHEN ev.tS IS NULL OR trim(ev.tS) = '' THEN NULL ELSE date(left(ev.tS, 10)) END AS dS,
     CASE WHEN ev.tB IS NULL OR trim(ev.tB) = '' THEN NULL ELSE date(left(ev.tB, 10)) END AS dB,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL OR trim(rkMin.budat) = '' THEN NULL
          ELSE date(left(rkMin.budat, 10)) END AS dIn,
     CASE WHEN ckMin IS NULL OR ckMin.wadat_ist IS NULL OR trim(ckMin.wadat_ist) = '' THEN NULL
          ELSE date(left(ckMin.wadat_ist, 10)) END AS dOut
WITH g, sS, sB, ev,
     (dS IS NOT NULL AND dB IS NOT NULL AND dB >= dS - duration('P60D') AND dB <= dS + duration('P60D')) AS c1,
     (dIn IS NOT NULL AND dOut IS NOT NULL AND dOut >= dIn - duration('P60D') AND dOut <= dIn + duration('P60D')) AS c2,
     (trim(coalesce(ev.cS.delivery_place, '')) IN ['', '仓库']
      OR trim(coalesce(ev.cB.delivery_place, '')) IN ['', '仓库']) AS c3
WHERE c1 OR c2 OR c3
WITH g, sS, sB, ev,
     trim(CASE WHEN c1 THEN '签订时间差60天内' ELSE '' END
          + CASE WHEN c2 THEN ' + 最早出入库差60天内' ELSE '' END
          + CASE WHEN c3 THEN ' + 交货地点未约定' ELSE '' END) AS 特征串
WITH g, sS, sB, ev,
     CASE WHEN 特征串 STARTS WITH '+ ' THEN substring(特征串, 2) ELSE 特征串 END AS 特征
WITH collect(DISTINCT sS.org_name + '|' + sB.org_name + '|'
             + ev.cS.contract_code + '|' + ev.cB.contract_code + '|' + 特征) AS 命中明细,
     ['MOCK9_外部采购相对方1|MOCK9_外部销售相对方1|MOCK9_HT_CS1A|MOCK9_HT_CB1A|签订时间差60天内',
      'MOCK9_外部采购相对方2|MOCK9_外部销售相对方2|MOCK9_HT_CS2|MOCK9_HT_CB2|最早出入库差60天内',
      'MOCK9_外部采购相对方3|MOCK9_外部销售相对方3|MOCK9_HT_CS3|MOCK9_HT_CB3|交货地点未约定'] AS 期望
RETURN CASE WHEN size(命中明细) = size(期望) AND all(x IN 期望 WHERE x IN 命中明细)
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 命中明细 | a + v + '; ') END AS 断言1_三正例命中且特征与证据正确;

// 断言 2：宽松版（变体 A）共 4 条 —— 3 个正例各自标注命中的特征，反例1 标注"无空转特征"；
//         反例2（方向同为采购，被方向过滤排除）与反例3（无同标的，被链条门槛排除）不出现
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950006371'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cS <> cB AND (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
  AND cS.payment_direction IN ['采购', '付款']
  AND cB.payment_direction IN ['销售', '收款']
MATCH (sS:dws_dsjsj_zstp_vertex_qy)-[rS:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH (sB:dws_dsjsj_zstp_vertex_qy)-[rB:dws_dsjsj_zstp_edge_qy_qd]->(cB)
WHERE sS <> g AND sB <> g AND sS.flag_gdtqy = '否' AND sB.flag_gdtqy = '否'
WITH g, sS, sB, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, sS, sB, collect({cS: cS, cB: cB, tS: tS, tB: tB})[0] AS ev
CALL {
    WITH ev
    WITH ev.cS AS cS
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH rk ORDER BY rk.budat ASC
    WITH head(collect(rk)) AS rkMin
    RETURN rkMin
}
CALL {
    WITH ev
    WITH ev.cB AS cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH ck ORDER BY ck.wadat_ist ASC
    WITH head(collect(ck)) AS ckMin
    RETURN ckMin
}
WITH g, sS, sB, ev,
     CASE WHEN ev.tS IS NULL OR trim(ev.tS) = '' THEN NULL ELSE date(left(ev.tS, 10)) END AS dS,
     CASE WHEN ev.tB IS NULL OR trim(ev.tB) = '' THEN NULL ELSE date(left(ev.tB, 10)) END AS dB,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL OR trim(rkMin.budat) = '' THEN NULL
          ELSE date(left(rkMin.budat, 10)) END AS dIn,
     CASE WHEN ckMin IS NULL OR ckMin.wadat_ist IS NULL OR trim(ckMin.wadat_ist) = '' THEN NULL
          ELSE date(left(ckMin.wadat_ist, 10)) END AS dOut
WITH g, sS, sB, ev,
     (dS IS NOT NULL AND dB IS NOT NULL AND dB >= dS - duration('P60D') AND dB <= dS + duration('P60D')) AS c1,
     (dIn IS NOT NULL AND dOut IS NOT NULL AND dOut >= dIn - duration('P60D') AND dOut <= dIn + duration('P60D')) AS c2,
     (trim(coalesce(ev.cS.delivery_place, '')) IN ['', '仓库']
      OR trim(coalesce(ev.cB.delivery_place, '')) IN ['', '仓库']) AS c3
WITH g, sS, sB, ev, c1, c2, c3,
     trim(CASE WHEN c1 THEN '签订时间差60天内' ELSE '' END
          + CASE WHEN c2 THEN ' + 最早出入库差60天内' ELSE '' END
          + CASE WHEN c3 THEN ' + 交货地点未约定' ELSE '' END) AS 特征串
WITH g, sS, sB, ev,
     CASE WHEN 特征串 = '' THEN '无空转特征'
          WHEN 特征串 STARTS WITH '+ ' THEN substring(特征串, 2)
          ELSE 特征串 END AS 特征
WITH collect(DISTINCT sS.org_name + '|' + sB.org_name + '|' + 特征) AS 宽松版明细,
     ['MOCK9_外部采购相对方1|MOCK9_外部销售相对方1|签订时间差60天内',
      'MOCK9_外部采购相对方2|MOCK9_外部销售相对方2|最早出入库差60天内',
      'MOCK9_外部采购相对方3|MOCK9_外部销售相对方3|交货地点未约定',
      'MOCK9_反例1_外部采购相对方|MOCK9_反例1_外部销售相对方|无空转特征'] AS 期望
RETURN CASE WHEN size(宽松版明细) = size(期望) AND all(x IN 期望 WHERE x IN 宽松版明细)
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 宽松版明细 | a + v + '; ') END AS 断言2_宽松版四条且特征标注正确;


// =============================================================================
// 七、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK9_' DETACH DELETE n;
