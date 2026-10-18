// =============================================================================
// 国电投 AI+审计 知识图谱  ·  初始化种子数据
// -----------------------------------------------------------------------------
// 依赖   : 先执行 01_neo4j_ddl.cypher 创建约束与索引
// 幂等性 : 全部使用 MERGE，可重复执行而不产生重复数据
// 规模   : 28 类顶点（37 个实例） + 60 类边（60 条实例，覆盖全部边类型）
// 时间   : 2026-10-16
// 数据为演示用构造样例，非真实业务数据
// =============================================================================


// =============================================================================
// 一、顶点（VERTEX）
// =============================================================================

// ---------- 1. 二级单位规范简称 ----------
MERGE (n:ZSTP:`二级单位规范简称` {object_key:'EJDW_BJDL'})
SET n.short_name      = '北京电力',
    n.notice_name     = '国家电投集团北京电力有限公司',
    n.period_history  = '',
    n.org_unique_code = 'BJDL_001',
    n.doc_num         = '国家电投人〔2020〕12号',
    n.send_time       = datetime('2020-03-01T00:00:00'),
    n.schema_name     = 'dws_dsjsj_zstp_vertex_ejdwgfjc';

// ---------- 2. 企业 ----------
MERGE (n:ZSTP:`企业` {object_key:'QY_BJDL'})
SET n.org_name           = '国家电投集团北京电力有限公司',
    n.org_credit_code    = '91110000100000001X',
    n.mdg_code           = 'MDG0001',
    n.mdg_name           = '国家电投集团北京电力有限公司',
    n.secondary_org_code = 'BJDL',
    n.secondary_org_name = '北京电力',
    n.companyorgtype     = '有限责任公司',
    n.regstatus          = '存续',
    n.reglocation        = '北京市西城区金融大街',
    n.businessscope      = '电力生产、热力生产与供应；电力设施承装、承修、承试。',
    n.estiblishtime      = datetime('2003-06-18T00:00:00'),
    n.socialstaffnum     = 5231,
    n.phonenumber        = '010-88886666',
    n.organizationlevel  = '二级单位',
    n.sfgq               = '是',
    n.flag_gdtqy         = '是',
    n.flag_cg            = '是',
    n.flag_kg            = '否',
    n.sfkh               = '否',
    n.sfgys              = '否',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_qy';

MERGE (n:ZSTP:`企业` {object_key:'QY_XNY'})
SET n.org_name           = '国电投新能源科技有限公司',
    n.org_credit_code    = '91110000100000002X',
    n.mdg_code           = 'MDG0002',
    n.mdg_name           = '国电投新能源科技有限公司',
    n.secondary_org_code = 'BJDL',
    n.secondary_org_name = '北京电力',
    n.companyorgtype     = '有限责任公司',
    n.regstatus          = '存续',
    n.reglocation        = '北京市昌平区科技园',
    n.businessscope      = '新能源发电技术开发、技术服务；光伏、风电项目投资。',
    n.estiblishtime      = datetime('2015-09-01T00:00:00'),
    n.socialstaffnum     = 386,
    n.phonenumber        = '010-88886002',
    n.organizationlevel  = '三级单位',
    n.sfgq               = '是',
    n.flag_gdtqy         = '是',
    n.flag_cg            = '是',
    n.flag_kg            = '否',
    n.sfkh               = '否',
    n.sfgys              = '否',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_qy';

MERGE (n:ZSTP:`企业` {object_key:'QY_HXJS'})
SET n.org_name           = '华信建设工程集团有限公司',
    n.org_credit_code    = '91110000100000003X',
    n.mdg_code           = 'MDG0003',
    n.mdg_name           = '华信建设工程集团有限公司',
    n.companyorgtype     = '有限责任公司',
    n.regstatus          = '存续',
    n.reglocation        = '北京市朝阳区建国路',
    n.businessscope      = '建设工程施工；电力工程施工；机电设备安装。',
    n.estiblishtime      = datetime('2008-04-10T00:00:00'),
    n.socialstaffnum     = 1280,
    n.phonenumber        = '010-66668888',
    n.sfgq               = '否',
    n.flag_gdtqy         = '否',
    n.flag_cg            = '否',
    n.flag_kg            = '否',
    n.sfkh               = '否',
    n.sfgys              = '是',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_qy';

MERGE (n:ZSTP:`企业` {object_key:'QY_ZYWL'})
SET n.org_name           = '中远物流服务有限公司',
    n.org_credit_code    = '91110000100000004X',
    n.mdg_code           = 'MDG0004',
    n.mdg_name           = '中远物流服务有限公司',
    n.companyorgtype     = '有限责任公司',
    n.regstatus          = '存续',
    n.reglocation        = '天津市滨海新区',
    n.businessscope      = '普通货物运输；仓储服务；供应链管理服务。',
    n.estiblishtime      = datetime('2011-11-20T00:00:00'),
    n.socialstaffnum     = 640,
    n.phonenumber        = '022-58889999',
    n.sfgq               = '否',
    n.flag_gdtqy         = '否',
    n.flag_cg            = '否',
    n.flag_kg            = '否',
    n.sfkh               = '是',
    n.sfgys              = '是',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_qy';

MERGE (n:ZSTP:`企业` {object_key:'QY_HBJD'})
SET n.org_name           = '华北电力设备制造有限公司',
    n.org_credit_code    = '91110000100000005X',
    n.mdg_code           = 'MDG0005',
    n.mdg_name           = '华北电力设备制造有限公司',
    n.companyorgtype     = '有限责任公司',
    n.regstatus          = '存续',
    n.reglocation        = '河北省保定市',
    n.businessscope      = '高低压开关设备、变压器的制造与销售。',
    n.estiblishtime      = datetime('2005-05-16T00:00:00'),
    n.socialstaffnum     = 890,
    n.phonenumber        = '0312-3336666',
    n.sfgq               = '否',
    n.flag_gdtqy         = '否',
    n.flag_cg            = '否',
    n.flag_kg            = '否',
    n.sfkh               = '否',
    n.sfgys              = '是',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_qy';

// ---------- 3. 自然人 ----------
MERGE (n:ZSTP:`自然人` {object_key:'ZRR_ZW'})
SET n.name                    = '张伟',
    n.emp_code                = 'E10001',
    n.post_name               = '董事长',
    n.is_key_person           = '是',
    n.is_history_key_person   = '否',
    n.is_emp                  = '是',
    n.work_status             = '在岗',
    n.source_system           = 'HR',
    n.schema_name             = 'dws_dsjsj_zstp_vertex_zrr';

MERGE (n:ZSTP:`自然人` {object_key:'ZRR_LQ'})
SET n.name                    = '李强',
    n.emp_code                = 'E10086',
    n.post_name               = '董事、总经理',
    n.is_key_person           = '是',
    n.is_history_key_person   = '否',
    n.is_emp                  = '是',
    n.work_status             = '在岗',
    n.source_system           = 'HR',
    n.schema_name             = 'dws_dsjsj_zstp_vertex_zrr';

MERGE (n:ZSTP:`自然人` {object_key:'ZRR_WF'})
SET n.name                    = '王芳',
    n.emp_code                = '',
    n.post_name               = '',
    n.is_key_person           = '否',
    n.is_history_key_person   = '否',
    n.is_emp                  = '否',
    n.work_status             = '',
    n.source_system           = 'MDG',
    n.schema_name             = 'dws_dsjsj_zstp_vertex_zrr';

// ---------- 4. 合同 ----------
MERGE (n:ZSTP:`合同` {object_key:'HT_001'})
SET n.contract_code      = 'HT-2024-BJDL-001',
    n.contract_name      = '北京电力2024年度电气设备采购合同',
    n.gategory_name      = '采购类合同',
    n.category_code      = 'CG',
    n.status_name        = '已生效',
    n.payment_direction  = '付款',
    n.contract_amount    = 12000000.0,
    n.sign_time          = datetime('2024-03-15T00:00:00'),
    n.sfjrlht            = '否',
    n.sfdblht            = '否',
    n.sfzxsppdylht       = '否',
    n.mdg_orgcode        = 'MDG0001',
    n.mdg_orgname        = '国家电投集团北京电力有限公司',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_ht';

MERGE (n:ZSTP:`合同` {object_key:'HT_002'})
SET n.contract_code      = 'HT-2024-XNY-002',
    n.contract_name      = '新能源科技升压站施工合同',
    n.gategory_name      = '工程类合同',
    n.category_code      = 'GC',
    n.status_name        = '履行中',
    n.payment_direction  = '付款',
    n.contract_amount    = 8600000.0,
    n.sign_time          = datetime('2024-05-20T00:00:00'),
    n.sfjrlht            = '否',
    n.sfdblht            = '否',
    n.sfzxsppdylht       = '是',
    n.mdg_orgcode        = 'MDG0002',
    n.mdg_orgname        = '国电投新能源科技有限公司',
    n.sourcesystem       = 'MDG',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_ht';

// ---------- 5. 标段 ----------
MERGE (n:ZSTP:`标段` {object_key:'BD_001'})
SET n.packno            = 'BD-2024-BJDL-001',
    n.packname          = '北京电力2024年第一批电气设备采购标段',
    n.tenderno          = 'ZB-2024-BJDL-001',
    n.tendername        = '北京电力2024年第一批设备招标项目',
    n.procurementmethod = '公开招标',
    n.tendermethod      = '资格后审',
    n.packid            = 'PK202403001',
    n.createtime        = datetime('2024-03-01T09:00:00'),
    n.maxlimitprice     = '15000000',
    n.system_source     = '招采平台',
    n.schema_name       = 'dws_dsjsj_zstp_vertex_bd';

// ---------- 6. 发票 ----------
MERGE (n:ZSTP:`发票` {object_key:'FP_001'})
SET n.fp_hm        = '11001234',
    n.fplx         = '增值税专用发票',
    n.kprq         = datetime('2024-04-10T00:00:00'),
    n.fpje         = '1356000',
    n.fpse         = '176280',
    n.jshj         = '1532280',
    n.xmmc         = '高压开关柜',
    n.taxpayer     = '91110000100000003X',
    n.system_source = '税务',
    n.schema_name  = 'dws_dsjsj_zstp_vertex_fp';

MERGE (n:ZSTP:`发票` {object_key:'FP_002'})
SET n.fp_hm        = '11001235',
    n.fplx         = '增值税专用发票',
    n.kprq         = datetime('2024-05-28T00:00:00'),
    n.fpje         = '800000',
    n.fpse         = '104000',
    n.jshj         = '904000',
    n.xmmc         = '高压开关柜',
    n.taxpayer     = '91110000100000005X',
    n.system_source = '税务',
    n.schema_name  = 'dws_dsjsj_zstp_vertex_fp';

// ---------- 7. 资金流水 ----------
MERGE (n:ZSTP:`资金流水` {object_key:'ZJLS_001'})
SET n.bill_num      = '20240601001',
    n.tran_amt      = 1532280.0,
    n.trade_dir     = '支出',
    n.TRANS_TIME    = datetime('2024-06-01T10:30:00'),
    n.SUMMARY       = '支付华信建设设备采购款',
    n.system_source = '资金管理系统',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_zjls';

// ---------- 8. 银行账户 ----------
MERGE (n:ZSTP:`银行账户` {object_key:'YHZH_001'})
SET n.acc_name      = '国家电投集团北京电力有限公司',
    n.bank_acc_no   = '6222020200012345',
    n.nam_dep_ban   = '中国工商银行北京金融街支行',
    n.use_state     = '正常',
    n.system_source = '资金管理系统',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_yhzh';

MERGE (n:ZSTP:`银行账户` {object_key:'YHZH_002'})
SET n.acc_name      = '华信建设工程集团有限公司',
    n.bank_acc_no   = '6222020200054321',
    n.nam_dep_ban   = '中国建设银行北京朝阳支行',
    n.use_state     = '正常',
    n.system_source = '资金管理系统',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_yhzh';

// ---------- 9. 财务凭证 ----------
MERGE (n:ZSTP:`财务凭证` {object_key:'CWPZ_001'})
SET n.POST_BH       = 'JZ2024060001',
    n.START_DATE    = datetime('2024-06-01T00:00:00'),
    n.REG_DATE      = datetime('2024-06-02T00:00:00'),
    n.DESCRIPTION   = '支付华信建设设备采购款',
    n.CR_BALANCE    = 0.0,
    n.DR_BALANCE    = 1532280.0,
    n.source_system = '财务共享',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_cwpz';

// ---------- 10. 物料 ----------
MERGE (n:ZSTP:`物料` {object_key:'WL_001'})
SET n.matnr        = 'M-100001',
    n.maktx        = '高压开关柜',
    n.sourcesystem = 'ERP',
    n.schema_name  = 'dws_dsjsj_zstp_vertex_wl';

// ---------- 11. 入库 ----------
MERGE (n:ZSTP:`入库` {object_key:'RK_001'})
SET n.mblnr        = '4900012345',
    n.menge        = '20',
    n.charg        = '自有库存',
    n.budat        = datetime('2024-04-15T00:00:00'),
    n.elikz        = '已完成',
    n.lfart_desc   = '采购入库',
    n.umlgo        = '北京中心库',
    n.sourcesystem = 'ERP',
    n.schema_name  = 'dws_dsjsj_zstp_vertex_rk';

// ---------- 12. 出库 ----------
MERGE (n:ZSTP:`出库` {object_key:'CK_001'})
SET n.vbeln         = '80001234',
    n.meins         = '10',
    n.wadat_ist     = datetime('2024-06-05T00:00:00'),
    n.wbstk         = '已完成',
    n.lfart         = '销售出库',
    n.lgort         = '北京中心库',
    n.source_system = 'ERP',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_ck';

// ---------- 13. 金融类项目 ----------
MERGE (n:ZSTP:`金融类项目` {object_key:'JRLXM_001'})
SET n.id                    = 'JR-2024-001',
    n.deal_name             = '国电投新能源产业基金投资项目',
    n.deal_type2            = '股权投资',
    n.deal_status           = '进行中',
    n.end_time_             = datetime('2024-02-01T00:00:00'),
    n.actual_payment_money  = 50000000.0,
    n.system_source         = '投资管理',
    n.schema_name           = 'dws_dsjsj_zstp_vertex_jrlxm';

// ---------- 14. 其他类项目 ----------
MERGE (n:ZSTP:`其他类项目` {object_key:'QTLXM_001'})
SET n.item_id            = 'QT-2024-001',
    n.item_name          = '北京电力智慧运维平台建设项目',
    n.item_type          = '信息化',
    n.ini_status         = '已立项',
    n.init_date          = datetime('2024-01-20T00:00:00'),
    n.depname            = '科技信息部',
    n.ass_capltal_money  = 3200000.0,
    n.sourcesystem       = '投资管理',
    n.schema_name        = 'dws_dsjsj_zstp_vertex_qtlxm';

// ---------- 15. 基建类项目 ----------
MERGE (n:ZSTP:`基建类项目` {object_key:'JJLXM_001'})
SET n.proj_code            = 'JJ-2024-001',
    n.proj_name            = '北京电力昌平光伏电站建设项目',
    n.proposal_code        = 'LX-2024-001',
    n.full_name            = '北京市',
    n.proj_status_name     = '在建',
    n.actual_start_time    = datetime('2024-03-01T00:00:00'),
    n.investment_type_name = '固定资产投资项目',
    n.proj_stage_name      = '施工阶段',
    n.industry_type_name   = '新能源发电',
    n.investment_amount    = 260000000.0,
    n.lyxt                 = '投资管理',
    n.schema_name          = 'dws_dsjsj_zstp_vertex_jjlxm';

// ---------- 16. 电能e购订单 ----------
MERGE (n:ZSTP:`电能e购订单` {object_key:'DNYGDD_001'})
SET n.order_no       = 20240600001,
    n.order_status   = '已完成',
    n.order_time     = datetime('2024-05-25T14:00:00'),
    n.amount_type_id = '设备采购',
    n.final_price    = 904000.0,
    n.system_source  = '电能e购',
    n.schema_name    = 'dws_dsjsj_zstp_vertex_dnygdd';

// ---------- 17. 信托产品 ----------
MERGE (n:ZSTP:`信托产品` {object_key:'XTCP_001'})
SET n.PRODUCT_CODE    = 'XT-2024-0001',
    n.PRODUCT_NAME    = '国电投新能源1号集合资金信托计划',
    n.PRODUCT_MONEY   = 100000000.0,
    n.START_DATE      = datetime('2024-02-15T00:00:00'),
    n.END_DATE        = datetime('2026-02-15T00:00:00'),
    n.CP_STATUS_NAME  = '存续',
    n.system_source   = '金融管理',
    n.schema_name     = 'dws_dsjsj_zstp_vertex_xtcp';

// ---------- 18. 信托底层资产 ----------
MERGE (n:ZSTP:`信托底层资产` {object_key:'XTDCZC_001'})
SET n.param_name    = '新能源电站收益权',
    n.dczcbcms      = '以昌平光伏电站电费收益权作为底层资产',
    n.zcqdfs        = '收益权受让',
    n.syqbizc       = '昌平光伏电站电费收益权',
    n.system_source = '金融管理',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_xtdczc';

// ---------- 19. 云链签发账单 ----------
MERGE (n:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'})
SET n.ini_bill_id   = '',
    n.bill_no       = 'YQFQ-2024-0001',
    n.bill_amt      = '12000000',
    n.bill_balan    = '12000000',
    n.bill_begin_dt = '2024-03-20',
    n.rpay_dt       = '',
    n.bill_over_dt  = '2024-09-20',
    n.bill_status   = '已签发',
    n.trx_type      = '签发',
    n.system_source = '云链平台',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_ylqfqszd';

// ---------- 20. 云链转让账单 ----------
MERGE (n:ZSTP:`云链转让账单` {object_key:'YLZR_001'})
SET n.ini_bill_id   = 'YQFQ-2024-0001',
    n.bill_no       = 'YZR-2024-0001',
    n.bill_amt      = '12000000',
    n.bill_balan    = '11000000',
    n.bill_begin_dt = '2024-04-01',
    n.rpay_dt       = '',
    n.bill_over_dt  = '2024-09-20',
    n.bill_status   = '已转让',
    n.trx_type      = '转让',
    n.system_source = '云链平台',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_ylzrzd';

// ---------- 21. 云链融资账单 ----------
MERGE (n:ZSTP:`云链融资账单` {object_key:'YLRZ_001'})
SET n.ini_bill_id       = 'YQFQ-2024-0001',
    n.sub_bill_id       = 'YRZ-2024-0001',
    n.lvrg_prod_name    = '云链保理融资',
    n.bill_amt          = 12000000.0,
    n.bill_balan        = 11000000.0,
    n.intr              = 330000.0,
    n.finance_days      = 180.0,
    n.lvrg_intr_rate    = 5.5,
    n.total_finance_fee = 330000.0,
    n.total_finance_rate= 5.5,
    n.pay_intr_method   = '到期一次还本付息',
    n.lvrg_apply_dt_f   = datetime('2024-04-05T00:00:00'),
    n.dtrb_dt_f         = datetime('2024-04-08T00:00:00'),
    n.dtrb_dt_s         = datetime('2024-04-10T00:00:00'),
    n.bill_over_dt_f    = datetime('2024-10-05T00:00:00'),
    n.rpay_dt_f         = datetime('2024-10-05T00:00:00'),
    n.org_ali_pmt_amt   = 11660000.0,
    n.trx_type          = '融资',
    n.bill_status       = '存续',
    n.system_source     = '云链平台',
    n.schema_name       = 'dws_dsjsj_zstp_vertex_ylrzzd';

// ---------- 22. 风险线索 ----------
MERGE (n:ZSTP:`风险线索` {object_key:'FXXS_001'})
SET n.risk_type    = '隐性关联关系',
    n.risk_desc    = 'IF 供应商与二级单位存在共同联系人 AND 中标金额占比超过阈值 AND 存在资金往来 THEN 命中隐性关联风险',
    n.risk_summary = '华信建设与北京电力存在疑似隐性关联，涉及标段BD-2024-BJDL-001',
    n.schema_name  = 'dws_dsjsj_zstp_vertex_fxxs';

// ---------- 23. 法律诉讼 ----------
MERGE (n:ZSTP:`法律诉讼` {object_key:'FLSS_001'})
SET n.case_no       = '(2024)京0105民初12345号',
    n.title         = '华信建设与某供应商买卖合同纠纷',
    n.case_type     = '民事案件',
    n.case_reason   = '买卖合同纠纷',
    n.case_money    = '3500000',
    n.judge_time    = datetime('2024-07-10T00:00:00'),
    n.court         = '北京市朝阳区人民法院',
    n.submit_time   = datetime('2024-07-15T00:00:00'),
    n.system_source = '司法数据',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_flss';

// ---------- 24. 破产重整 ----------
MERGE (n:ZSTP:`破产重整` {object_key:'PCCZ_001'})
SET n.case_no       = '(2024)冀06破申5号',
    n.case_type     = '破产重整',
    n.submit_time   = datetime('2024-02-28T00:00:00'),
    n.system_source = '司法数据',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_pccz';

// ---------- 25. 行政处罚 ----------
MERGE (n:ZSTP:`行政处罚` {object_key:'XZCF_001'})
SET n.punish_name     = '安全生产违规处罚',
    n.punish_number   = '京应急罚〔2024〕008号',
    n.decision_date   = datetime('2024-04-18T00:00:00'),
    n.department_name = '北京市应急管理局',
    n.reason          = '施工现场安全防护措施不到位',
    n.content         = '罚款人民币30万元',
    n.evidence        = '《安全生产法》第九十六条',
    n.syetem_source   = '信用中国',
    n.schema_name     = 'dws_dsjsj_zstp_vertex_xzcf';

// ---------- 26. 失信被执行人 ----------
MERGE (n:ZSTP:`失信被执行人` {object_key:'SXBZXR_001'})
SET n.type            = '法人或其他组织',
    n.casecode        = '(2024)京0105执9876号',
    n.disrupttypename = '有履行能力而拒不履行生效法律文书确定义务',
    n.performance     = '全部未履行',
    n.regdate         = datetime('2024-06-20T00:00:00'),
    n.publishdate     = datetime('2024-06-25T00:00:00'),
    n.gistunit        = '北京市朝阳区人民法院',
    n.system_source   = '信用中国',
    n.schema_name     = 'dws_dsjsj_zstp_vertex_sxbzxr';

// ---------- 27. 决策会议 ----------
MERGE (n:ZSTP:`决策会议` {object_key:'JCHY_001'})
SET n.meeting_name  = '北京电力2024年第3次投资决策会议',
    n.meeting_code  = 'JCHY-2024-003',
    n.meeting_date  = datetime('2024-02-05T09:00:00'),
    n.type_name     = '投资决策会',
    n.system_source = 'OA',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_jchy';

// ---------- 28. 决策会议议题 ----------
MERGE (n:ZSTP:`决策会议议题` {object_key:'JCHYYT_001'})
SET n.subject_name  = '关于国电投新能源科技有限公司股权投资的议题',
    n.subject_code  = 'YT-2024-003-01',
    n.pass_flag     = '通过',
    n.system_source = 'OA',
    n.schema_name   = 'dws_dsjsj_zstp_vertex_jchyyt';


// =============================================================================
// 二、边（EDGE）—— 60 类全部覆盖
// =============================================================================

// ---------- 1. 二级单位规范简称 -[对应企业]-> 企业 ----------
MATCH (a:ZSTP:`二级单位规范简称` {object_key:'EJDW_BJDL'}), (b:ZSTP:`企业` {object_key:'QY_BJDL'})
MERGE (a)-[r:`对应企业` {object_key:'E_EJDW_DYQY_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ejdwgfjc_dyqy';

// ---------- 2. 企业 -[股东持股（%）企业-企业]-> 企业 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`企业` {object_key:'QY_XNY'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'E_QY_GDCGBFB_0001'}]->(b)
SET r.sflsgd                = '否',
    r.ft_shareholding       = datetime('2015-09-01T00:00:00'),
    r.capital_amomon        = '300000000',
    r.capital_percent       = '100',
    r.capital_time          = datetime('2015-08-20T00:00:00'),
    r.capital_actl_amomon   = '300000000',
    r.capital_actl_percent  = '100',
    r.capital_actl_time     = datetime('2015-09-10T00:00:00'),
    r.capital_actl_paymet   = '货币出资',
    r.schema_name           = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

// ---------- 3. 自然人 -[股东持股（%）企业-自然人]-> 企业 ----------
MATCH (a:ZSTP:`自然人` {object_key:'ZRR_WF'}), (b:ZSTP:`企业` {object_key:'QY_XNY'})
MERGE (a)-[r:`股东持股（%）企业-自然人` {object_key:'E_ZRR_GDCGQY_0001'}]->(b)
SET r.ft_shareholding         = datetime('2015-08-20T00:00:00'),
    r.capital_amomon          = '1000000',
    r.capital_percent         = '5',
    r.capital_time            = datetime('2015-08-20T00:00:00'),
    r.capital_actl_amomon     = '1000000',
    r.capital_actl_percent    = '5',
    r.capital_actl_time       = datetime('2015-09-10T00:00:00'),
    r.capital_actl_paymet     = '货币出资',
    r.is_history_shareholder  = '否',
    r.history_ft_shareholding = datetime('2015-08-20T00:00:00'),
    r.schema_name             = 'dws_dsjsj_zstp_edge_zrr_gdcgqy';

// ---------- 4. 企业 -[签订合同]-> 合同 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`合同` {object_key:'HT_001'})
MERGE (a)-[r:`签订合同` {object_key:'E_QY_QD_0001'}]->(b)
SET r.contract_amount = '12000000',
    r.contract_status = '已生效',
    r.sign_time       = datetime('2024-03-15T00:00:00'),
    r.schema_name     = 'dws_dsjsj_zstp_edge_qy_qd';

// ---------- 5. 标段 -[隶属合同]-> 合同 ----------
MATCH (a:ZSTP:`标段` {object_key:'BD_001'}), (b:ZSTP:`合同` {object_key:'HT_001'})
MERGE (a)-[r:`隶属合同` {object_key:'E_BD_LSHT_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_bd_lsht';

// ---------- 6. 企业 -[发布标段]-> 标段 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`标段` {object_key:'BD_001'})
MERGE (a)-[r:`发布标段` {object_key:'E_QY_FB_0001'}]->(b)
SET r.createtime  = datetime('2024-03-01T09:00:00'),
    r.schema_name = 'dws_dsjsj_zstp_edge_qy_fb';

// ---------- 7. 企业 -[参与投标]-> 标段 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`标段` {object_key:'BD_001'})
MERGE (a)-[r:`参与投标` {object_key:'E_QY_CY_0001'}]->(b)
SET r.createtime  = datetime('2024-03-10T10:00:00'),
    r.final_price = 11800000.0,
    r.schema_name = 'dws_dsjsj_zstp_edge_qy_cy';

// ---------- 8. 企业 -[中标]-> 标段 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`标段` {object_key:'BD_001'})
MERGE (a)-[r:`中标` {object_key:'E_QY_ZB_0001'}]->(b)
SET r.bid_send_time = datetime('2024-03-12T16:00:00'),
    r.finalprice    = '11800000',
    r.schema_name   = 'dws_dsjsj_zstp_edge_qy_zb';

// ---------- 9. 企业 -[上传/下载标书]-> 标段 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`标段` {object_key:'BD_001'})
MERGE (a)-[r:`上传/下载标书` {object_key:'E_QY_SCXZBS_0001'}]->(b)
SET r.ip          = '10.20.31.18',
    r.iptag       = '上传',
    r.rel_time    = datetime('2024-03-09T11:22:00'),
    r.schema_name = 'dws_dsjsj_zstp_edge_qy_scxzbs';

// ---------- 10. 企业 -[产生发票_企业]-> 发票 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`发票` {object_key:'FP_001'})
MERGE (a)-[r:`产生发票_企业` {object_key:'E_QY_CSFP_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_csfp';

// ---------- 11. 企业 -[开具接收发票]-> 发票 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`发票` {object_key:'FP_001'})
MERGE (a)-[r:`开具接收发票` {object_key:'E_QY_KJJSFP_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_kjjsfp';

// ---------- 12. 电能e购订单 -[产生发票]-> 发票 ----------
MATCH (a:ZSTP:`电能e购订单` {object_key:'DNYGDD_001'}), (b:ZSTP:`发票` {object_key:'FP_002'})
MERGE (a)-[r:`产生发票` {object_key:'E_DNEGDD_CSFP_0001'}]->(b)
SET r.real_invoice_time = datetime('2024-05-28T00:00:00'),
    r.HJJE              = '904000',
    r.schema_name       = 'dws_dsjsj_zstp_edge_dnegdd_csfp';

// ---------- 13. 合同 -[派生订单]-> 电能e购订单 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_001'}), (b:ZSTP:`电能e购订单` {object_key:'DNYGDD_001'})
MERGE (a)-[r:`派生订单` {object_key:'E_HT_PSDD_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_psdd';

// ---------- 14. 企业 -[发起订单]-> 电能e购订单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_ZYWL'}), (b:ZSTP:`电能e购订单` {object_key:'DNYGDD_001'})
MERGE (a)-[r:`发起订单` {object_key:'E_QY_FQDD_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_fqdd';

// ---------- 15. 企业 -[拥有账户]-> 银行账户 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`银行账户` {object_key:'YHZH_001'})
MERGE (a)-[r:`拥有账户` {object_key:'E_QY_YYZH_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_yyzh';

// ---------- 16. 银行账户 -[交易]-> 银行账户 ----------
MATCH (a:ZSTP:`银行账户` {object_key:'YHZH_001'}), (b:ZSTP:`银行账户` {object_key:'YHZH_002'})
MERGE (a)-[r:`交易` {object_key:'E_YHZH_JY_0001'}]->(b)
SET r.trans_time  = datetime('2024-06-01T10:30:00'),
    r.tran_amt    = 1532280.0,
    r.abstract    = '设备采购款支付',
    r.schema_name = 'dws_dsjsj_zstp_edge_yhzh_jy';

// ---------- 17. 企业 -[企业收款/付款]-> 资金流水 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_ZYWL'}), (b:ZSTP:`资金流水` {object_key:'ZJLS_001'})
MERGE (a)-[r:`企业收款/付款` {object_key:'E_QY_SKFK_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_skfk';

// ---------- 18. 合同 -[合同收款/付款]-> 资金流水 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_001'}), (b:ZSTP:`资金流水` {object_key:'ZJLS_001'})
MERGE (a)-[r:`合同收款/付款` {object_key:'E_HT_SKFK_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_skfk';

// ---------- 19. 发票 -[依据发票收款/付款]-> 资金流水 ----------
MATCH (a:ZSTP:`发票` {object_key:'FP_001'}), (b:ZSTP:`资金流水` {object_key:'ZJLS_001'})
MERGE (a)-[r:`依据发票收款/付款` {object_key:'E_FP_YJFPSKFK_0001'}]->(b)
SET r.invoice_no   = '11001234',
    r.invoice_date = datetime('2024-04-10T00:00:00'),
    r.bill_num     = '20240601001',
    r.schema_name  = 'dws_dsjsj_zstp_edge_fp_yjfpskfk';

// ---------- 20. 资金流水 -[资金流水收款/付款账号]-> 银行账户 ----------
MATCH (a:ZSTP:`资金流水` {object_key:'ZJLS_001'}), (b:ZSTP:`银行账户` {object_key:'YHZH_001'})
MERGE (a)-[r:`资金流水收款/付款账号` {object_key:'E_ZJLS_ZJLSSKFKZH_0001'}]->(b)
SET r.bank_acc_no   = '6222020200012345',
    r.trans_time    = datetime('2024-06-01T10:30:00'),
    r.tran_uni_cod  = 'TRX2024060100001',
    r.schema_name   = 'dws_dsjsj_zstp_edge_zjls_zjlsskfkzh';

// ---------- 21. 资金流水 -[生成凭证]-> 财务凭证 ----------
MATCH (a:ZSTP:`资金流水` {object_key:'ZJLS_001'}), (b:ZSTP:`财务凭证` {object_key:'CWPZ_001'})
MERGE (a)-[r:`生成凭证` {object_key:'E_ZJLS_SCPZ_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_zjls_scpz';

// ---------- 22. 合同 -[按采购合同入库]-> 入库 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_001'}), (b:ZSTP:`入库` {object_key:'RK_001'})
MERGE (a)-[r:`按采购合同入库` {object_key:'E_HT_ACGHTRK_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_acghtrk';

// ---------- 23. 合同 -[按销售合同出库]-> 出库 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_002'}), (b:ZSTP:`出库` {object_key:'CK_001'})
MERGE (a)-[r:`按销售合同出库` {object_key:'E_HT_AXSHTCK_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_axshtck';

// ---------- 24. 物料 -[领用物料]-> 入库 ----------
MATCH (a:ZSTP:`物料` {object_key:'WL_001'}), (b:ZSTP:`入库` {object_key:'RK_001'})
MERGE (a)-[r:`领用物料` {object_key:'E_WL_LYWL_0001'}]->(b)
SET r.name1       = '北京中心库',
    r.werks       = 'CN01',
    r.lgobe       = '北京中心库',
    r.cputm       = datetime('2024-04-15T00:00:00'),
    r.schema_name = 'dws_dsjsj_zstp_edge_wl_lywl';

// ---------- 25. 物料 -[消耗物料]-> 出库 ----------
MATCH (a:ZSTP:`物料` {object_key:'WL_001'}), (b:ZSTP:`出库` {object_key:'CK_001'})
MERGE (a)-[r:`消耗物料` {object_key:'E_WL_XHWL_0001'}]->(b)
SET r.name1       = '北京中心库',
    r.werks       = 'CN01',
    r.lgobe       = '北京中心库',
    r.erdat       = datetime('2024-06-05T00:00:00'),
    r.schema_name = 'dws_dsjsj_zstp_edge_wl_xhwl';

// ---------- 26. 合同 -[同一标的物关联_合同]-> 合同 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_001'}), (b:ZSTP:`合同` {object_key:'HT_002'})
MERGE (a)-[r:`同一标的物关联_合同` {object_key:'E_HT_TYBDWGL_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_tybdwgl';

// ---------- 27. 发票 -[同一标的物关联]-> 发票 ----------
MATCH (a:ZSTP:`发票` {object_key:'FP_001'}), (b:ZSTP:`发票` {object_key:'FP_002'})
MERGE (a)-[r:`同一标的物关联` {object_key:'E_FP_TYBDWGL_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_fp_tybdwgl';

// ---------- 28. 企业 -[发起项目_金融]-> 金融类项目 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`金融类项目` {object_key:'JRLXM_001'})
MERGE (a)-[r:`发起项目_金融` {object_key:'E_QY_FQXM_JRLXM_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_fqxm_jrlxm';

// ---------- 29. 企业 -[发起项目_其他]-> 其他类项目 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`其他类项目` {object_key:'QTLXM_001'})
MERGE (a)-[r:`发起项目_其他` {object_key:'E_QY_FQXM_QTLXM_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_fqxm_qtlxm';

// ---------- 30. 企业 -[发起项目_基建]-> 基建类项目 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`基建类项目` {object_key:'JJLXM_001'})
MERGE (a)-[r:`发起项目_基建` {object_key:'E_QY_FQXM_JJLXM_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_fqxm_jjlxm';

// ---------- 31. 金融类项目 -[穿透]-> 信托底层资产 ----------
MATCH (a:ZSTP:`金融类项目` {object_key:'JRLXM_001'}), (b:ZSTP:`信托底层资产` {object_key:'XTDCZC_001'})
MERGE (a)-[r:`穿透` {object_key:'E_JRLXM_CT_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_jrlxm_ct';

// ---------- 32. 金融类项目 -[投向]-> 信托产品 ----------
MATCH (a:ZSTP:`金融类项目` {object_key:'JRLXM_001'}), (b:ZSTP:`信托产品` {object_key:'XTCP_001'})
MERGE (a)-[r:`投向` {object_key:'E_JRLXM_TX_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_edge_jrlxm_tx';

// ---------- 33. 企业 -[发起决策会议]-> 决策会议 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_BJDL'}), (b:ZSTP:`决策会议` {object_key:'JCHY_001'})
MERGE (a)-[r:`发起决策会议` {object_key:'E_QY_FQJCHY_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_fqjchy';

// ---------- 34. 决策会议 -[会议讨论议题]-> 决策会议议题 ----------
MATCH (a:ZSTP:`决策会议` {object_key:'JCHY_001'}), (b:ZSTP:`决策会议议题` {object_key:'JCHYYT_001'})
MERGE (a)-[r:`会议讨论议题` {object_key:'E_JCHY_HYTLYT_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_jchy_hytlyt';

// ---------- 35. 决策会议议题 -[决策项目_基建类项目]-> 基建类项目 ----------
MATCH (a:ZSTP:`决策会议议题` {object_key:'JCHYYT_001'}), (b:ZSTP:`基建类项目` {object_key:'JJLXM_001'})
MERGE (a)-[r:`决策项目_基建类项目` {object_key:'E_JCHYYT_JJLXM_0001'}]->(b)
SET r.subject_name = '北京电力昌平光伏电站建设项目',
    r.schema_name  = 'dws_dsjsj_edge_jchyyt_jjlxm';

// ---------- 36. 决策会议议题 -[决策项目_其他类项目]-> 其他类项目 ----------
MATCH (a:ZSTP:`决策会议议题` {object_key:'JCHYYT_001'}), (b:ZSTP:`其他类项目` {object_key:'QTLXM_001'})
MERGE (a)-[r:`决策项目_其他类项目` {object_key:'E_JCHYYT_QTLXM_0001'}]->(b)
SET r.subject_name = '北京电力智慧运维平台建设项目',
    r.schema_name  = 'dws_dsjsj_zstp_edge_jchyyt_qtlxm';

// ---------- 37. 决策会议议题 -[决策项目_金融类项目]-> 金融类项目 ----------
MATCH (a:ZSTP:`决策会议议题` {object_key:'JCHYYT_001'}), (b:ZSTP:`金融类项目` {object_key:'JRLXM_001'})
MERGE (a)-[r:`决策项目_金融类项目` {object_key:'E_JCHYYT_JRLXM_0001'}]->(b)
SET r.subject_name = '关于国电投新能源产业基金投资项目的议题',
    r.schema_name  = 'dws_dsjsj_zstp_edge_jchyyt_jrlxm';

// ---------- 38. 自然人 -[参与议题]-> 决策会议议题 ----------
MATCH (a:ZSTP:`自然人` {object_key:'ZRR_LQ'}), (b:ZSTP:`决策会议议题` {object_key:'JCHYYT_001'})
MERGE (a)-[r:`参与议题` {object_key:'E_ZRR_CYYT_0001'}]->(b)
SET r.attendance_ame = '李强',
    r.position       = '总经理',
    r.schema_name    = 'dws_dsjsj_zstp_edge_zrr_cyyt';

// ---------- 39. 自然人 -[担任/曾任企业法人]-> 企业 ----------
MATCH (a:ZSTP:`自然人` {object_key:'ZRR_ZW'}), (b:ZSTP:`企业` {object_key:'QY_XNY'})
MERGE (a)-[r:`担任/曾任企业法人` {object_key:'E_ZRR_DRCRQYFR_0001'}]->(b)
SET r.is_current_legal_person = '是',
    r.is_history_legal_person = '否',
    r.schema_name             = 'dws_dsjsj_zstp_edge_zrr_drcrqyfr';

// ---------- 40. 自然人 -[担任/曾任企业高管]-> 企业 ----------
MATCH (a:ZSTP:`自然人` {object_key:'ZRR_LQ'}), (b:ZSTP:`企业` {object_key:'QY_HXJS'})
MERGE (a)-[r:`担任/曾任企业高管` {object_key:'E_ZRR_RZQY_0001'}]->(b)
SET r.position              = '董事',
    r.term                  = '2022-2025',
    r.history_position      = '',
    r.history_term          = '',
    r.is_history_key_person = '否',
    r.report_date           = datetime('2022-06-30T00:00:00'),
    r.schema_name           = 'dws_dsjsj_zstp_edge_zrr_rzqy';

// ---------- 41. 合同 -[采购合同生成签发账单]-> 云链签发账单 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_001'}), (b:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'})
MERGE (a)-[r:`采购合同生成签发账单` {object_key:'E_HT_CGHTCSQFZD_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_cghtscqfzd';

// ---------- 42. 企业 -[签发账单（出让方）]-> 云链签发账单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'})
MERGE (a)-[r:`签发账单（出让方）` {object_key:'E_QY_QFZD_CRF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_qfzd_crf';

// ---------- 43. 企业 -[签发账单（受让方）]-> 云链签发账单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_ZYWL'}), (b:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'})
MERGE (a)-[r:`签发账单（受让方）` {object_key:'E_QY_QFZD_SRF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_qfzd_srf';

// ---------- 44. 云链签发账单 -[生成转让账单]-> 云链转让账单 ----------
MATCH (a:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'}), (b:ZSTP:`云链转让账单` {object_key:'YLZR_001'})
MERGE (a)-[r:`生成转让账单` {object_key:'E_YLQFQSZD_SCZRZD_0001'}]->(b)
SET r.ylqfqs_bill_no = 'YQFQ-2024-0001',
    r.ylzz_bill_no   = 'YZR-2024-0001',
    r.schema_name    = 'dws_dsjsj_zstp_edge_ylqfqszd_sczrzd';

// ---------- 45. 企业 -[转让账单（出让方）]-> 云链转让账单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`云链转让账单` {object_key:'YLZR_001'})
MERGE (a)-[r:`转让账单（出让方）` {object_key:'E_QY_ZRZD_CRF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_zrzd_crf';

// ---------- 46. 企业 -[转让账单（受让方）]-> 云链转让账单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_ZYWL'}), (b:ZSTP:`云链转让账单` {object_key:'YLZR_001'})
MERGE (a)-[r:`转让账单（受让方）` {object_key:'E_QY_ZRZD_SRF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_zrzd_srf';

// ---------- 47. 云链转让账单 -[关联到采购合同]-> 合同 ----------
MATCH (a:ZSTP:`云链转让账单` {object_key:'YLZR_001'}), (b:ZSTP:`合同` {object_key:'HT_001'})
MERGE (a)-[r:`关联到采购合同` {object_key:'E_YLZRZD_GLDCGHT_0001'}]->(b)
SET r.financing_ratio_pct = '91.67',
    r.schema_name         = 'dws_dsjsj_zstp_edge_ylzrzd_gldcght';

// ---------- 48. 云链签发账单 -[用于融资]-> 云链融资账单 ----------
MATCH (a:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'}), (b:ZSTP:`云链融资账单` {object_key:'YLRZ_001'})
MERGE (a)-[r:`用于融资` {object_key:'E_YLQFZD_YYRZ_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ylqfzd_yyrz';

// ---------- 49. 企业 -[融资账单（出让方）]-> 云链融资账单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_XNY'}), (b:ZSTP:`云链融资账单` {object_key:'YLRZ_001'})
MERGE (a)-[r:`融资账单（出让方）` {object_key:'E_QY_SQRZ_CRF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_sqrz_crf';

// ---------- 50. 企业 -[融资账单（受让方）]-> 云链融资账单 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_ZYWL'}), (b:ZSTP:`云链融资账单` {object_key:'YLRZ_001'})
MERGE (a)-[r:`融资账单（受让方）` {object_key:'E_QY_SQRZ_SRF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_sqrz_srf';

// ---------- 51. 企业 -[涉及诉讼]-> 法律诉讼 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`法律诉讼` {object_key:'FLSS_001'})
MERGE (a)-[r:`涉及诉讼` {object_key:'E_QY_SJSS_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_sjss';

// ---------- 52. 企业 -[涉及破产重整]-> 破产重整 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HBJD'}), (b:ZSTP:`破产重整` {object_key:'PCCZ_001'})
MERGE (a)-[r:`涉及破产重整` {object_key:'E_QY_SJPCCZ_0001'}]->(b)
SET r.total       = '1',
    r.schema_name = 'dws_dsjsj_zstp_edge_qy_sjpccz';

// ---------- 53. 企业 -[受到行政处罚]-> 行政处罚 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`行政处罚` {object_key:'XZCF_001'})
MERGE (a)-[r:`受到行政处罚` {object_key:'E_QY_SDXZCF_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_sdxzcf';

// ---------- 54. 企业 -[被列为失信被执行人]-> 失信被执行人 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`失信被执行人` {object_key:'SXBZXR_001'})
MERGE (a)-[r:`被列为失信被执行人` {object_key:'E_QY_BLWSXZXR_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_blwsxzxr';

// ---------- 55. 企业 -[触发风险_企业]-> 风险线索 ----------
MATCH (a:ZSTP:`企业` {object_key:'QY_HXJS'}), (b:ZSTP:`风险线索` {object_key:'FXXS_001'})
MERGE (a)-[r:`触发风险_企业` {object_key:'E_QY_CFFX_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_cffx';

// ---------- 56. 自然人 -[触发风险_自然人]-> 风险线索 ----------
MATCH (a:ZSTP:`自然人` {object_key:'ZRR_LQ'}), (b:ZSTP:`风险线索` {object_key:'FXXS_001'})
MERGE (a)-[r:`触发风险_自然人` {object_key:'E_ZZR_CFFX_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_zzr_cffx';

// ---------- 57. 标段 -[触发风险_标段]-> 风险线索 ----------
MATCH (a:ZSTP:`标段` {object_key:'BD_001'}), (b:ZSTP:`风险线索` {object_key:'FXXS_001'})
MERGE (a)-[r:`触发风险_标段` {object_key:'E_BD_CFFX_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_bd_cffx';

// ---------- 58. 合同 -[触发风险_合同]-> 风险线索 ----------
MATCH (a:ZSTP:`合同` {object_key:'HT_001'}), (b:ZSTP:`风险线索` {object_key:'FXXS_001'})
MERGE (a)-[r:`触发风险_合同` {object_key:'E_HT_CFFX_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_cffx';

// ---------- 59. 云链签发账单 -[触发风险_云链签发账单]-> 风险线索 ----------
MATCH (a:ZSTP:`云链签发账单` {object_key:'YLQFQ_001'}), (b:ZSTP:`风险线索` {object_key:'FXXS_001'})
MERGE (a)-[r:`触发风险_云链签发账单` {object_key:'E_YLQFQSZD_CFFX_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ylqfqszd_cffx';

// ---------- 60. 风险线索 -[触发风险_发票]-> 发票 ----------
MATCH (a:ZSTP:`风险线索` {object_key:'FXXS_001'}), (b:ZSTP:`发票` {object_key:'FP_001'})
MERGE (a)-[r:`触发风险_发票` {object_key:'E_FXXS_FP_0001'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_fxxs_fp';


// =============================================================================
// 三、初始化结果自检
// =============================================================================
// 顶点数量（按标签）
// MATCH (n:ZSTP) RETURN labels(n) AS labels, count(*) AS cnt ORDER BY cnt DESC;
//
// 边数量（按类型）
// MATCH (:ZSTP)-[r]->(:ZSTP) RETURN type(r) AS rel_type, count(*) AS cnt ORDER BY cnt DESC;
//
// 隐性关联关系探查示例（企业 → 标段 → 合同 → 发票 → 资金流水 → 银行账户 全链路）
// MATCH p = (q:ZSTP:`企业` {object_key:'QY_HXJS'})-[*1..6]->(:ZSTP)
// RETURN p LIMIT 50;
