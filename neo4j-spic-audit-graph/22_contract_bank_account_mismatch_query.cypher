// =============================================================================
// 22 SPIC-CW-0106-01 有悖于交易常识的异常交易 · 实际收付款银行账户与合同约定不一致
// -----------------------------------------------------------------------------
// 对应流程图（国电投企业A 居中）:
//
//   (合同相对方 s)-[:签订合同]->(合同 c)<-[:签订合同]-(国电投企业A g)
//   (c)-[:合同约定银行账户]->(银行账户 ca)          ← 合同里写的收款/付款账号
//   (c)-[:合同收款/付款]->(资金流水 f)-[:资金流水收款/付款账号]->(银行账户 aa)
//                                                  ← 实际收付款账号
//   norm(ca.bank_acc_no) <> norm(aa.bank_acc_no)
//     ⇒ 命中: 实际收付款银行账户与合同约定不一致
//
// 规则原文：合同约定银行账号和实际收款、付款账号不一致。
//
// 口径:
//   1. 以国电投企业 g 签订的合同 c 为入口；全库口径见第三节变体 A。
//   2. 合同约定账户走派生边 合同约定银行账户（合同 → 银行账户），见下方补充建模说明。
//   3. 实际收付款账户走现有链路：
//        合同 -[:合同收款/付款]-> 资金流水 -[:资金流水收款/付款账号]-> 银行账户
//   4. 账号比较前先归一化：去首尾空白、半角/全角空格、半角/全角连字符，转大写。
//      仅格式不同（空格/横线）视为同一账号，不报异常。
//   5. 同一合同有多条流水时，任意一条流水的实际账号与约定账号不同即命中；
//      返回"合同 + 流水 + 实际账户"逐笔明细，便于核查。
//   6. 账号取值优先级：
//        合同侧  ca.bank_acc_no  为空时回落 合同约定银行账户.bank_acc_no（合同快照）
//        实际侧  aa.bank_acc_no  为空时回落 资金流水收款/付款账号.bank_acc_no
//   7. 任一侧账号缺失（NULL/空串）不判定为"不一致"，另见第四节"无法判定/待核查"。
//   8. 若合同按收/付款方向分别约定多个账户（如 收款账户 / 付款账户），需在比对前
//      按 f.trade_dir 过滤约定账户（约定边建议带 trade_dir 属性），否则会把另一
//      方向的账户误判为"不一致"；本文件演示数据为单账户口径。
//
// 补充建模说明（重要）:
//   源表 60 类边中没有 合同 → 银行账户 的约定账户关系，本规则按流程图新增派生边:
//     (:合同)-[:`合同约定银行账户`]->(:银行账户)
//     生产 schema 名: dws_dsjsj_zstp_edge_ht_htydyhzh
//     关系属性     : object_key(主键), from_key, to_key,
//                    bank_acc_no(约定账号快照, 可空), schema_name
//   若生产已有其他落地方式（合同表字段 payee_bank_acc_no、合同附件账户表等），
//   把主查询第 2 步换成对应属性/关系即可，见第五节变体 C。
//   可选 DDL（Neo4j 5.7+，关系属性唯一约束）:
//     CREATE CONSTRAINT rel_ht_htydyhzh_object_key IF NOT EXISTS
//       FOR ()-[r:`合同约定银行账户`]-() REQUIRE r.object_key IS UNIQUE;
//
// 标签对照（生产原始 schema 名，与 16/17/18 号文件一致）:
//   dws_dsjsj_zstp_vertex_qy=企业          dws_dsjsj_zstp_vertex_ht=合同
//   dws_dsjsj_zstp_vertex_zjls=资金流水    dws_dsjsj_zstp_vertex_yhzh=银行账户
//   dws_dsjsj_zstp_edge_qy_qd=签订合同
//   dws_dsjsj_zstp_edge_ht_skfk=合同收款/付款
//   dws_dsjsj_zstp_edge_zjls_zjlsskfkzh=资金流水收款/付款账号
//   dws_dsjsj_zstp_edge_ht_htydyhzh=合同约定银行账户（本文件新增派生边）
//
// 账号归一化（后文多处复用，改变规则时只改这一处口径）:
//   toUpper(replace(replace(replace(replace(trim(x),
//     ' ',''), '　',''), '-',''), '－',''))
// =============================================================================


// =============================================================================
// 一、主查询：国电投企业合同 约定账号 vs 实际收付款账号，不一致即命中
//    返回 5 段路径（签约 + 相对方签约 + 约定账户 + 收款/付款 + 实际账户）
// =============================================================================
// 0. 输入：国电投主体企业（按统一社会信用代码定位；全库扫描见第三节变体 A）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'

// 1. g 签订的合同
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)

// 2. 合同约定银行账户（派生边）
MATCH (c)-[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)

// 3. 合同实际收款/付款流水，以及流水上的实际账号
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
MATCH (f)-[ra:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)

// 4. 两侧账号归一化后比较（仅格式差异不算不一致）
WITH g, c, f, ca, aa, rc, ra,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(ca.bank_acc_no, '')) <> '' THEN ca.bank_acc_no
            ELSE coalesce(rc.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(aa.bank_acc_no, '')) <> '' THEN aa.bank_acc_no
            ELSE coalesce(ra.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号
WHERE 合同账号 <> '' AND 实际账号 <> '' AND 合同账号 <> 实际账号

// 5. 还原 5 段路径
OPTIONAL MATCH pP = (s:dws_dsjsj_zstp_vertex_qy)
                    -[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WHERE s <> g
MATCH pC = (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c)
MATCH pA = (c)-[:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca)
MATCH pF = (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f)
MATCH pR = (f)-[:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa)
RETURN DISTINCT pC, pP, pA, pF, pR,
       g.org_name            AS 国电投企业,
       c.contract_code       AS 合同编号,
       c.contract_name       AS 合同名称,
       c.payment_direction   AS 合同方向,
       合同账号              AS 合同约定账号,
       ca.acc_name           AS 合同约定户名,
       ca.nam_dep_ban        AS 合同约定开户行,
       实际账号              AS 实际收付款账号,
       aa.acc_name           AS 实际收付款户名,
       aa.nam_dep_ban        AS 实际收付款开户行,
       f.bill_num            AS 资金流水单号,
       f.tran_amt            AS 交易金额,
       f.trade_dir           AS 收付方向,
       f.TRANS_TIME          AS 交易时间,
       '实际收付款银行账户与合同约定不一致' AS 命中规则;


// =============================================================================
// 二、明细输出版（核查字段，不返回路径）：替换主查询第 5 步的 MATCH/RETURN
// =============================================================================
// RETURN DISTINCT
//     g.org_name          AS 国电投企业,
//     c.contract_code     AS 合同编号, c.contract_name AS 合同名称,
//     c.payment_direction AS 合同方向,
//     合同账号            AS 合同约定账号,
//     ca.acc_name         AS 合同约定户名, ca.nam_dep_ban AS 合同约定开户行,
//     实际账号            AS 实际收付款账号,
//     aa.acc_name         AS 实际收付款户名, aa.nam_dep_ban AS 实际收付款开户行,
//     f.bill_num          AS 资金流水单号, f.tran_amt AS 交易金额,
//     f.trade_dir         AS 收付方向, f.TRANS_TIME AS 交易时间,
//     '实际收付款银行账户与合同约定不一致' AS 命中规则;


// =============================================================================
// 三、变体 A：全库版（不锚定国电投企业，任意合同只要签约方存在即纳入）
// -----------------------------------------------------------------------------
// 用于全量扫描/离线核查；生产可按合同签订时间、金额、组织再叠加过滤。
// =============================================================================
MATCH (c:dws_dsjsj_zstp_vertex_ht)
      -[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
      -[ra:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH c, ca, aa, f, rc, ra,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(ca.bank_acc_no, '')) <> '' THEN ca.bank_acc_no
            ELSE coalesce(rc.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(aa.bank_acc_no, '')) <> '' THEN aa.bank_acc_no
            ELSE coalesce(ra.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号
WHERE 合同账号 <> '' AND 实际账号 <> '' AND 合同账号 <> 实际账号
OPTIONAL MATCH (s:dws_dsjsj_zstp_vertex_qy)
               -[:dws_dsjsj_zstp_edge_qy_qd]->(c)
WITH c, ca, aa, f, 合同账号, 实际账号,
     collect(DISTINCT s.org_name) AS 签约企业
RETURN DISTINCT
       c.contract_code     AS 合同编号,
       c.payment_direction AS 合同方向,
       签约企业,
       合同账号            AS 合同约定账号,
       实际账号            AS 实际收付款账号,
       f.bill_num          AS 资金流水单号,
       f.trade_dir         AS 收付方向,
       f.TRANS_TIME        AS 交易时间,
       '实际收付款银行账户与合同约定不一致' AS 命中规则
ORDER BY 合同编号, 资金流水单号;


// =============================================================================
// 四、变体 B：无法判定 / 待核查（账号缺失，不能直接判"不一致"也不能放过）
// -----------------------------------------------------------------------------
// 输出四类：
//   合同未约定银行账户      —— 合同侧无 合同约定银行账户 边或账号为空
//   合同无收款/付款流水     —— 有约定账户但没有任何实际流水
//   流水无有效收付款账号    —— 有流水但流水未挂账户或账号为空
// 说明：只要合同至少有一条有效流水账号，就视为"可判定"，由主查询逐笔判断；
//       部分流水缺账号的情形需在生产侧补齐数据后复核。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
OPTIONAL MATCH (c)-[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (f)-[:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH c,
     count(DISTINCT CASE WHEN ca IS NOT NULL
              AND (trim(coalesce(ca.bank_acc_no, '')) <> ''
                   OR trim(coalesce(rc.bank_acc_no, '')) <> '')
            THEN ca END) AS 约定有效账号数,
     count(DISTINCT f)    AS 流水数,
     count(DISTINCT CASE WHEN aa IS NOT NULL
              AND trim(coalesce(aa.bank_acc_no, '')) <> ''
            THEN aa END) AS 实际有效账号数
WITH c, 约定有效账号数, 流水数, 实际有效账号数,
     CASE
       WHEN 约定有效账号数 = 0 AND 流水数 = 0 THEN '合同未约定银行账户且无流水'
       WHEN 约定有效账号数 = 0               THEN '合同未约定银行账户'
       WHEN 流水数 = 0                       THEN '合同无收款/付款流水'
       WHEN 实际有效账号数 = 0               THEN '流水无有效收付款账号'
       ELSE '可判定'
     END AS 待核查原因
WHERE 待核查原因 <> '可判定'
RETURN c.contract_code AS 合同编号,
       c.contract_name AS 合同名称,
       c.payment_direction AS 合同方向,
       约定有效账号数, 流水数, 实际有效账号数,
       待核查原因
ORDER BY 待核查原因, 合同编号;


// =============================================================================
// 五、变体 C：补充口径（账号相同但户名不同 / 合同账户以属性承载）
// -----------------------------------------------------------------------------
// C1. 账号一致、户名不一致：作为"账号一致"的补充风险提示（非本规则主口径）。
//     若生产把合同约定账号直接放在合同属性上，把 C1 的
//       (c)-[:合同约定银行账户]->(ca)
//     换成
//       WITH c, c AS ca
//       ... WHERE trim(coalesce(c.payee_bank_acc_no, '')) <> ''
//     并把 ca.bank_acc_no 换成 c.payee_bank_acc_no、ca.acc_name 换成 c.payee_acc_name 即可。
// =============================================================================
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
      -[:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH g, c, f, ca, aa,
     toUpper(replace(replace(replace(replace(trim(coalesce(ca.bank_acc_no, '')),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(coalesce(aa.bank_acc_no, '')),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号,
     trim(coalesce(ca.acc_name, '')) AS 合同户名,
     trim(coalesce(aa.acc_name, '')) AS 实际户名
WHERE 合同账号 <> '' AND 合同账号 = 实际账号
  AND 合同户名 <> '' AND 实际户名 <> '' AND 合同户名 <> 实际户名
RETURN DISTINCT
       g.org_name          AS 国电投企业,
       c.contract_code     AS 合同编号,
       c.payment_direction AS 合同方向,
       合同账号            AS 账号,
       合同户名            AS 合同约定户名,
       实际户名            AS 实际收付款户名,
       f.bill_num          AS 资金流水单号,
       f.trade_dir         AS 收付方向,
       '账号一致但户名不一致（补充核查）' AS 提示
ORDER BY 合同编号, 资金流水单号;


// =============================================================================
// 六、自包含验证数据（MOCK12_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 主查询正例（应命中，账号不一致）:
//   P1  采购合同，约定 6222...1111 111   vs 实际 6222...9999 8888 888
//   P2  销售合同，两条流水：一条账号与约定一致（仅格式不同），一条不一致
//       → 只应报不一致的那一条（AA3），一致流水不得误报
//   P3  合同账户节点 bank_acc_no 为空，约定账号放在关系属性上（回落口径）→ 命中
// 主查询反例（不应命中）:
//   N1  账号仅空格/全角连字符不同 → 归一化后一致，不报
//   N2  合同有约定账户但无任何流水 → 不报（待核查）
//   N3  有流水但流水未挂账号 → 不报（待核查）
//   N4  实际账户节点账号为空串 → 不报（待核查）
//   N5  合同未约定账户，但有流水 → 不报（待核查）
// 变体用例:
//   P4  无国电投企业参与的外部-外部合同，账号不一致 → 仅全库版（变体 A）命中
//   P5  账号一致但户名不同 → 主查询不命中，仅户名补充口径（变体 C1）命中
// =============================================================================

// ---- 6.1 企业 ----
MERGE (g:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
  ON CREATE SET g.org_name='MOCK12_国电投企业A', g.flag_gdtqy='是',
                g.org_credit_code='91340200395000999X',
                g.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s1:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
  ON CREATE SET s1.org_name='MOCK12_合同相对方1', s1.flag_gdtqy='否',
                s1.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s2:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP2'})
  ON CREATE SET s2.org_name='MOCK12_合同相对方2', s2.flag_gdtqy='否',
                s2.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s3:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP3'})
  ON CREATE SET s3.org_name='MOCK12_外部签约方甲', s3.flag_gdtqy='否',
                s3.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (s4:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP4'})
  ON CREATE SET s4.org_name='MOCK12_外部签约方乙', s4.flag_gdtqy='否',
                s4.schema_name='dws_dsjsj_zstp_vertex_qy';

// ---- 6.2 合同 ----
MERGE (p1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P1'})
  ON CREATE SET p1.contract_code='MOCK12_HT_P1', p1.contract_name='MOCK12_采购合同P1',
                p1.payment_direction='采购', p1.sign_time='2024-03-01',
                p1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P2'})
  ON CREATE SET p2.contract_code='MOCK12_HT_P2', p2.contract_name='MOCK12_销售合同P2',
                p2.payment_direction='销售', p2.sign_time='2024-04-01',
                p2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P3'})
  ON CREATE SET p3.contract_code='MOCK12_HT_P3', p3.contract_name='MOCK12_采购合同P3',
                p3.payment_direction='采购', p3.sign_time='2024-05-01',
                p3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P4'})
  ON CREATE SET p4.contract_code='MOCK12_HT_P4', p4.contract_name='MOCK12_外部合同P4',
                p4.payment_direction='采购', p4.sign_time='2024-06-01',
                p4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (p5:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P5'})
  ON CREATE SET p5.contract_code='MOCK12_HT_P5', p5.contract_name='MOCK12_销售合同P5',
                p5.payment_direction='销售', p5.sign_time='2024-07-01',
                p5.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n1:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N1'})
  ON CREATE SET n1.contract_code='MOCK12_HT_N1', n1.contract_name='MOCK12_反例1_仅格式不同',
                n1.payment_direction='采购', n1.sign_time='2024-08-01',
                n1.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n2:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N2'})
  ON CREATE SET n2.contract_code='MOCK12_HT_N2', n2.contract_name='MOCK12_反例2_无流水',
                n2.payment_direction='采购', n2.sign_time='2024-08-02',
                n2.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n3:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N3'})
  ON CREATE SET n3.contract_code='MOCK12_HT_N3', n3.contract_name='MOCK12_反例3_流水无账号',
                n3.payment_direction='采购', n3.sign_time='2024-08-03',
                n3.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n4:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N4'})
  ON CREATE SET n4.contract_code='MOCK12_HT_N4', n4.contract_name='MOCK12_反例4_实际账号为空',
                n4.payment_direction='销售', n4.sign_time='2024-08-04',
                n4.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n5:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N5'})
  ON CREATE SET n5.contract_code='MOCK12_HT_N5', n5.contract_name='MOCK12_反例5_未约定账户',
                n5.payment_direction='采购', n5.sign_time='2024-08-05',
                n5.schema_name='dws_dsjsj_zstp_vertex_ht';

// ---- 6.3 银行账户 ----
MERGE (ca1:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_CA1'})
  ON CREATE SET ca1.acc_name='MOCK12_国电投企业A', ca1.bank_acc_no='6222 0202 0000 1111 111',
                ca1.nam_dep_ban='工商银行北京分行', ca1.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aa1:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA1'})
  ON CREATE SET aa1.acc_name='MOCK12_外部收款方B', aa1.bank_acc_no='6222 0202 9999 8888 888',
                aa1.nam_dep_ban='建设银行上海分行', aa1.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (ca2:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_CA2'})
  ON CREATE SET ca2.acc_name='MOCK12_国电投企业A', ca2.bank_acc_no='6222-0202-0000-2222-222',
                ca2.nam_dep_ban='工商银行北京分行', ca2.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aa2:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA2'})
  ON CREATE SET aa2.acc_name='MOCK12_国电投企业A', aa2.bank_acc_no='6222 0202 0000 2222 222',
                aa2.nam_dep_ban='工商银行北京分行', aa2.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aa3:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA3'})
  ON CREATE SET aa3.acc_name='MOCK12_异常收款方C', aa3.bank_acc_no='6222020200003333333',
                aa3.nam_dep_ban='农业银行广州分行', aa3.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (ca3:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_CA3'})
  ON CREATE SET ca3.acc_name='MOCK12_合同快照账户P3', ca3.bank_acc_no=NULL,
                ca3.nam_dep_ban='中国银行北京分行', ca3.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aa4:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA4'})
  ON CREATE SET aa4.acc_name='MOCK12_异常收款方D', aa4.bank_acc_no='6222 0202 5555 4444 444',
                aa4.nam_dep_ban='交通银行杭州分行', aa4.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (ca4:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P4_CA'})
  ON CREATE SET ca4.acc_name='MOCK12_外部签约方甲', ca4.bank_acc_no='6222 0202 0000 1212 121',
                ca4.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aa5:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P4_AA'})
  ON CREATE SET aa5.acc_name='MOCK12_外部收款方E', aa5.bank_acc_no='6222 0202 0000 1313 131',
                aa5.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (ca5:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P5_CA'})
  ON CREATE SET ca5.acc_name='MOCK12_国电投企业A', ca5.bank_acc_no='6222 0202 0000 1414 141',
                ca5.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aa6:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P5_AA'})
  ON CREATE SET aa6.acc_name='MOCK12_某某贸易有限公司', aa6.bank_acc_no='6222 0202 0000 1414 141',
                aa6.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (caN1:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N1_CA'})
  ON CREATE SET caN1.acc_name='MOCK12_同名账户', caN1.bank_acc_no='6222 0202 0000 4444 444',
                caN1.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aaN1:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N1_AA'})
  ON CREATE SET aaN1.acc_name='MOCK12_同名账户', aaN1.bank_acc_no='6222－0202－0000－4444－444',
                aaN1.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (caN2:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N2_CA'})
  ON CREATE SET caN2.acc_name='MOCK12_反例2_约定账户', caN2.bank_acc_no='6222 0202 0000 5555 555',
                caN2.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (caN3:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N3_CA'})
  ON CREATE SET caN3.acc_name='MOCK12_反例3_约定账户', caN3.bank_acc_no='6222 0202 0000 6666 666',
                caN3.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (caN4:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N4_CA'})
  ON CREATE SET caN4.acc_name='MOCK12_反例4_约定账户', caN4.bank_acc_no='6222 0202 0000 7777 777',
                caN4.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aaN4:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N4_AA'})
  ON CREATE SET aaN4.acc_name='MOCK12_反例4_实际账户', aaN4.bank_acc_no='',
                aaN4.schema_name='dws_dsjsj_zstp_vertex_yhzh';
MERGE (aaN5:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N5_AA'})
  ON CREATE SET aaN5.acc_name='MOCK12_反例5_实际账户', aaN5.bank_acc_no='6222 0202 0000 8888 888',
                aaN5.schema_name='dws_dsjsj_zstp_vertex_yhzh';

// ---- 6.4 资金流水 ----
MERGE (f1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P1'})
  ON CREATE SET f1.bill_num='MOCK12_BL_P1', f1.tran_amt=100000.00, f1.trade_dir='付款',
                f1.TRANS_TIME='2024-05-10', f1.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f2a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P2A'})
  ON CREATE SET f2a.bill_num='MOCK12_BL_P2A', f2a.tran_amt=200000.00, f2a.trade_dir='收款',
                f2a.TRANS_TIME='2024-05-12', f2a.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f2b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P2B'})
  ON CREATE SET f2b.bill_num='MOCK12_BL_P2B', f2b.tran_amt=300000.00, f2b.trade_dir='收款',
                f2b.TRANS_TIME='2024-05-15', f2b.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f3:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P3'})
  ON CREATE SET f3.bill_num='MOCK12_BL_P3', f3.tran_amt=150000.00, f3.trade_dir='付款',
                f3.TRANS_TIME='2024-06-01', f3.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f4:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P4'})
  ON CREATE SET f4.bill_num='MOCK12_BL_P4', f4.tran_amt=80000.00, f4.trade_dir='付款',
                f4.TRANS_TIME='2024-06-20', f4.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (f5:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P5'})
  ON CREATE SET f5.bill_num='MOCK12_BL_P5', f5.tran_amt=60000.00, f5.trade_dir='收款',
                f5.TRANS_TIME='2024-07-10', f5.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fN1:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N1'})
  ON CREATE SET fN1.bill_num='MOCK12_BL_N1', fN1.tran_amt=50000.00, fN1.trade_dir='付款',
                fN1.TRANS_TIME='2024-08-10', fN1.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fN3:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N3'})
  ON CREATE SET fN3.bill_num='MOCK12_BL_N3', fN3.tran_amt=40000.00, fN3.trade_dir='付款',
                fN3.TRANS_TIME='2024-08-12', fN3.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fN4:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N4'})
  ON CREATE SET fN4.bill_num='MOCK12_BL_N4', fN4.tran_amt=30000.00, fN4.trade_dir='收款',
                fN4.TRANS_TIME='2024-08-13', fN4.schema_name='dws_dsjsj_zstp_vertex_zjls';
MERGE (fN5:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N5'})
  ON CREATE SET fN5.bill_num='MOCK12_BL_N5', fN5.tran_amt=20000.00, fN5.trade_dir='付款',
                fN5.TRANS_TIME='2024-08-14', fN5.schema_name='dws_dsjsj_zstp_vertex_zjls';

// ---- 6.5 边：签订合同（企业 → 合同，MATCH 端点 + MERGE 关系，幂等）----
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_P1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_P1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_P2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S2_P2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_P3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP2'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S2_P3'}]->(b);
// P4：外部-外部签约，国电投不参与
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP3'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S3_P4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP4'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S4_P4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_P5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_P5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_N1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N1'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_N1'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_N2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N2'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_N2'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_N3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N3'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_N3'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_N4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N4'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_N4'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_GDT'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_G_N5'}]->(b);
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK12_QY_SUP1'})
MATCH (b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N5'})
MERGE (a)-[:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK12_E_QD_S1_N5'}]->(b);

// ---- 6.6 边：合同约定银行账户（派生边 合同 → 银行账户）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_CA1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_P1'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_CA2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_P2'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_CA3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_P3'}]->(b)
  ON CREATE SET r.bank_acc_no='6222 0202 0000 3333 333',
                r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P4_CA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_P4'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P5'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P5_CA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_P5'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N1_CA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_N1'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N2'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N2_CA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_N2'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N3'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N3_CA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_N3'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N4'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N4_CA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_htydyhzh {object_key:'MOCK12_E_HTACC_N4'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_ht_htydyhzh';
// N5 刻意不建 合同约定银行账户 边

// ---- 6.7 边：合同收款/付款（合同 → 资金流水）----
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_P1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P2A'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_P2A'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P2'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P2B'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_P2B'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_P3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_P4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_P5'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_P5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_N1'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N3'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_N3'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N4'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_N4'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK12_HT_N5'})
MATCH (b:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N5'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_ht_skfk {object_key:'MOCK12_E_SKFK_N5'}]->(b)
  ON CREATE SET r.schema_name='dws_dsjsj_zstp_edge_ht_skfk';

// ---- 6.8 边：资金流水收款/付款账号（资金流水 → 银行账户，N3 刻意不建）----
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P1'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA1'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_P1'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P2A'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA2'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_P2A'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P2B'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA3'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_P2B'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P3'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_AA4'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_P3'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P4'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P4_AA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_P4'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_P5'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_P5_AA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_P5'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N1'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N1_AA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_N1'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N4'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N4_AA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_N4'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';
MATCH (a:dws_dsjsj_zstp_vertex_zjls {object_key:'MOCK12_ZJLS_N5'})
MATCH (b:dws_dsjsj_zstp_vertex_yhzh {object_key:'MOCK12_YHZH_N5_AA'})
MERGE (a)-[r:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh {object_key:'MOCK12_E_ZJLSACC_N5'}]->(b)
  ON CREATE SET r.bank_acc_no=NULL, r.schema_name='dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';


// =============================================================================
// 七、断言校验（先跑第六节灌数据，再跑本节，应全部 PASS）
// =============================================================================

// 断言 1：主查询恰好命中 3 条正例，且实际账号正确
//         P1 -> 6222020299998888888
//         P2 -> 6222020200003333333（一致流水 AA2 不得出现）
//         P3 -> 6222020255554444444（关系属性回落）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
MATCH (f)-[ra:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH g, c, f, ca, aa, rc, ra,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(ca.bank_acc_no, '')) <> '' THEN ca.bank_acc_no
            ELSE coalesce(rc.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(aa.bank_acc_no, '')) <> '' THEN aa.bank_acc_no
            ELSE coalesce(ra.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号
WHERE 合同账号 <> '' AND 实际账号 <> '' AND 合同账号 <> 实际账号
WITH collect(DISTINCT c.contract_code + '|' + 实际账号) AS 命中,
     ['MOCK12_HT_P1|6222020299998888888',
      'MOCK12_HT_P2|6222020200003333333',
      'MOCK12_HT_P3|6222020255554444444'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言1_主查询仅3条正例且账号正确;

// 断言 2：仅格式不同不误报（N1），同合同一致流水也不误报（AA2）
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
MATCH (f)-[ra:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH c, f, ca, aa, rc, ra,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(ca.bank_acc_no, '')) <> '' THEN ca.bank_acc_no
            ELSE coalesce(rc.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(aa.bank_acc_no, '')) <> '' THEN aa.bank_acc_no
            ELSE coalesce(ra.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号
WHERE 合同账号 <> '' AND 实际账号 <> '' AND 合同账号 <> 实际账号
WITH collect(DISTINCT c.contract_code + '|' + aa.object_key) AS 命中
RETURN CASE WHEN NOT any(x IN 命中 WHERE x STARTS WITH 'MOCK12_HT_N1|')
             AND NOT any(x IN 命中 WHERE x STARTS WITH 'MOCK12_HT_P2|MOCK12_YHZH_AA2')
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言2_格式差异与一致流水不误报;

// 断言 3：无法判定/待核查恰好 4 条：N2/N3/N4/N5，原因正确
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
OPTIONAL MATCH (c)-[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
OPTIONAL MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
OPTIONAL MATCH (f)-[:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH c,
     count(DISTINCT CASE WHEN ca IS NOT NULL
              AND (trim(coalesce(ca.bank_acc_no, '')) <> ''
                   OR trim(coalesce(rc.bank_acc_no, '')) <> '')
            THEN ca END) AS 约定有效账号数,
     count(DISTINCT f) AS 流水数,
     count(DISTINCT CASE WHEN aa IS NOT NULL
              AND trim(coalesce(aa.bank_acc_no, '')) <> ''
            THEN aa END) AS 实际有效账号数
WITH c, 约定有效账号数, 流水数, 实际有效账号数,
     CASE
       WHEN 约定有效账号数 = 0 AND 流水数 = 0 THEN '合同未约定银行账户且无流水'
       WHEN 约定有效账号数 = 0               THEN '合同未约定银行账户'
       WHEN 流水数 = 0                       THEN '合同无收款/付款流水'
       WHEN 实际有效账号数 = 0               THEN '流水无有效收付款账号'
       ELSE '可判定'
     END AS 待核查原因
WHERE 待核查原因 <> '可判定'
WITH collect(DISTINCT c.contract_code + '|' + 待核查原因) AS 待核查,
     ['MOCK12_HT_N2|合同无收款/付款流水',
      'MOCK12_HT_N3|流水无有效收付款账号',
      'MOCK12_HT_N4|流水无有效收付款账号',
      'MOCK12_HT_N5|合同未约定银行账户'] AS 期望
RETURN CASE WHEN size(待核查) = size(期望) AND all(x IN 期望 WHERE x IN 待核查)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 待核查 | a + v + '; ') END
       AS 断言3_无法判定4条且原因正确;

// 断言 4：全库版（变体 A）在 MOCK12_ 内命中 4 条：P1/P2/P3 + 外部-外部 P4
MATCH (c:dws_dsjsj_zstp_vertex_ht)
      -[rc:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
      -[ra:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH c, ca, aa, f, rc, ra,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(ca.bank_acc_no, '')) <> '' THEN ca.bank_acc_no
            ELSE coalesce(rc.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(
       CASE WHEN trim(coalesce(aa.bank_acc_no, '')) <> '' THEN aa.bank_acc_no
            ELSE coalesce(ra.bank_acc_no, '') END),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号
WHERE 合同账号 <> '' AND 实际账号 <> '' AND 合同账号 <> 实际账号
  AND c.contract_code STARTS WITH 'MOCK12_'
WITH collect(DISTINCT c.contract_code) AS 命中,
     ['MOCK12_HT_P1', 'MOCK12_HT_P2', 'MOCK12_HT_P3', 'MOCK12_HT_P4'] AS 期望
RETURN CASE WHEN size(命中) = size(期望) AND all(x IN 期望 WHERE x IN 命中)
            THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言4_全库版含外部外部合同P4;

// 断言 5：户名补充口径（变体 C1）仅命中 P5
MATCH (g:dws_dsjsj_zstp_vertex_qy {org_credit_code: '91340200395000999X'})
WHERE g.flag_gdtqy = '是'
MATCH (g)-[:dws_dsjsj_zstp_edge_qy_qd]->(c:dws_dsjsj_zstp_vertex_ht)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_htydyhzh]->(ca:dws_dsjsj_zstp_vertex_yhzh)
MATCH (c)-[:dws_dsjsj_zstp_edge_ht_skfk]->(f:dws_dsjsj_zstp_vertex_zjls)
      -[:dws_dsjsj_zstp_edge_zjls_zjlsskfkzh]->(aa:dws_dsjsj_zstp_vertex_yhzh)
WITH c, f, ca, aa,
     toUpper(replace(replace(replace(replace(trim(coalesce(ca.bank_acc_no, '')),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 合同账号,
     toUpper(replace(replace(replace(replace(trim(coalesce(aa.bank_acc_no, '')),
       ' ', ''), '　', ''), '-', ''), '－', '')) AS 实际账号,
     trim(coalesce(ca.acc_name, '')) AS 合同户名,
     trim(coalesce(aa.acc_name, '')) AS 实际户名
WHERE 合同账号 <> '' AND 合同账号 = 实际账号
  AND 合同户名 <> '' AND 实际户名 <> '' AND 合同户名 <> 实际户名
WITH collect(DISTINCT c.contract_code) AS 命中
RETURN CASE WHEN 命中 = ['MOCK12_HT_P5'] THEN 'PASS'
            ELSE 'FAIL: ' + reduce(a = '', v IN 命中 | a + v + '; ') END
       AS 断言5_户名不一致仅命中P5;


// =============================================================================
// 八、清理本文件模拟数据
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK12_' DETACH DELETE n;
