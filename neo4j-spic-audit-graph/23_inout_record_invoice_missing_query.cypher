// =============================================================================
// 23 SPIC-CW-0106-02 有悖于交易常识的异常交易 · (1) 有出入库记录但发票缺失
// -----------------------------------------------------------------------------
// 对应流程图（国电投企业A 居中，一份主体同时签销售合同与采购合同）:
//
//   (销售合同相对方 s)-[:签订合同]->(销售合同 cS)<-[:签订合同]-(国电投企业A g)
//   (cS)-[:按销售合同出库]->(出库 ck)<-[:消耗物料]-(物料 m)
//
//   (国电投企业A g)-[:签订合同]->(采购合同 cB)<-[:签订合同]-(采购合同相对方 sB)
//   (cB)-[:按采购合同入库]->(入库 rk)<-[:领用物料]-(物料 m)
//
//   发票链路（发票挂在资金流水上，不直接挂合同/企业）:
//   (合同 c)-[:合同收款/付款]->(资金流水 f)<-[:依据发票收款/付款]-(发票 fp)
//
//   判定: 合同有 出库 或 入库 任一物流记录，
//         而沿 合同收款/付款 → 资金流水 ← 依据发票收款/付款 找不到任何发票
//     ⇒ 命中: 有出库记录或入库记录，但发票记录缺失
//
// 规则原文：有出库记录或入库记录，但发票记录缺失。
//
// 口径:
//   1. 以国电投企业 g 签订的合同 c 为入口（同一 g 既签销售合同又签采购合同，
//      与流程图一致）；销售合同看出库（按销售合同出库）、采购合同看入库
//      （按采购合同入库），任一物流记录存在即纳入；全库口径见第三节变体 A。
//      两条 UNION 分支按物流边类型天然区分方向，不依赖 payment_direction 属性。
//   2. "发票记录缺失"采用合同级口径：沿 (c)-[:合同收款/付款]->(:资金流水)
//      <-[:依据发票收款/付款]-(:发票) 找不到任何发票 ⇒ 缺失。
//      发票经由资金流水间接挂到合同，天然不受别家合同、别家企业发票影响
//      （MOCK14 用例 P5 演示：发票挂在第三方合同 X 的流水上，本合同仍判缺失）。
//   3. 两类情形都算缺失，主查询一并命中：
//        a) 合同无任何收付款资金流水；
//        b) 合同有资金流水，但流水均未关联发票（依据发票收款/付款 边缺失）。
//      第三节变体 B 将两类细分，便于核查时区分"货到了钱票全无"与
//      "钱到了票没开"两种情节轻重不同的场景。
//   4. 领用物料 / 消耗物料 边仅用于还原物流路径（与 17 号文件方向一致：
//      物料 → 入库 / 物料 → 出库），不参与判定。
//   5. 出入库时间与开票时间背离（票货时间差）不在本规则（1）范围。
//
// 标签对照（生产原始 schema 名，与 16/17/24 号文件一致）:
//   dws_dsjsj_zstp_vertex_qy=企业  _ht=合同  _wl=物料  _rk=入库
//   _ck=出库  _fp=发票  _zjls=资金流水
//   dws_dsjsj_zstp_edge_qy_qd=签订合同
//   dws_dsjsj_zstp_edge_ht_axshtck=按销售合同出库   dws_dsjsj_zstp_edge_ht_acghtrk=按采购合同入库
//   dws_dsjsj_zstp_edge_wl_xhwl=消耗物料(物料→出库) dws_dsjsj_zstp_edge_wl_lywl=领用物料(物料→入库)
//   dws_dsjsj_zstp_edge_ht_skfk=合同收款/付款(合同→资金流水)
//   dws_dsjsj_zstp_edge_fp_yjfpskfk=依据发票收款/付款(发票→资金流水)
// =============================================================================


// =============================================================================
// 一、主查询：国电投企业合同有出入库记录、合同级发票缺失 ⇒ 命中
//    销售出库 / 采购入库两条 UNION 分支，各返回 4 段路径
//    （签约 + 相对方签约 + 物流 + 物料）
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位；全库扫描见第三节变体 A）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395001499X'})
WHERE g.flag_gdtqy = '是'

// 1. g 与相对方 s 签订的销售合同，且合同有出库记录（消耗同一物料）
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE s <> g
MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
      <-[:dws_dsjsj_zstp_edge_wl_xhwl]-(m:dws_dsjsj_zstp_vertex_wl)

// 2. 发票缺失：沿 合同收款/付款 → 资金流水 ← 依据发票收款/付款 找不到任何发票
WHERE NOT EXISTS {
    MATCH (cS)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
          <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp)
  }

// 3. 还原 4 段路径
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH pP = (s)-[:dws_dsjsj_zstp_edge_qy_qd]->(cS)
MATCH pW = (cS)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck)
MATCH pM = (m)-[:dws_dsjsj_zstp_edge_wl_xhwl]->(ck)
RETURN DISTINCT pC, pP, pW, pM,
       g.org_name            AS 国电投企业,
       s.org_name            AS 合同相对方,
       cS.contract_code      AS 合同编号,
       cS.contract_name      AS 合同名称,
       cS.payment_direction  AS 合同方向,
       ck.vbeln              AS 物流单号,
       '出库'                AS 物流类型,
       ck.wadat_ist          AS 物流日期,
       m.matnr               AS 物料编码,
       '有出库记录但发票记录缺失' AS 命中规则

UNION
// —— 采购入库分支：结构对称，物流边与物料边换成入库侧 ——
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395001499X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE s <> g
MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
      <-[:dws_dsjsj_zstp_edge_wl_lywl]-(m:dws_dsjsj_zstp_vertex_wl)
WHERE NOT EXISTS {
    MATCH (cB)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
          <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp)
  }
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB)
MATCH pP = (s)-[:dws_dsjsj_zstp_edge_qy_qd]->(cB)
MATCH pW = (cB)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk)
MATCH pM = (m)-[:dws_dsjsj_zstp_edge_wl_lywl]->(rk)
RETURN DISTINCT pC, pP, pW, pM,
       g.org_name            AS 国电投企业,
       s.org_name            AS 合同相对方,
       cB.contract_code      AS 合同编号,
       cB.contract_name      AS 合同名称,
       cB.payment_direction  AS 合同方向,
       rk.mblnr              AS 物流单号,
       '入库'                AS 物流类型,
       rk.budat              AS 物流日期,
       m.matnr               AS 物料编码,
       '有入库记录但发票记录缺失' AS 命中规则;


// =============================================================================
// 二、明细输出版（核查字段，不返回路径）：替换主查询第 3 步的 MATCH/RETURN
// =============================================================================
// RETURN DISTINCT
//        g.org_name           AS 国电投企业,
//        s.org_name           AS 合同相对方,
//        cS.contract_code     AS 合同编号, cS.contract_name AS 合同名称,
//        cS.payment_direction AS 合同方向,
//        ck.vbeln             AS 出库单号, ck.wadat_ist AS 出库日期,
//        m.matnr              AS 物料编码, m.maktx AS 物料名称,
//        '有出库记录但发票记录缺失' AS 命中规则
// （采购分支对应列: cB/rk/m 与 rk.mblnr AS 入库单号, rk.budat AS 入库日期）


// =============================================================================
// 三、变体 A：全库版（不锚定国电投企业，任意合同只要有签约方即纳入）
// -----------------------------------------------------------------------------
// 用于全量扫描/离线核查；生产可按合同签订时间、金额、组织再叠加过滤。
// =============================================================================
MATCH (c:dws_dsjsj_zstp_vertex_ht)<-[:dws_dsjsj_zstp_edge_qy_qd]-(x:dws_dsjsj_zstp_vertex_qy)
WITH c, collect(DISTINCT x) AS 签约方
WHERE size(签约方) >= 1
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
// 注意：发票缺失判定放在聚合后的 WHERE（WITH 的 WHERE 是行过滤器）。
// 不能挂在 OPTIONAL MATCH 上——OPTIONAL MATCH 的 WHERE 失败只会把本步
// 引入的变量置 NULL、行保留，前一步已匹配的 ck 原样保留，已挂票的
// 出库合同（如 N1）会漏过单号非空检查而被误报。
WITH c, 签约方, collect(DISTINCT ck.vbeln) AS 出库单号, collect(DISTINCT rk.mblnr) AS 入库单号
WHERE size(出库单号) + size(入库单号) > 0
  AND NOT EXISTS {
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
          <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp)
  }
RETURN DISTINCT
       c.contract_code       AS 合同编号,
       c.contract_name       AS 合同名称,
       c.payment_direction   AS 合同方向,
       [p IN 签约方 | p.org_name] AS 签约企业,
       出库单号,
       入库单号,
       CASE WHEN size(出库单号) = 0 THEN '有入库记录但发票记录缺失'
            ELSE '有出库记录但发票记录缺失' END AS 命中规则
ORDER BY 合同编号;


// =============================================================================
// 四、变体 B：缺失情形细分版（无资金流水 / 有流水未挂发票）
// -----------------------------------------------------------------------------
// 主查询把两类情形一并命中；本变体进一步区分，便于核查定性：
//   合同无收付款资金流水 —— 货到了（出入库），钱和票全无，情节更重；
//   资金流水未关联发票   —— 钱到了（有流水），但没开票，可能是开票滞后或故意不开。
// 已挂发票的合同输出"发票齐全"并在 WHERE 中排除。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE g.flag_gdtqy = '是' AND g <> s
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH g, s, c, ck, rk, f
WHERE ck IS NOT NULL OR rk IS NOT NULL
WITH g, s, c,
     collect(DISTINCT ck.vbeln) AS 出库单号,
     collect(DISTINCT rk.mblnr) AS 入库单号,
     count(DISTINCT f)          AS 流水数,
     EXISTS { MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
                   <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp) } AS 已挂发票
WITH g, s, c, 出库单号, 入库单号, 流水数,
     CASE WHEN 已挂发票          THEN '发票齐全'
          WHEN 流水数 = 0        THEN '合同无收付款资金流水'
          ELSE                        '资金流水未关联发票' END AS 缺失情形
WHERE 缺失情形 <> '发票齐全'
RETURN g.org_name             AS 国电投企业,
       s.org_name             AS 合同相对方,
       c.contract_code        AS 合同编号,
       c.contract_name        AS 合同名称,
       c.payment_direction    AS 合同方向,
       出库单号,
       入库单号,
       流水数,
       缺失情形
ORDER BY 合同编号;


// =============================================================================
// 五、自包含验证数据（MOCK14_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 单一国电投主体 MOCK14_QY_GDT（对应流程图居中的 国电投企业A），
// 同一主体既签采购合同又签销售合同；发票为合同级口径，无需多实例隔离。
//
// 主查询正例（应命中，合同级发票缺失）:
//   P1  采购合同 + 入库记录，无任何资金流水            → 命中（入库分支，无流水）
//   P2  销售合同 + 出库记录，无任何资金流水            → 命中（出库分支，无流水）
//   P3  销售合同 + 两条出库记录，无任何资金流水        → 命中（两条出库各一行）
//   P5  销售合同 + 出库记录，发票挂在第三方合同 X 的流水上 → 仍命中（合同级口径不串票）
//   P6  采购合同 + 入库记录，有资金流水但流水未挂发票  → 命中（入库分支，有流水未挂票）
// 主查询反例（不应命中）:
//   N1  销售合同 + 出库，流水已挂发票（依据发票收款/付款）→ 不命中
//   N2  采购合同 + 入库，流水已挂发票                  → 不命中
//   N3  销售合同，签约但无任何出入库记录               → 不命中（无物流证据）
// 变体用例:
//   P4  外部-外部采购合同 + 入库，无发票               → 仅全库版（变体 A）命中
//   X   第三方合同（无出入库），其流水挂着发票         → 永不命中，仅作 P5 的干扰项
// =============================================================================

// ---- 5.1 企业（单一国电投主体 + 各相对方）----
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
  ON CREATE SET n.org_name='MOCK14_国电投企业A', n.flag_gdtqy='是',
                n.org_credit_code='91340200395001499X', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S1'})
  ON CREATE SET n.org_name='MOCK14_采购相对方1', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2'})
  ON CREATE SET n.org_name='MOCK14_销售相对方2', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S3'})
  ON CREATE SET n.org_name='MOCK14_外部采购方甲', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S4'})
  ON CREATE SET n.org_name='MOCK14_外部销售方乙', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S5'})
  ON CREATE SET n.org_name='MOCK14_销售相对方5', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S6'})
  ON CREATE SET n.org_name='MOCK14_采购相对方6', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2B'})
  ON CREATE SET n.org_name='MOCK14_销售相对方N1', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2C'})
  ON CREATE SET n.org_name='MOCK14_采购相对方N2', n.flag_gdtqy='否', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// ---- 5.2 合同 ----
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P1'})
  ON CREATE SET n.contract_code='MOCK14_HT_P1', n.contract_name='MOCK14_采购合同P1_无流水',
                n.payment_direction='采购', n.contract_amount=1200000.0, n.sign_time='2024-03-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P2'})
  ON CREATE SET n.contract_code='MOCK14_HT_P2', n.contract_name='MOCK14_销售合同P2_无流水',
                n.payment_direction='销售', n.contract_amount=1500000.0, n.sign_time='2024-04-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P3'})
  ON CREATE SET n.contract_code='MOCK14_HT_P3', n.contract_name='MOCK14_销售合同P3_两次出库',
                n.payment_direction='销售', n.contract_amount=900000.0,  n.sign_time='2024-05-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P4'})
  ON CREATE SET n.contract_code='MOCK14_HT_P4', n.contract_name='MOCK14_外部采购合同P4',
                n.payment_direction='采购', n.contract_amount=600000.0,  n.sign_time='2024-06-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P5'})
  ON CREATE SET n.contract_code='MOCK14_HT_P5', n.contract_name='MOCK14_销售合同P5_发票在别家合同',
                n.payment_direction='销售', n.contract_amount=700000.0,  n.sign_time='2024-07-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P6'})
  ON CREATE SET n.contract_code='MOCK14_HT_P6', n.contract_name='MOCK14_采购合同P6_有流水未挂票',
                n.payment_direction='采购', n.contract_amount=980000.0,  n.sign_time='2024-07-15',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N1'})
  ON CREATE SET n.contract_code='MOCK14_HT_N1', n.contract_name='MOCK14_销售合同N1_流水已挂票',
                n.payment_direction='销售', n.contract_amount=800000.0,  n.sign_time='2024-08-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N2'})
  ON CREATE SET n.contract_code='MOCK14_HT_N2', n.contract_name='MOCK14_采购合同N2_流水已挂票',
                n.payment_direction='采购', n.contract_amount=1100000.0, n.sign_time='2024-09-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N3'})
  ON CREATE SET n.contract_code='MOCK14_HT_N3', n.contract_name='MOCK14_销售合同N3_无出入库',
                n.payment_direction='销售', n.contract_amount=500000.0,  n.sign_time='2024-10-01',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_X'})
  ON CREATE SET n.contract_code='MOCK14_HT_X', n.contract_name='MOCK14_第三方合同X_持票干扰项',
                n.payment_direction='销售', n.contract_amount=300000.0,  n.sign_time='2024-07-05',
                n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';

// ---- 5.3 物料 ----
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_1'})
  ON CREATE SET n.matnr='MOCK14-MAT-001', n.maktx='MOCK14_高压电缆YJV22', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_2'})
  ON CREATE SET n.matnr='MOCK14-MAT-002', n.maktx='MOCK14_单晶硅光伏组件', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_3'})
  ON CREATE SET n.matnr='MOCK14-MAT-003', n.maktx='MOCK14_干式变压器', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_4'})
  ON CREATE SET n.matnr='MOCK14-MAT-004', n.maktx='MOCK14_不锈钢无缝管', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_5'})
  ON CREATE SET n.matnr='MOCK14-MAT-005', n.maktx='MOCK14_断路器LW36', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_6'})
  ON CREATE SET n.matnr='MOCK14-MAT-006', n.maktx='MOCK14_开关柜KYN28', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_N1'})
  ON CREATE SET n.matnr='MOCK14-MAT-N01', n.maktx='MOCK14_服务器（N1）', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_N2'})
  ON CREATE SET n.matnr='MOCK14-MAT-N02', n.maktx='MOCK14_燃机备件（N2）', n.sourcesystem='MOCK14', n.schema_name='dws_dsjsj_zstp_vertex_wl';

// ---- 5.4 入库 / 出库 ----
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P1'})
  ON CREATE SET n.mblnr='MOCK14-RK-0301', n.menge='120', n.budat='2024-03-18', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P2'})
  ON CREATE SET n.vbeln='MOCK14-CK-0415', n.meins='PC', n.wadat_ist='2024-04-15', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P3A'})
  ON CREATE SET n.vbeln='MOCK14-CK-0520', n.meins='TAI', n.wadat_ist='2024-05-20', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P3B'})
  ON CREATE SET n.vbeln='MOCK14-CK-0612', n.meins='TAI', n.wadat_ist='2024-06-12', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P4'})
  ON CREATE SET n.mblnr='MOCK14-RK-0625', n.menge='600', n.budat='2024-06-25', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P5'})
  ON CREATE SET n.vbeln='MOCK14-CK-0718', n.meins='TAI', n.wadat_ist='2024-07-18', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P6'})
  ON CREATE SET n.mblnr='MOCK14-RK-0728', n.menge='40', n.budat='2024-07-28', n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_N1'})
  ON CREATE SET n.vbeln='MOCK14-CK-0822', n.meins='PC', n.wadat_ist='2024-08-22', n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_N2'})
  ON CREATE SET n.mblnr='MOCK14-RK-0910', n.menge='12', n.budat='2024-09-10', n.schema_name='dws_dsjsj_zstp_vertex_rk';
// N3 刻意无任何出入库记录；HT_X 刻意无出入库记录

// ---- 5.5 资金流水（仅 P6/N1/N2/X 四份合同有流水）----
MERGE (n:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_P6'})
  ON CREATE SET n.bill_num='MOCK14-BL-P6', n.tran_amt=980000.0, n.trade_dir='付款',
                n.TRANS_TIME='2024-07-25', n.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (n:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_N1'})
  ON CREATE SET n.bill_num='MOCK14-BL-N1', n.tran_amt=800000.0, n.trade_dir='收款',
                n.TRANS_TIME='2024-08-25', n.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (n:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_N2'})
  ON CREATE SET n.bill_num='MOCK14-BL-N2', n.tran_amt=1100000.0, n.trade_dir='付款',
                n.TRANS_TIME='2024-09-12', n.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (n:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_X'})
  ON CREATE SET n.bill_num='MOCK14-BL-X', n.tran_amt=300000.0, n.trade_dir='收款',
                n.TRANS_TIME='2024-07-08', n.schema_name='dws_dsjsj_zstp_vertex_zjls';

// ---- 5.6 发票（仅 N1/N2/X 的流水挂票；正例合同 P1/P2/P3/P5/P6 均无票）----
MERGE (n:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK14_FP_N1'})
  ON CREATE SET n.fp_hm='MOCK14FP0001', n.fplx='增值税专用发票', n.kprq='2024-08-26',
                n.fpje=769911.50, n.fpse=100088.50, n.xmmc='MOCK14_服务器', n.schema_name='dws_dsjsj_zstp_vertex_fp';
MERGE (n:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK14_FP_N2'})
  ON CREATE SET n.fp_hm='MOCK14FP0002', n.fplx='增值税专用发票', n.kprq='2024-09-13',
                n.fpje=973451.33, n.fpse=126548.67, n.xmmc='MOCK14_燃机备件', n.schema_name='dws_dsjsj_zstp_vertex_fp';
MERGE (n:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK14_FP_X'})
  ON CREATE SET n.fp_hm='MOCK14FP00XX', n.fplx='增值税专用发票', n.kprq='2024-07-09',
                n.fpje=283018.87, n.fpse=36981.13, n.xmmc='MOCK14_断路器（第三方合同X）', n.schema_name='dws_dsjsj_zstp_vertex_fp';

// ---- 5.7 边：签订合同（企业 → 合同）----
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_P1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S1_P1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_P2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S2_P2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_P3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S2_P3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// P4：外部-外部签约，国电投不参与
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S3_P4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S4_P4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_P5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S5_P5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_P6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S6'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S6_P6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2B'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S2B_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2C'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S2C_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_G_N3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S2_N3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_X'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S3_X'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK14_QY_S5'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_X'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK14_E_QD_S5_X'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_qy_qd';

// ---- 5.8 边：出入库物流（合同 → 入库/出库，物料 → 入库/出库）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK14_E_CG_RK_P1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_1'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK14_E_LY_RK_P1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK14_E_AX_CK_P2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_2'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK14_E_XH_CK_P2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P3A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK14_E_AX_CK_P3A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_3'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P3A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK14_E_XH_CK_P3A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P3B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK14_E_AX_CK_P3B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_3'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P3B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK14_E_XH_CK_P3B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK14_E_CG_RK_P4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_4'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK14_E_LY_RK_P4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P5'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK14_E_AX_CK_P5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_5'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK14_E_XH_CK_P5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P6'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK14_E_CG_RK_P6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_6'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_P6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK14_E_LY_RK_P6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK14_E_AX_CK_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK14_CK_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK14_E_XH_CK_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK14_E_CG_RK_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK14_WL_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK14_RK_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK14_E_LY_RK_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
// N3、HT_X 刻意不建物流边

// ---- 5.9 边：合同收款/付款（合同 → 资金流水；仅 P6/N1/N2/X 有）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_P6'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_P6'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK14_E_SKFK_P6'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK14_E_SKFK_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK14_E_SKFK_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK14_HT_X'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_X'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK14_E_SKFK_X'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
// P1/P2/P3/P5/P4 刻意无任何资金流水

// ---- 5.10 边：依据发票收款/付款（发票 → 资金流水；仅 N1/N2/X 的流水挂票）----
MATCH (a:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK14_FP_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_fp_yjfpskfk {object_key:'MOCK14_E_YJFP_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_fp_yjfpskfk';
MATCH (a:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK14_FP_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_N2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_fp_yjfpskfk {object_key:'MOCK14_E_YJFP_N2'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_fp_yjfpskfk';
MATCH (a:dws_dsjsj_zstp_vertex_fp {object_key:'MOCK14_FP_X'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK14_ZJLS_X'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_fp_yjfpskfk {object_key:'MOCK14_E_YJFP_X'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_fp_yjfpskfk';
// P6 的流水刻意不挂发票（"资金流水未关联发票"用例）


// =============================================================================
// 六、断言校验（先跑第五节灌数据，再跑本节，应全部 PASS）
// 注意：Neo4j 5.26 中 collect 结果跨 MATCH 携带后再做列表拼接（a + b）会丢失
// 元素类型（reduce 报 Type mismatch: ... but was Boolean），因此断言一律单次
// collect（必要时用关系类型交替 [:出库边|入库边] + 标签判定），不做跨 MATCH
// 列表拼接。
// =============================================================================

// 断言 1：主查询恰好命中 5 份正例合同 P1/P2/P3/P5/P6，不含任何 N*（N1~N3 全部排除）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395001499X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE s <> g
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck|dws_dsjsj_zstp_edge_ht_acghtrk]->(w)
WHERE (w:dws_dsjsj_zstp_vertex_ck OR w:dws_dsjsj_zstp_vertex_rk)
  AND NOT EXISTS {
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
          <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp)
  }
WITH collect(DISTINCT c.contract_code) AS 命中,
     ['MOCK14_HT_P1','MOCK14_HT_P2','MOCK14_HT_P3','MOCK14_HT_P5','MOCK14_HT_P6'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
              AND none(x IN 命中 WHERE x CONTAINS '_N')
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言1_主查询恰命中P1P2P3P5P6且排除全部反例;

// 断言 2：主查询按物流单逐条输出（P3 两条出库各一行），明细共 6 行
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395001499X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE s <> g
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck|dws_dsjsj_zstp_edge_ht_acghtrk]->(w)
WHERE (w:dws_dsjsj_zstp_vertex_ck OR w:dws_dsjsj_zstp_vertex_rk)
  AND NOT EXISTS {
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
          <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp)
  }
WITH collect(DISTINCT coalesce(w.vbeln, w.mblnr)) AS 单明细,
     ['MOCK14-RK-0301','MOCK14-CK-0415','MOCK14-CK-0520','MOCK14-CK-0612','MOCK14-CK-0718','MOCK14-RK-0728'] AS 期望
RETURN CASE WHEN size(单明细) = size(期望) AND all(x IN 期望 WHERE x IN 单明细)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 单明细 | a + v + '; ') END
       AS 断言2_物流单明细共6条含P3两条出库;

// 断言 3：全库版（变体 A）恰好命中 6 份：P1/P2/P3/P4/P5/P6（P4 为外部-外部合同）
MATCH (c:dws_dsjsj_zstp_vertex_ht)<-[:dws_dsjsj_zstp_edge_qy_qd]-(x:dws_dsjsj_zstp_vertex_qy)
WITH c, collect(DISTINCT x) AS 签约方
WHERE size(签约方) >= 1
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
// 发票缺失判定放聚合后的 WHERE（同变体 A 说明，不能挂在 OPTIONAL MATCH 上）
WITH c, collect(DISTINCT ck.vbeln) AS 出库单号, collect(DISTINCT rk.mblnr) AS 入库单号
WHERE size(出库单号) + size(入库单号) > 0
  AND c.contract_code STARTS WITH 'MOCK14_'
  AND NOT EXISTS {
    MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
          <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp)
  }
WITH collect(DISTINCT c.contract_code) AS 命中,
     ['MOCK14_HT_P1','MOCK14_HT_P2','MOCK14_HT_P3','MOCK14_HT_P4','MOCK14_HT_P5','MOCK14_HT_P6'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言3_全库版含外部外部合同P4共6条;

// 断言 4：变体 B（缺失情形细分）5 条缺失说明逐项正确
//         P1/P2/P3/P5 无资金流水；P6 有流水但未挂发票
MATCH (g:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE g.flag_gdtqy = '是' AND g <> s AND c.contract_code STARTS WITH 'MOCK14_'
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH c, ck, rk, f
WHERE ck IS NOT NULL OR rk IS NOT NULL
WITH c,
     count(DISTINCT f) AS 流水数,
     EXISTS { MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
                   <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp) } AS 已挂发票
WITH c,
     CASE WHEN 已挂发票          THEN '发票齐全'
          WHEN 流水数 = 0        THEN '合同无收付款资金流水'
          ELSE                        '资金流水未关联发票' END AS 缺失情形
WHERE 缺失情形 <> '发票齐全'
WITH collect(DISTINCT c.contract_code + '|' + 缺失情形) AS 命中,
     ['MOCK14_HT_P1|合同无收付款资金流水',
      'MOCK14_HT_P2|合同无收付款资金流水',
      'MOCK14_HT_P3|合同无收付款资金流水',
      'MOCK14_HT_P5|合同无收付款资金流水',
      'MOCK14_HT_P6|资金流水未关联发票'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言4_变体B缺失情形5条逐项正确;

// 断言 5：变体 B 排除项——N1/N2（流水已挂票 → 发票齐全被 WHERE 排除）、
//         N3（无出入库）、X（无出入库）、P4（无国电投签约方）均不出现
MATCH (g:dws_dsjsj_zstp_vertex_qy)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
      <-[:dws_dsjsj_zstp_edge_qy_qd]-(s:dws_dsjsj_zstp_vertex_qy)
WHERE g.flag_gdtqy = '是' AND g <> s AND c.contract_code STARTS WITH 'MOCK14_'
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_axshtck]->(ck:dws_dsjsj_zstp_vertex_ck)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_acghtrk]->(rk:dws_dsjsj_zstp_vertex_rk)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
WITH c, ck, rk, f
WHERE ck IS NOT NULL OR rk IS NOT NULL
WITH c,
     count(DISTINCT f) AS 流水数,
     EXISTS { MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(:dws_dsjsj_zstp_vertex_zjls)
                   <-[:dws_dsjsj_zstp_edge_fp_yjfpskfk]-(:dws_dsjsj_zstp_vertex_fp) } AS 已挂发票
WITH c,
     CASE WHEN 已挂发票          THEN '发票齐全'
          WHEN 流水数 = 0        THEN '合同无收付款资金流水'
          ELSE                        '资金流水未关联发票' END AS 缺失情形
WITH collect(c.contract_code + '|' + 缺失情形) AS 全部
RETURN CASE WHEN size(全部) = 7
              AND any(x IN 全部 WHERE x = 'MOCK14_HT_N1|发票齐全')
              AND any(x IN 全部 WHERE x = 'MOCK14_HT_N2|发票齐全')
              AND none(x IN 全部 WHERE x STARTS WITH 'MOCK14_HT_N3|')
              AND none(x IN 全部 WHERE x STARTS WITH 'MOCK14_HT_X|')
              AND none(x IN 全部 WHERE x STARTS WITH 'MOCK14_HT_P4|')
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 全部 | a + v + '; ') END
       AS 断言5_变体B含N1N2发票齐全且排除N3XP4;


// =============================================================================
// 七、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK14_' DETACH DELETE n;
