// =============================================================================
// 24 SPIC-CW-0106-03 有悖于交易常识的异常交易 · (1) 销售/采购合同有流水无出/入库记录
// -----------------------------------------------------------------------------
// 对应流程图（国电投企业A 居中）:
//
//   (合同相对方 s)-[:签订合同]->(合同 c)<-[:签订合同]-(国电投企业A g)
//   (c)-[:合同收款/付款]->(资金流水 f)              ← 有资金流水往来
//   (c)-[:按采购合同入库]->(入库)  ← 采购合同本应有多少条入库记录
//   (c)-[:按销售合同出库]->(出库)  ← 销售合同本应有多少条出库记录
//
//   采购合同: 有流水 但 入库记录缺失   ⇒ 命中「采购合同有流水无入库记录」
//   销售合同: 有流水 但 出库记录缺失   ⇒ 命中「销售合同有流水无出库记录」
//
// 规则原文：销售/采购合同有流水无出/入库记录——有资金流水往来，但出库或入库记录缺失。
//
// 口径:
//   1. 以国电投企业 g 签订的合同 c 为入口；全库口径见第三节变体 A。
//   2. 合同必须有 合同收款/付款 流水（MATCH 硬匹配），流水数 = 0 不属于本规则。
//   3. 采购/销售由 合同.payment_direction 区分（与 18 号文件口径一致）:
//        '采购' / '付款' ⇒ 采购合同，查 按采购合同入库
//        '销售' / '收款' ⇒ 销售合同，查 按销售合同出库
//   4. 缺失判定按"合同维度聚合"：入库数/出库数为 0 才算缺失；
//      反方向单据不能抵扣（销售合同只有入库、采购合同只有出库 仍命中，见 P5）。
//   5. OPTIONAL MATCH 后 count(DISTINCT ...) 聚合，天然去重，无笛卡尔积误计数。
//   6. payment_direction 缺失或取值未知时无法确定该查入库还是出库，
//      不判命中，另见第四节变体 B（待核查）与第五节变体 C（按流水方向推断）。
//   7. 同标的关联合同上有出入库的，多为"单据挂错合同"，见第六节变体 D 旁证版。
//
// 标签对照（生产原始 schema 名，与 16/17/18/22 号文件一致）:
//   dws_dsjsj_zstp_vertex_qy=企业        dws_dsjsj_zstp_vertex_ht=合同
//   dws_dsjsj_zstp_vertex_zjls=资金流水  dws_dsjsj_zstp_vertex_rk=入库
//   dws_dsjsj_zstp_vertex_ck=出库
//   dws_dsjsj_zstp_edge_qy_qd=签订合同
//   dws_dsjsj_zstp_edge_ht_skfk=合同收款/付款
//   dws_dsjsj_zstp_edge_ht_acghtrk=按采购合同入库
//   dws_dsjsj_zstp_edge_ht_axshtck=按销售合同出库
//   dws_dsjsj_zstp_edge_ht_tybdwgl=同一标的物关联_合同
// =============================================================================


// =============================================================================
// 一、主查询：国电投企业合同 有流水 但 缺入库(采购)/缺出库(销售)
//    返回 3 段路径（签约 + 相对方签约 + 收款/付款），逐笔流水展示
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位；全库扫描见第三节变体 A）
//    本文件锚点 913402003950014021 为 MOCK16 专用演示代码（与 22 号文件
//    MOCK12、23 号 0106-02 文件 MOCK14_、25 号文件 MOCK15_ 的锚点各自隔离，
//    多套模拟数据可共存互不干扰）；生产使用时替换为
//    国电投企业的真实统一社会信用代码即可。
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'

// 1. g 签订的合同，方向必须可判定（缺失/未知口径见变体 B）
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']

// 2. 合同必须有资金流水（规则前提：有资金流水往来）
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)

// 3. 该合同名下的入库/出库单（可能为 0 条；反方向单据也一并统计用于展示）
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH g, c, f,
     count(DISTINCT rk) AS 入库数,
     count(DISTINCT ck) AS 出库数

// 4. 缺失判定：采购合同入库数=0 / 销售合同出库数=0（反方向单据不抵扣）
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )

// 5. 还原 3 段路径（相对方取除 g 外的签约企业）
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pF = (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f)
OPTIONAL MATCH pP = (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE s <> g
WITH pC, pP, pF, g, c, f, s, 入库数, 出库数,
     CASE WHEN c.payment_direction IN ['采购', '付款']
          THEN '采购合同有流水无入库记录'
          ELSE '销售合同有流水无出库记录'
     END AS 命中规则
RETURN DISTINCT pC, pP, pF,
       g.org_name            AS 国电投企业,
       c.contract_code       AS 合同编号,
       c.contract_name       AS 合同名称,
       c.payment_direction   AS 合同方向,
       入库数,
       出库数,
       s.org_name            AS 合同相对方,
       f.bill_num            AS 资金流水单号,
       f.tran_amt            AS 交易金额,
       f.trade_dir           AS 收付方向,
       f.TRANS_TIME          AS 交易时间,
       命中规则;


// =============================================================================
// 二、明细输出版（合同级汇总，一合同一行，不返回路径）：替换主查询第 5 步
// =============================================================================
// WITH g, c,
//      count(DISTINCT f)  AS 流水数,
//      count(DISTINCT rk) AS 入库数,
//      count(DISTINCT ck) AS 出库数
// //  ——第 4 步 WHERE 之后，先补相对方再汇总——
// OPTIONAL MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
// WHERE s <> g
// RETURN DISTINCT
//        g.org_name          AS 国电投企业,
//        c.contract_code     AS 合同编号,
//        c.contract_name     AS 合同名称,
//        c.payment_direction AS 合同方向,
//        流水数, 入库数, 出库数,
//        collect(DISTINCT s.org_name)  AS 合同相对方,
//        CASE WHEN c.payment_direction IN ['采购','付款']
//             THEN '采购合同有流水无入库记录'
//             ELSE '销售合同有流水无出库记录'
//        END AS 命中规则
// ORDER BY 合同编号;


// =============================================================================
// 三、变体 A：全库版（不锚定国电投企业，任意合同只要签约方存在即纳入）
// -----------------------------------------------------------------------------
// 用于全量扫描/离线核查；生产可按合同签订时间、金额、组织再叠加过滤。
// =============================================================================
MATCH (c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c, f, count(DISTINCT rk) AS 入库数, count(DISTINCT ck) AS 出库数
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )
OPTIONAL MATCH (s:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WITH c, f, 入库数, 出库数, collect(DISTINCT s.org_name) AS 签约企业
RETURN DISTINCT
       c.contract_code     AS 合同编号,
       c.contract_name     AS 合同名称,
       c.payment_direction AS 合同方向,
       签约企业,
       入库数,
       出库数,
       f.bill_num          AS 资金流水单号,
       f.trade_dir         AS 收付方向,
       f.TRANS_TIME        AS 交易时间,
       CASE WHEN c.payment_direction IN ['采购', '付款']
            THEN '采购合同有流水无入库记录'
            ELSE '销售合同有流水无出库记录'
       END AS 命中规则
ORDER BY 合同编号, 资金流水单号;


// =============================================================================
// 四、变体 B：无法判定 / 待核查（合同方向缺失或取值未知，不知道该查入库还是出库）
// -----------------------------------------------------------------------------
// 输出两类：
//   合同方向缺失        —— payment_direction 为 NULL/空串
//   合同方向未知        —— payment_direction 不在 采购/付款/销售/收款 四值内
// 说明：只列"有流水"的合同（本规则前提）；方向补齐后转入主查询口径判定。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE NOT trim(coalesce(c.payment_direction, '')) IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c,
     count(DISTINCT f)  AS 流水数,
     count(DISTINCT rk) AS 入库数,
     count(DISTINCT ck) AS 出库数
RETURN c.contract_code AS 合同编号,
       c.contract_name AS 合同名称,
       流水数, 入库数, 出库数,
       CASE WHEN trim(coalesce(c.payment_direction, '')) = ''
            THEN '合同方向缺失'
            ELSE '合同方向未知(' + c.payment_direction + ')'
       END AS 待核查原因
ORDER BY 待核查原因, 合同编号;


// =============================================================================
// 五、变体 C：方向缺失时按流水收付方向推断（payment_direction 为空串/NULL 才适用）
// -----------------------------------------------------------------------------
// 推断规则：合同全部流水 trade_dir = '收款' ⇒ 按销售合同查 出库
//           合同全部流水 trade_dir = '付款' ⇒ 按采购合同查 入库
//           收付方向混合或缺失               ⇒ 不推断，转待核查
// 注意：payment_direction 为"非空未知值"（如 '服务'）不推断，保守留待人工核查。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE trim(coalesce(c.payment_direction, '')) = ''
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c,
     collect(DISTINCT f.trade_dir) AS 收付方向列表,
     count(DISTINCT f)             AS 流水数,
     count(DISTINCT rk)            AS 入库数,
     count(DISTINCT ck)            AS 出库数
WITH c, 收付方向列表, 流水数, 入库数, 出库数,
     [d IN 收付方向列表 WHERE trim(coalesce(d, '')) <> '' AND d IN ['收款', '付款']] AS 有效方向
WITH c, 收付方向列表, 流水数, 入库数, 出库数, 有效方向,
     CASE
       WHEN size(有效方向) = 0 OR size(有效方向) <> size(收付方向列表)
         THEN '流水收付方向缺失或异常，无法推断'
       WHEN 有效方向 = ['收款'] AND 出库数 = 0
         THEN '销售合同有流水无出库记录（按流水方向推断）'
       WHEN 有效方向 = ['付款'] AND 入库数 = 0
         THEN '采购合同有流水无入库记录（按流水方向推断）'
       WHEN 有效方向 = ['收款'] AND 出库数 > 0
         THEN '推断为销售，出库记录齐全（未命中）'
       WHEN 有效方向 = ['付款'] AND 入库数 > 0
         THEN '推断为采购，入库记录齐全（未命中）'
       ELSE '流水收付方向混合，无法推断'
     END AS 判定结果
RETURN c.contract_code AS 合同编号,
       c.contract_name AS 合同名称,
       流水数, 入库数, 出库数,
       收付方向列表,
       判定结果
ORDER BY 判定结果, 合同编号;


// =============================================================================
// 六、变体 D：同标的关联合同旁证（出入库可能挂在关联合同上 → 提示"单据挂错合同"）
// -----------------------------------------------------------------------------
// 在主查询命中结果上叠加：命中合同 c 经 同一标的物关联_合同（无向）连到 c2，
// 且 c2 名下有本方向应有的出入库单 ⇒ 很可能是实物单据挂错了合同，而非完全无货。
// 有旁证的命中优先核查合同-单据归属；无旁证的命中（主查询已返回）才是纯缺失。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH g, c, count(DISTINCT rk) AS 入库数, count(DISTINCT ck) AS 出库数
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )

// 同标的关联合同 c2 名下有本方向应有的出入库单（旁证）
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(c2:dws_dsjsj_zstp_vertex_ht)
WHERE c2 <> c
  AND ( (c.payment_direction IN ['采购', '付款']
         AND EXISTS { (c2)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(:dws_dsjsj_zstp_vertex_rk) })
    OR  (c.payment_direction IN ['销售', '收款']
         AND EXISTS { (c2)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(:dws_dsjsj_zstp_vertex_ck) }) )
WITH g, c, 入库数, 出库数,
     collect(DISTINCT c2.contract_code) AS 同标的关联合同
WHERE size(同标的关联合同) > 0
RETURN DISTINCT
       g.org_name          AS 国电投企业,
       c.contract_code     AS 合同编号,
       c.contract_name     AS 合同名称,
       c.payment_direction AS 合同方向,
       入库数, 出库数,
       同标的关联合同,
       CASE WHEN c.payment_direction IN ['采购', '付款']
            THEN '采购合同有流水无入库记录'
            ELSE '销售合同有流水无出库记录'
       END + '，同标的关联合同有对应出入库单（疑似单据挂错合同）' AS 命中规则
ORDER BY 合同编号;


// =============================================================================
// 七、自包含验证数据（MOCK16_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 注：本节用 MERGE + 无条件 SET（而非家族惯用的 MERGE + ON CREATE SET）：
//     若库中已有同名前缀的旧版模拟数据（如结构改版后），重复执行会刷新属性，
//     避免旧属性残留导致断言失败。模拟结构改版后建议先执行第九节清理。
// -----------------------------------------------------------------------------
// 主查询正例（应命中）:
//   P1  采购合同('采购')，1 条付款流水，无入库            → 采购有流水无入库
//   P2  销售合同('销售')，2 条收款流水，无出库            → 销售有流水无出库
//   P3  采购合同('付款' 别名值)，1 条流水，无入库         → 采购有流水无入库
//   P5  销售合同，有 1 条入库（反方向单据）但无出库       → 销售有流水无出库
//       （反方向入库不能抵扣出库缺失）
//   D1  采购合同，1 条付款流水，无入库；同标的关联合同 D1B
//       上有入库                                          → 主查询命中，
//                                                         → 变体 D 旁证命中
//   C1  合同方向缺失，全部流水 '收款'，无出库             → 主查询不命中，
//                                                         → 变体 B 待核查(方向缺失)，
//                                                         → 变体 C 推断命中(销售)
//   C2  合同方向缺失，全部流水 '付款'，无入库             → 主查询不命中，
//                                                         → 变体 B 待核查(方向缺失)，
//                                                         → 变体 C 推断命中(采购)
//   P4  外部-外部销售合同（国电投不参与），有流水无出库   → 仅全库版(变体 A)命中
// 主查询反例（不应命中）:
//   N1  采购合同，有流水且有入库                          → 记录齐全，不报
//   N2  销售合同，有流水且有出库                          → 记录齐全，不报
//   N3  采购合同，无任何流水（有入库）                    → 无流水，不属于本规则
//   N4  合同方向缺失，流水有收有付（混合）                → 变体 B 待核查，
//                                                         → 变体 C 不推断
//   N6  合同方向未知('服务')，1 条付款流水，无入库        → 变体 B 待核查，
//                                                         → 变体 C 不适用
// =============================================================================

// ---- 7.1 企业 ----
MERGE (g:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
  SET g.org_name='MOCK16_国电投企业A', g.flag_gdtqy='是',
                g.org_credit_code='913402003950014021',
                g.schema_name='dws_dsjsj_zstp_vertex_qy';
// 注意：模拟企业信用代码独立于 MOCK12（'91340200395000999X'）、
//       MOCK14_（0106-02 文件）、MOCK15_（25 号文件），
//       避免多个模拟数据集共存时按信用代码锚定的查询互相串数据。
MERGE (s1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
  SET s1.org_name='MOCK16_合同相对方1', s1.flag_gdtqy='否',
                s1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP2'})
  SET s2.org_name='MOCK16_合同相对方2', s2.flag_gdtqy='否',
                s2.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP3'})
  SET s3.org_name='MOCK16_外部签约方甲', s3.flag_gdtqy='否',
                s3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP4'})
  SET s4.org_name='MOCK16_外部签约方乙', s4.flag_gdtqy='否',
                s4.schema_name='dws_dsjsj_zstp_vertex_qy';

// ---- 7.2 合同 ----
MERGE (p1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P1'})
  SET p1.contract_code='MOCK16_HT_P1', p1.contract_name='MOCK16_采购合同P1',
                p1.payment_direction='采购', p1.sign_time='2024-03-01',
                p1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P2'})
  SET p2.contract_code='MOCK16_HT_P2', p2.contract_name='MOCK16_销售合同P2',
                p2.payment_direction='销售', p2.sign_time='2024-04-01',
                p2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P3'})
  SET p3.contract_code='MOCK16_HT_P3', p3.contract_name='MOCK16_采购合同P3',
                p3.payment_direction='付款', p3.sign_time='2024-05-01',
                p3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P4'})
  SET p4.contract_code='MOCK16_HT_P4', p4.contract_name='MOCK16_外部销售合同P4',
                p4.payment_direction='销售', p4.sign_time='2024-06-01',
                p4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p5:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P5'})
  SET p5.contract_code='MOCK16_HT_P5', p5.contract_name='MOCK16_销售合同P5_仅有入库',
                p5.payment_direction='销售', p5.sign_time='2024-07-01',
                p5.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (d1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1'})
  SET d1.contract_code='MOCK16_HT_D1', d1.contract_name='MOCK16_采购合同D1_同标的旁证',
                d1.payment_direction='采购', d1.sign_time='2024-08-01',
                d1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (d1b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1B'})
  SET d1b.contract_code='MOCK16_HT_D1B', d1b.contract_name='MOCK16_采购合同D1B_同标的',
                d1b.payment_direction='采购', d1b.sign_time='2024-08-05',
                d1b.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C1'})
  SET c1.contract_code='MOCK16_HT_C1', c1.contract_name='MOCK16_方向缺失合同C1_全收款',
                c1.payment_direction='', c1.sign_time='2024-09-01',
                c1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (c2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C2'})
  SET c2.contract_code='MOCK16_HT_C2', c2.contract_name='MOCK16_方向缺失合同C2_全付款',
                c2.payment_direction='', c2.sign_time='2024-09-02',
                c2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N1'})
  SET n1.contract_code='MOCK16_HT_N1', n1.contract_name='MOCK16_反例1_采购记录齐全',
                n1.payment_direction='采购', n1.sign_time='2024-10-01',
                n1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N2'})
  SET n2.contract_code='MOCK16_HT_N2', n2.contract_name='MOCK16_反例2_销售记录齐全',
                n2.payment_direction='销售', n2.sign_time='2024-10-02',
                n2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N3'})
  SET n3.contract_code='MOCK16_HT_N3', n3.contract_name='MOCK16_反例3_无流水',
                n3.payment_direction='采购', n3.sign_time='2024-10-03',
                n3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N4'})
  SET n4.contract_code='MOCK16_HT_N4', n4.contract_name='MOCK16_反例4_方向缺失且收付混合',
                n4.payment_direction='', n4.sign_time='2024-10-04',
                n4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n6:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N6'})
  SET n6.contract_code='MOCK16_HT_N6', n6.contract_name='MOCK16_反例6_方向未知服务',
                n6.payment_direction='服务', n6.sign_time='2024-10-06',
                n6.schema_name='dws_dsjsj_zstp_vertex_ht';

// ---- 7.3 入库 / 出库 ----
MERGE (r1:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_R1'})
  SET r1.mblnr='MOCK16_MB_R1', r1.menge=100.0, r1.budat='2024-04-10',
                r1.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (r3:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_R3'})
  SET r3.mblnr='MOCK16_MB_R3', r3.menge=50.0, r3.budat='2024-06-10',
                r3.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (r5:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_R5'})
  SET r5.mblnr='MOCK16_MB_R5', r5.menge=30.0, r5.budat='2024-07-20',
                r5.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (rd1b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_RD1B'})
  SET rd1b.mblnr='MOCK16_MB_RD1B', rd1b.menge=200.0, rd1b.budat='2024-08-20',
                rd1b.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (ck2:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK16_CK_C2'})
  SET ck2.vbeln='MOCK16_VB_C2', ck2.wadat_ist='2024-11-10',
                ck2.schema_name='dws_dsjsj_zstp_vertex_ck';

// ---- 7.4 资金流水 ----
MERGE (f1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P1'})
  SET f1.bill_num='MOCK16_BL_P1', f1.tran_amt=100000.00, f1.trade_dir='付款',
                f1.TRANS_TIME='2024-03-20', f1.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f2a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P2A'})
  SET f2a.bill_num='MOCK16_BL_P2A', f2a.tran_amt=200000.00, f2a.trade_dir='收款',
                f2a.TRANS_TIME='2024-04-15', f2a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f2b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P2B'})
  SET f2b.bill_num='MOCK16_BL_P2B', f2b.tran_amt=300000.00, f2b.trade_dir='收款',
                f2b.TRANS_TIME='2024-04-25', f2b.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f3:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P3'})
  SET f3.bill_num='MOCK16_BL_P3', f3.tran_amt=150000.00, f3.trade_dir='付款',
                f3.TRANS_TIME='2024-05-20', f3.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f4:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P4'})
  SET f4.bill_num='MOCK16_BL_P4', f4.tran_amt=80000.00, f4.trade_dir='收款',
                f4.TRANS_TIME='2024-06-20', f4.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f5:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P5'})
  SET f5.bill_num='MOCK16_BL_P5', f5.tran_amt=60000.00, f5.trade_dir='收款',
                f5.TRANS_TIME='2024-07-15', f5.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fd1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_D1'})
  SET fd1.bill_num='MOCK16_BL_D1', fd1.tran_amt=900000.00, fd1.trade_dir='付款',
                fd1.TRANS_TIME='2024-08-15', fd1.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fc1a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_C1A'})
  SET fc1a.bill_num='MOCK16_BL_C1A', fc1a.tran_amt=70000.00, fc1a.trade_dir='收款',
                fc1a.TRANS_TIME='2024-09-10', fc1a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fc1b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_C1B'})
  SET fc1b.bill_num='MOCK16_BL_C1B', fc1b.tran_amt=75000.00, fc1b.trade_dir='收款',
                fc1b.TRANS_TIME='2024-09-11', fc1b.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fc2:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_C2'})
  SET fc2.bill_num='MOCK16_BL_C2', fc2.tran_amt=120000.00, fc2.trade_dir='付款',
                fc2.TRANS_TIME='2024-09-20', fc2.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fn1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N1'})
  SET fn1.bill_num='MOCK16_BL_N1', fn1.tran_amt=110000.00, fn1.trade_dir='付款',
                fn1.TRANS_TIME='2024-10-15', fn1.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fn2:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N2'})
  SET fn2.bill_num='MOCK16_BL_N2', fn2.tran_amt=130000.00, fn2.trade_dir='收款',
                fn2.TRANS_TIME='2024-10-16', fn2.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fn4a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N4A'})
  SET fn4a.bill_num='MOCK16_BL_N4A', fn4a.tran_amt=140000.00, fn4a.trade_dir='收款',
                fn4a.TRANS_TIME='2024-10-20', fn4a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fn4b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N4B'})
  SET fn4b.bill_num='MOCK16_BL_N4B', fn4b.tran_amt=150000.00, fn4b.trade_dir='付款',
                fn4b.TRANS_TIME='2024-10-21', fn4b.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fn6:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N6'})
  SET fn6.bill_num='MOCK16_BL_N6', fn6.tran_amt=160000.00, fn6.trade_dir='付款',
                fn6.TRANS_TIME='2024-10-25', fn6.schema_name='dws_dsjsj_zstp_vertex_zjls';

// ---- 7.5 边：签订合同（企业 → 合同，MATCH 端点 + MERGE 关系，幂等）----
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_P1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_P1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_P2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S2_P2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_P3'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_P3'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// P4：外部-外部签约，国电投不参与
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S3_P4'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S4_P4'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_P5'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S2_P5'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_D1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_D1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_D1B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_D1B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_C1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S2_C1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_C2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_C2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_N1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_N1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_N2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S2_N2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_N3'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_N3'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_N4'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S2_N4'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_G_N6'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK16_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK16_E_QD_S1_N6'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';

// ---- 7.6 边：合同收款/付款（合同 → 资金流水，N3 刻意不建）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_P1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_P2A'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_P2B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_P3'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_P4'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P5'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_P5'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_D1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_D1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_C1A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_C1A'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_C1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_C1B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_C2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_C2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_C2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_N1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_N2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N4A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_N4A'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N4B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_N4B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N6'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK16_ZJLS_N6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK16_E_SKFK_N6'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';

// ---- 7.7 边：按采购合同入库（合同 → 入库）----
// P1/P2/P3/D1/C1/C2 刻意不建（缺失）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_R1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK16_E_RK_N1'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N3'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_R3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK16_E_RK_N3'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
// P5：销售合同挂着入库（反方向单据，不能抵扣出库缺失）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_P5'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_R5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK16_E_RK_P5'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
// D1B：同标的关联合同上有入库（D1 的旁证）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1B'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK16_RK_RD1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK16_E_RK_D1B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';

// ---- 7.8 边：按销售合同出库（合同 → 出库）----
// 仅 N2 有出库；P2/P4/P5/C1 刻意不建（缺失）
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK16_CK_C2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK16_E_CK_N2'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';

// ---- 7.9 边：同一标的物关联_合同（合同 → 合同，D1 → D1B 旁证用）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK16_HT_D1B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_tybdwgl {object_key:'MOCK16_E_TYBD_D1_D1B'}]->(b)
  SET r.schema_name='dws_dsjsj_zstp_edge_ht_tybdwgl';


// =============================================================================
// 八、断言校验（先跑第七节灌数据，再跑本节，应全部 PASS）
// =============================================================================

// 断言 1：主查询恰好命中 5 份合同，且命中类型正确
//         P1/P3/D1 → 采购有流水无入库；P2/P5 → 销售有流水无出库
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c, count(DISTINCT rk) AS 入库数, count(DISTINCT ck) AS 出库数
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )
WITH collect(DISTINCT c.contract_code + '|' +
     CASE WHEN c.payment_direction IN ['采购', '付款']
          THEN '采购合同有流水无入库记录'
          ELSE '销售合同有流水无出库记录' END) AS 命中,
     ['MOCK16_HT_P1|采购合同有流水无入库记录',
      'MOCK16_HT_P2|销售合同有流水无出库记录',
      'MOCK16_HT_P3|采购合同有流水无入库记录',
      'MOCK16_HT_P5|销售合同有流水无出库记录',
      'MOCK16_HT_D1|采购合同有流水无入库记录'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言1_主查询命中5份合同且类型正确;

// 断言 2：主查询不误报（N1/N2/N3 记录齐全或无流水；C1/C2/N4 方向缺失不在主查询范围）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c, count(DISTINCT rk) AS 入库数, count(DISTINCT ck) AS 出库数
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )
WITH collect(DISTINCT c.contract_code) AS 命中
RETURN CASE WHEN none(x IN 命中 WHERE x IN
       ['MOCK16_HT_N1', 'MOCK16_HT_N2', 'MOCK16_HT_N3'])
            THEN 'PASS'
            ELSE 'FAIL: 误报 ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言2_反例N1N2N3不误报;

// 断言 3：全库版（变体 A）在 MOCK16_ 内命中 6 份合同：P1/P2/P3/P5/D1 + 外部-外部 P4
MATCH (c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']
  AND c.contract_code STARTS WITH 'MOCK16_'
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c, count(DISTINCT rk) AS 入库数, count(DISTINCT ck) AS 出库数
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )
WITH collect(DISTINCT c.contract_code) AS 命中,
     ['MOCK16_HT_P1', 'MOCK16_HT_P2', 'MOCK16_HT_P3',
      'MOCK16_HT_P4', 'MOCK16_HT_P5', 'MOCK16_HT_D1'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言3_全库版6份含外部外部合同P4;

// 断言 4：待核查（变体 B）恰好 4 条：
//         N4 方向缺失、C1/C2 方向缺失（虽可由变体 C 推断，但方向未补录前仍在待核查清单）、
//         N6 方向未知(服务)
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE NOT trim(coalesce(c.payment_direction, '')) IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH c,
     CASE WHEN trim(coalesce(c.payment_direction, '')) = ''
          THEN '合同方向缺失'
          ELSE '合同方向未知(' + c.payment_direction + ')'
     END AS 待核查原因
WITH collect(DISTINCT c.contract_code + '|' + 待核查原因) AS 待核查,
     ['MOCK16_HT_N4|合同方向缺失',
      'MOCK16_HT_C1|合同方向缺失',
      'MOCK16_HT_C2|合同方向缺失',
      'MOCK16_HT_N6|合同方向未知(服务)'] AS 期望
RETURN CASE WHEN size(待核查) = size(期望) AND all(x IN 期望 WHERE x IN 待核查)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 待核查 | a + v + '; ') END
       AS 断言4_待核查N4N6且原因正确;

// 断言 5：方向缺失推断（变体 C）：
//         C1 全收款无出库 → 推断销售命中；C2 全付款无入库 → 推断采购命中；
//         N4 收付混合 → 无法推断；N6 方向未知值 → 不适用（不出现）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE trim(coalesce(c.payment_direction, '')) = ''
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c,
     collect(DISTINCT f.trade_dir) AS 收付方向列表,
     count(DISTINCT rk)            AS 入库数,
     count(DISTINCT ck)            AS 出库数
WITH c, 收付方向列表, 入库数, 出库数,
     [d IN 收付方向列表 WHERE trim(coalesce(d, '')) <> '' AND d IN ['收款', '付款']] AS 有效方向
WITH c,
     CASE
       WHEN size(有效方向) = 0 OR size(有效方向) <> size(收付方向列表)
         THEN '流水收付方向缺失或异常，无法推断'
       WHEN 有效方向 = ['收款'] AND 出库数 = 0
         THEN '销售合同有流水无出库记录（按流水方向推断）'
       WHEN 有效方向 = ['付款'] AND 入库数 = 0
         THEN '采购合同有流水无入库记录（按流水方向推断）'
       WHEN 有效方向 = ['收款'] AND 出库数 > 0
         THEN '推断为销售，出库记录齐全（未命中）'
       WHEN 有效方向 = ['付款'] AND 入库数 > 0
         THEN '推断为采购，入库记录齐全（未命中）'
       ELSE '流水收付方向混合，无法推断'
     END AS 判定结果
WITH collect(DISTINCT c.contract_code + '|' + 判定结果) AS 推断,
     ['MOCK16_HT_C1|销售合同有流水无出库记录（按流水方向推断）',
      'MOCK16_HT_C2|采购合同有流水无入库记录（按流水方向推断）',
      'MOCK16_HT_N4|流水收付方向混合，无法推断'] AS 期望
RETURN CASE WHEN size(推断) = size(期望) AND all(x IN 期望 WHERE x IN 推断)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 推断 | a + v + '; ') END
       AS 断言5_推断版C1C2命中N4混合不推断;

// 断言 6：同标的旁证（变体 D）仅命中 D1，旁证合同为 D1B
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '913402003950014021'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
WHERE c.payment_direction IN ['采购', '付款', '销售', '收款']
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
WITH c, count(DISTINCT rk) AS 入库数, count(DISTINCT ck) AS 出库数
WHERE ( (c.payment_direction IN ['采购', '付款']) AND 入库数 = 0 )
   OR ( (c.payment_direction IN ['销售', '收款']) AND 出库数 = 0 )
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_tybdwgl]-(c2:dws_dsjsj_zstp_vertex_ht)
WHERE c2 <> c
  AND ( (c.payment_direction IN ['采购', '付款']
         AND EXISTS { (c2)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(:dws_dsjsj_zstp_vertex_rk) })
    OR  (c.payment_direction IN ['销售', '收款']
         AND EXISTS { (c2)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(:dws_dsjsj_zstp_vertex_ck) }) )
WITH c, collect(DISTINCT c2.contract_code) AS 同标的关联合同
WHERE size(同标的关联合同) > 0
WITH collect(DISTINCT c.contract_code + '|' + 同标的关联合同[0]) AS 命中,
     ['MOCK16_HT_D1|MOCK16_HT_D1B'] AS 期望
RETURN CASE WHEN 命中 = 期望
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言6_同标的旁证仅命中D1;


// =============================================================================
// 九、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK16_' DETACH DELETE n;
