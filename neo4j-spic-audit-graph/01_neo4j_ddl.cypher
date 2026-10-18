// =============================================================================
// 国电投 AI+审计 知识图谱  ·  Neo4j DDL（顶点约束 / 索引 / 边约束）
// -----------------------------------------------------------------------------
// 数据来源 : 国电投AI+审计 (1).xls
//              sheet `schemas` : 88 行 = 28 个 VERTEX + 60 个 EDGE
//              sheet `fields`  : 503 行 字段定义
// 目标版本 : Neo4j 5.x（Community / Enterprise 均可）
// 生成时间 : 2026-10-16
// -----------------------------------------------------------------------------
// 建模约定
//   1) 所有顶点共用通用标签 :ZSTP，并叠加业务标签（中文），写作 (:ZSTP:企业)
//   2) 顶点主键统一为 object_key（对应源表 isMain=true / isIdentity=true 的字段）
//   3) 边类型 = 源表 schemaNameCn（中文，反引号包裹）；方向固定 from_key -> to_key
//   4) 边的业务属性挂在关系上，object_key 为边自身主键
//   5) 顶点 / 边均额外保留 schema_name 属性，用于回溯源表 schema
// -----------------------------------------------------------------------------
// 执行顺序 : 先执行本文件（DDL），再执行 02_neo4j_init_data.cypher（初始化数据）
//
// 若使用 Neo4j 4.x，约束语法需改为：
//   CREATE CONSTRAINT cst_x IF NOT EXISTS ON (n:`企业`) ASSERT n.object_key IS UNIQUE;
// =============================================================================


// =============================================================================
// 一、顶点唯一约束（28 个）—— 每个业务标签的 object_key 唯一
// =============================================================================
CREATE CONSTRAINT cst_qy_object_key          IF NOT EXISTS FOR (n:`企业`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_zrr_object_key         IF NOT EXISTS FOR (n:`自然人`)         REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_ht_object_key          IF NOT EXISTS FOR (n:`合同`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_bd_object_key          IF NOT EXISTS FOR (n:`标段`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_fp_object_key          IF NOT EXISTS FOR (n:`发票`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_zjls_object_key        IF NOT EXISTS FOR (n:`资金流水`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_yhzh_object_key        IF NOT EXISTS FOR (n:`银行账户`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_cwpz_object_key        IF NOT EXISTS FOR (n:`财务凭证`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_wl_object_key          IF NOT EXISTS FOR (n:`物料`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_rk_object_key          IF NOT EXISTS FOR (n:`入库`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_ck_object_key          IF NOT EXISTS FOR (n:`出库`)           REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_jrlxm_object_key       IF NOT EXISTS FOR (n:`金融类项目`)     REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_qtlxm_object_key       IF NOT EXISTS FOR (n:`其他类项目`)     REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_jjlxm_object_key       IF NOT EXISTS FOR (n:`基建类项目`)     REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_dnygdd_object_key      IF NOT EXISTS FOR (n:`电能e购订单`)    REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_xtcp_object_key        IF NOT EXISTS FOR (n:`信托产品`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_xtdczc_object_key      IF NOT EXISTS FOR (n:`信托底层资产`)   REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_ylqfqszd_object_key    IF NOT EXISTS FOR (n:`云链签发账单`)   REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_ylzrzd_object_key      IF NOT EXISTS FOR (n:`云链转让账单`)   REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_ylrzzd_object_key      IF NOT EXISTS FOR (n:`云链融资账单`)   REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_fxxs_object_key        IF NOT EXISTS FOR (n:`风险线索`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_flss_object_key        IF NOT EXISTS FOR (n:`法律诉讼`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_pccz_object_key        IF NOT EXISTS FOR (n:`破产重整`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_xzcf_object_key        IF NOT EXISTS FOR (n:`行政处罚`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_sxbzxr_object_key      IF NOT EXISTS FOR (n:`失信被执行人`)   REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_jchy_object_key        IF NOT EXISTS FOR (n:`决策会议`)       REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_jchyyt_object_key      IF NOT EXISTS FOR (n:`决策会议议题`)   REQUIRE n.object_key IS UNIQUE;
CREATE CONSTRAINT cst_ejdwgfjc_object_key    IF NOT EXISTS FOR (n:`二级单位规范简称`) REQUIRE n.object_key IS UNIQUE;


// =============================================================================
// 二、顶点业务属性索引（按各节点常用的名称/编号字段建索引，加速按名检索）
// =============================================================================
CREATE INDEX idx_qy_org_name        IF NOT EXISTS FOR (n:`企业`)           ON (n.org_name);
CREATE INDEX idx_qy_credit_code     IF NOT EXISTS FOR (n:`企业`)           ON (n.org_credit_code);
CREATE INDEX idx_zrr_name           IF NOT EXISTS FOR (n:`自然人`)         ON (n.name);
CREATE INDEX idx_ht_contract_code   IF NOT EXISTS FOR (n:`合同`)           ON (n.contract_code);
CREATE INDEX idx_bd_packno          IF NOT EXISTS FOR (n:`标段`)           ON (n.packno);
CREATE INDEX idx_fp_fp_hm           IF NOT EXISTS FOR (n:`发票`)           ON (n.fp_hm);
CREATE INDEX idx_zjls_bill_num      IF NOT EXISTS FOR (n:`资金流水`)       ON (n.bill_num);
CREATE INDEX idx_yhzh_bank_acc_no   IF NOT EXISTS FOR (n:`银行账户`)       ON (n.bank_acc_no);
CREATE INDEX idx_cwpz_post_bh       IF NOT EXISTS FOR (n:`财务凭证`)       ON (n.POST_BH);
CREATE INDEX idx_wl_matnr           IF NOT EXISTS FOR (n:`物料`)           ON (n.matnr);
CREATE INDEX idx_rk_mblnr           IF NOT EXISTS FOR (n:`入库`)           ON (n.mblnr);
CREATE INDEX idx_ck_vbeln           IF NOT EXISTS FOR (n:`出库`)           ON (n.vbeln);
CREATE INDEX idx_jrlxm_deal_name    IF NOT EXISTS FOR (n:`金融类项目`)     ON (n.deal_name);
CREATE INDEX idx_qtlxm_item_name    IF NOT EXISTS FOR (n:`其他类项目`)     ON (n.item_name);
CREATE INDEX idx_jjlxm_proj_name    IF NOT EXISTS FOR (n:`基建类项目`)     ON (n.proj_name);
CREATE INDEX idx_dnygdd_order_no    IF NOT EXISTS FOR (n:`电能e购订单`)    ON (n.order_no);
CREATE INDEX idx_xtcp_product_code  IF NOT EXISTS FOR (n:`信托产品`)       ON (n.PRODUCT_CODE);
CREATE INDEX idx_ylqfqszd_bill_no   IF NOT EXISTS FOR (n:`云链签发账单`)   ON (n.bill_no);
CREATE INDEX idx_ylzrzd_bill_no     IF NOT EXISTS FOR (n:`云链转让账单`)   ON (n.bill_no);
CREATE INDEX idx_ylrzzd_sub_bill_id IF NOT EXISTS FOR (n:`云链融资账单`)   ON (n.sub_bill_id);
CREATE INDEX idx_fxxs_risk_type     IF NOT EXISTS FOR (n:`风险线索`)       ON (n.risk_type);
CREATE INDEX idx_flss_case_no       IF NOT EXISTS FOR (n:`法律诉讼`)       ON (n.case_no);
CREATE INDEX idx_xzcf_punish_number IF NOT EXISTS FOR (n:`行政处罚`)       ON (n.punish_number);
CREATE INDEX idx_sxbzxr_casecode    IF NOT EXISTS FOR (n:`失信被执行人`)   ON (n.casecode);
CREATE INDEX idx_jchy_meeting_code  IF NOT EXISTS FOR (n:`决策会议`)       ON (n.meeting_code);
CREATE INDEX idx_jchyyt_subject_code IF NOT EXISTS FOR (n:`决策会议议题`)  ON (n.subject_code);
CREATE INDEX idx_ejdw_short_name    IF NOT EXISTS FOR (n:`二级单位规范简称`) ON (n.short_name);


// =============================================================================
// 三、边唯一约束（60 个）—— 需要 Neo4j 5.7+（关系属性唯一约束）
//     若版本低于 5.7，请整段注释掉：不影响图模型与初始化数据
// =============================================================================
CREATE CONSTRAINT rel_qy_gdcgbfb_object_key        IF NOT EXISTS FOR ()-[r:`股东持股（%）企业-企业`]-()    REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zrr_gdcgqy_object_key        IF NOT EXISTS FOR ()-[r:`股东持股（%）企业-自然人`]-()  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_qd_object_key             IF NOT EXISTS FOR ()-[r:`签订合同`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_csfp_object_key           IF NOT EXISTS FOR ()-[r:`产生发票_企业`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_dnegdd_csfp_object_key       IF NOT EXISTS FOR ()-[r:`产生发票`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_kjjsfp_object_key         IF NOT EXISTS FOR ()-[r:`开具接收发票`]-()              REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_yyzh_object_key           IF NOT EXISTS FOR ()-[r:`拥有账户`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_yhzh_jy_object_key           IF NOT EXISTS FOR ()-[r:`交易`]-()                      REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_skfk_object_key           IF NOT EXISTS FOR ()-[r:`企业收款/付款`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_skfk_object_key           IF NOT EXISTS FOR ()-[r:`合同收款/付款`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_fp_yjfpskfk_object_key       IF NOT EXISTS FOR ()-[r:`依据发票收款/付款`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zjls_zjlsskfkzh_object_key   IF NOT EXISTS FOR ()-[r:`资金流水收款/付款账号`]-()     REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zjls_scpz_object_key         IF NOT EXISTS FOR ()-[r:`生成凭证`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_acghtrk_object_key        IF NOT EXISTS FOR ()-[r:`按采购合同入库`]-()            REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_axshtck_object_key        IF NOT EXISTS FOR ()-[r:`按销售合同出库`]-()            REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_wl_lywl_object_key           IF NOT EXISTS FOR ()-[r:`领用物料`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_wl_xhwl_object_key           IF NOT EXISTS FOR ()-[r:`消耗物料`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_psdd_object_key           IF NOT EXISTS FOR ()-[r:`派生订单`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_fqdd_object_key           IF NOT EXISTS FOR ()-[r:`发起订单`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_bd_lsht_object_key           IF NOT EXISTS FOR ()-[r:`隶属合同`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_tybdwgl_object_key        IF NOT EXISTS FOR ()-[r:`同一标的物关联_合同`]-()       REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_fp_tybdwgl_object_key        IF NOT EXISTS FOR ()-[r:`同一标的物关联`]-()            REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_fb_object_key             IF NOT EXISTS FOR ()-[r:`发布标段`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_cy_object_key             IF NOT EXISTS FOR ()-[r:`参与投标`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_zb_object_key             IF NOT EXISTS FOR ()-[r:`中标`]-()                      REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_scxzbs_object_key         IF NOT EXISTS FOR ()-[r:`上传/下载标书`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_fqxm_jrlxm_object_key     IF NOT EXISTS FOR ()-[r:`发起项目_金融`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_fqxm_qtlxm_object_key     IF NOT EXISTS FOR ()-[r:`发起项目_其他`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_fqxm_jjlxm_object_key     IF NOT EXISTS FOR ()-[r:`发起项目_基建`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_jrlxm_ct_object_key          IF NOT EXISTS FOR ()-[r:`穿透`]-()                      REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_jrlxm_tx_object_key          IF NOT EXISTS FOR ()-[r:`投向`]-()                      REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_fqjchy_object_key         IF NOT EXISTS FOR ()-[r:`发起决策会议`]-()              REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_jchy_hytlyt_object_key       IF NOT EXISTS FOR ()-[r:`会议讨论议题`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_jchyyt_jjlxm_object_key      IF NOT EXISTS FOR ()-[r:`决策项目_基建类项目`]-()       REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_jchyyt_qtlxm_object_key      IF NOT EXISTS FOR ()-[r:`决策项目_其他类项目`]-()       REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_jchyyt_jrlxm_object_key      IF NOT EXISTS FOR ()-[r:`决策项目_金融类项目`]-()       REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zrr_cyyt_object_key          IF NOT EXISTS FOR ()-[r:`参与议题`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zrr_drcrqyfr_object_key      IF NOT EXISTS FOR ()-[r:`担任/曾任企业法人`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zrr_rzqy_object_key          IF NOT EXISTS FOR ()-[r:`担任/曾任企业高管`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ylqfqszd_sczrzd_object_key   IF NOT EXISTS FOR ()-[r:`生成转让账单`]-()              REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ylqfzd_yyrz_object_key       IF NOT EXISTS FOR ()-[r:`用于融资`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ylzrzd_gldcght_object_key    IF NOT EXISTS FOR ()-[r:`关联到采购合同`]-()            REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_qfzd_srf_object_key       IF NOT EXISTS FOR ()-[r:`签发账单（受让方）`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_qfzd_crf_object_key       IF NOT EXISTS FOR ()-[r:`签发账单（出让方）`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_cghtscqfzd_object_key     IF NOT EXISTS FOR ()-[r:`采购合同生成签发账单`]-()       REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_zrzd_crf_object_key       IF NOT EXISTS FOR ()-[r:`转让账单（出让方）`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_zrzd_srf_object_key       IF NOT EXISTS FOR ()-[r:`转让账单（受让方）`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_sqrz_srf_object_key       IF NOT EXISTS FOR ()-[r:`融资账单（受让方）`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_sqrz_crf_object_key       IF NOT EXISTS FOR ()-[r:`融资账单（出让方）`]-()         REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_sjss_object_key           IF NOT EXISTS FOR ()-[r:`涉及诉讼`]-()                  REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_sjpccz_object_key         IF NOT EXISTS FOR ()-[r:`涉及破产重整`]-()              REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_sdxzcf_object_key         IF NOT EXISTS FOR ()-[r:`受到行政处罚`]-()              REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_blwsxzxr_object_key       IF NOT EXISTS FOR ()-[r:`被列为失信被执行人`]-()       REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_qy_cffx_object_key           IF NOT EXISTS FOR ()-[r:`触发风险_企业`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_zzr_cffx_object_key          IF NOT EXISTS FOR ()-[r:`触发风险_自然人`]-()           REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_bd_cffx_object_key           IF NOT EXISTS FOR ()-[r:`触发风险_标段`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ht_cffx_object_key           IF NOT EXISTS FOR ()-[r:`触发风险_合同`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ylqfqszd_cffx_object_key     IF NOT EXISTS FOR ()-[r:`触发风险_云链签发账单`]-()     REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_fxxs_fp_object_key           IF NOT EXISTS FOR ()-[r:`触发风险_发票`]-()             REQUIRE r.object_key IS UNIQUE;
CREATE CONSTRAINT rel_ejdwgfjc_dyqy_object_key     IF NOT EXISTS FOR ()-[r:`对应企业`]-()                  REQUIRE r.object_key IS UNIQUE;


// =============================================================================
// 四、顶点定义速查（28 类）—— 注释形式，供建图/导入时对照
//     格式: 业务标签 | object_key 之外的业务属性(原字段名)
// =============================================================================
// :企业             | org_name, org_credit_code, mdg_code, mdg_name, secondary_org_code, secondary_org_name,
//                    | companyorgtype, regstatus, reglocation, businessscope, estiblishtime, socialstaffnum,
//                    | phonenumber, organizationlevel, sfgq, flag_gdtqy, flag_cg, flag_kg, sfkh, sfgys, sourcesystem
// :自然人           | name, emp_code, post_name, is_key_person, is_history_key_person, is_emp, work_status, source_system
// :合同             | contract_code, contract_name, gategory_name, category_code, status_name, payment_direction,
//                    | contract_amount, sign_time, sfjrlht, sfdblht, sfzxsppdylht, mdg_orgcode, mdg_orgname, sourcesystem
// :标段             | packno, packname, tenderno, tendername, procurementmethod, tendermethod, packid,
//                    | createtime, maxlimitprice, system_source
// :发票             | fp_hm, fplx, kprq, fpje, fpse, jshj, xmmc, taxpayer, system_source
// :资金流水         | bill_num, tran_amt, trade_dir, TRANS_TIME, SUMMARY, system_source
// :银行账户         | acc_name, bank_acc_no, nam_dep_ban, use_state, system_source
// :财务凭证         | POST_BH, START_DATE, REG_DATE, DESCRIPTION, CR_BALANCE, DR_BALANCE, source_system
// :物料             | matnr, maktx, sourcesystem
// :入库             | mblnr, menge, charg, budat, elikz, lfart_desc, umlgo, sourcesystem
// :出库             | vbeln, meins, wadat_ist, wbstk, lfart, lgort, source_system
// :金融类项目       | id, deal_name, deal_type2, deal_status, end_time_, actual_payment_money, system_source
// :其他类项目       | item_id, item_name, item_type, ini_status, init_date, depname, ass_capltal_money, sourcesystem
// :基建类项目       | proj_code, proj_name, proposal_code, full_name, proj_status_name, actual_start_time,
//                    | investment_type_name, proj_stage_name, industry_type_name, investment_amount, lyxt
// :电能e购订单      | order_no, order_status, order_time, amount_type_id, final_price, system_source
// :信托产品         | PRODUCT_CODE, PRODUCT_NAME, PRODUCT_MONEY, START_DATE, END_DATE, CP_STATUS_NAME, system_source
// :信托底层资产     | param_name, dczcbcms, zcqdfs, syqbizc, system_source
// :云链签发账单     | ini_bill_id, bill_no, bill_amt, bill_balan, bill_begin_dt, rpay_dt, bill_over_dt,
//                    | bill_status, trx_type, system_source
// :云链转让账单     | ini_bill_id, bill_no, bill_amt, bill_balan, bill_begin_dt, rpay_dt, bill_over_dt,
//                    | bill_status, trx_type, system_source
// :云链融资账单     | ini_bill_id, sub_bill_id, lvrg_prod_name, bill_amt, bill_balan, intr, finance_days,
//                    | lvrg_intr_rate, total_finance_fee, total_finance_rate, pay_intr_method, dtrb_dt_f,
//                    | bill_over_dt_f, dtrb_dt_s, lvrg_apply_dt_f, rpay_dt_f, org_ali_pmt_amt, trx_type,
//                    | bill_status, system_source
// :风险线索         | risk_type, risk_desc, risk_summary
// :法律诉讼         | case_no, title, case_type, case_reason, case_money, judge_time, court, submit_time, system_source
// :破产重整         | case_no, case_type, submit_time, system_source
// :行政处罚         | punish_name, punish_number, decision_date, department_name, reason, content, evidence, syetem_source
// :失信被执行人     | type, casecode, disrupttypename, performance, regdate, publishdate, gistunit, system_source
// :决策会议         | meeting_name, meeting_code, meeting_date, type_name, system_source
// :决策会议议题     | subject_name, subject_code, pass_flag, system_source
// :二级单位规范简称 | short_name, notice_name, period_history, org_unique_code, doc_num, send_time
//
// 注: 除 `企业`/`自然人`/`合同` 等中文标签外，每个顶点还必须带通用标签 :ZSTP


// =============================================================================
// 五、边定义速查（60 类）—— 注释形式
//     格式: (:起点标签)-[:边类型]->(:终点标签) | 关系属性(除 object_key/from_key/to_key)
// =============================================================================
// (:企业)-[:`股东持股（%）企业-企业`]->(:企业)            | ft_shareholding, capital_amomon, capital_percent, capital_time,
//                                                          | capital_actl_amomon, capital_actl_percent, capital_actl_time,
//                                                          | capital_actl_paymet, sflsgd
// (:自然人)-[:`股东持股（%）企业-自然人`]->(:企业)          | ft_shareholding, capital_amomon, capital_percent, capital_time,
//                                                          | capital_actl_amomon, capital_actl_percent, capital_actl_time,
//                                                          | capital_actl_paymet, is_history_shareholder, history_ft_shareholding
// (:企业)-[:`签订合同`]->(:合同)                           | contract_amount, contract_status, sign_time
// (:企业)-[:`产生发票_企业`]->(:发票)                       | -
// (:电能e购订单)-[:`产生发票`]->(:发票)                     | real_invoice_time, HJJE
// (:企业)-[:`开具接收发票`]->(:发票)                        | -
// (:企业)-[:`拥有账户`]->(:银行账户)                        | -
// (:银行账户)-[:`交易`]->(:银行账户)                        | trans_time, tran_amt, abstract
// (:企业)-[:`企业收款/付款`]->(:资金流水)                   | -
// (:合同)-[:`合同收款/付款`]->(:资金流水)                   | -
// (:发票)-[:`依据发票收款/付款`]->(:资金流水)               | invoice_no, invoice_date, bill_num
// (:资金流水)-[:`资金流水收款/付款账号`]->(:银行账户)        | bank_acc_no, trans_time, tran_uni_cod
// (:资金流水)-[:`生成凭证`]->(:财务凭证)                    | -
// (:合同)-[:`按采购合同入库`]->(:入库)                      | -
// (:合同)-[:`按销售合同出库`]->(:出库)                      | -
// (:物料)-[:`领用物料`]->(:入库)                            | name1, werks, lgobe, cputm
// (:物料)-[:`消耗物料`]->(:出库)                            | name1, werks, lgobe, erdat
// (:合同)-[:`派生订单`]->(:电能e购订单)                     | -
// (:企业)-[:`发起订单`]->(:电能e购订单)                     | -
// (:标段)-[:`隶属合同`]->(:合同)                            | -
// (:合同)-[:`同一标的物关联_合同`]->(:合同)                 | -
// (:发票)-[:`同一标的物关联`]->(:发票)                      | -
// (:企业)-[:`发布标段`]->(:标段)                            | createtime
// (:企业)-[:`参与投标`]->(:标段)                            | createtime, final_price
// (:企业)-[:`中标`]->(:标段)                                | bid_send_time, finalprice
// (:企业)-[:`上传/下载标书`]->(:标段)                       | ip, iptag, rel_time
// (:企业)-[:`发起项目_金融`]->(:金融类项目)                 | -
// (:企业)-[:`发起项目_其他`]->(:其他类项目)                 | -
// (:企业)-[:`发起项目_基建`]->(:基建类项目)                 | -
// (:金融类项目)-[:`穿透`]->(:信托底层资产)                  | -
// (:金融类项目)-[:`投向`]->(:信托产品)                      | -
// (:企业)-[:`发起决策会议`]->(:决策会议)                    | -
// (:决策会议)-[:`会议讨论议题`]->(:决策会议议题)            | -
// (:决策会议议题)-[:`决策项目_基建类项目`]->(:基建类项目)   | subject_name
// (:决策会议议题)-[:`决策项目_其他类项目`]->(:其他类项目)   | subject_name
// (:决策会议议题)-[:`决策项目_金融类项目`]->(:金融类项目)   | subject_name
// (:自然人)-[:`参与议题`]->(:决策会议议题)                  | attendance_ame, position
// (:自然人)-[:`担任/曾任企业法人`]->(:企业)                 | is_current_legal_person, is_history_legal_person
// (:自然人)-[:`担任/曾任企业高管`]->(:企业)                 | position, term, history_position, history_term,
//                                                          | is_history_key_person, report_date
// (:云链签发账单)-[:`生成转让账单`]->(:云链转让账单)        | ylqfqs_bill_no, ylzz_bill_no
// (:云链签发账单)-[:`用于融资`]->(:云链融资账单)            | -
// (:云链转让账单)-[:`关联到采购合同`]->(:合同)              | financing_ratio_pct
// (:企业)-[:`签发账单（受让方）`]->(:云链签发账单)           | -
// (:企业)-[:`签发账单（出让方）`]->(:云链签发账单)           | -
// (:合同)-[:`采购合同生成签发账单`]->(:云链签发账单)         | -
// (:企业)-[:`转让账单（出让方）`]->(:云链转让账单)           | -
// (:企业)-[:`转让账单（受让方）`]->(:云链转让账单)           | -
// (:企业)-[:`融资账单（受让方）`]->(:云链融资账单)           | -
// (:企业)-[:`融资账单（出让方）`]->(:云链融资账单)           | -
// (:企业)-[:`涉及诉讼`]->(:法律诉讼)                        | -
// (:企业)-[:`涉及破产重整`]->(:破产重整)                    | total
// (:企业)-[:`受到行政处罚`]->(:行政处罚)                    | -
// (:企业)-[:`被列为失信被执行人`]->(:失信被执行人)          | -
// (:企业)-[:`触发风险_企业`]->(:风险线索)                   | -
// (:自然人)-[:`触发风险_自然人`]->(:风险线索)               | -
// (:标段)-[:`触发风险_标段`]->(:风险线索)                   | -
// (:合同)-[:`触发风险_合同`]->(:风险线索)                   | -
// (:云链签发账单)-[:`触发风险_云链签发账单`]->(:风险线索)    | -
// (:风险线索)-[:`触发风险_发票`]->(:发票)                   | -
// (:二级单位规范简称)-[:`对应企业`]->(:企业)                | -


// =============================================================================
// 六、校验
// =============================================================================
// 查看已创建的约束与索引
// SHOW CONSTRAINTS;
// SHOW INDEXES;
//
// 统计图谱规模
// MATCH (n:ZSTP) RETURN labels(n) AS label, count(*) AS cnt ORDER BY cnt DESC;
// MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY cnt DESC;
