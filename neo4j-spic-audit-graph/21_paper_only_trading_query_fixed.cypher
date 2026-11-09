// =============================================================================
// 21 SPIC-CW-0104 疑似空转走单交易 · 草稿修复与扩写版
// -----------------------------------------------------------------------------
// 输入：国电投企业（默认按统一社会信用代码定位）
//
// 图模式（与需求草图一致，箭头按生产 DDL 的 from_key -> to_key）：
//
//   (s 销售合同相对方)-[:签订合同]->(cS 销售合同)<-[:签订合同]-(g 国电投企业A)
//   (g 国电投企业A)-[:签订合同]->(cB 采购合同)<-[:签订合同]-(b 采购合同相对方)
//   (cS 销售合同)-[:同一标的物关联_合同]-(cB 采购合同)
//   (cB 采购合同)-[:按采购合同入库]->(rk 入库)<-[:领用物料]-(mIn 物料)
//   (cS 销售合同)-[:按销售合同出库]->(ck 出库)<-[:消耗物料]-(mOut 物料)
//
// 三项特征（任一命中即判“疑似空转走单交易”）：
//   C1 购销合同签订时间差在 ±60 天内，
//      或进销项发票开票时间差在 ±60 天内（无合同-发票直连边时按企业级近似）；
//   C2 采购侧入库的入库时间最早一条入库 与 销售侧出库的出库时间最早一条出库 时间差在 ±60 天内；
//   C3 采购或销售合同交货地点为空，或仅填写“仓库”。
//
// 对用户草稿的修复点：
//   [1] USING NO_SECONDARY_INDEX 不是合法 Cypher 提示。Neo4j 只有
//       USING INDEX / USING SCAN / USING JOIN，已删除该行。
//   [2] 草稿的 CALL 子查询直接 RETURN rkMin / ckMin，但变量从未定义；
//       本版改为 OPTIONAL MATCH -> ORDER BY -> head(collect(...)) -> RETURN。
//   [3] 草稿把销售合同 cS 接到“按采购合同入库”、把采购合同 cB 接到
//       “按销售合同出库”，方向正好反了；本版按合同方向纠正为
//       cB -> 按采购合同入库 -> rk，cS -> 按销售合同出库 -> ck。
//   [4] 草稿 WITH g, sS, sB, ev, rkMin, ckMin 中 sS / sB / ev 均未定义；
//       本版统一使用 g / s / b / cS / cB，并逐段显式传递。
//   [5] 草稿只 RETURN DISTINCT p0b，缺销售侧与物流路径；本版补齐
//       p0s / p0b / pL / pIn / pOut 五段路径 + 三条件判定明细。
//   [6] 草稿 b <> s 排除了“同一外部企业既买又卖”，而这恰恰是空转走单的
//       典型形态；本版默认不排除，如需排除请取消对应注释。
//   [7] 草稿未实现条件 1 / 2 / 3；本版按需求补全，并把“时间差”统一改为
//       duration('P60D') 加减判定（不要用 duration.between(a,b).days：
//       它会把整月差归入 months 组件，days=0 导致恒命中）。
//
// 口径说明：
//   · 合同方向：payment_direction ∈ ['销售','收款'] 为销售侧，
//     ∈ ['采购','付款'] 为采购侧；若生产存在方向缺失合同，可把条件放宽为
//     (x IN [...] OR x IS NULL)。
//   · 时间字段：合同取 签订合同边 sign_time，回落合同节点 sign_time；
//     入库取 budat，出库取 wadat_ist；统一 date(left(toString(x),10))。
//   · 交货地点：01 号 DDL 未固定字段名，默认按
//     coalesce(delivery_place, delivery_address, delivery_addr) 读取，
//     生产请替换为实际字段名。
//   · 发票：模型没有 合同-发票 直连边，C1 的发票分支只能做企业级近似
//     （g 的销项发票与进项发票是否存在一对开票时间差 ≤60 天）。
//     将 useInvoiceApprox 置为 false 即可关闭该分支。
//   · 证据选择：同一 (g, s, b) 有多对同标的合同时，先判条件、再取最早一条
//     命中的合同对；如需“无论是否命中都只取最早一对”，把第 7 步的
//     ORDER BY / collect 移到条件判定之前。
//
// 自包含验证：本文件不带模拟数据，可直接复用
//   18_paper_only_trading_query.cypher 第五节的 MOCK9_ 数据（信用代码
//   913402003950006371），应命中 3 个正例；验证后执行文件末尾清理语句。
// =============================================================================


// =============================================================================
// 一、主查询：命中三条件任一即返回五段路径 + 命中明细
// =============================================================================
WITH true AS useInvoiceApprox          // false = 关闭发票近似口径

// 0. 目标国电投企业（全图扫描时注释掉本 MATCH/WHERE，并去掉 g 的绑定）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: 'MOCK9_QY_GDT'})
WHERE g.flag_gdtqy = '是'

// 1. 销售侧：g ↔ 销售合同 cS ↔ 外部销售相对方 s
//    签订合同按无向匹配，兼容 ETL 把 企业->合同 反向落库的情况
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]-(cS:dws_dsjsj_zstp_vertex_ht)
      -[rS:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE cS.payment_direction IN ['销售', '收款']
  AND s <> g
  AND s.flag_gdtqy = '否'

// 2. 同一标的物关联：销售合同 ↔ 采购合同
MATCH (cS)-[rL:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cB <> cS
  AND cB.payment_direction IN ['采购', '付款']

// 3. 采购侧：g ↔ 采购合同 cB ↔ 外部采购相对方 b
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]-(cB)
      -[rB:dws_dsjsj_zstp_edge_qy_qd]-(b:dws_dsjsj_zstp_vertex_qy)
WHERE b <> g
  AND b.flag_gdtqy = '否'
  // 草稿要求 b <> s；空转走单常见“同一外部企业又买又卖”，默认不排除：
  // AND b <> s

// 4. 采购侧最早一条入库、销售侧最早一条出库（每个合同对独立取值）
CALL {
    WITH cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_acghtrk]
                   ->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH rk
    ORDER BY rk.budat ASC
    WITH head(collect(rk)) AS rkMin
    RETURN rkMin
}
CALL {
    WITH cS
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_axshtck]
                   ->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH ck
    ORDER BY ck.wadat_ist ASC
    WITH head(collect(ck)) AS ckMin
    RETURN ckMin
}

// 5. 发票近似口径（企业级；无合同-发票直连边时的兜底）
//    销项：fplx 含“销”；进项：fplx 含“进”；存在一对开票时间差 ≤60 天即真
CALL {
    WITH g
    OPTIONAL MATCH (g)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|
                       dws_dsjsj_zstp_edge_qy_csfp]
                   -(f:dws_dsjsj_zstp_vertex_fp)
    WITH g, collect(DISTINCT f) AS fs
    WITH [x IN fs
          WHERE x.kprq IS NOT NULL
            AND trim(toString(x.kprq)) <> ''
            AND toString(x.kprq) =~ '\\d{4}-\\d{2}-\\d{2}.*'
            AND trim(coalesce(x.fplx, '')) CONTAINS '销'
          | date(left(toString(x.kprq), 10))] AS dOuts,
         [x IN fs
          WHERE x.kprq IS NOT NULL
            AND trim(toString(x.kprq)) <> ''
            AND toString(x.kprq) =~ '\\d{4}-\\d{2}-\\d{2}.*'
            AND trim(coalesce(x.fplx, '')) CONTAINS '进'
          | date(left(toString(x.kprq), 10))] AS dIns
    RETURN any(o IN dOuts WHERE any(i IN dIns
             WHERE o >= i - duration('P60D')
               AND o <= i + duration('P60D'))) AS invoiceHit
}

// 6. 时间归一化（合同签订时间、最早入库/出库时间）
WITH useInvoiceApprox, g, s, b, cS, cB, rdS, rS, rdB, rB, rL, rkMin, ckMin, invoiceHit,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
WITH useInvoiceApprox, g, s, b, cS, cB, rdS, rS, rdB, rB, rL, rkMin, ckMin, invoiceHit,
     tS, tB,
     CASE WHEN tS IS NULL
               OR trim(toString(tS)) = ''
               OR NOT toString(tS) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(tS), 10)) END AS dS,
     CASE WHEN tB IS NULL
               OR trim(toString(tB)) = ''
               OR NOT toString(tB) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(tB), 10)) END AS dB,
     CASE WHEN rkMin IS NULL
               OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn,
     CASE WHEN ckMin IS NULL
               OR ckMin.wadat_ist IS NULL
               OR trim(toString(ckMin.wadat_ist)) = ''
               OR NOT toString(ckMin.wadat_ist) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(ckMin.wadat_ist), 10)) END AS dOut

// 7. 三条件判定（C1 = 合同签订时间差 OR 发票开票时间差）
WITH useInvoiceApprox, g, s, b, cS, cB, rdS, rS, rdB, rB, rL, rkMin, ckMin,
     tS, tB, dS, dB, dIn, dOut,
     (dS IS NOT NULL AND dB IS NOT NULL
      AND dB >= dS - duration('P60D')
      AND dB <= dS + duration('P60D')) AS C1_合同,
     (useInvoiceApprox AND invoiceHit) AS C1_发票,
     (dIn IS NOT NULL AND dOut IS NOT NULL
      AND dOut >= dIn - duration('P60D')
      AND dOut <= dIn + duration('P60D')) AS C2_出入库,
     (trim(toString(coalesce(cS.delivery_place,
                             cS.delivery_address,
                             cS.delivery_addr, ''))) IN ['', '仓库']
      OR trim(toString(coalesce(cB.delivery_place,
                                cB.delivery_address,
                                cB.delivery_addr, ''))) IN ['', '仓库']) AS C3_交货地点
WITH useInvoiceApprox, g, s, b, cS, cB, rdS, rS, rdB, rB, rL, rkMin, ckMin,
     tS, tB, dS, dB, dIn, dOut,
     C1_合同, C1_发票, C2_出入库, C3_交货地点,
     (C1_合同 OR C1_发票) AS C1
WHERE C1 OR C2_出入库 OR C3_交货地点

// 8. 命中特征串（去掉开头的 “ + ”）
WITH useInvoiceApprox, g, s, b, cS, cB, rdS, rS, rdB, rB, rL, rkMin, ckMin,
     tS, tB, dS, dB, dIn, dOut,
     C1_合同, C1_发票, C1, C2_出入库, C3_交货地点,
     trim(
       CASE WHEN C1_合同 THEN '签订时间差60天内' ELSE '' END
       + CASE WHEN C1_发票 THEN ' + 进销项发票时间差60天内' ELSE '' END
       + CASE WHEN C2_出入库 THEN ' + 最早出入库差60天内' ELSE '' END
       + CASE WHEN C3_交货地点 THEN ' + 交货地点未约定' ELSE '' END
     ) AS 命中特征串
WITH useInvoiceApprox, g, s, b, cS, cB, rdS, rS, rdB, rB, rL, rkMin, ckMin,
     tS, tB, dS, dB, dIn, dOut,
     C1_合同, C1_发票, C1, C2_出入库, C3_交货地点,
     CASE WHEN 命中特征串 STARTS WITH '+ '
          THEN substring(命中特征串, 2)
          ELSE 命中特征串 END AS 命中特征

// 9. 同一 (g, s, b) 只保留最早一条“命中”的合同对作为证据
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, s, b,
     collect({
         cS: cS, cB: cB, rkMin: rkMin, ckMin: ckMin,
         rdS: rdS, rS: rS, rdB: rdB, rB: rB, rL: rL,
         tS: tS, tB: tB, dS: dS, dB: dB, dIn: dIn, dOut: dOut,
         C1_合同: C1_合同, C1_发票: C1_发票, C1: C1,
         C2_出入库: C2_出入库, C3_交货地点: C3_交货地点,
         命中特征: 命中特征
     })[0] AS ev
WITH g, s, b,
     ev.cS AS cS, ev.cB AS cB, ev.rkMin AS rkMin, ev.ckMin AS ckMin,
     ev.C1_合同 AS C1_合同, ev.C1_发票 AS C1_发票, ev.C1 AS C1,
     ev.C2_出入库 AS C2_出入库, ev.C3_交货地点 AS C3_交货地点,
     ev.命中特征 AS 命中特征,
     ev.dS AS dS, ev.dB AS dB, ev.dIn AS dIn, ev.dOut AS dOut

// 10. 还原五段路径（签发/同标的按无向匹配，物流按 DDL 方向）
MATCH p0s = (g)-[:dws_dsjsj_zstp_edge_qy_qd]-(cS)
            -[:dws_dsjsj_zstp_edge_qy_qd]-(s)
MATCH p0b = (g)-[:dws_dsjsj_zstp_edge_qy_qd]-(cB)
            -[:dws_dsjsj_zstp_edge_qy_qd]-(b)
MATCH pL  = (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB)
OPTIONAL MATCH pIn  = (mIn:dws_dsjsj_zstp_vertex_wl)
                      -[:dws_dsjsj_zstp_edge_wl_lywl]->(rkMin)
                      <-[:dws_dsjsj_zstp_edge_ht_acghtrk]-(cB)
OPTIONAL MATCH pOut = (mOut:dws_dsjsj_zstp_vertex_wl)
                      -[:dws_dsjsj_zstp_edge_wl_xhwl]->(ckMin)
                      <-[:dws_dsjsj_zstp_edge_ht_axshtck]-(cS)

RETURN DISTINCT
    p0s, p0b, pL, pIn, pOut,
    g.org_name  AS 国电投企业,
    s.org_name  AS 销售合同相对方,
    b.org_name  AS 采购合同相对方,
    cS.contract_code AS 销售合同, cS.sign_time AS 销售合同签订时间,
    cB.contract_code AS 采购合同, cB.sign_time AS 采购合同签订时间,
    rkMin.mblnr      AS 最早入库单号, rkMin.budat AS 入库时间,
    ckMin.vbeln      AS 最早出库单号, ckMin.wadat_ist AS 出库时间,
    dS AS 销售合同签订日期, dB AS 采购合同签订日期,
    dIn AS 最早入库日期, dOut AS 最早出库日期,
    C1_合同        AS 条件1_合同签订时间差60天内,
    C1_发票        AS 条件1_进销项发票时间差60天内,
    C2_出入库      AS 条件2_最早出入库差60天内,
    C3_交货地点    AS 条件3_交货地点未约定,
    命中特征,
    '疑似空转走单交易' AS 命中规则;


// =============================================================================
// 二、明细输出版（不返回路径，便于导出核查表）
// -----------------------------------------------------------------------------
// 把上面第 10 步的 MATCH / RETURN 替换为下面这段即可：
// =============================================================================
// RETURN DISTINCT
//     g.org_name  AS 国电投企业,
//     s.org_name  AS 销售合同相对方,
//     b.org_name  AS 采购合同相对方,
//     cS.contract_code AS 销售合同, cS.sign_time AS 销售合同签订时间,
//     cB.contract_code AS 采购合同, cB.sign_time AS 采购合同签订时间,
//     rkMin.mblnr AS 最早入库单号, rkMin.budat AS 入库时间,
//     ckMin.vbeln AS 最早出库单号, ckMin.wadat_ist AS 出库时间,
//     C1_合同 AS 条件1_合同签订时间差60天内,
//     C1_发票 AS 条件1_进销项发票时间差60天内,
//     C2_出入库 AS 条件2_最早出入库差60天内,
//     C3_交货地点 AS 条件3_交货地点未约定,
//     命中特征,
//     '疑似空转走单交易' AS 命中规则;


// =============================================================================
// 三、变体：关闭发票近似口径，只看合同签订时间 / 出入库 / 交货地点
// -----------------------------------------------------------------------------
// 将主查询第 0 步的 WITH true AS useInvoiceApprox 改为
//     WITH false AS useInvoiceApprox
// 即可。条件 1 只保留“合同签订时间差”，结果更收敛，适合正式核查。
// =============================================================================


// =============================================================================
// 四、变体：全图扫描（不锚定单个国电投企业）
// -----------------------------------------------------------------------------
// 删除主查询第 0 步的 MATCH/WHERE 两行，把第 1 步改为：
//     MATCH (g:dws_dsjsj_zstp_vertex_qy)
//     WHERE g.flag_gdtqy = '是'
//     MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]-(cS:...)
// 其余不变。数据量大时建议保留信用代码锚点，或按二级单位分批跑。
// =============================================================================


// =============================================================================
// 五、验证方式（复用 18 号文件的 MOCK9_ 数据）
// -----------------------------------------------------------------------------
// 1. 从 18_paper_only_trading_query.cypher 第五节执行 MOCK9_ 顶点与边；
// 2. 把本文件第 0 步信用代码改为 '913402003950006371'；
// 3. 执行主查询，应命中 3 条正例：
//      MOCK9_外部采购相对方1 / 外部销售相对方1 → 条件1（签订差 19 天）
//      MOCK9_外部采购相对方2 / 外部销售相对方2 → 条件2（出入库差 10 天）
//      MOCK9_外部采购相对方3 / 外部销售相对方3 → 条件3（交货地点='仓库'/空）
//    反例1（三条件均不满足）、反例2（两份合同方向同为采购）、
//    反例3（无同一标的物关联）不应出现。
// 4. 验证后清理：
//      MATCH (n) WHERE n.object_key STARTS WITH 'MOCK9_' DETACH DELETE n;
// =============================================================================
