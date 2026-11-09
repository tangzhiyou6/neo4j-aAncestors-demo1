// =============================================================================
// 26 SPIC-CW-0106-05 有悖于交易常识的异常交易 · 时间线倒置（取最早口径）
// -----------------------------------------------------------------------------
// 对应流程图（国电投企业A 居中，销售侧）:
//
//   (销售合同相对方 s)-[:签订合同]->(销售合同 c)<-[:签订合同]-(国电投企业A g)
//   (物料 wl)-[:消耗物料]->(出库 ck)<-[:按销售合同出库]-(c)
//   (c)-[:合同收款/付款]->(资金流水 f)   ← f.trade_dir 为收款方向
//   min(ck.wadat_ist) < min(f.TRANS_TIME)
//     ⇒ 命中: 出库时间早于收款时间
//
// 镜像口径（采购侧，同法）:
//   (采购相对方 s)-[:签订合同]->(采购合同 c)<-[:签订合同]-(g)
//   (物料 wl)-[:领用物料]->(入库 rk)<-[:按采购合同入库]-(c)
//   (c)-[:合同收款/付款]->(资金流水 f)   ← f.trade_dir 为付款方向
//   min(rk.budat) > min(f.TRANS_TIME)
//     ⇒ 命中: 最早入库时间晚于最早付款时间
//
// 规则原文:
//   1. 最早入库时间晚于最早付款时间（采购侧）
//     （1）出库时间早于收款时间（销售侧）
//   两条子规则的共同画像：企业资金先流出（先付款）、货款后收回（后收款），
//   物流单据与资金收付顺序颠倒，有悖于"钱货两讫、先货后款"的正常交易常识。
//   注：采购侧子规则与 25 号文件（SPIC-CW-0106-04 最早入库时间晚于最早付款时间，
//   `MOCK15_` 数据）同一业务口径；本文件为按 0106-05 规则原文的两条子规则合并版，
//   主查询 B 为镜像完整性口径，两者可独立使用，互不影响。
//
// 口径:
//   1. 以国电投企业 g 签订的合同 c 为入口；全库口径见第四节变体 B。
//   2. 销售侧以 按销售合同出库 边界定物流单据，采购侧以 按采购合同入库 边界定；
//      合同 payment_direction（'销售'/'收款'=销售、'采购'/'付款'=采购）仅作辅助校验，
//      不作为主判定条件（以物流边类型为准）。
//   3. 收付方向按 f.trade_dir 判定，兼容两种取值口径:
//        收款方向 = ['收款', '收入']；付款方向 = ['付款', '支出']
//      trade_dir 为空或取值不在此列表的流水不参与判定（防误判），另见第五节"待核查"。
//   4. 时间比较取"最早"口径：同一合同多张出库/入库、多条流水时，
//      销售侧取 min(出库) 与 min(收款)、采购侧取 min(入库) 与 min(付款) 比较。
//   5. 时间字段可能为 datetime 或 'YYYY-MM-DD…' 字符串，统一按
//      date(left(toString(x), 10)) 归一化为 date 再比较；缺失/空串视为 NULL。
//   6. 严格比较：出库早于收款 / 入库晚于付款 均不含"同日"（同日视为正常）。
//   7. 物料贯通（消耗物料/领用物料）不是本规则判定条件，主查询仅作证据展示；
//      需要"同一物料"强关联口径时见第三节变体 A（要求物料存在才命中）。
//   8. 只报"最早证据"（最早一张出库单 + 最早一笔收款流水，采购侧同理），
//      多组证据不重复报，便于核查。
//
// 标签对照（生产原始 schema 名，与 16/17/18/22 号文件一致）:
//   dws_dsjsj_zstp_vertex_qy=企业          dws_dsjsj_zstp_vertex_ht=合同
//   dws_dsjsj_zstp_vertex_zjls=资金流水    dws_dsjsj_zstp_vertex_wl=物料
//   dws_dsjsj_zstp_vertex_rk=入库          dws_dsjsj_zstp_vertex_ck=出库
//   dws_dsjsj_zstp_edge_qy_qd=签订合同
//   dws_dsjsj_zstp_edge_ht_skfk=合同收款/付款
//   dws_dsjsj_zstp_edge_ht_axshtck=按销售合同出库
//   dws_dsjsj_zstp_edge_ht_acghtrk=按采购合同入库
//   dws_dsjsj_zstp_edge_wl_xhwl=消耗物料   dws_dsjsj_zstp_edge_wl_lywl=领用物料
//
// 时间归一化（后文多处复用，改变规则时只改这一处口径）:
//   CASE WHEN x IS NULL OR trim(toString(x)) = '' THEN NULL
//        ELSE date(left(toString(x), 10)) END
// =============================================================================


// =============================================================================
// 一、主查询 A（销售侧）：出库时间早于收款时间 —— 按流程图返回 5 段路径
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位；全库扫描见第四节变体 B）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'

// 1. g 签订的合同，以及合同相对方
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE s <> g

// 2. 按销售合同出库的单据 + 合同收款方向的资金流水
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WHERE f.trade_dir IN ['收款', '收入']

// 3. 时间归一化（出库 wadat_ist / 流水 TRANS_TIME，兼容 datetime 与字符串）
WITH g, s, c, ck, f,
     CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
          ELSE date(left(toString(ck.wadat_ist), 10)) END AS ckDate,
     CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
          ELSE date(left(toString(f.TRANS_TIME), 10)) END AS fDate

// 4. 取最早口径：最早出库时间 vs 最早收款时间（同日不算，严格小于才命中）
WITH g, s, c,
     min(ckDate) AS ckMin, min(fDate) AS skMin,
     count(DISTINCT ck) AS 出库单数, count(DISTINCT f) AS 收款笔数
WHERE ckMin IS NOT NULL AND skMin IS NOT NULL AND ckMin < skMin

// 5. 还原最早证据：最早一张出库单 + 最早一笔收款流水（+ 物料，可缺）
//    注意按"归一化 date"排序（wadat_ist/TRANS_TIME 可能 datetime 与字符串混存，
//    直接按原字段排序会因类型不同得到不确定的顺序）
WITH g, s, c, ckMin, skMin, 出库单数, 收款笔数
CALL {
    WITH c
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(x:dws_dsjsj_zstp_vertex_ck)
    WITH x, CASE WHEN x.wadat_ist IS NULL OR trim(toString(x.wadat_ist)) = '' THEN NULL
                 ELSE date(left(toString(x.wadat_ist), 10)) END AS d
    ORDER BY d ASC
    WITH head(collect(x)) AS ck0
    RETURN ck0
}
CALL {
    WITH c
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(y:dws_dsjsj_zstp_vertex_zjls)
    WHERE y.trade_dir IN ['收款', '收入']
    WITH y, CASE WHEN y.TRANS_TIME IS NULL OR trim(toString(y.TRANS_TIME)) = '' THEN NULL
                 ELSE date(left(toString(y.TRANS_TIME), 10)) END AS d
    ORDER BY d ASC
    WITH head(collect(y)) AS f0
    RETURN f0
}
OPTIONAL MATCH pWL = (wl:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck0)
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pS = (s)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pK = (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck0)
MATCH pF = (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f0)
RETURN DISTINCT pC, pS, pK, pF, pWL,
       g.org_name            AS 国电投企业,
       s.org_name            AS 销售合同相对方,
       c.contract_code       AS 合同编号,
       c.contract_name       AS 合同名称,
       c.payment_direction   AS 合同方向,
       ckMin                 AS 最早出库时间,
       skMin                 AS 最早收款时间,
       duration.between(ckMin, skMin) AS 出库领先收款,
       出库单数, 收款笔数,
       ck0.vbeln             AS 最早出库单号,
       f0.bill_num           AS 最早收款流水号,
       f0.tran_amt           AS 最早收款金额,
       '出库时间早于收款时间' AS 命中规则;


// =============================================================================
// 二、主查询 B（采购侧）：最早入库时间晚于最早付款时间（镜像口径）
// -----------------------------------------------------------------------------
// 与主查询 A 同构：物流边换成 按采购合同入库→入库，流水方向换成 付款，
// 判定条件反向为 min(入库) > min(付款)。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE s <> g

// 按采购合同入库的单据 + 合同付款方向的资金流水
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WHERE f.trade_dir IN ['付款', '支出']

WITH g, s, c, rk, f,
     CASE WHEN rk.budat IS NULL OR trim(toString(rk.budat)) = '' THEN NULL
          ELSE date(left(toString(rk.budat), 10)) END AS rkDate,
     CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
          ELSE date(left(toString(f.TRANS_TIME), 10)) END AS fDate

// 最早口径：最早入库时间 vs 最早付款时间（同日不算，严格大于才命中）
WITH g, s, c,
     min(rkDate) AS rkMin, min(fDate) AS fkMin,
     count(DISTINCT rk) AS 入库单数, count(DISTINCT f) AS 付款笔数
WHERE rkMin IS NOT NULL AND fkMin IS NOT NULL AND rkMin > fkMin

WITH g, s, c, rkMin, fkMin, 入库单数, 付款笔数
CALL {
    WITH c
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(x:dws_dsjsj_zstp_vertex_rk)
    WITH x, CASE WHEN x.budat IS NULL OR trim(toString(x.budat)) = '' THEN NULL
                 ELSE date(left(toString(x.budat), 10)) END AS d
    ORDER BY d ASC
    WITH head(collect(x)) AS rk0
    RETURN rk0
}
CALL {
    WITH c
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(y:dws_dsjsj_zstp_vertex_zjls)
    WHERE y.trade_dir IN ['付款', '支出']
    WITH y, CASE WHEN y.TRANS_TIME IS NULL OR trim(toString(y.TRANS_TIME)) = '' THEN NULL
                 ELSE date(left(toString(y.TRANS_TIME), 10)) END AS d
    ORDER BY d ASC
    WITH head(collect(y)) AS f0
    RETURN f0
}
OPTIONAL MATCH pWL = (wl:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk0)
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pS = (s)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pK = (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk0)
MATCH pF = (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f0)
RETURN DISTINCT pC, pS, pK, pF, pWL,
       g.org_name            AS 国电投企业,
       s.org_name            AS 采购合同相对方,
       c.contract_code       AS 合同编号,
       c.contract_name       AS 合同名称,
       c.payment_direction   AS 合同方向,
       rkMin                 AS 最早入库时间,
       fkMin                 AS 最早付款时间,
       duration.between(fkMin, rkMin) AS 入库晚于付款,
       入库单数, 付款笔数,
       rk0.mblnr             AS 最早入库单号,
       f0.bill_num           AS 最早付款流水号,
       f0.tran_amt           AS 最早付款金额,
       '最早入库时间晚于最早付款时间' AS 命中规则;


// =============================================================================
// 三、变体 A：物料贯通强口径（同一物料既有入库/出库单据才命中）
// -----------------------------------------------------------------------------
// 流程图含 (物料)-[:消耗物料]->(出库) 一段；若业务要求"单据必须挂物料"才判定，
// 在主查询第 2 步的 MATCH 后追加物料存在性条件即可（把 OPTIONAL 换成 WHERE EXISTS）。
// 以下以销售侧为例，采购侧同法（把 消耗物料/axshtck 换成 领用物料/acghtrk）。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WHERE f.trade_dir IN ['收款', '收入']
  AND EXISTS { MATCH (:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck) }
WITH g, c, ck, f,
     CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
          ELSE date(left(toString(ck.wadat_ist), 10)) END AS ckDate,
     CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
          ELSE date(left(toString(f.TRANS_TIME), 10)) END AS fDate
WITH g, c, min(ckDate) AS ckMin, min(fDate) AS skMin
WHERE ckMin IS NOT NULL AND skMin IS NOT NULL AND ckMin < skMin
RETURN DISTINCT g.org_name      AS 国电投企业,
       c.contract_code          AS 合同编号,
       c.payment_direction      AS 合同方向,
       ckMin                    AS 最早出库时间,
       skMin                    AS 最早收款时间,
       '出库时间早于收款时间（物料贯通口径）' AS 命中规则
ORDER BY 合同编号;


// =============================================================================
// 四、变体 B：全库版（不锚定国电投企业，任意合同只要两侧单据齐全即纳入）
// -----------------------------------------------------------------------------
// 销售/采购两侧合并扫描，一次输出两类时间线倒置；生产可按合同签订时间、
// 金额、组织再叠加过滤。签约企业通过 签订合同 边反查（可为空）。
// =============================================================================
MATCH (c:dws_dsjsj_zstp_vertex_ht)
OPTIONAL MATCH (cx:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WITH c, collect(DISTINCT cx.org_name) AS 签约企业

// 销售侧：出库 vs 收款
CALL {
    WITH c
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WHERE f.trade_dir IN ['收款', '收入']
    WITH c,
         min(CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
                  ELSE date(left(toString(ck.wadat_ist), 10)) END) AS t1,
         min(CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
                  ELSE date(left(toString(f.TRANS_TIME), 10)) END) AS t2
    WHERE t1 IS NOT NULL AND t2 IS NOT NULL AND t1 < t2
    RETURN '出库时间早于收款时间' AS 命中规则, t1 AS 最早物流时间, t2 AS 最早资金时间
    UNION ALL
    WITH c
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WHERE f.trade_dir IN ['付款', '支出']
    WITH c,
         min(CASE WHEN rk.budat IS NULL OR trim(toString(rk.budat)) = '' THEN NULL
                  ELSE date(left(toString(rk.budat), 10)) END) AS t1,
         min(CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
                  ELSE date(left(toString(f.TRANS_TIME), 10)) END) AS t2
    WHERE t1 IS NOT NULL AND t2 IS NOT NULL AND t1 > t2
    RETURN '最早入库时间晚于最早付款时间' AS 命中规则, t1 AS 最早物流时间, t2 AS 最早资金时间
}
RETURN DISTINCT c.contract_code AS 合同编号,
       c.contract_name          AS 合同名称,
       c.payment_direction      AS 合同方向,
       签约企业,
       命中规则,
       最早物流时间,
       最早资金时间,
       duration.between(最早资金时间, 最早物流时间) AS 时间倒置幅度
ORDER BY 合同编号, 命中规则;


// =============================================================================
// 五、变体 C：无法判定 / 待核查（单据或流水缺一侧、时间缺失，不能判也不能放过）
// -----------------------------------------------------------------------------
// 输出待核查原因（合同维度，命中可判定的不重复输出）:
//   销售合同无出库单        —— 有收款流水但没有任何 按销售合同出库 单据
//   销售合同无收款流水      —— 有出库单但没有收款方向的流水
//   采购合同无入库单        —— 有付款流水但没有任何 按采购合同入库 单据
//   采购合同无付款流水      —— 有入库单但没有付款方向的流水
//   单据与流水方向不匹配    —— 只有少量单据/流水且方向对不上，需人工核查
//   物流与资金单据均缺失    —— 没有任何有效时间的单据与流水
// 说明：主查询只对"两侧齐全且时间有效"的合同判定；本节把其余情形列为待核查。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH c,
     count(DISTINCT CASE WHEN ck.wadat_ist IS NOT NULL
               AND trim(toString(ck.wadat_ist)) <> '' THEN ck END) AS 有效出库数,
     count(DISTINCT CASE WHEN rk.budat IS NOT NULL
               AND trim(toString(rk.budat)) <> '' THEN rk END) AS 有效入库数,
     count(DISTINCT CASE WHEN f.trade_dir IN ['收款', '收入']
               AND f.TRANS_TIME IS NOT NULL
               AND trim(toString(f.TRANS_TIME)) <> '' THEN f END) AS 有效收款数,
     count(DISTINCT CASE WHEN f.trade_dir IN ['付款', '支出']
               AND f.TRANS_TIME IS NOT NULL
               AND trim(toString(f.TRANS_TIME)) <> '' THEN f END) AS 有效付款数
WITH c, 有效出库数, 有效入库数, 有效收款数, 有效付款数,
     CASE
       WHEN 有效出库数 = 0 AND 有效收款数 > 0 THEN '销售合同无出库单'
       WHEN 有效出库数 > 0 AND 有效收款数 = 0 THEN '销售合同无收款流水'
       WHEN 有效入库数 = 0 AND 有效付款数 > 0 THEN '采购合同无入库单'
       WHEN 有效入库数 > 0 AND 有效付款数 = 0 THEN '采购合同无付款流水'
       WHEN (有效出库数 > 0 AND 有效收款数 > 0)
         OR (有效入库数 > 0 AND 有效付款数 > 0) THEN '可判定'
       WHEN 有效出库数 + 有效入库数 + 有效收款数 + 有效付款数 > 0
            THEN '单据与流水方向不匹配（待人工核查）'
       ELSE '物流与资金单据均缺失'
     END AS 待核查原因
WHERE 待核查原因 <> '可判定'
RETURN c.contract_code AS 合同编号,
       c.contract_name AS 合同名称,
       c.payment_direction AS 合同方向,
       有效出库数, 有效入库数, 有效收款数, 有效付款数,
       待核查原因
ORDER BY 待核查原因, 合同编号;


// =============================================================================
// 六、自包含验证数据（MOCK17_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 主查询 A 正例（销售侧，应命中"出库时间早于收款时间"）:
//   PA1 销售合同：出库 2024-03-10（字符串）早于 收款 2024-05-20（datetime）→ 命中；
//       不挂物料（验证主查询不要求物料贯通）
//   PA2 销售合同：2 出库 × 2 收款交错，min(出库)=2024-02-01 < min(收款)=2024-04-01
//       → 命中（验证"取最早"口径；挂物料 → 变体 A 也命中）
// 主查询 B 正例（采购侧，应命中"入库晚于付款"）:
//   PB1 采购合同：付款 2024-01-15（datetime）早于 入库 2024-04-20（字符串）→ 命中；
//       挂物料 → 变体 A 采购侧同法命中
//   PB2 采购合同：2 付款 × 2 入库交错，min(入库)=2024-03-01 > min(付款)=2024-01-05
//       → 命中（验证"取最早"口径；不挂物料）
// 反例（不应命中）:
//   NA1 收款先于出库（先款后货，正常）        → A 不报
//   NA2 出库与收款同日（口径 6：同日不算）    → A 不报
//   NA3 有收款流水、无出库单                  → A 不报（待核查）
//   NA4 有出库单、无收款流水                  → A 不报（待核查）
//   NA5 只有付款方向流水（方向不符不参与判定）→ A 不报（待核查）
//   NB1 入库先于付款（货到付款，正常）        → B 不报
//   NB2 有付款流水、无入库单                  → B 不报（待核查）
//   NB3 有入库单、无付款流水                  → B 不报（待核查）
//   NB4 只有收款方向流水                      → B 不报（待核查）
// 变体用例:
//   PEXT 外部-外部销售合同，出库早于收款 → 主查询不命中（非国电投锚点），仅全库版（变体 B）命中
// =============================================================================

// ---- 6.1 企业 ----
MERGE (g:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
  ON CREATE SET g.org_name='MOCK17_国电投企业A', g.flag_gdtqy='是',
                g.org_credit_code='91340200395000777V',
                g.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
  ON CREATE SET s1.org_name='MOCK17_销售相对方1', s1.flag_gdtqy='否',
                s1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB2'})
  ON CREATE SET s2.org_name='MOCK17_销售相对方2', s2.flag_gdtqy='否',
                s2.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB1'})
  ON CREATE SET s3.org_name='MOCK17_采购相对方1', s3.flag_gdtqy='否',
                s3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB2'})
  ON CREATE SET s4.org_name='MOCK17_采购相对方2', s4.flag_gdtqy='否',
                s4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sx:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_EXT'})
  ON CREATE SET sx.org_name='MOCK17_外部销售方', sx.flag_gdtqy='否',
                sx.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (sy:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_EXTB'})
  ON CREATE SET sy.org_name='MOCK17_外部购买方', sy.flag_gdtqy='否',
                sy.schema_name='dws_dsjsj_zstp_vertex_qy';

// ---- 6.2 合同 ----
MERGE (a1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA1'})
  ON CREATE SET a1.contract_code='MOCK17_HT_PA1', a1.contract_name='MOCK17_销售合同PA1',
                a1.payment_direction='销售', a1.sign_time='2024-02-01',
                a1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (a2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
  ON CREATE SET a2.contract_code='MOCK17_HT_PA2', a2.contract_name='MOCK17_销售合同PA2',
                a2.payment_direction='销售', a2.sign_time='2024-01-15',
                a2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (b1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB1'})
  ON CREATE SET b1.contract_code='MOCK17_HT_PB1', b1.contract_name='MOCK17_采购合同PB1',
                b1.payment_direction='采购', b1.sign_time='2024-01-05',
                b1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (b2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
  ON CREATE SET b2.contract_code='MOCK17_HT_PB2', b2.contract_name='MOCK17_采购合同PB2',
                b2.payment_direction='采购', b2.sign_time='2024-01-03',
                b2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA1'})
  ON CREATE SET n1.contract_code='MOCK17_HT_NA1', n1.contract_name='MOCK17_反例NA1_先款后货',
                n1.payment_direction='销售', n1.sign_time='2024-01-10',
                n1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA2'})
  ON CREATE SET n2.contract_code='MOCK17_HT_NA2', n2.contract_name='MOCK17_反例NA2_出收款同日',
                n2.payment_direction='销售', n2.sign_time='2024-04-01',
                n2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA3'})
  ON CREATE SET n3.contract_code='MOCK17_HT_NA3', n3.contract_name='MOCK17_反例NA3_无出库',
                n3.payment_direction='销售', n3.sign_time='2024-03-01',
                n3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA4'})
  ON CREATE SET n4.contract_code='MOCK17_HT_NA4', n4.contract_name='MOCK17_反例NA4_无收款流水',
                n4.payment_direction='销售', n4.sign_time='2024-03-02',
                n4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n5:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA5'})
  ON CREATE SET n5.contract_code='MOCK17_HT_NA5', n5.contract_name='MOCK17_反例NA5_仅付款流水',
                n5.payment_direction='销售', n5.sign_time='2024-03-03',
                n5.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (m1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB1'})
  ON CREATE SET m1.contract_code='MOCK17_HT_NB1', m1.contract_name='MOCK17_反例NB1_货到付款',
                m1.payment_direction='采购', m1.sign_time='2024-01-08',
                m1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (m2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB2'})
  ON CREATE SET m2.contract_code='MOCK17_HT_NB2', m2.contract_name='MOCK17_反例NB2_无入库',
                m2.payment_direction='采购', m2.sign_time='2024-01-09',
                m2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (m3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB3'})
  ON CREATE SET m3.contract_code='MOCK17_HT_NB3', m3.contract_name='MOCK17_反例NB3_无付款流水',
                m3.payment_direction='采购', m3.sign_time='2024-01-10',
                m3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (m4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB4'})
  ON CREATE SET m4.contract_code='MOCK17_HT_NB4', m4.contract_name='MOCK17_反例NB4_仅收款流水',
                m4.payment_direction='采购', m4.sign_time='2024-01-11',
                m4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (ex:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PEXT'})
  ON CREATE SET ex.contract_code='MOCK17_HT_PEXT', ex.contract_name='MOCK17_外部合同PEXT',
                ex.payment_direction='销售', ex.sign_time='2024-02-20',
                ex.schema_name='dws_dsjsj_zstp_vertex_ht';

// ---- 6.3 物料 ----
MERGE (w1:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK17_WL_1'})
  ON CREATE SET w1.matnr='M-MOCK14-001', w1.maktx='MOCK17_物料1',
                w1.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (w2:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK17_WL_2'})
  ON CREATE SET w2.matnr='M-MOCK14-002', w2.maktx='MOCK17_物料2',
                w2.schema_name='dws_dsjsj_zstp_vertex_wl';

// ---- 6.4 出库（销售侧物流单据）----
// PA1：字符串时间，早于收款 → 命中
MERGE (k1:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A1'})
  ON CREATE SET k1.vbeln='MOCK14-CK-A1', k1.wadat_ist='2024-03-10',
                k1.schema_name='dws_dsjsj_zstp_vertex_ck';
// PA2：两张出库，最早 2024-02-01（datetime 与字符串混用）→ 命中
MERGE (k2a:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A2A'})
  ON CREATE SET k2a.vbeln='MOCK14-CK-A2A', k2a.wadat_ist=datetime('2024-02-01T09:00:00'),
                k2a.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (k2b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A2B'})
  ON CREATE SET k2b.vbeln='MOCK14-CK-A2B', k2b.wadat_ist='2024-06-01',
                k2b.schema_name='dws_dsjsj_zstp_vertex_ck';
// NA1：出库 2024-04-10 晚于收款 2024-02-10 → 不命中
MERGE (kN1:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N1'})
  ON CREATE SET kN1.vbeln='MOCK14-CK-N1', kN1.wadat_ist='2024-04-10',
                kN1.schema_name='dws_dsjsj_zstp_vertex_ck';
// NA2：出库与收款同日 2024-06-15 → 不命中
MERGE (kN2:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N2'})
  ON CREATE SET kN2.vbeln='MOCK14-CK-N2', kN2.wadat_ist='2024-06-15',
                kN2.schema_name='dws_dsjsj_zstp_vertex_ck';
// NA4：有出库无收款流水 → A 不命中（待核查）
MERGE (kN4:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N4'})
  ON CREATE SET kN4.vbeln='MOCK14-CK-N4', kN4.wadat_ist='2024-03-20',
                kN4.schema_name='dws_dsjsj_zstp_vertex_ck';
// NA5：出库 2024-03-25，但合同只挂付款方向流水 → 不命中
MERGE (kN5:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N5'})
  ON CREATE SET kN5.vbeln='MOCK14-CK-N5', kN5.wadat_ist='2024-03-25',
                kN5.schema_name='dws_dsjsj_zstp_vertex_ck';
// PEXT：外部合同出库 2024-03-05 → 仅全库版命中
MERGE (kX:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_EXT'})
  ON CREATE SET kX.vbeln='MOCK14-CK-EXT', kX.wadat_ist='2024-03-05',
                kX.schema_name='dws_dsjsj_zstp_vertex_ck';

// ---- 6.5 入库（采购侧物流单据）----
// PB1：字符串时间 2024-04-20 晚于付款 2024-01-15（datetime）→ 命中
MERGE (r1:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B1'})
  ON CREATE SET r1.mblnr='MOCK14-RK-B1', r1.budat='2024-04-20',
                r1.schema_name='dws_dsjsj_zstp_vertex_rk';
// PB2：两张入库，最早 2024-03-01（datetime 与字符串混用）→ 命中
MERGE (r2a:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B2A'})
  ON CREATE SET r2a.mblnr='MOCK14-RK-B2A', r2a.budat=datetime('2024-03-01T08:00:00'),
                r2a.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (r2b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B2B'})
  ON CREATE SET r2b.mblnr='MOCK14-RK-B2B', r2b.budat='2024-06-01',
                r2b.schema_name='dws_dsjsj_zstp_vertex_rk';
// NB1：入库 2024-02-10 早于付款 2024-03-10 → 不命中（货到付款）
MERGE (rM1:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_M1'})
  ON CREATE SET rM1.mblnr='MOCK14-RK-M1', rM1.budat='2024-02-10',
                rM1.schema_name='dws_dsjsj_zstp_vertex_rk';
// NB3：有入库无付款流水 → B 不命中（待核查）
MERGE (rM3:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_M3'})
  ON CREATE SET rM3.mblnr='MOCK14-RK-M3', rM3.budat='2024-02-15',
                rM3.schema_name='dws_dsjsj_zstp_vertex_rk';

// ---- 6.6 资金流水 ----
// PA1 收款：datetime 时间
MERGE (fa1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_A1'})
  ON CREATE SET fa1.bill_num='MOCK14-BL-A1', fa1.tran_amt=500000.00, fa1.trade_dir='收款',
                fa1.TRANS_TIME=datetime('2024-05-20T14:30:00'),
                fa1.schema_name='dws_dsjsj_zstp_vertex_zjls';
// PA2 两笔收款，最早 2024-04-01
MERGE (fa2a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_A2A'})
  ON CREATE SET fa2a.bill_num='MOCK14-BL-A2A', fa2a.tran_amt=200000.00, fa2a.trade_dir='收款',
                fa2a.TRANS_TIME='2024-04-01',
                fa2a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fa2b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_A2B'})
  ON CREATE SET fa2b.bill_num='MOCK14-BL-A2B', fa2b.tran_amt=300000.00, fa2b.trade_dir='收入',
                fa2b.TRANS_TIME=datetime('2024-07-01T10:00:00'),
                fa2b.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NA1 收款 2024-02-10 早于出库 → 不命中
MERGE (fN1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N1'})
  ON CREATE SET fN1.bill_num='MOCK14-BL-N1', fN1.tran_amt=100000.00, fN1.trade_dir='收款',
                fN1.TRANS_TIME='2024-02-10',
                fN1.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NA2 收款与出库同日 2024-06-15 → 不命中
MERGE (fN2:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N2'})
  ON CREATE SET fN2.bill_num='MOCK14-BL-N2', fN2.tran_amt=90000.00, fN2.trade_dir='收款',
                fN2.TRANS_TIME='2024-06-15',
                fN2.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NA3 只有收款流水、无出库 → 待核查
MERGE (fN3:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N3'})
  ON CREATE SET fN3.bill_num='MOCK14-BL-N3', fN3.tran_amt=80000.00, fN3.trade_dir='收款',
                fN3.TRANS_TIME='2024-03-05',
                fN3.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NA5 付款方向流水挂在销售合同上 → 不参与收款判定
MERGE (fN5:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N5'})
  ON CREATE SET fN5.bill_num='MOCK14-BL-N5', fN5.tran_amt=70000.00, fN5.trade_dir='付款',
                fN5.TRANS_TIME='2024-03-06',
                fN5.schema_name='dws_dsjsj_zstp_vertex_zjls';
// PB1 付款：datetime 时间 2024-01-15，早于入库
MERGE (fb1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_B1'})
  ON CREATE SET fb1.bill_num='MOCK14-BL-B1', fb1.tran_amt=400000.00, fb1.trade_dir='付款',
                fb1.TRANS_TIME=datetime('2024-01-15T09:30:00'),
                fb1.schema_name='dws_dsjsj_zstp_vertex_zjls';
// PB2 两笔付款，最早 2024-01-05
MERGE (fb2a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_B2A'})
  ON CREATE SET fb2a.bill_num='MOCK14-BL-B2A', fb2a.tran_amt=150000.00, fb2a.trade_dir='付款',
                fb2a.TRANS_TIME='2024-01-05',
                fb2a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fb2b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_B2B'})
  ON CREATE SET fb2b.bill_num='MOCK14-BL-B2B', fb2b.tran_amt=250000.00, fb2b.trade_dir='支出',
                fb2b.TRANS_TIME=datetime('2024-05-01T11:00:00'),
                fb2b.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NB1 付款 2024-03-10 晚于入库 → 不命中
MERGE (fM1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_M1'})
  ON CREATE SET fM1.bill_num='MOCK14-BL-M1', fM1.tran_amt=120000.00, fM1.trade_dir='付款',
                fM1.TRANS_TIME='2024-03-10',
                fM1.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NB2 只有付款流水、无入库 → 待核查
MERGE (fM2:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_M2'})
  ON CREATE SET fM2.bill_num='MOCK14-BL-M2', fM2.tran_amt=60000.00, fM2.trade_dir='付款',
                fM2.TRANS_TIME='2024-01-20',
                fM2.schema_name='dws_dsjsj_zstp_vertex_zjls';
// NB4 收款方向流水挂在采购合同上 → 不参与付款判定
MERGE (fM4:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_M4'})
  ON CREATE SET fM4.bill_num='MOCK14-BL-M4', fM4.tran_amt=55000.00, fM4.trade_dir='收款',
                fM4.TRANS_TIME='2024-01-21',
                fM4.schema_name='dws_dsjsj_zstp_vertex_zjls';
// PEXT 外部合同收款 2024-05-05 → 仅全库版命中
MERGE (fX:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_EXT'})
  ON CREATE SET fX.bill_num='MOCK14-BL-EXT', fX.tran_amt=330000.00, fX.trade_dir='收款',
                fX.TRANS_TIME='2024-05-05',
                fX.schema_name='dws_dsjsj_zstp_vertex_zjls';

// ---- 6.7 边：签订合同（企业 → 合同，MATCH 端点 + MERGE 关系，幂等）----
// PA1/PA2 销售合同：国电投 g + 销售相对方
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_PA1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S1_PA1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_PA2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S2_PA2'}]->(b);
// PB1/PB2 采购合同：国电投 g + 采购相对方
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_PB1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_P1_PB1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_PB2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_P2_PB2'}]->(b);
// 反例合同均按 国电投 g + 相对方1 签约
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NA1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S1_NA1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NA2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S1_NA2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NA3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S1_NA3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NA4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S1_NA4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NA5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_SB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_S1_NA5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NB1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_P1_NB1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NB2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_P1_NB2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NB3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_P1_NB3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_G_NB4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_P1_NB4'}]->(b);
// PEXT 外部-外部合同：国电投不参与
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_EXT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PEXT'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_EXT_PEXT'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK17_QY_EXTB'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PEXT'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK17_E_QD_EXTB_PEXT'}]->(b);

// ---- 6.8 边：按销售合同出库（合同 → 出库）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA1'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_A1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_A2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_A2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA1'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA4'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_N4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA5'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_N5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_N5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PEXT'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_EXT'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK17_E_CK_EXT'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';

// ---- 6.9 边：按采购合同入库（合同 → 入库）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK17_E_RK_B1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK17_E_RK_B2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK17_E_RK_B2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_M1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK17_E_RK_M1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB3'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_M3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK17_E_RK_M3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';

// ---- 6.10 边：合同收款/付款（合同 → 资金流水）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_A1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_A1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_A2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_A2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PA2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_A2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_A2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA3'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_N3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NA5'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_N5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_N5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_B1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_B1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_B2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_B2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PB2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_B2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_B2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_M1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_M1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_M2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_M2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_NB4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_M4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_M4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK17_HT_PEXT'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK17_ZJLS_EXT'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK17_E_SKFK_EXT'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';

// ---- 6.11 边：物料贯通（物料 → 出库/入库，仅 PA2/PB1 挂物料）----
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK17_WL_1'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK17_CK_A2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK17_E_XHWL_1'}]->(b)
  ON CREATE SET r.name1='MOCK17_销售出库', r.werks='1000', r.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK17_WL_2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK17_RK_B1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK17_E_LYWL_1'}]->(b)
  ON CREATE SET r.name1='MOCK17_采购入库', r.werks='1000', r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';


// =============================================================================
// 七、断言校验（先跑第六节灌数据，再跑本节，应全部 PASS）
// =============================================================================

// 断言 1：主查询 A（销售侧）恰好命中 PA1/PA2，且最早时间正确
//         PA1: min(出库)=2024-03-10 < min(收款)=2024-05-20
//         PA2: min(出库)=2024-02-01 < min(收款)=2024-04-01（取最早口径）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WHERE f.trade_dir IN ['收款', '收入']
WITH c,
     min(CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
              ELSE date(left(toString(ck.wadat_ist), 10)) END) AS ckMin,
     min(CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
              ELSE date(left(toString(f.TRANS_TIME), 10)) END) AS fMin
WHERE ckMin IS NOT NULL AND fMin IS NOT NULL AND ckMin < fMin
WITH collect(DISTINCT c.contract_code + '|' + toString(ckMin) + '|' + toString(fMin)) AS 命中,
     ['MOCK17_HT_PA1|2024-03-10|2024-05-20',
      'MOCK17_HT_PA2|2024-02-01|2024-04-01'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言1_销售侧命中PA1PA2且取最早;

// 断言 2：主查询 B（采购侧）恰好命中 PB1/PB2，且最早时间正确
//         PB1: min(付款)=2024-01-15 < min(入库)=2024-04-20
//         PB2: min(付款)=2024-01-05 < min(入库)=2024-03-01
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WHERE f.trade_dir IN ['付款', '支出']
WITH c,
     min(CASE WHEN rk.budat IS NULL OR trim(toString(rk.budat)) = '' THEN NULL
              ELSE date(left(toString(rk.budat), 10)) END) AS rkMin,
     min(CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
              ELSE date(left(toString(f.TRANS_TIME), 10)) END) AS fMin
WHERE rkMin IS NOT NULL AND fMin IS NOT NULL AND rkMin > fMin
WITH collect(DISTINCT c.contract_code + '|' + toString(rkMin) + '|' + toString(fMin)) AS 命中,
     ['MOCK17_HT_PB1|2024-04-20|2024-01-15',
      'MOCK17_HT_PB2|2024-03-01|2024-01-05'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言2_采购侧命中PB1PB2且取最早;

// 断言 3：反例不误报（先款后货 NA1 / 同日 NA2 / 货到付款 NB1 / 缺一侧 NA3、NA4、NB2、NB3 /
//         方向不符 NA5、NB4），九条反例对两条规则均不命中
MATCH (c:dws_dsjsj_zstp_vertex_ht)
WHERE c.contract_code IN ['MOCK17_HT_NA1', 'MOCK17_HT_NA2', 'MOCK17_HT_NA3',
         'MOCK17_HT_NA4', 'MOCK17_HT_NA5',
         'MOCK17_HT_NB1', 'MOCK17_HT_NB2', 'MOCK17_HT_NB3', 'MOCK17_HT_NB4']
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH c,
     min(CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
              ELSE date(left(toString(ck.wadat_ist), 10)) END) AS ckMin,
     min(CASE WHEN rk.budat IS NULL OR trim(toString(rk.budat)) = '' THEN NULL
              ELSE date(left(toString(rk.budat), 10)) END) AS rkMin,
     min(CASE WHEN f.trade_dir IN ['收款', '收入']
              THEN CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
                        ELSE date(left(toString(f.TRANS_TIME), 10)) END END) AS skMin,
     min(CASE WHEN f.trade_dir IN ['付款', '支出']
              THEN CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
                        ELSE date(left(toString(f.TRANS_TIME), 10)) END END) AS fkMin
WITH c.contract_code AS 编号,
     (ckMin IS NOT NULL AND skMin IS NOT NULL AND ckMin < skMin) AS 销售侧命中,
     (rkMin IS NOT NULL AND fkMin IS NOT NULL AND rkMin > fkMin) AS 采购侧命中
WITH collect(编号 + CASE WHEN 销售侧命中 OR 采购侧命中 THEN '|误报' ELSE '|ok' END) AS 判定,
     ['MOCK17_HT_NA1|ok', 'MOCK17_HT_NA2|ok', 'MOCK17_HT_NA3|ok',
      'MOCK17_HT_NA4|ok', 'MOCK17_HT_NA5|ok',
      'MOCK17_HT_NB1|ok', 'MOCK17_HT_NB2|ok', 'MOCK17_HT_NB3|ok',
      'MOCK17_HT_NB4|ok'] AS 期望
RETURN CASE WHEN size(判定) = size(期望) AND all(x IN 期望 WHERE x IN 判定)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 判定 | a + v + '; ') END
       AS 断言3_九条反例两侧规则均不误报;

// 断言 4：待核查（变体 C）恰好 6 条，原因正确
//         NA3 -> 销售合同无出库单       NA4 -> 销售合同无收款流水
//         NA5 -> 销售合同无收款流水     NB4 -> 销售合同无出库单（采购合同挂收款流水且无出库）
//         NB2 -> 采购合同无入库单       NB3 -> 采购合同无付款流水
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH c,
     count(DISTINCT CASE WHEN ck.wadat_ist IS NOT NULL
               AND trim(toString(ck.wadat_ist)) <> '' THEN ck END) AS 有效出库数,
     count(DISTINCT CASE WHEN rk.budat IS NOT NULL
               AND trim(toString(rk.budat)) <> '' THEN rk END) AS 有效入库数,
     count(DISTINCT CASE WHEN f.trade_dir IN ['收款', '收入']
               AND f.TRANS_TIME IS NOT NULL
               AND trim(toString(f.TRANS_TIME)) <> '' THEN f END) AS 有效收款数,
     count(DISTINCT CASE WHEN f.trade_dir IN ['付款', '支出']
               AND f.TRANS_TIME IS NOT NULL
               AND trim(toString(f.TRANS_TIME)) <> '' THEN f END) AS 有效付款数
WITH c, 有效出库数, 有效入库数, 有效收款数, 有效付款数,
     CASE
       WHEN 有效出库数 = 0 AND 有效收款数 > 0 THEN '销售合同无出库单'
       WHEN 有效出库数 > 0 AND 有效收款数 = 0 THEN '销售合同无收款流水'
       WHEN 有效入库数 = 0 AND 有效付款数 > 0 THEN '采购合同无入库单'
       WHEN 有效入库数 > 0 AND 有效付款数 = 0 THEN '采购合同无付款流水'
       WHEN (有效出库数 > 0 AND 有效收款数 > 0)
         OR (有效入库数 > 0 AND 有效付款数 > 0) THEN '可判定'
       WHEN 有效出库数 + 有效入库数 + 有效收款数 + 有效付款数 > 0
            THEN '单据与流水方向不匹配（待人工核查）'
       ELSE '物流与资金单据均缺失'
     END AS 待核查原因
WHERE 待核查原因 <> '可判定'
WITH collect(DISTINCT c.contract_code + '|' + 待核查原因) AS 待核查,
     ['MOCK17_HT_NA3|销售合同无出库单',
      'MOCK17_HT_NA4|销售合同无收款流水',
      'MOCK17_HT_NA5|销售合同无收款流水',
      'MOCK17_HT_NB4|销售合同无出库单',
      'MOCK17_HT_NB2|采购合同无入库单',
      'MOCK17_HT_NB3|采购合同无付款流水'] AS 期望
RETURN CASE WHEN size(待核查) = size(期望) AND all(x IN 期望 WHERE x IN 待核查)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 待核查 | a + v + '; ') END
       AS 断言4_待核查6条且原因正确;

// 断言 5：全库版（变体 B）在 MOCK17_ 内恰好命中 5 条：
//         PA1/PA2/PEXT 命中销售侧，PB1/PB2 命中采购侧（外部-外部 PEXT 仅全库版可见）
MATCH (c:dws_dsjsj_zstp_vertex_ht)
WHERE c.contract_code STARTS WITH 'MOCK17_'
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(fS:dws_dsjsj_zstp_vertex_zjls)
    WHERE fS.trade_dir IN ['收款', '收入']
    WITH min(CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
                  ELSE date(left(toString(ck.wadat_ist), 10)) END) AS t1,
         min(CASE WHEN fS.TRANS_TIME IS NULL OR trim(toString(fS.TRANS_TIME)) = '' THEN NULL
                  ELSE date(left(toString(fS.TRANS_TIME), 10)) END) AS t2
    WHERE t1 IS NOT NULL AND t2 IS NOT NULL AND t1 < t2
    RETURN collect('出库时间早于收款时间|' + toString(t1) + '|' + toString(t2)) AS 规则
    UNION ALL
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(fB:dws_dsjsj_zstp_vertex_zjls)
    WHERE fB.trade_dir IN ['付款', '支出']
    WITH min(CASE WHEN rk.budat IS NULL OR trim(toString(rk.budat)) = '' THEN NULL
                  ELSE date(left(toString(rk.budat), 10)) END) AS t1,
         min(CASE WHEN fB.TRANS_TIME IS NULL OR trim(toString(fB.TRANS_TIME)) = '' THEN NULL
                  ELSE date(left(toString(fB.TRANS_TIME), 10)) END) AS t2
    WHERE t1 IS NOT NULL AND t2 IS NOT NULL AND t1 > t2
    RETURN collect('最早入库时间晚于最早付款时间|' + toString(t2) + '|' + toString(t1)) AS 规则
}
UNWIND 规则 AS r
WITH DISTINCT c.contract_code + '|' + r AS 命中行
WITH collect(命中行) AS 命中,
     ['MOCK17_HT_PA1|出库时间早于收款时间|2024-03-10|2024-05-20',
      'MOCK17_HT_PA2|出库时间早于收款时间|2024-02-01|2024-04-01',
      'MOCK17_HT_PEXT|出库时间早于收款时间|2024-03-05|2024-05-05',
      'MOCK17_HT_PB1|最早入库时间晚于最早付款时间|2024-01-15|2024-04-20',
      'MOCK17_HT_PB2|最早入库时间晚于最早付款时间|2024-01-05|2024-03-01'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言5_全库版5条含外部合同PEXT;

// 断言 6：物料贯通强口径（变体 A，销售侧）只命中挂物料的 PA2；PA1 无物料不命中
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000777V'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WHERE f.trade_dir IN ['收款', '收入']
  AND EXISTS { MATCH (:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck) }
WITH c,
     min(CASE WHEN ck.wadat_ist IS NULL OR trim(toString(ck.wadat_ist)) = '' THEN NULL
              ELSE date(left(toString(ck.wadat_ist), 10)) END) AS ckMin,
     min(CASE WHEN f.TRANS_TIME IS NULL OR trim(toString(f.TRANS_TIME)) = '' THEN NULL
              ELSE date(left(toString(f.TRANS_TIME), 10)) END) AS fMin
WHERE ckMin IS NOT NULL AND fMin IS NOT NULL AND ckMin < fMin
WITH collect(DISTINCT c.contract_code) AS 命中
RETURN CASE WHEN 命中 = ['MOCK17_HT_PA2'] THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言6_物料贯通口径仅命中PA2;


// =============================================================================
// 八、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK17_' DETACH DELETE n;
