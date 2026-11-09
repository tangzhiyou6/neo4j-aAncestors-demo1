// =============================================================================
// 22 SPIC-CW-0104 疑似空转走单交易 · v3 重写优化版（自包含，MOCK13_ 前缀）
// -----------------------------------------------------------------------------
// 图模式（与流程图一致，箭头按生产 DDL 的 from_key -> to_key）：
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
//   C2 采购侧最早一条入库（rk.budat） 与 销售侧最早一条出库（ck.wadat_ist）
//      时间差在 ±60 天内；
//   C3 采购或销售合同交货地点为空，或仅填写“仓库”。
//
// 相对 21 号文件的优化（21 号保留不动，本文件独立成篇、互不冲突）：
//   [1] 两次 CALL(入库/出库) 合并为一次 CALL：先按 cS 聚合取 rkMin，
//       再在该行上取 ckMin，子查询执行次数减半，且不产生 rk×ck 笛卡尔积；
//   [2] 进入 CALL 之前先 WITH DISTINCT 去重合同对、并把 签订边 sign_time
//       coalesce 成 tS/tB，之后不再携带 rdS/rS/rdB/rB/rL 等边变量，
//       中间传递列明显减少；
//   [3] 发票口径仍是企业级近似（g 的销项/进项发票存在一对 ≤60 天即真），
//       注意这会让该企业的所有合同对共享同一结论 —— 模拟数据里特意用
//       两家国电投企业（g1/g2）隔离演示，避免发票结论“串味”；
//   [4] 时间差全部用 duration('P60D') 加减判定（不要用
//       duration.between(a,b).days：整月差归入 months 组件，days=0 恒命中）；
//   [5] 自包含 MOCK13_ 数据 + 2 条断言，正反例覆盖四个命中分支与三类排除项。
//
// 口径说明：
//   · 合同方向：payment_direction ∈ ['销售','收款'] 为销售侧，
//     ∈ ['采购','付款'] 为采购侧（方向过滤天然防角色镜像）；
//   · 交货地点字段名按 coalesce(delivery_place, delivery_address,
//     delivery_addr) 读取，生产按实际字段替换；
//   · 同一 (g,s,b) 多对同标的合同：先判条件，再取最早一条“命中”的证据；
//   · 默认不排除 b = s（同一外部企业既买又卖是空转走单典型形态）。
// =============================================================================


// =============================================================================
// 一、主查询：命中三条件任一即返回五段路径 + 命中明细
// =============================================================================
WITH true AS useInvoiceApprox          // 置 false 可关闭发票近似口径

// 0. 目标国电投企业（全图扫描时注释掉本 MATCH/WHERE，见第四节变体）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1300A'})
WHERE g.flag_gdtqy = '是'

// 1. 销售侧：g ↔ 销售合同 cS ↔ 外部销售相对方 s（无向匹配兼容反向落库）
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]-(cS:dws_dsjsj_zstp_vertex_ht)
      -[rS:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE cS.payment_direction IN ['销售', '收款']
  AND s <> g
  AND s.flag_gdtqy = '否'

// 2. 同一标的物关联：销售合同 ↔ 采购合同
MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cB <> cS
  AND cB.payment_direction IN ['采购', '付款']

// 3. 采购侧：g ↔ 采购合同 cB ↔ 外部采购相对方 b
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]-(cB)
      -[rB:dws_dsjsj_zstp_edge_qy_qd]-(b:dws_dsjsj_zstp_vertex_qy)
WHERE b <> g
  AND b.flag_gdtqy = '否'
  // 如需排除“同一外部企业既买又卖”，放开下一行：
  // AND b <> s

// 4. 去重合同对 + 提前固化签订时间，之后不再携带签约边变量
WITH DISTINCT useInvoiceApprox, g, s, b, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB

// 5. 一次 CALL 同时取：采购侧最早入库 rkMin + 销售侧最早出库 ckMin
//    （先按 cS 聚合再取 ckMin，两段互不产生笛卡尔积；无记录返回 null）
CALL {
    WITH cS, cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_acghtrk]
                   ->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH cS, rk
    ORDER BY rk.budat ASC
    WITH cS, head(collect(rk)) AS rkMin
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_axshtck]
                   ->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH rkMin, ck
    ORDER BY ck.wadat_ist ASC
    WITH rkMin, head(collect(ck)) AS ckMin
    RETURN rkMin, ckMin
}

// 6. 发票近似口径（企业级；模型无 合同-发票 直连边时的兜底）
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

// 7. 时间归一化（非 ISO 日期 / 空值一律按 NULL 处理，对应条件不命中）
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin, invoiceHit,
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

// 8. 三条件判定（C1 = 合同签订时间差 OR 发票开票时间差）
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin,
     dS, dB, dIn, dOut,
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
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin,
     dS, dB, dIn, dOut,
     C1_合同, C1_发票, C2_出入库, C3_交货地点,
     (C1_合同 OR C1_发票) AS C1
WHERE C1 OR C2_出入库 OR C3_交货地点

// 9. 命中特征串（去掉开头的 “ + ”）
WITH g, s, b, cS, cB, tS, tB, rkMin, ckMin,
     dS, dB, dIn, dOut,
     C1_合同, C1_发票, C1, C2_出入库, C3_交货地点,
     trim(
       CASE WHEN C1_合同 THEN '签订时间差60天内' ELSE '' END
       + CASE WHEN C1_发票 THEN ' + 进销项发票时间差60天内' ELSE '' END
       + CASE WHEN C2_出入库 THEN ' + 最早出入库差60天内' ELSE '' END
       + CASE WHEN C3_交货地点 THEN ' + 交货地点未约定' ELSE '' END
     ) AS 命中特征串
WITH g, s, b, cS, cB, tS, tB, rkMin, ckMin,
     dS, dB, dIn, dOut,
     C1_合同, C1_发票, C1, C2_出入库, C3_交货地点,
     CASE WHEN 命中特征串 STARTS WITH '+ '
          THEN substring(命中特征串, 2)
          ELSE 命中特征串 END AS 命中特征

// 10. 同一 (g, s, b) 只保留最早一条“命中”的合同对作为证据
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, s, b,
     collect({
         cS: cS, cB: cB, rkMin: rkMin, ckMin: ckMin,
         dS: dS, dB: dB, dIn: dIn, dOut: dOut,
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

// 11. 还原五段路径（签约/同标的无向匹配，物流按 DDL 方向）
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
    C1_合同     AS 条件1_合同签订时间差60天内,
    C1_发票     AS 条件1_进销项发票时间差60天内,
    C2_出入库   AS 条件2_最早出入库差60天内,
    C3_交货地点 AS 条件3_交货地点未约定,
    命中特征,
    '疑似空转走单交易' AS 命中规则;


// =============================================================================
// 二、明细输出版（不返回路径，便于导出核查表）
// -----------------------------------------------------------------------------
// 把上面第 11 步的 MATCH / RETURN 替换为下面这段即可：
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
// 三、变体：关闭发票近似口径
// -----------------------------------------------------------------------------
// 把主查询第 0 步改为 WITH false AS useInvoiceApprox 即可。
// 条件 1 只保留“合同签订时间差”，结果更收敛，适合正式核查；
// 生产若补齐 合同-发票 关联边，应改按合同对取进/销项发票后再判定。
// =============================================================================


// =============================================================================
// 四、变体：全图扫描（不锚定单个国电投企业）
// -----------------------------------------------------------------------------
// 删除主查询第 0 步的 MATCH/WHERE，把第 1 步改为：
//     MATCH (g:dws_dsjsj_zstp_vertex_qy)
//     WHERE g.flag_gdtqy = '是'
//     MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]-(cS:...)
// 其余不变。注意：发票近似口径是企业级的，全图扫描时每家国电投企业
// 的所有合同对会共享同一 invoiceHit 结论，建议先关闭或先行核实。
// =============================================================================


// =============================================================================
// 五、自包含模拟数据（MOCK13_ 前缀，幂等可重复执行）
// -----------------------------------------------------------------------------
// g1 = MOCK13_QY_GDT（信用代码 91310112MOCK1300A）承载 A/B/C/E/F/G 六组；
// g2 = MOCK13_QY_GDT2（信用代码 91310112MOCK1300B）单独承载 D 组，
//      避免 g2 的发票结论“串”到 g1 的合同对上（企业级近似的固有特性）。
//
//   A 正例1：签订差 19 天 → C1_合同（另有更晚的同组合同标的对 S1B/P1B，
//            证据应取最早的 S1A/P1A）
//   B 正例2：最早出入库差 10 天 → C2（签订差 116 天、地点真实）
//   C 正例3：交货地点 '仓库' / 空 → C3（签订差 89 天、出入库差 92 天）
//   D 正例4：仅发票口径命中（进销项差 19 天），且 b = s 同一外部企业
//   E 反例1：三条件均不命中（签订差 121 天、出入库差 131 天、地点真实）
//   F 反例2：两份合同方向同为“采购”→ 被方向过滤排除
//   G 反例3：无“同一标的物关联”边 → 被链条门槛排除（尽管三条件均会命中）
// =============================================================================

// ---- 5.1 顶点：企业 ----
UNWIND [
  {k:'MOCK13_QY_GDT',  n:'MOCK13_国电投企业A', f:'是', c:'91310112MOCK1300A'},
  {k:'MOCK13_QY_GDT2', n:'MOCK13_国电投企业B', f:'是', c:'91310112MOCK1300B'},
  {k:'MOCK13_QY_SS1',  n:'MOCK13_外部采购相对方1', f:'否', c:null},
  {k:'MOCK13_QY_SB1',  n:'MOCK13_外部销售相对方1', f:'否', c:null},
  {k:'MOCK13_QY_SS2',  n:'MOCK13_外部采购相对方2', f:'否', c:null},
  {k:'MOCK13_QY_SB2',  n:'MOCK13_外部销售相对方2', f:'否', c:null},
  {k:'MOCK13_QY_SS3',  n:'MOCK13_外部采购相对方3', f:'否', c:null},
  {k:'MOCK13_QY_SB3',  n:'MOCK13_外部销售相对方3', f:'否', c:null},
  {k:'MOCK13_QY_TRADER', n:'MOCK13_同一外部企业', f:'否', c:null},
  {k:'MOCK13_QY_SS5',  n:'MOCK13_反例1_外部采购相对方', f:'否', c:null},
  {k:'MOCK13_QY_SB5',  n:'MOCK13_反例1_外部销售相对方', f:'否', c:null},
  {k:'MOCK13_QY_SS6',  n:'MOCK13_反例2_外部相对方A', f:'否', c:null},
  {k:'MOCK13_QY_SB6',  n:'MOCK13_反例2_外部相对方B', f:'否', c:null},
  {k:'MOCK13_QY_SS7',  n:'MOCK13_反例3_外部采购相对方', f:'否', c:null},
  {k:'MOCK13_QY_SB7',  n:'MOCK13_反例3_外部销售相对方', f:'否', c:null}
] AS row
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key: row.k})
  ON CREATE SET n.org_name = row.n, n.flag_gdtqy = row.f,
                n.org_credit_code = row.c,
                n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// ---- 5.2 顶点：合同（d=交货地点，p=方向，t=签订时间） ----
UNWIND [
  {k:'MOCK13_HT_S1A', c:'MOCK13_HT_S1A', p:'销售', t:'2024-03-20', d:'上海市浦东新区世纪大道88号'},
  {k:'MOCK13_HT_P1A', c:'MOCK13_HT_P1A', p:'采购', t:'2024-03-01', d:'上海市浦东新区世纪大道88号'},
  {k:'MOCK13_HT_S1B', c:'MOCK13_HT_S1B', p:'销售', t:'2024-07-05', d:'上海市浦东新区世纪大道88号'},
  {k:'MOCK13_HT_P1B', c:'MOCK13_HT_P1B', p:'采购', t:'2024-07-01', d:'上海市浦东新区世纪大道88号'},
  {k:'MOCK13_HT_S2',  c:'MOCK13_HT_S2',  p:'销售', t:'2024-05-01', d:'北京市海淀区知春路1号'},
  {k:'MOCK13_HT_P2',  c:'MOCK13_HT_P2',  p:'采购', t:'2024-01-05', d:'北京市海淀区知春路1号'},
  {k:'MOCK13_HT_S3',  c:'MOCK13_HT_S3',  p:'销售', t:'2024-05-01', d:''},
  {k:'MOCK13_HT_P3',  c:'MOCK13_HT_P3',  p:'采购', t:'2024-02-01', d:'仓库'},
  {k:'MOCK13_HT_S4',  c:'MOCK13_HT_S4',  p:'销售', t:'2024-01-01', d:'广州市天河区体育西路100号'},
  {k:'MOCK13_HT_P4',  c:'MOCK13_HT_P4',  p:'采购', t:'2024-12-01', d:'广州市天河区体育西路100号'},
  {k:'MOCK13_HT_S5',  c:'MOCK13_HT_S5',  p:'销售', t:'2024-05-01', d:'深圳市福田区深南大道200号'},
  {k:'MOCK13_HT_P5',  c:'MOCK13_HT_P5',  p:'采购', t:'2024-01-01', d:'深圳市福田区深南大道200号'},
  {k:'MOCK13_HT_P6A', c:'MOCK13_HT_P6A', p:'采购', t:'2024-02-01', d:'仓库'},
  {k:'MOCK13_HT_P6B', c:'MOCK13_HT_P6B', p:'采购', t:'2024-02-15', d:'仓库'},
  {k:'MOCK13_HT_S7',  c:'MOCK13_HT_S7',  p:'销售', t:'2024-03-10', d:'仓库'},
  {k:'MOCK13_HT_P7',  c:'MOCK13_HT_P7',  p:'采购', t:'2024-03-01', d:'仓库'}
] AS row
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key: row.k})
  ON CREATE SET n.contract_code = row.c, n.payment_direction = row.p,
                n.sign_time = row.t, n.delivery_place = row.d,
                n.schema_name = 'dws_dsjsj_zstp_vertex_ht';

// ---- 5.3 顶点：入库 / 出库 / 物料 / 发票 ----
UNWIND [
  {k:'MOCK13_RK_1', m:'MOCK13_RK_1', t:'2024-06-01'},
  {k:'MOCK13_RK_2', m:'MOCK13_RK_2', t:'2024-05-10'},
  {k:'MOCK13_RK_3', m:'MOCK13_RK_3', t:'2024-05-02'},
  {k:'MOCK13_RK_4', m:'MOCK13_RK_4', t:'2024-02-01'},
  {k:'MOCK13_RK_5', m:'MOCK13_RK_5', t:'2024-05-02'},
  {k:'MOCK13_RK_7', m:'MOCK13_RK_7', t:'2024-03-05'}
] AS row
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key: row.k})
  ON CREATE SET n.mblnr = row.m, n.budat = row.t,
                n.schema_name = 'dws_dsjsj_zstp_vertex_rk';
UNWIND [
  {k:'MOCK13_CK_1', v:'MOCK13_CK_1', t:'2024-09-01'},
  {k:'MOCK13_CK_2', v:'MOCK13_CK_2', t:'2024-05-20'},
  {k:'MOCK13_CK_3', v:'MOCK13_CK_3', t:'2024-08-02'},
  {k:'MOCK13_CK_4', v:'MOCK13_CK_4', t:'2024-12-01'},
  {k:'MOCK13_CK_5', v:'MOCK13_CK_5', t:'2024-09-10'},
  {k:'MOCK13_CK_7', v:'MOCK13_CK_7', t:'2024-03-08'}
] AS row
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key: row.k})
  ON CREATE SET n.vbeln = row.v, n.wadat_ist = row.t,
                n.schema_name = 'dws_dsjsj_zstp_vertex_ck';
UNWIND [
  {k:'MOCK13_WL_IN1',  m:'MOCK13-MAT-IN1',  n:'MOCK13_入库物料1'},
  {k:'MOCK13_WL_OUT1', m:'MOCK13-MAT-OUT1', n:'MOCK13_出库物料1'},
  {k:'MOCK13_WL_IN2',  m:'MOCK13-MAT-IN2',  n:'MOCK13_入库物料2'},
  {k:'MOCK13_WL_OUT2', m:'MOCK13-MAT-OUT2', n:'MOCK13_出库物料2'},
  {k:'MOCK13_WL_IN3',  m:'MOCK13-MAT-IN3',  n:'MOCK13_入库物料3'},
  {k:'MOCK13_WL_OUT3', m:'MOCK13-MAT-OUT3', n:'MOCK13_出库物料3'}
] AS row
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key: row.k})
  ON CREATE SET n.matnr = row.m, n.maktx = row.n,
                n.schema_name = 'dws_dsjsj_zstp_vertex_wl';
UNWIND [
  {k:'MOCK13_FP_OUT', h:'MOCK13_FP_OUT', x:'销项发票', t:'2024-06-01'},
  {k:'MOCK13_FP_IN',  h:'MOCK13_FP_IN',  x:'进项发票', t:'2024-06-20'}
] AS row
MERGE (n:dws_dsjsj_zstp_vertex_fp {object_key: row.k})
  ON CREATE SET n.fp_hm = row.h, n.fplx = row.x, n.kprq = row.t,
                n.schema_name = 'dws_dsjsj_zstp_vertex_fp';

// ---- 5.4 边：签订合同（t=边上签订时间） ----
UNWIND [
  // A 正例1（早对 + 晚对）
  {k:'MOCK13_E_QD_01', a:'MOCK13_QY_SB1', b:'MOCK13_HT_S1A', t:'2024-03-20'},
  {k:'MOCK13_E_QD_02', a:'MOCK13_QY_GDT', b:'MOCK13_HT_S1A', t:'2024-03-20'},
  {k:'MOCK13_E_QD_03', a:'MOCK13_QY_SS1', b:'MOCK13_HT_P1A', t:'2024-03-01'},
  {k:'MOCK13_E_QD_04', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P1A', t:'2024-03-01'},
  {k:'MOCK13_E_QD_05', a:'MOCK13_QY_SB1', b:'MOCK13_HT_S1B', t:'2024-07-05'},
  {k:'MOCK13_E_QD_06', a:'MOCK13_QY_GDT', b:'MOCK13_HT_S1B', t:'2024-07-05'},
  {k:'MOCK13_E_QD_07', a:'MOCK13_QY_SS1', b:'MOCK13_HT_P1B', t:'2024-07-01'},
  {k:'MOCK13_E_QD_08', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P1B', t:'2024-07-01'},
  // B 正例2
  {k:'MOCK13_E_QD_09', a:'MOCK13_QY_SB2', b:'MOCK13_HT_S2', t:'2024-05-01'},
  {k:'MOCK13_E_QD_10', a:'MOCK13_QY_GDT', b:'MOCK13_HT_S2', t:'2024-05-01'},
  {k:'MOCK13_E_QD_11', a:'MOCK13_QY_SS2', b:'MOCK13_HT_P2', t:'2024-01-05'},
  {k:'MOCK13_E_QD_12', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P2', t:'2024-01-05'},
  // C 正例3
  {k:'MOCK13_E_QD_13', a:'MOCK13_QY_SB3', b:'MOCK13_HT_S3', t:'2024-05-01'},
  {k:'MOCK13_E_QD_14', a:'MOCK13_QY_GDT', b:'MOCK13_HT_S3', t:'2024-05-01'},
  {k:'MOCK13_E_QD_15', a:'MOCK13_QY_SS3', b:'MOCK13_HT_P3', t:'2024-02-01'},
  {k:'MOCK13_E_QD_16', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P3', t:'2024-02-01'},
  // D 正例4（g2 + 同一外部企业双向签约）
  {k:'MOCK13_E_QD_17', a:'MOCK13_QY_TRADER', b:'MOCK13_HT_S4', t:'2024-01-01'},
  {k:'MOCK13_E_QD_18', a:'MOCK13_QY_GDT2',   b:'MOCK13_HT_S4', t:'2024-01-01'},
  {k:'MOCK13_E_QD_19', a:'MOCK13_QY_TRADER', b:'MOCK13_HT_P4', t:'2024-12-01'},
  {k:'MOCK13_E_QD_20', a:'MOCK13_QY_GDT2',   b:'MOCK13_HT_P4', t:'2024-12-01'},
  // E 反例1
  {k:'MOCK13_E_QD_21', a:'MOCK13_QY_SB5', b:'MOCK13_HT_S5', t:'2024-05-01'},
  {k:'MOCK13_E_QD_22', a:'MOCK13_QY_GDT', b:'MOCK13_HT_S5', t:'2024-05-01'},
  {k:'MOCK13_E_QD_23', a:'MOCK13_QY_SS5', b:'MOCK13_HT_P5', t:'2024-01-01'},
  {k:'MOCK13_E_QD_24', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P5', t:'2024-01-01'},
  // F 反例2（两份均为采购合同）
  {k:'MOCK13_E_QD_25', a:'MOCK13_QY_SS6', b:'MOCK13_HT_P6A', t:'2024-02-01'},
  {k:'MOCK13_E_QD_26', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P6A', t:'2024-02-01'},
  {k:'MOCK13_E_QD_27', a:'MOCK13_QY_SB6', b:'MOCK13_HT_P6B', t:'2024-02-15'},
  {k:'MOCK13_E_QD_28', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P6B', t:'2024-02-15'},
  // G 反例3（无同标的关系）
  {k:'MOCK13_E_QD_29', a:'MOCK13_QY_SB7', b:'MOCK13_HT_S7', t:'2024-03-10'},
  {k:'MOCK13_E_QD_30', a:'MOCK13_QY_GDT', b:'MOCK13_HT_S7', t:'2024-03-10'},
  {k:'MOCK13_E_QD_31', a:'MOCK13_QY_SS7', b:'MOCK13_HT_P7', t:'2024-03-01'},
  {k:'MOCK13_E_QD_32', a:'MOCK13_QY_GDT', b:'MOCK13_HT_P7', t:'2024-03-01'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key: row.k}]->(b)
  ON CREATE SET e.sign_time = row.t,
                e.schema_name = 'dws_dsjsj_zstp_edge_qy_qd';

// ---- 5.5 边：同一标的物关联_合同（G 反例3 故意不建） ----
UNWIND [
  {k:'MOCK13_E_TY_1A', a:'MOCK13_HT_S1A', b:'MOCK13_HT_P1A'},
  {k:'MOCK13_E_TY_1B', a:'MOCK13_HT_S1B', b:'MOCK13_HT_P1B'},
  {k:'MOCK13_E_TY_2',  a:'MOCK13_HT_S2',  b:'MOCK13_HT_P2'},
  {k:'MOCK13_E_TY_3',  a:'MOCK13_HT_S3',  b:'MOCK13_HT_P3'},
  {k:'MOCK13_E_TY_4',  a:'MOCK13_HT_S4',  b:'MOCK13_HT_P4'},
  {k:'MOCK13_E_TY_5',  a:'MOCK13_HT_S5',  b:'MOCK13_HT_P5'},
  {k:'MOCK13_E_TY_6',  a:'MOCK13_HT_P6B', b:'MOCK13_HT_P6A'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key: row.k}]->(b)
  ON CREATE SET e.schema_name = 'dws_dsjsj_zstp_edge_ht_tybdwgl';

// ---- 5.6 边：按采购合同入库 / 按销售合同出库 ----
UNWIND [
  {k:'MOCK13_E_RK_1', a:'MOCK13_HT_P1A', b:'MOCK13_RK_1'},
  {k:'MOCK13_E_RK_2', a:'MOCK13_HT_P2',  b:'MOCK13_RK_2'},
  {k:'MOCK13_E_RK_3', a:'MOCK13_HT_P3',  b:'MOCK13_RK_3'},
  {k:'MOCK13_E_RK_4', a:'MOCK13_HT_P4',  b:'MOCK13_RK_4'},
  {k:'MOCK13_E_RK_5', a:'MOCK13_HT_P5',  b:'MOCK13_RK_5'},
  {k:'MOCK13_E_RK_7', a:'MOCK13_HT_P7',  b:'MOCK13_RK_7'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key: row.k}]->(b)
  ON CREATE SET e.schema_name = 'dws_dsjsj_zstp_edge_ht_acghtrk';
UNWIND [
  {k:'MOCK13_E_CK_1', a:'MOCK13_HT_S1A', b:'MOCK13_CK_1'},
  {k:'MOCK13_E_CK_2', a:'MOCK13_HT_S2',  b:'MOCK13_CK_2'},
  {k:'MOCK13_E_CK_3', a:'MOCK13_HT_S3',  b:'MOCK13_CK_3'},
  {k:'MOCK13_E_CK_4', a:'MOCK13_HT_S4',  b:'MOCK13_CK_4'},
  {k:'MOCK13_E_CK_5', a:'MOCK13_HT_S5',  b:'MOCK13_CK_5'},
  {k:'MOCK13_E_CK_7', a:'MOCK13_HT_S7',  b:'MOCK13_CK_7'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key: row.k}]->(b)
  ON CREATE SET e.schema_name = 'dws_dsjsj_zstp_edge_ht_axshtck';

// ---- 5.7 边：领用物料 / 消耗物料 ----
UNWIND [
  {k:'MOCK13_E_LY_1', a:'MOCK13_WL_IN1',  b:'MOCK13_RK_1'},
  {k:'MOCK13_E_LY_2', a:'MOCK13_WL_IN2',  b:'MOCK13_RK_2'},
  {k:'MOCK13_E_LY_3', a:'MOCK13_WL_IN3',  b:'MOCK13_RK_3'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key: row.k}]->(b)
  ON CREATE SET e.schema_name = 'dws_dsjsj_zstp_edge_wl_lywl';
UNWIND [
  {k:'MOCK13_E_XH_1', a:'MOCK13_WL_OUT1', b:'MOCK13_CK_1'},
  {k:'MOCK13_E_XH_2', a:'MOCK13_WL_OUT2', b:'MOCK13_CK_2'},
  {k:'MOCK13_E_XH_3', a:'MOCK13_WL_OUT3', b:'MOCK13_CK_3'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key: row.k}]->(b)
  ON CREATE SET e.schema_name = 'dws_dsjsj_zstp_edge_wl_xhwl';

// ---- 5.8 边：发票（销项=开具接收发票，进项=产生发票_企业） ----
UNWIND [
  {k:'MOCK13_E_FP_1', a:'MOCK13_QY_GDT2', b:'MOCK13_FP_OUT'},
  {k:'MOCK13_E_FP_2', a:'MOCK13_QY_GDT2', b:'MOCK13_FP_IN'}
] AS row
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key: row.a})
MATCH (b:dws_dsjsj_zstp_vertex_fp {object_key: row.b})
MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_kjjsfp {object_key: row.k}]->(b)
  ON CREATE SET e.schema_name = 'dws_dsjsj_zstp_edge_qy_kjjsfp';


// =============================================================================
// 六、断言校验（先跑第五节灌数据，再跑本节，应全部 PASS）
// =============================================================================

// 断言 1（锚定 g1）：恰好命中 A/B/C 三组，特征正确、证据取最早对（S1A 而非 S1B），
//                   E（三条件均不中）、F（方向同为采购）、G（无同标的）全部排除
WITH true AS useInvoiceApprox
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1300A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]-(cS:dws_dsjsj_zstp_vertex_ht)
      -[rS:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE cS.payment_direction IN ['销售', '收款'] AND s <> g AND s.flag_gdtqy = '否'
MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cB <> cS AND cB.payment_direction IN ['采购', '付款']
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]-(cB)
      -[rB:dws_dsjsj_zstp_edge_qy_qd]-(b:dws_dsjsj_zstp_vertex_qy)
WHERE b <> g AND b.flag_gdtqy = '否'
WITH DISTINCT useInvoiceApprox, g, s, b, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
CALL {
    WITH cS, cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH cS, rk
    ORDER BY rk.budat ASC
    WITH cS, head(collect(rk)) AS rkMin
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH rkMin, ck
    ORDER BY ck.wadat_ist ASC
    WITH rkMin, head(collect(ck)) AS ckMin
    RETURN rkMin, ckMin
}
CALL {
    WITH g
    OPTIONAL MATCH (g)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|
                       dws_dsjsj_zstp_edge_qy_csfp]-(f:dws_dsjsj_zstp_vertex_fp)
    WITH g, collect(DISTINCT f) AS fs
    WITH [x IN fs WHERE x.kprq IS NOT NULL AND trim(toString(x.kprq)) <> ''
            AND toString(x.kprq) =~ '\\d{4}-\\d{2}-\\d{2}.*'
            AND trim(coalesce(x.fplx, '')) CONTAINS '销'
          | date(left(toString(x.kprq), 10))] AS dOuts,
         [x IN fs WHERE x.kprq IS NOT NULL AND trim(toString(x.kprq)) <> ''
            AND toString(x.kprq) =~ '\\d{4}-\\d{2}-\\d{2}.*'
            AND trim(coalesce(x.fplx, '')) CONTAINS '进'
          | date(left(toString(x.kprq), 10))] AS dIns
    RETURN any(o IN dOuts WHERE any(i IN dIns
             WHERE o >= i - duration('P60D') AND o <= i + duration('P60D'))) AS invoiceHit
}
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin, invoiceHit,
     CASE WHEN tS IS NULL OR trim(toString(tS)) = ''
               OR NOT toString(tS) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(tS), 10)) END AS dS,
     CASE WHEN tB IS NULL OR trim(toString(tB)) = ''
               OR NOT toString(tB) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(tB), 10)) END AS dB,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn,
     CASE WHEN ckMin IS NULL OR ckMin.wadat_ist IS NULL
               OR trim(toString(ckMin.wadat_ist)) = ''
               OR NOT toString(ckMin.wadat_ist) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(ckMin.wadat_ist), 10)) END AS dOut
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin, dS, dB, dIn, dOut,
     (dS IS NOT NULL AND dB IS NOT NULL
      AND dB >= dS - duration('P60D') AND dB <= dS + duration('P60D')) AS c1,
     (dIn IS NOT NULL AND dOut IS NOT NULL
      AND dOut >= dIn - duration('P60D') AND dOut <= dIn + duration('P60D')) AS c2,
     (trim(toString(coalesce(cS.delivery_place, cS.delivery_address, cS.delivery_addr, ''))) IN ['', '仓库']
      OR trim(toString(coalesce(cB.delivery_place, cB.delivery_address, cB.delivery_addr, ''))) IN ['', '仓库']) AS c3,
     (useInvoiceApprox AND invoiceHit) AS c1f
WHERE c1 OR c1f OR c2 OR c3
WITH g, s, b, cS, cB, tS, tB, c1, c1f, c2, c3,
     trim(CASE WHEN c1 THEN '签订时间差60天内' ELSE '' END
          + CASE WHEN c1f THEN ' + 进销项发票时间差60天内' ELSE '' END
          + CASE WHEN c2 THEN ' + 最早出入库差60天内' ELSE '' END
          + CASE WHEN c3 THEN ' + 交货地点未约定' ELSE '' END) AS 特征串
WITH g, s, b, cS, cB, tS, tB,
     CASE WHEN 特征串 STARTS WITH '+ ' THEN substring(特征串, 2) ELSE 特征串 END AS 特征
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, s, b, collect({cS: cS, cB: cB, 特征: 特征})[0] AS ev
WITH collect(DISTINCT s.org_name + '|' + b.org_name + '|'
             + ev.cS.contract_code + '|' + ev.cB.contract_code + '|' + ev.特征) AS 命中明细,
     ['MOCK13_外部销售相对方1|MOCK13_外部采购相对方1|MOCK13_HT_S1A|MOCK13_HT_P1A|签订时间差60天内',
      'MOCK13_外部销售相对方2|MOCK13_外部采购相对方2|MOCK13_HT_S2|MOCK13_HT_P2|最早出入库差60天内',
      'MOCK13_外部销售相对方3|MOCK13_外部采购相对方3|MOCK13_HT_S3|MOCK13_HT_P3|交货地点未约定'] AS 期望
RETURN CASE WHEN size(命中明细) = size(期望) AND all(x IN 期望 WHERE x IN 命中明细)
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 命中明细 | a + v + '; ')
       END AS 断言1_g1恰好三正例且证据取最早;

// 断言 2（锚定 g2）：仅发票口径命中 D 组，且 b = s 为同一外部企业（默认不排除）
WITH true AS useInvoiceApprox
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1300B'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[rdS:dws_dsjsj_zstp_edge_qy_qd]-(cS:dws_dsjsj_zstp_vertex_ht)
      -[rS:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE cS.payment_direction IN ['销售', '收款'] AND s <> g AND s.flag_gdtqy = '否'
MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(cB:dws_dsjsj_zstp_vertex_ht)
WHERE cB <> cS AND cB.payment_direction IN ['采购', '付款']
MATCH (g)-[rdB:dws_dsjsj_zstp_edge_qy_qd]-(cB)
      -[rB:dws_dsjsj_zstp_edge_qy_qd]-(b:dws_dsjsj_zstp_vertex_qy)
WHERE b <> g AND b.flag_gdtqy = '否'
WITH DISTINCT useInvoiceApprox, g, s, b, cS, cB,
     coalesce(rdS.sign_time, rS.sign_time, cS.sign_time) AS tS,
     coalesce(rdB.sign_time, rB.sign_time, cB.sign_time) AS tB
CALL {
    WITH cS, cB
    OPTIONAL MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH cS, rk
    ORDER BY rk.budat ASC
    WITH cS, head(collect(rk)) AS rkMin
    OPTIONAL MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    WITH rkMin, ck
    ORDER BY ck.wadat_ist ASC
    WITH rkMin, head(collect(ck)) AS ckMin
    RETURN rkMin, ckMin
}
CALL {
    WITH g
    OPTIONAL MATCH (g)-[:dws_dsjsj_zstp_edge_qy_kjjsfp|
                       dws_dsjsj_zstp_edge_qy_csfp]-(f:dws_dsjsj_zstp_vertex_fp)
    WITH g, collect(DISTINCT f) AS fs
    WITH [x IN fs WHERE x.kprq IS NOT NULL AND trim(toString(x.kprq)) <> ''
            AND toString(x.kprq) =~ '\\d{4}-\\d{2}-\\d{2}.*'
            AND trim(coalesce(x.fplx, '')) CONTAINS '销'
          | date(left(toString(x.kprq), 10))] AS dOuts,
         [x IN fs WHERE x.kprq IS NOT NULL AND trim(toString(x.kprq)) <> ''
            AND toString(x.kprq) =~ '\\d{4}-\\d{2}-\\d{2}.*'
            AND trim(coalesce(x.fplx, '')) CONTAINS '进'
          | date(left(toString(x.kprq), 10))] AS dIns
    RETURN any(o IN dOuts WHERE any(i IN dIns
             WHERE o >= i - duration('P60D') AND o <= i + duration('P60D'))) AS invoiceHit
}
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin, invoiceHit,
     CASE WHEN tS IS NULL OR trim(toString(tS)) = ''
               OR NOT toString(tS) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(tS), 10)) END AS dS,
     CASE WHEN tB IS NULL OR trim(toString(tB)) = ''
               OR NOT toString(tB) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(tB), 10)) END AS dB,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn,
     CASE WHEN ckMin IS NULL OR ckMin.wadat_ist IS NULL
               OR trim(toString(ckMin.wadat_ist)) = ''
               OR NOT toString(ckMin.wadat_ist) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(ckMin.wadat_ist), 10)) END AS dOut
WITH useInvoiceApprox, g, s, b, cS, cB, tS, tB, rkMin, ckMin, dS, dB, dIn, dOut,
     (dS IS NOT NULL AND dB IS NOT NULL
      AND dB >= dS - duration('P60D') AND dB <= dS + duration('P60D')) AS c1,
     (dIn IS NOT NULL AND dOut IS NOT NULL
      AND dOut >= dIn - duration('P60D') AND dOut <= dIn + duration('P60D')) AS c2,
     (trim(toString(coalesce(cS.delivery_place, cS.delivery_address, cS.delivery_addr, ''))) IN ['', '仓库']
      OR trim(toString(coalesce(cB.delivery_place, cB.delivery_address, cB.delivery_addr, ''))) IN ['', '仓库']) AS c3,
     (useInvoiceApprox AND invoiceHit) AS c1f
WHERE c1 OR c1f OR c2 OR c3
WITH g, s, b, cS, cB, tS, tB, c1, c1f, c2, c3,
     trim(CASE WHEN c1 THEN '签订时间差60天内' ELSE '' END
          + CASE WHEN c1f THEN ' + 进销项发票时间差60天内' ELSE '' END
          + CASE WHEN c2 THEN ' + 最早出入库差60天内' ELSE '' END
          + CASE WHEN c3 THEN ' + 交货地点未约定' ELSE '' END) AS 特征串
WITH g, s, b, cS, cB, tS, tB, c1, c1f, c2, c3,
     CASE WHEN 特征串 STARTS WITH '+ ' THEN substring(特征串, 2) ELSE 特征串 END AS 特征
ORDER BY tS ASC, tB ASC, cS.object_key ASC, cB.object_key ASC
WITH g, s, b, collect({cS: cS, cB: cB, 特征: 特征,
                       同一企业: CASE WHEN s = b THEN '是' ELSE '否' END})[0] AS ev
WITH collect(DISTINCT s.org_name + '|' + b.org_name + '|'
             + ev.cS.contract_code + '|' + ev.cB.contract_code + '|'
             + ev.特征 + '|b=s:' + ev.同一企业) AS 命中明细,
     ['MOCK13_同一外部企业|MOCK13_同一外部企业|MOCK13_HT_S4|MOCK13_HT_P4|进销项发票时间差60天内|b=s:是'] AS 期望
RETURN CASE WHEN size(命中明细) = size(期望) AND all(x IN 期望 WHERE x IN 命中明细)
            THEN 'PASS' ELSE 'FAIL: ' + reduce(a = '', v IN 命中明细 | a + v + '; ')
       END AS 断言2_g2仅发票口径且允许同一外部企业;


// =============================================================================
// 七、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK13_' DETACH DELETE n;
