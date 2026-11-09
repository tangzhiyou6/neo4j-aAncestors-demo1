// =============================================================================
// 25 SPIC-CW-0106-04 有悖于交易常识的异常交易 · 最早入库时间晚于最早付款时间
// -----------------------------------------------------------------------------
// 对应流程图（国电投企业A 居中）:
//
//   (采购合同相对方 s)-[:签订合同]->(采购合同 c)<-[:签订合同]-(国电投企业A g)
//   (c)-[:合同收款/付款]->(资金流水 f)                        ← 付款时间 f.TRANS_TIME
//   (c)-[:按采购合同入库]->(入库 rk)<-[:领用物料]-(物料 m)     ← 入库时间 rk.budat
//
//   min(rk.budat) > min(f.TRANS_TIME)
//     ⇒ 命中：最早入库时间晚于最早付款时间（先付款、后到货，有悖交易常识）
//
// 规则原文：1.最早入库时间晚于最早付款时间：（1）入库时间晚于付款时间。
// 同族规则：SPIC-CW-0106-01（实际收付款银行账户与合同约定不一致）
//          见 22_contract_bank_account_mismatch_query.cypher。
//
// 口径:
//   1. 入口为国电投企业 g 签订的采购合同
//      （payment_direction ∈ ['采购','付款']，方向过滤天然防角色镜像）；
//      采购合同相对方 s 按流程图参与匹配，缺相对方签约边的合同
//      由第三节变体 A（全库版，不要求相对方）兜底。
//   2. 付款时间 = 资金流水.TRANS_TIME（经 合同收款/付款 边关联）；
//      入库时间 = 入库.budat（经 按采购合同入库 边关联）。
//      同一合同多条流水/多张入库单各取最早一条（min），命中证据展示该最早单据；
//      同日多条按 object_key 升序取第一条（确定性输出）。
//   3. 时间归一化与 22_v3 相同：date(left(toString(x), 10))，
//      兼容 datetime 与 'YYYY-MM-DD...' 字符串两种落库方式；
//      非 ISO 前缀 / 空值一律按 NULL 处理 → 不判定 → 进第四节待核查版。
//      注意 ORDER BY 直接按原字段排（datetime 与字符串混落时排序不稳定），
//      生产侧应保证同一字段类型一致。
//   4. 比较粒度为自然日：入库日期 严格大于 付款日期 才命中；
//      同日不命中（含"当天先款后货"的时点差）。如需到时分秒，
//      把 dPay/dIn 归一化换成 datetime 级（去掉 date()/left()）再比较。
//      入库滞后天数用 datetime(...).epochMillis 换算（本库 5.26 的 date
//      无 epochDays 访问器、date-date 相减不合法；勿用 duration.between().days，
//      整月差会归入 months 组件 —— 同 18 号文件警示）。
//   5. 收付方向：主查询按合同全部流水口径（合同收款/付款 边本身不分方向）；
//      若要剔除退款/代收等 收款 流水，见第五节变体 C
//      （f.trade_dir ∈ 付款/支出/支付），第六节 P4 演示两口径差异。
//   6. 预付款、分批到货等正常商业安排也可能命中 —— 本查询是线索生成器，
//      命中需人工核查合同约定的付款/交货节点后再定性。
//   7. 物料链（领用物料）只作入库标的证据，缺失不影响判定。
//
// 标签对照（生产原始 schema 名，与 16~22 号文件一致）:
//   dws_dsjsj_zstp_vertex_qy=企业          dws_dsjsj_zstp_vertex_ht=合同
//   dws_dsjsj_zstp_vertex_zjls=资金流水    dws_dsjsj_zstp_vertex_rk=入库
//   dws_dsjsj_zstp_vertex_wl=物料
//   dws_dsjsj_zstp_edge_qy_qd=签订合同     dws_dsjsj_zstp_edge_ht_skfk=合同收款/付款
//   dws_dsjsj_zstp_edge_ht_acghtrk=按采购合同入库
//   dws_dsjsj_zstp_edge_wl_lywl=领用物料
//
// 时间归一化（后文多处复用，改变规则时只改这一处口径）:
//   date(left(toString(x), 10))，前置校验：
//   x IS NOT NULL AND trim(toString(x)) <> ''
//     AND toString(x) =~ '\\d{4}-\\d{2}-\\d{2}.*'
// =============================================================================


// =============================================================================
// 一、主查询：g 的采购合同，最早入库日期 > 最早付款日期 即命中
//    返回 4 段路径（双方签约 + 付款流水 + 入库单）+ 明细
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位；全库扫描见第三节变体 A）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'

// 1. g 签订的采购合同 + 采购合同相对方
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE c.payment_direction IN ['采购', '付款']
  AND s <> g

WITH DISTINCT g, s, c

// 2. 最早一笔付款流水 fMin（无流水返回 null；同日按 object_key 升序取第一条）
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}

// 3. 最早一张入库单 rkMin（无入库返回 null）
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}

// 4. 时间归一化（datetime / 字符串双兼容；非 ISO 前缀 / 空值 → NULL 不判定）
WITH g, s, c, fMin, rkMin,
     CASE WHEN fMin IS NULL
               OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL
               OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay

// 5. 还原 4 段路径 + 入库标的物料证据（领用物料，可空）
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pP = (s)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pF = (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(fMin)
MATCH pR = (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rkMin)
OPTIONAL MATCH (m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rkMin)
WITH g, s, c, fMin, rkMin, dPay, dIn, pC, pP, pF, pR,
     collect(DISTINCT m.matnr) AS 物料编码
RETURN DISTINCT pC, pP, pF, pR,
       g.org_name          AS 国电投企业,
       s.org_name          AS 采购合同相对方,
       c.contract_code     AS 合同编号,
       c.contract_name     AS 合同名称,
       c.payment_direction AS 合同方向,
       dPay                AS 最早付款日期,
       dIn                 AS 最早入库日期,
       (datetime(toString(dIn) + 'T00:00:00Z').epochMillis
          - datetime(toString(dPay) + 'T00:00:00Z').epochMillis) / 86400000 AS 入库滞后天数,
       fMin.bill_num       AS 付款流水单号,
       fMin.tran_amt       AS 付款金额,
       fMin.trade_dir      AS 收付方向,
       rkMin.mblnr         AS 最早入库单号,
       rkMin.menge         AS 入库数量,
       rkMin.umlgo         AS 入库仓库,
       物料编码,
       '最早入库时间晚于最早付款时间' AS 命中规则;


// =============================================================================
// 二、明细输出版（核查字段，不返回路径）：替换主查询第 5 步的 MATCH/RETURN
// =============================================================================
// WITH g, s, c, fMin, rkMin, dPay, dIn,
//      [(m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rkMin)
//       | m.matnr] AS 物料编码
// RETURN DISTINCT
//     g.org_name          AS 国电投企业,
//     s.org_name          AS 采购合同相对方,
//     c.contract_code     AS 合同编号, c.contract_name AS 合同名称,
//     c.payment_direction AS 合同方向,
//     dPay                AS 最早付款日期,
//     dIn                 AS 最早入库日期,
//     (datetime(toString(dIn) + 'T00:00:00Z').epochMillis
//        - datetime(toString(dPay) + 'T00:00:00Z').epochMillis) / 86400000 AS 入库滞后天数,
//     fMin.bill_num       AS 付款流水单号, fMin.tran_amt AS 付款金额,
//     fMin.trade_dir      AS 收付方向,
//     rkMin.mblnr         AS 最早入库单号, rkMin.menge AS 入库数量,
//     rkMin.umlgo         AS 入库仓库,
//     物料编码,
//     '最早入库时间晚于最早付款时间' AS 命中规则;


// =============================================================================
// 三、变体 A：全库版（不锚定国电投企业、不要求相对方签约边，任意采购合同纳入）
// -----------------------------------------------------------------------------
// 用于全量扫描/离线核查；生产可按合同签订时间、金额、组织再叠加过滤。
// =============================================================================
MATCH (c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款']

CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}
WITH c, fMin, rkMin,
     CASE WHEN fMin IS NULL
               OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL
               OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay
OPTIONAL MATCH (sg:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WITH c, fMin, rkMin, dPay, dIn, collect(DISTINCT sg.org_name) AS 签约企业
RETURN DISTINCT
       c.contract_code     AS 合同编号,
       c.contract_name     AS 合同名称,
       c.payment_direction AS 合同方向,
       签约企业,
       dPay                AS 最早付款日期,
       dIn                 AS 最早入库日期,
       (datetime(toString(dIn) + 'T00:00:00Z').epochMillis
          - datetime(toString(dPay) + 'T00:00:00Z').epochMillis) / 86400000 AS 入库滞后天数,
       fMin.bill_num       AS 付款流水单号,
       fMin.trade_dir      AS 收付方向,
       rkMin.mblnr         AS 最早入库单号,
       '最早入库时间晚于最早付款时间' AS 命中规则
ORDER BY 合同编号;


// =============================================================================
// 四、变体 B：无法判定 / 待核查（证据链不完整，不能判命中也不能放过）
// -----------------------------------------------------------------------------
// 输出五类：
//   合同无付款流水且无入库记录
//   合同无付款流水        —— 有入库单但没有任何流水
//   合同无入库记录        —— 有付款流水但没有任何入库单
//   付款时间缺失          —— 有流水但 TRANS_TIME 全部为空/非 ISO 格式
//   入库时间缺失          —— 有入库单但 budat 全部为空/非 ISO 格式
// 说明：只要两侧各有至少一条有效时间，就视为"可判定"，由主查询判定；
//       部分单据缺时间的情形由主查询忽略（min 天然跳过 NULL），
//       需生产侧补齐数据后复核。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款']
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
WITH c,
     count(DISTINCT f)  AS 付款流水数,
     count(DISTINCT rk) AS 入库单数,
     count(DISTINCT CASE WHEN f IS NOT NULL
                   AND f.TRANS_TIME IS NOT NULL
                   AND trim(toString(f.TRANS_TIME)) <> ''
                   AND toString(f.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
              THEN f END) AS 有效付款时间数,
     count(DISTINCT CASE WHEN rk IS NOT NULL
                   AND rk.budat IS NOT NULL
                   AND trim(toString(rk.budat)) <> ''
                   AND toString(rk.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
              THEN rk END) AS 有效入库时间数
WITH c, 付款流水数, 入库单数, 有效付款时间数, 有效入库时间数,
     CASE
       WHEN 付款流水数 = 0 AND 入库单数 = 0 THEN '合同无付款流水且无入库记录'
       WHEN 付款流水数 = 0                  THEN '合同无付款流水'
       WHEN 入库单数 = 0                    THEN '合同无入库记录'
       WHEN 有效付款时间数 = 0              THEN '付款时间缺失'
       WHEN 有效入库时间数 = 0              THEN '入库时间缺失'
       ELSE '可判定'
     END AS 待核查原因
WHERE 待核查原因 <> '可判定'
RETURN c.contract_code     AS 合同编号,
       c.contract_name     AS 合同名称,
       c.payment_direction AS 合同方向,
       付款流水数, 入库单数, 有效付款时间数, 有效入库时间数,
       待核查原因
ORDER BY 待核查原因, 合同编号;


// =============================================================================
// 五、变体 C：按收付方向过滤的严格口径（只认 付款 方向的流水）
// -----------------------------------------------------------------------------
// 合同收款/付款 边不分方向，退款/代收等 收款 流水会把"最早付款时间"提前，
// 造成误报（见第六节 P4）。本变体只把 trade_dir ∈ ['付款','支出','支付']
// 的流水计入付款时间；其余口径与主查询一致。
// trade_dir 取值因来源系统而异（02 号初始化数据用 '支出'，MOCK12 用 '付款'），
// 生产按实际取值调整集合。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE c.payment_direction IN ['采购', '付款']
  AND s <> g
WITH DISTINCT g, s, c
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WHERE trim(coalesce(f.trade_dir, '')) IN ['付款', '支出', '支付']
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}
WITH g, s, c, fMin, rkMin,
     CASE WHEN fMin IS NULL
               OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL
               OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay
RETURN DISTINCT
       g.org_name          AS 国电投企业,
       s.org_name          AS 采购合同相对方,
       c.contract_code     AS 合同编号,
       c.payment_direction AS 合同方向,
       dPay                AS 最早付款日期,
       dIn                 AS 最早入库日期,
       fMin.bill_num       AS 付款流水单号,
       fMin.trade_dir      AS 收付方向,
       rkMin.mblnr         AS 最早入库单号,
       '最早入库时间晚于最早付款时间（仅付款方向流水）' AS 命中规则
ORDER BY 合同编号;


// =============================================================================
// 六、自包含验证数据（MOCK15_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 主查询正例（应命中，入库晚于付款）:
//   P1  两条付款（最早 05-10）+ 两张入库单（最早 06-01，仅 R1B 挂物料）
//       → 取最早比较：06-01 > 05-10 命中；物料证据只有 M14-100001
//   P2  三条付款（最早 03-05）+ 两张入库单（最早 04-01，均挂 M14-100002）
//       → 多流水/多入库取最早；03-05 < 04-01 命中
//   P4  有收款流水（退款 01-05）+ 付款流水（07-01）+ 入库（最早 06-01）
//       → 主查询按全部流水口径命中（01-05 < 06-01），
//         变体 C 只认付款方向（07-01 > 06-01）不命中 —— 两口径差异演示
// 主查询反例（不应命中）:
//   N1  入库（最早 03-01）早于付款（05-10）→ 正常到货后付款，不报
//       （多张入库取最早 03-01，若误取最晚会得到 04-15 仍不命中，但最早口径校验见断言 5）
//   N2  同日：付款 04-10 14:00，入库 04-10 18:30（入库时点晚于付款时点）
//       → 按自然日粒度相等，不报（口径 4）
//   N3  有付款流水、无入库记录 → 不报（待核查）
//   N4  有入库单、无付款流水 → 不报（待核查）
//   N5  有付款流水、入库单 budat 为空串 → 不报（待核查）
//   N6  销售合同（payment_direction='销售'）同形态 → 方向过滤，全口径均不报
//   N7  无付款流水且无入库记录 → 不报（待核查）
//   N8  付款流水 TRANS_TIME 为空串、有入库 → 不报（待核查）
// 变体用例:
//   P3  外部-外部合同（无国电投企业参与），入库 07-01 > 付款 06-05
//       → 仅全库版（变体 A）命中
// =============================================================================

// ---- 6.1 企业 ----
MERGE (g:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
  ON CREATE SET g.org_name='MOCK15_国电投企业A', g.flag_gdtqy='是',
                g.org_credit_code='91310112MOCK1400A',
                g.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
  ON CREATE SET s1.org_name='MOCK15_合同相对方1', s1.flag_gdtqy='否',
                s1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP2'})
  ON CREATE SET s2.org_name='MOCK15_合同相对方2', s2.flag_gdtqy='否',
                s2.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP3'})
  ON CREATE SET s3.org_name='MOCK15_外部签约方甲', s3.flag_gdtqy='否',
                s3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP4'})
  ON CREATE SET s4.org_name='MOCK15_外部签约方乙', s4.flag_gdtqy='否',
                s4.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s5:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP5'})
  ON CREATE SET s5.org_name='MOCK15_合同相对方3', s5.flag_gdtqy='否',
                s5.schema_name='dws_dsjsj_zstp_vertex_qy';

// ---- 6.2 合同 ----
MERGE (p1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
  ON CREATE SET p1.contract_code='MOCK15_HT_P1', p1.contract_name='MOCK15_采购合同P1',
                p1.payment_direction='采购', p1.sign_time='2024-03-01',
                p1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
  ON CREATE SET p2.contract_code='MOCK15_HT_P2', p2.contract_name='MOCK15_采购合同P2',
                p2.payment_direction='采购', p2.sign_time='2024-02-15',
                p2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P3'})
  ON CREATE SET p3.contract_code='MOCK15_HT_P3', p3.contract_name='MOCK15_外部合同P3',
                p3.payment_direction='采购', p3.sign_time='2024-05-01',
                p3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
  ON CREATE SET p4.contract_code='MOCK15_HT_P4', p4.contract_name='MOCK15_采购合同P4_含退款',
                p4.payment_direction='采购', p4.sign_time='2024-01-01',
                p4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
  ON CREATE SET n1.contract_code='MOCK15_HT_N1', n1.contract_name='MOCK15_反例1_先货后款',
                n1.payment_direction='采购', n1.sign_time='2024-02-01',
                n1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N2'})
  ON CREATE SET n2.contract_code='MOCK15_HT_N2', n2.contract_name='MOCK15_反例2_同日款货',
                n2.payment_direction='采购', n2.sign_time='2024-03-15',
                n2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N3'})
  ON CREATE SET n3.contract_code='MOCK15_HT_N3', n3.contract_name='MOCK15_反例3_无入库',
                n3.payment_direction='采购', n3.sign_time='2024-04-01',
                n3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N4'})
  ON CREATE SET n4.contract_code='MOCK15_HT_N4', n4.contract_name='MOCK15_反例4_无付款',
                n4.payment_direction='采购', n4.sign_time='2024-04-02',
                n4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n5:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N5'})
  ON CREATE SET n5.contract_code='MOCK15_HT_N5', n5.contract_name='MOCK15_反例5_入库时间空',
                n5.payment_direction='采购', n5.sign_time='2024-04-03',
                n5.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n6:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N6'})
  ON CREATE SET n6.contract_code='MOCK15_HT_N6', n6.contract_name='MOCK15_反例6_销售合同',
                n6.payment_direction='销售', n6.sign_time='2024-01-20',
                n6.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n7:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N7'})
  ON CREATE SET n7.contract_code='MOCK15_HT_N7', n7.contract_name='MOCK15_反例7_无付款无入库',
                n7.payment_direction='采购', n7.sign_time='2024-04-04',
                n7.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n8:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N8'})
  ON CREATE SET n8.contract_code='MOCK15_HT_N8', n8.contract_name='MOCK15_反例8_付款时间空',
                n8.payment_direction='采购', n8.sign_time='2024-04-05',
                n8.schema_name='dws_dsjsj_zstp_vertex_ht';

// ---- 6.3 物料 ----
MERGE (m1:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK15_WL_M1'})
  ON CREATE SET m1.matnr='M14-100001', m1.maktx='高压开关柜',
                m1.sourcesystem='ERP', m1.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (m2:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK15_WL_M2'})
  ON CREATE SET m2.matnr='M14-100002', m2.maktx='电力电缆',
                m2.sourcesystem='ERP', m2.schema_name='dws_dsjsj_zstp_vertex_wl';

// ---- 6.4 资金流水 ----
// P1：最早付款 2024-05-10
MERGE (f1a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F1A'})
  ON CREATE SET f1a.bill_num='MOCK15_BL_P1A', f1a.tran_amt=100000.00, f1a.trade_dir='付款',
                f1a.TRANS_TIME=datetime('2024-05-10T10:00:00'),
                f1a.SUMMARY='MOCK15_P1 第一笔采购付款', f1a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f1b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F1B'})
  ON CREATE SET f1b.bill_num='MOCK15_BL_P1B', f1b.tran_amt=50000.00, f1b.trade_dir='付款',
                f1b.TRANS_TIME=datetime('2024-05-25T09:00:00'),
                f1b.SUMMARY='MOCK15_P1 第二笔采购付款', f1b.schema_name='dws_dsjsj_zstp_vertex_zjls';
// P2：最早付款 2024-03-05（刻意让最早一笔不是最先 MERGE 的一条）
MERGE (f2c:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F2C'})
  ON CREATE SET f2c.bill_num='MOCK15_BL_P2C', f2c.tran_amt=70000.00, f2c.trade_dir='付款',
                f2c.TRANS_TIME=datetime('2024-04-10T11:00:00'),
                f2c.SUMMARY='MOCK15_P2 第三笔采购付款', f2c.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f2a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F2A'})
  ON CREATE SET f2a.bill_num='MOCK15_BL_P2A', f2a.tran_amt=200000.00, f2a.trade_dir='付款',
                f2a.TRANS_TIME=datetime('2024-03-05T09:30:00'),
                f2a.SUMMARY='MOCK15_P2 预付货款', f2a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f2b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F2B'})
  ON CREATE SET f2b.bill_num='MOCK15_BL_P2B', f2b.tran_amt=150000.00, f2b.trade_dir='付款',
                f2b.TRANS_TIME=datetime('2024-03-20T14:20:00'),
                f2b.SUMMARY='MOCK15_P2 第二笔采购付款', f2b.schema_name='dws_dsjsj_zstp_vertex_zjls';
// P3：付款 2024-06-05
MERGE (f3:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F3'})
  ON CREATE SET f3.bill_num='MOCK15_BL_P3', f3.tran_amt=120000.00, f3.trade_dir='付款',
                f3.TRANS_TIME=datetime('2024-06-05T10:00:00'),
                f3.SUMMARY='MOCK15_P3 外部合同付款', f3.schema_name='dws_dsjsj_zstp_vertex_zjls';
// P4：收款（退款）2024-01-05 + 付款 2024-07-01
MERGE (f4a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F4A'})
  ON CREATE SET f4a.bill_num='MOCK15_BL_P4A', f4a.tran_amt=20000.00, f4a.trade_dir='收款',
                f4a.TRANS_TIME=datetime('2024-01-05T10:00:00'),
                f4a.SUMMARY='MOCK15_P4 退款（收款方向）', f4a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f4b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F4B'})
  ON CREATE SET f4b.bill_num='MOCK15_BL_P4B', f4b.tran_amt=80000.00, f4b.trade_dir='付款',
                f4b.TRANS_TIME=datetime('2024-07-01T10:00:00'),
                f4b.SUMMARY='MOCK15_P4 采购付款', f4b.schema_name='dws_dsjsj_zstp_vertex_zjls';
// N1：付款 2024-05-10 / 2024-05-30
MERGE (fn1a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N1A'})
  ON CREATE SET fn1a.bill_num='MOCK15_BL_N1A', fn1a.tran_amt=90000.00, fn1a.trade_dir='付款',
                fn1a.TRANS_TIME=datetime('2024-05-10T10:00:00'),
                fn1a.SUMMARY='MOCK15_N1 到货后付款', fn1a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fn1b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N1B'})
  ON CREATE SET fn1b.bill_num='MOCK15_BL_N1B', fn1b.tran_amt=30000.00, fn1b.trade_dir='付款',
                fn1b.TRANS_TIME=datetime('2024-05-30T10:00:00'),
                fn1b.SUMMARY='MOCK15_N1 尾款', fn1b.schema_name='dws_dsjsj_zstp_vertex_zjls';
// N2：付款 2024-04-10 14:00（与入库同日）
MERGE (fn2:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N2'})
  ON CREATE SET fn2.bill_num='MOCK15_BL_N2', fn2.tran_amt=60000.00, fn2.trade_dir='付款',
                fn2.TRANS_TIME=datetime('2024-04-10T14:00:00'),
                fn2.SUMMARY='MOCK15_N2 同日付款', fn2.schema_name='dws_dsjsj_zstp_vertex_zjls';
// N3：有付款、无入库
MERGE (fn3:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N3'})
  ON CREATE SET fn3.bill_num='MOCK15_BL_N3', fn3.tran_amt=45000.00, fn3.trade_dir='付款',
                fn3.TRANS_TIME=datetime('2024-05-01T10:00:00'),
                fn3.SUMMARY='MOCK15_N3 付款但无入库', fn3.schema_name='dws_dsjsj_zstp_vertex_zjls';
// N5：付款正常
MERGE (fn5:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N5'})
  ON CREATE SET fn5.bill_num='MOCK15_BL_N5', fn5.tran_amt=35000.00, fn5.trade_dir='付款',
                fn5.TRANS_TIME=datetime('2024-05-01T10:00:00'),
                fn5.SUMMARY='MOCK15_N5 付款', fn5.schema_name='dws_dsjsj_zstp_vertex_zjls';
// N6：销售合同收款
MERGE (fn6:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N6'})
  ON CREATE SET fn6.bill_num='MOCK15_BL_N6', fn6.tran_amt=250000.00, fn6.trade_dir='收款',
                fn6.TRANS_TIME=datetime('2024-02-01T10:00:00'),
                fn6.SUMMARY='MOCK15_N6 销售预收款', fn6.schema_name='dws_dsjsj_zstp_vertex_zjls';
// N8：付款流水 TRANS_TIME 为空串
MERGE (fn8:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N8'})
  ON CREATE SET fn8.bill_num='MOCK15_BL_N8', fn8.tran_amt=55000.00, fn8.trade_dir='付款',
                fn8.TRANS_TIME='', fn8.SUMMARY='MOCK15_N8 交易时间缺失',
                fn8.schema_name='dws_dsjsj_zstp_vertex_zjls';

// ---- 6.5 入库 ----
// P1：最早入库 2024-06-01（R1A 不挂物料，R1B 挂 M14-100001）
MERGE (r1a:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R1A'})
  ON CREATE SET r1a.mblnr='MOCK15_RK_P1A', r1a.menge='10',
                r1a.budat=datetime('2024-06-01T00:00:00'),
                r1a.umlgo='MOCK15_中心库', r1a.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (r1b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R1B'})
  ON CREATE SET r1b.mblnr='MOCK15_RK_P1B', r1b.menge='5',
                r1b.budat=datetime('2024-06-20T00:00:00'),
                r1b.umlgo='MOCK15_中心库', r1b.schema_name='dws_dsjsj_zstp_vertex_rk';
// P2：最早入库 2024-04-01（均挂 M14-100002）
MERGE (r2b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R2B'})
  ON CREATE SET r2b.mblnr='MOCK15_RK_P2B', r2b.menge='800',
                r2b.budat=datetime('2024-04-25T00:00:00'),
                r2b.umlgo='MOCK15_中心库', r2b.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (r2a:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R2A'})
  ON CREATE SET r2a.mblnr='MOCK15_RK_P2A', r2a.menge='1200',
                r2a.budat=datetime('2024-04-01T08:00:00'),
                r2a.umlgo='MOCK15_中心库', r2a.schema_name='dws_dsjsj_zstp_vertex_rk';
// P3：入库 2024-07-01
MERGE (r3:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R3'})
  ON CREATE SET r3.mblnr='MOCK15_RK_P3', r3.menge='30',
                r3.budat=datetime('2024-07-01T00:00:00'),
                r3.umlgo='MOCK15_外部仓', r3.schema_name='dws_dsjsj_zstp_vertex_rk';
// P4：入库 2024-06-01 / 2024-06-15
MERGE (r4a:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R4A'})
  ON CREATE SET r4a.mblnr='MOCK15_RK_P4A', r4a.menge='40',
                r4a.budat=datetime('2024-06-01T00:00:00'),
                r4a.umlgo='MOCK15_中心库', r4a.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (r4b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R4B'})
  ON CREATE SET r4b.mblnr='MOCK15_RK_P4B', r4b.menge='20',
                r4b.budat=datetime('2024-06-15T00:00:00'),
                r4b.umlgo='MOCK15_中心库', r4b.schema_name='dws_dsjsj_zstp_vertex_rk';
// N1：入库 2024-03-01 / 2024-04-15（均早于付款）
MERGE (rn1a:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N1A'})
  ON CREATE SET rn1a.mblnr='MOCK15_RK_N1A', rn1a.menge='60',
                rn1a.budat=datetime('2024-03-01T00:00:00'),
                rn1a.umlgo='MOCK15_中心库', rn1a.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (rn1b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N1B'})
  ON CREATE SET rn1b.mblnr='MOCK15_RK_N1B', rn1b.menge='40',
                rn1b.budat=datetime('2024-04-15T00:00:00'),
                rn1b.umlgo='MOCK15_中心库', rn1b.schema_name='dws_dsjsj_zstp_vertex_rk';
// N2：入库与付款同日（时点更晚：18:30）
MERGE (rn2:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N2'})
  ON CREATE SET rn2.mblnr='MOCK15_RK_N2', rn2.menge='15',
                rn2.budat=datetime('2024-04-10T18:30:00'),
                rn2.umlgo='MOCK15_中心库', rn2.schema_name='dws_dsjsj_zstp_vertex_rk';
// N4：有入库、无付款
MERGE (rn4:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N4'})
  ON CREATE SET rn4.mblnr='MOCK15_RK_N4', rn4.menge='25',
                rn4.budat=datetime('2024-05-20T00:00:00'),
                rn4.umlgo='MOCK15_中心库', rn4.schema_name='dws_dsjsj_zstp_vertex_rk';
// N5：入库单 budat 为空串
MERGE (rn5:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N5'})
  ON CREATE SET rn5.mblnr='MOCK15_RK_N5', rn5.menge='18',
                rn5.budat='', rn5.umlgo='MOCK15_中心库',
                rn5.schema_name='dws_dsjsj_zstp_vertex_rk';
// N6：销售合同下挂入库（若不过滤方向本应命中）
MERGE (rn6:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N6'})
  ON CREATE SET rn6.mblnr='MOCK15_RK_N6', rn6.menge='5',
                rn6.budat=datetime('2024-03-01T00:00:00'),
                rn6.umlgo='MOCK15_中心库', rn6.schema_name='dws_dsjsj_zstp_vertex_rk';
// N8：入库 2024-05-01（付款时间缺失）
MERGE (rn8:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N8'})
  ON CREATE SET rn8.mblnr='MOCK15_RK_N8', rn8.menge='22',
                rn8.budat=datetime('2024-05-01T00:00:00'),
                rn8.umlgo='MOCK15_中心库', rn8.schema_name='dws_dsjsj_zstp_vertex_rk';

// ---- 6.6 边：签订合同（企业 → 合同，MATCH 端点 + MERGE 关系，幂等）----
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_P1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_P1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_P2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S2_P2'}]->(b);
// P3：外部-外部签约，国电投不参与
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S3_P3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S4_P3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_P4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S2_P4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_N1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_N2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_N3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S5_N4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_N5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N6'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N6'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N6'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S5_N6'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N7'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N7'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N7'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_N7'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N8'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_G_N8'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK15_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N8'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK15_E_QD_S1_N8'}]->(b);

// ---- 6.7 边：合同收款/付款（合同 → 资金流水）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F1A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P1A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P1B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F2C'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P2C'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F4A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P4A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_F4B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_P4B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N1A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N1A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N1B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N3'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N5'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N6'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N8'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK15_ZJLS_N8'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK15_E_SKFK_N8'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';

// ---- 6.8 边：按采购合同入库（合同 → 入库）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R1A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P1A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P1B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R4A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P4A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R4B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_P4B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N1A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N1A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N1B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N5'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N6'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK15_HT_N8'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_N8'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK15_E_AC_N8'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';

// ---- 6.9 边：领用物料（物料 → 入库，入库标的证据，可缺失）----
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK15_WL_M1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R1A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK15_E_LYWL_M1_R1A'}]->(b)
  ON CREATE SET r.name1='MOCK15_高压开关柜', r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK15_WL_M1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK15_E_LYWL_M1_R1B'}]->(b)
  ON CREATE SET r.name1='MOCK15_高压开关柜', r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK15_WL_M2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK15_E_LYWL_M2_R2A'}]->(b)
  ON CREATE SET r.name1='MOCK15_电力电缆', r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK15_WL_M2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK15_RK_R2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK15_E_LYWL_M2_R2B'}]->(b)
  ON CREATE SET r.name1='MOCK15_电力电缆', r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';


// =============================================================================
// 七、断言校验（先跑第六节灌数据，再跑本节，应全部 PASS）
// =============================================================================

// 断言 1：主查询恰好命中 3 条正例，且最早付款/入库日期正确
//         P1 -> 付款 2024-05-10 / 入库 2024-06-01
//         P2 -> 付款 2024-03-05 / 入库 2024-04-01
//         P4 -> 付款 2024-01-05（收款流水口径）/ 入库 2024-06-01
//         隐含排除：N1/N2/N5/N6/N8 不在主查询命中内，P3 未锚定国电投不命中
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE c.payment_direction IN ['采购', '付款'] AND s <> g
WITH DISTINCT g, s, c
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}
WITH c, fMin, rkMin,
     CASE WHEN fMin IS NULL OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay
WITH collect(c.contract_code + '|' + toString(dPay) + '|' + toString(dIn)) AS 命中,
     ['MOCK15_HT_P1|2024-05-10|2024-06-01',
      'MOCK15_HT_P2|2024-03-05|2024-04-01',
      'MOCK15_HT_P4|2024-01-05|2024-06-01'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言1_主查询3条正例且日期正确;

// 断言 2：待核查恰好 5 条：N3/N4/N5/N7/N8，原因正确
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款']
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
WITH c,
     count(DISTINCT f)  AS 付款流水数,
     count(DISTINCT rk) AS 入库单数,
     count(DISTINCT CASE WHEN f IS NOT NULL AND f.TRANS_TIME IS NOT NULL
                   AND trim(toString(f.TRANS_TIME)) <> ''
                   AND toString(f.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
              THEN f END) AS 有效付款时间数,
     count(DISTINCT CASE WHEN rk IS NOT NULL AND rk.budat IS NOT NULL
                   AND trim(toString(rk.budat)) <> ''
                   AND toString(rk.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
              THEN rk END) AS 有效入库时间数
WITH c, 付款流水数, 入库单数, 有效付款时间数, 有效入库时间数,
     CASE
       WHEN 付款流水数 = 0 AND 入库单数 = 0 THEN '合同无付款流水且无入库记录'
       WHEN 付款流水数 = 0                  THEN '合同无付款流水'
       WHEN 入库单数 = 0                    THEN '合同无入库记录'
       WHEN 有效付款时间数 = 0              THEN '付款时间缺失'
       WHEN 有效入库时间数 = 0              THEN '入库时间缺失'
       ELSE '可判定'
     END AS 待核查原因
WHERE 待核查原因 <> '可判定'
WITH collect(DISTINCT c.contract_code + '|' + 待核查原因) AS 待核查,
     ['MOCK15_HT_N3|合同无入库记录',
      'MOCK15_HT_N4|合同无付款流水',
      'MOCK15_HT_N5|入库时间缺失',
      'MOCK15_HT_N7|合同无付款流水且无入库记录',
      'MOCK15_HT_N8|付款时间缺失'] AS 期望
RETURN CASE WHEN size(待核查) = size(期望) AND all(x IN 期望 WHERE x IN 待核查)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 待核查 | a + v + '; ') END
       AS 断言2_待核查5条且原因正确;

// 断言 3：全库版（变体 A）在 MOCK15_ 内命中 4 条：P1/P2/P3/P4
//         P3 仅全库版命中（外部-外部合同）；N6 销售合同方向过滤仍不命中
MATCH (c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款']
  AND c.contract_code STARTS WITH 'MOCK15_'
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}
WITH c, fMin, rkMin,
     CASE WHEN fMin IS NULL OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay
WITH collect(DISTINCT c.contract_code) AS 命中,
     ['MOCK15_HT_P1', 'MOCK15_HT_P2', 'MOCK15_HT_P3', 'MOCK15_HT_P4'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言3_全库版含外部外部合同P3;

// 断言 4：变体 C（仅付款方向流水）恰好命中 2 条：P1/P2；P4 被剔除
//         （P4 最早"付款"方向的流水 2024-07-01 晚于最早入库 2024-06-01）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款']
  AND c.contract_code STARTS WITH 'MOCK15_'
WITH DISTINCT g, c
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WHERE trim(coalesce(f.trade_dir, '')) IN ['付款', '支出', '支付']
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}
WITH c, fMin, rkMin,
     CASE WHEN fMin IS NULL OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay
WITH collect(DISTINCT c.contract_code) AS 命中,
     ['MOCK15_HT_P1', 'MOCK15_HT_P2'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言4_付款方向口径仅P1P2;

// 断言 5：物料证据正确 + "取最早"口径正确
//         P1 挂 M14-100001（只有 R1B 挂物料，R1A 无）；P2 挂 M14-100002；P4 无物料
//         P2 最早入库必须是 2024-04-01（R2A），最早付款必须是 2024-03-05（F2A）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91310112MOCK1400A'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE c.payment_direction IN ['采购', '付款'] AND s <> g
WITH DISTINCT g, s, c
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
    WITH c, f
    ORDER BY f.TRANS_TIME ASC, f.object_key ASC
    WITH c, head(collect(f)) AS fMin
    RETURN fMin
}
CALL {
    WITH c
    OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
    WITH c, rk
    ORDER BY rk.budat ASC, rk.object_key ASC
    WITH c, head(collect(rk)) AS rkMin
    RETURN rkMin
}
WITH c, fMin, rkMin,
     CASE WHEN fMin IS NULL OR fMin.TRANS_TIME IS NULL
               OR trim(toString(fMin.TRANS_TIME)) = ''
               OR NOT toString(fMin.TRANS_TIME) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(fMin.TRANS_TIME), 10)) END AS dPay,
     CASE WHEN rkMin IS NULL OR rkMin.budat IS NULL
               OR trim(toString(rkMin.budat)) = ''
               OR NOT toString(rkMin.budat) =~ '\\d{4}-\\d{2}-\\d{2}.*'
          THEN NULL ELSE date(left(toString(rkMin.budat), 10)) END AS dIn
WHERE dPay IS NOT NULL AND dIn IS NOT NULL AND dIn > dPay
OPTIONAL MATCH (m:dws_dsjsj_zstp_vertex_wl)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rkMin)
WITH c.contract_code AS 合同, dPay, dIn, collect(DISTINCT m.matnr) AS 物料编码
WITH collect(合同 + '=' + reduce(a = '', v IN 物料编码 | a + v + ',')) AS 物料命中,
     collect(合同 + '|' + toString(dPay) + '|' + toString(dIn)) AS 日期命中,
     ['MOCK15_HT_P1=M14-100001,',
      'MOCK15_HT_P2=M14-100002,',
      'MOCK15_HT_P4='] AS 期望物料
WITH 物料命中, 日期命中, 期望物料,
     all(x IN 期望物料 WHERE x IN 物料命中)
     AND size(物料命中) = size(期望物料) AS 物料OK,
     'MOCK15_HT_P2|2024-03-05|2024-04-01' IN 日期命中 AS 取最早OK
RETURN CASE WHEN 物料OK AND 取最早OK THEN 'PASS'
            ELSE 'FAIL: 物料=' + reduce(a = '', v IN 物料命中 | a + v + '; ')
                 + ' 日期=' + reduce(a = '', v IN 日期命中 | a + v + '; ') END
       AS 断言5_物料证据与取最早口径;


// =============================================================================
// 八、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK15_' DETACH DELETE n;
