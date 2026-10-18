# 国电投 AI+审计 知识图谱 · Neo4j 模型

由 `国电投AI+审计 (1).xls` 自动推导。源表 `schemas`（88 行）定义图元素类型，`fields`（503 行）定义元素字段。

| 项目 | 值 |
|---|---|
| 顶点类型（VERTEX） | **28** |
| 边类型（EDGE） | **60** |
| 字段定义总数 | 503 |
| 顶点主键 | 全部为 `object_key`（源表 `isMain=true` & `isIdentity=true`） |
| 边主键 | 全部为 `object_key`；端点由 `from_key` → `to_key` 决定 |
| 方向性 | 全部 EDGE `directed = Y`；VERTEX 无方向 |
| externalFlag | 全部为 `N`（无外部表） |
| 推荐版本 | Neo4j 5.x（关系属性唯一约束需 5.7+） |

## 建模约定

1. 所有顶点带通用标签 `:ZSTP` + 业务标签（中文），例如 `(:ZSTP:企业)`，便于整图遍历。
2. 顶点主键统一 `object_key`；边属性挂在关系上，边自身主键也是 `object_key`。
3. 边类型 = 源表 `schemaNameCn`（中文，反引号包裹）；方向由 `from_key`→`to_key` 保证。
4. 顶点/边均保留 `schema_name` 属性，可回溯到源 `schemas.schemaName`。

## 文件说明

| 文件 | 作用 |
|---|---|
| `01_neo4j_ddl.cypher` | 28 个顶点唯一约束 + 27 个属性索引 + 60 个边唯一约束（5.7+），并附节点/关系定义速查注释 |
| `02_neo4j_init_data.cypher` | 幂等初始化数据：37 个顶点实例 + 60 条边实例（覆盖全部 60 类边） |
| `03_reset_clean.cypher` | 数据清空 / 重置：按标签精准删、全库清空、分批删、物理级清空，以及 115 条 `DROP CONSTRAINT / DROP INDEX` |
| `04_clear_current_db.cypher` | AuraDB 专用清空脚本（确认 → 清空 → 校验，含 token 残留说明） |
| `05_risk_hidden_relation_phone_addr.cypher` | 隐性关联查询：电话/地址相同 + ≤3 层关联（企业两两直接比对版） |
| `06_mock_data_for_risk_query.cypher` | 05 的模拟测试数据（`MOCK_` 前缀，含 4 类边界用例） |
| `07_risk_type_driven_query.cypher` | **风险线索驱动查询（推荐思路）**：risk_type → 触发风险的企业 → ≤3 层控股穿透 → 电话相同 |
| `08_mock_data_risk_type.cypher` | 07 的模拟数据（`MOCK2_` 前缀）：风险线索 + 两条持股链 + 合同/发票，含边界反例 |
| `09_risk_shareholding_contract_query.cypher` | 07 基础上追加条件：**a、b 同签一份合同**（多份只取一条），含子查询 LIMIT 1 / OPTIONAL / 全列对照 / 末端企业同签合同变体 |
| `10_mock_data_contract_extra.cypher` | 09 的追加模拟数据：合同字段名对齐 DDL、多份共同合同（取最早一条）、无共同合同、有合同但不构成命中的反例 |
| `11_verify_contract_condition.cypher` | **自包含验证脚本**：自带 `MOCK3_` 最小数据集 + 主查询 + 7 条断言式校验（输出 PASS/FAIL）+ 宽松版 + 清理 |
| `12_pair_risk_shareholding_contract.cypher` | **另一口径版（与 `07`/`09`/`13` 的原始查询口径不同）**：同一条风险线索下电话相同的两家企业 a、b → a、b 之间 3 层内控股关联 → 同签一份合同（多份取最早）；自带 `MOCK4_` 数据集 + 3 个变体 + 7 条断言校验 |
| `13_mock_data_for_p0p1p2_query.cypher` | 原始查询（`07`/`09` 那条"线索→3 层控股→同电话→同签合同"）的**专属自包含模拟数据**（`MOCK5_` 前缀，21 节点 / 24 边）：2 行命中 + 层数/合同/电话/无控股链路 4 类反例；目标查询原样附在文件头部注释 |
| `14_mock_enterprise_contract_enterprise.cypher` | **企业-合同-企业** 结构的自包含模拟数据（`MOCK6_` 前缀，2 企业 + 2 合同 + 3 条 `签订合同` 边）：1 份共同合同 + 1 份单方合同对照，用于验证"同签一份合同"判定 |

执行顺序：先 `01`，再 `02`。两个文件均可重复执行（`IF NOT EXISTS` + `MERGE`）。
`03` 是**按需选用**的清空脚本，请只执行需要的章节，不要整文件顺序跑。
风险线索场景：先跑 `08` 灌模拟数据，再跑 `07` 的查询（`05`/`06` 是早期直接两两比对版，可作对照）。
带合同条件：再跑 `10` 追加数据，然后跑 `09` 的查询（`09` 第一节为必中版，第三节为保留控股关系的宽松版）。
只想快速验证：直接跑 `11`（自包含，不依赖 08/10，跑完输出 7 条 PASS/FAIL 判定）；或用 `13` 验证原始查询（自带数据，目标查询见其文件头部）。
**两套口径并存，不是修改关系**：`07`/`09`/`13` 为"线索上的企业 → 沿控股链向下找同电话企业"（b 不必挂线索）；`12` 为"同一线索下两家企业彼此关联"（a、b 都挂线索）。两者结果必然不同，按业务口径选用。

## 清空数据速查

| 目标 | 命令 |
|---|---|
| 只删本图谱（推荐，精准） | `MATCH (n:ZSTP) DETACH DELETE n;` |
| 清空整库节点与关系 | `MATCH (n) DETACH DELETE n;` |
| 只删关系、保留节点 | `MATCH ()-[r]->() DELETE r;` |
| 大数据量分批删（>10 万节点） | `MATCH (n:ZSTP) CALL { WITH n DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;` |
| 连约束索引一起清（回到未建模状态） | 见 `03_reset_clean.cypher` 方式六（115 条 DROP） |
| 最快（整库重置，需停库） | 停库 → 删 `data/databases/neo4j` + `data/transactions/neo4j` → 起库 |

⚠️ `DETACH DELETE` 与 `DROP` 不可逆，执行前请先备份（见 `03` 第八节）。

---

## 一、顶点类型（28）

| # | 标签 | 源 schemaName | 主要字段 |
|---|---|---|---|
| 1 | `企业` | `dws_dsjsj_zstp_vertex_qy` | org_name, org_credit_code, mdg_code, mdg_name, secondary_org_code, secondary_org_name, companyorgtype, regstatus, reglocation, businessscope, estiblishtime, socialstaffnum, phonenumber, organizationlevel, sfgq, flag_gdtqy, flag_cg, flag_kg, sfkh, sfgys, sourcesystem |
| 2 | `自然人` | `dws_dsjsj_zstp_vertex_zrr` | name, emp_code, post_name, is_key_person, is_history_key_person, is_emp, work_status, source_system |
| 3 | `合同` | `dws_dsjsj_zstp_vertex_ht` | contract_code, contract_name, gategory_name, category_code, status_name, payment_direction, contract_amount, sign_time, sfjrlht, sfdblht, sfzxsppdylht, mdg_orgcode, mdg_orgname, sourcesystem |
| 4 | `标段` | `dws_dsjsj_zstp_vertex_bd` | packno, packname, tenderno, tendername, procurementmethod, tendermethod, packid, createtime, maxlimitprice, system_source |
| 5 | `发票` | `dws_dsjsj_zstp_vertex_fp` | fp_hm, fplx, kprq, fpje, fpse, jshj, xmmc, taxpayer, system_source |
| 6 | `资金流水` | `dws_dsjsj_zstp_vertex_zjls` | bill_num, tran_amt, trade_dir, TRANS_TIME, SUMMARY, system_source |
| 7 | `银行账户` | `dws_dsjsj_zstp_vertex_yhzh` | acc_name, bank_acc_no, nam_dep_ban, use_state, system_source |
| 8 | `财务凭证` | `dws_dsjsj_zstp_vertex_cwpz` | POST_BH, START_DATE, REG_DATE, DESCRIPTION, CR_BALANCE, DR_BALANCE, source_system |
| 9 | `物料` | `dws_dsjsj_zstp_vertex_wl` | matnr, maktx, sourcesystem |
| 10 | `入库` | `dws_dsjsj_zstp_vertex_rk` | mblnr, menge, charg, budat, elikz, lfart_desc, umlgo, sourcesystem |
| 11 | `出库` | `dws_dsjsj_zstp_vertex_ck` | vbeln, meins, wadat_ist, wbstk, lfart, lgort, source_system |
| 12 | `金融类项目` | `dws_dsjsj_zstp_vertex_jrlxm` | id, deal_name, deal_type2, deal_status, end_time_, actual_payment_money, system_source |
| 13 | `其他类项目` | `dws_dsjsj_zstp_vertex_qtlxm` | item_id, item_name, item_type, ini_status, init_date, depname, ass_capltal_money, sourcesystem |
| 14 | `基建类项目` | `dws_dsjsj_zstp_vertex_jjlxm` | proj_code, proj_name, proposal_code, full_name, proj_status_name, actual_start_time, investment_type_name, proj_stage_name, industry_type_name, investment_amount, lyxt |
| 15 | `电能e购订单` | `dws_dsjsj_zstp_vertex_dnygdd` | order_no, order_status, order_time, amount_type_id, final_price, system_source |
| 16 | `信托产品` | `dws_dsjsj_zstp_vertex_xtcp` | PRODUCT_CODE, PRODUCT_NAME, PRODUCT_MONEY, START_DATE, END_DATE, CP_STATUS_NAME, system_source |
| 17 | `信托底层资产` | `dws_dsjsj_zstp_vertex_xtdczc` | param_name, dczcbcms, zcqdfs, syqbizc, system_source |
| 18 | `云链签发账单` | `dws_dsjsj_zstp_vertex_ylqfqszd` | ini_bill_id, bill_no, bill_amt, bill_balan, bill_begin_dt, rpay_dt, bill_over_dt, bill_status, trx_type, system_source |
| 19 | `云链转让账单` | `dws_dsjsj_zstp_vertex_ylzrzd` | ini_bill_id, bill_no, bill_amt, bill_balan, bill_begin_dt, rpay_dt, bill_over_dt, bill_status, trx_type, system_source |
| 20 | `云链融资账单` | `dws_dsjsj_zstp_vertex_ylrzzd` | ini_bill_id, sub_bill_id, lvrg_prod_name, bill_amt, bill_balan, intr, finance_days, lvrg_intr_rate, total_finance_fee, total_finance_rate, pay_intr_method, dtrb_dt_f, dtrb_dt_s, lvrg_apply_dt_f, bill_over_dt_f, rpay_dt_f, org_ali_pmt_amt, trx_type, bill_status, system_source |
| 21 | `风险线索` | `dws_dsjsj_zstp_vertex_fxxs` | risk_type, risk_desc, risk_summary |
| 22 | `法律诉讼` | `dws_dsjsj_zstp_vertex_flss` | case_no, title, case_type, case_reason, case_money, judge_time, court, submit_time, system_source |
| 23 | `破产重整` | `dws_dsjsj_zstp_vertex_pccz` | case_no, case_type, submit_time, system_source |
| 24 | `行政处罚` | `dws_dsjsj_zstp_vertex_xzcf` | punish_name, punish_number, decision_date, department_name, reason, content, evidence, syetem_source |
| 25 | `失信被执行人` | `dws_dsjsj_zstp_vertex_sxbzxr` | type, casecode, disrupttypename, performance, regdate, publishdate, gistunit, system_source |
| 26 | `决策会议` | `dws_dsjsj_zstp_vertex_jchy` | meeting_name, meeting_code, meeting_date, type_name, system_source |
| 27 | `决策会议议题` | `dws_dsjsj_zstp_vertex_jchyyt` | subject_name, subject_code, pass_flag, system_source |
| 28 | `二级单位规范简称` | `dws_dsjsj_zstp_vertex_ejdwgfjc` | short_name, notice_name, period_history, org_unique_code, doc_num, send_time |

---

## 二、边类型（60）

除 `object_key` / `from_key` / `to_key` 三件套外，其余字段为关系业务属性。

| # | 边类型 | 起点 → 终点 | 关系属性 | 源 schemaName |
|---|---|---|---|---|
| 1 | `股东持股（%）企业-企业` | 企业 → 企业 | ft_shareholding, capital_amomon, capital_percent, capital_time, capital_actl_amomon, capital_actl_percent, capital_actl_time, capital_actl_paymet, sflsgd | `..._edge_qy_gdcgbfb` |
| 2 | `股东持股（%）企业-自然人` | 自然人 → 企业 | ft_shareholding, capital_amomon, capital_percent, capital_time, capital_actl_amomon, capital_actl_percent, capital_actl_time, capital_actl_paymet, is_history_shareholder, history_ft_shareholding | `..._edge_zrr_gdcgqy` |
| 3 | `签订合同` | 企业 → 合同 | contract_amount, contract_status, sign_time | `..._edge_qy_qd` |
| 4 | `产生发票_企业` | 企业 → 发票 | — | `..._edge_qy_csfp` |
| 5 | `产生发票` | 电能e购订单 → 发票 | real_invoice_time, HJJE | `..._edge_dnegdd_csfp` |
| 6 | `开具接收发票` | 企业 → 发票 | — | `..._edge_qy_kjjsfp` |
| 7 | `拥有账户` | 企业 → 银行账户 | — | `..._edge_qy_yyzh` |
| 8 | `交易` | 银行账户 → 银行账户 | trans_time, tran_amt, abstract | `..._edge_yhzh_jy` |
| 9 | `企业收款/付款` | 企业 → 资金流水 | — | `..._edge_qy_skfk` |
| 10 | `合同收款/付款` | 合同 → 资金流水 | — | `..._edge_ht_skfk` |
| 11 | `依据发票收款/付款` | 发票 → 资金流水 | invoice_no, invoice_date, bill_num | `..._edge_fp_yjfpskfk` |
| 12 | `资金流水收款/付款账号` | 资金流水 → 银行账户 | bank_acc_no, trans_time, tran_uni_cod | `..._edge_zjls_zjlsskfkzh` |
| 13 | `生成凭证` | 资金流水 → 财务凭证 | — | `..._edge_zjls_scpz` |
| 14 | `按采购合同入库` | 合同 → 入库 | — | `..._edge_ht_acghtrk` |
| 15 | `按销售合同出库` | 合同 → 出库 | — | `..._edge_ht_axshtck` |
| 16 | `领用物料` | 物料 → 入库 | name1, werks, lgobe, cputm | `..._edge_wl_lywl` |
| 17 | `消耗物料` | 物料 → 出库 | name1, werks, lgobe, erdat | `..._edge_wl_xhwl` |
| 18 | `派生订单` | 合同 → 电能e购订单 | — | `..._edge_ht_psdd` |
| 19 | `发起订单` | 企业 → 电能e购订单 | — | `..._edge_qy_fqdd` |
| 20 | `隶属合同` | 标段 → 合同 | — | `..._edge_bd_lsht` |
| 21 | `同一标的物关联_合同` | 合同 → 合同 | — | `..._edge_ht_tybdwgl` |
| 22 | `同一标的物关联` | 发票 → 发票 | — | `..._edge_fp_tybdwgl` |
| 23 | `发布标段` | 企业 → 标段 | createtime | `..._edge_qy_fb` |
| 24 | `参与投标` | 企业 → 标段 | createtime, final_price | `..._edge_qy_cy` |
| 25 | `中标` | 企业 → 标段 | bid_send_time, finalprice | `..._edge_qy_zb` |
| 26 | `上传/下载标书` | 企业 → 标段 | ip, iptag, rel_time | `..._edge_qy_scxzbs` |
| 27 | `发起项目_金融` | 企业 → 金融类项目 | — | `..._edge_qy_fqxm_jrlxm` |
| 28 | `发起项目_其他` | 企业 → 其他类项目 | — | `..._edge_qy_fqxm_qtlxm` |
| 29 | `发起项目_基建` | 企业 → 基建类项目 | — | `..._edge_qy_fqxm_jjlxm` |
| 30 | `穿透` | 金融类项目 → 信托底层资产 | — | `..._edge_jrlxm_ct` |
| 31 | `投向` | 金融类项目 → 信托产品 | — | `dws_dsjsj_edge_jrlxm_tx` |
| 32 | `发起决策会议` | 企业 → 决策会议 | — | `..._edge_qy_fqjchy` |
| 33 | `会议讨论议题` | 决策会议 → 决策会议议题 | — | `..._edge_jchy_hytlyt` |
| 34 | `决策项目_基建类项目` | 决策会议议题 → 基建类项目 | subject_name | `dws_dsjsj_edge_jchyyt_jjlxm` |
| 35 | `决策项目_其他类项目` | 决策会议议题 → 其他类项目 | subject_name | `..._edge_jchyyt_qtlxm` |
| 36 | `决策项目_金融类项目` | 决策会议议题 → 金融类项目 | subject_name | `..._edge_jchyyt_jrlxm` |
| 37 | `参与议题` | 自然人 → 决策会议议题 | attendance_ame, position | `..._edge_zrr_cyyt` |
| 38 | `担任/曾任企业法人` | 自然人 → 企业 | is_current_legal_person, is_history_legal_person | `..._edge_zrr_drcrqyfr` |
| 39 | `担任/曾任企业高管` | 自然人 → 企业 | position, term, history_position, history_term, is_history_key_person, report_date | `..._edge_zrr_rzqy` |
| 40 | `生成转让账单` | 云链签发账单 → 云链转让账单 | ylqfqs_bill_no, ylzz_bill_no | `..._edge_ylqfqszd_sczrzd` |
| 41 | `用于融资` | 云链签发账单 → 云链融资账单 | — | `..._edge_ylqfzd_yyrz` |
| 42 | `关联到采购合同` | 云链转让账单 → 合同 | financing_ratio_pct | `..._edge_ylzrzd_gldcght` |
| 43 | `签发账单（受让方）` | 企业 → 云链签发账单 | — | `..._edge_qy_qfzd_srf` |
| 44 | `签发账单（出让方）` | 企业 → 云链签发账单 | — | `..._edge_qy_qfzd_crf` |
| 45 | `采购合同生成签发账单` | 合同 → 云链签发账单 | — | `..._edge_ht_cghtscqfzd` |
| 46 | `转让账单（出让方）` | 企业 → 云链转让账单 | — | `..._edge_qy_zrzd_crf` |
| 47 | `转让账单（受让方）` | 企业 → 云链转让账单 | — | `..._edge_qy_zrzd_srf` |
| 48 | `融资账单（受让方）` | 企业 → 云链融资账单 | — | `..._edge_qy_sqrz_srf` |
| 49 | `融资账单（出让方）` | 企业 → 云链融资账单 | — | `..._edge_qy_sqrz_crf` |
| 50 | `涉及诉讼` | 企业 → 法律诉讼 | — | `..._edge_qy_sjss` |
| 51 | `涉及破产重整` | 企业 → 破产重整 | total | `..._edge_qy_sjpccz` |
| 52 | `受到行政处罚` | 企业 → 行政处罚 | — | `..._edge_qy_sdxzcf` |
| 53 | `被列为失信被执行人` | 企业 → 失信被执行人 | — | `..._edge_qy_blwsxzxr` |
| 54 | `触发风险_企业` | 企业 → 风险线索 | — | `..._edge_qy_cffx` |
| 55 | `触发风险_自然人` | 自然人 → 风险线索 | — | `..._edge_zzr_cffx` |
| 56 | `触发风险_标段` | 标段 → 风险线索 | — | `..._edge_bd_cffx` |
| 57 | `触发风险_合同` | 合同 → 风险线索 | — | `..._edge_ht_cffx` |
| 58 | `触发风险_云链签发账单` | 云链签发账单 → 风险线索 | — | `..._edge_ylqfqszd_cffx` |
| 59 | `触发风险_发票` | 风险线索 → 发票 | — | `..._edge_fxxs_fp` |
| 60 | `对应企业` | 二级单位规范简称 → 企业 | — | `..._edge_ejdwgfjc_dyqy` |

> `...` 为 `dws_dsjsj_zstp` 前缀缩写；完整名见 `01_neo4j_ddl.cypher`。

---

## 三、数据质量提示（源自源表勘察）

建模时已按源表原样保留字段名，以下几点建议在 ETL 阶段归一：

1. **来源系统字段有 4 种写法**：`system_source` / `source_system` / `sourcesystem` / `lyxt`，另有拼写错误 `syetem_source`（`行政处罚`）。建议统一为 `source_system`。
2. **金额字段类型不一致**：`合同.contract_amount`、`云链融资账单.bill_amt` 为 `DOUBLE`，而 `云链签发账单.bill_amt`、合同边的 `contract_amount` 为 `STRING`。建议统一数值化。
3. **其他拼写异常**（脚本已保留原样并加中文注释）：`capital_actl_amomon`、`capital_actl_paymet`、`ass_capltal_money`、`attendance_ame`、`gategory_name`、`estiblishtime`、`syetem_source`。
4. **命名易混淆**：`股东持股（%）企业-企业` 与 `股东持股（%）企业-自然人` 的 `schemaNameCn` 中"企业"含义与实际端点不完全对应，建议以 `from_key`/`to_key` 的节点标签为准。
5. **`云链签发账单` 与 `云链转让账单` 字段结构几乎一致**（仅 `bill_no` 语义不同），如后续扩展可考虑抽象公共标签 `云链账单`。
6. **自环边 4 条**：`股东持股（%）企业-企业`、`交易`、`同一标的物关联`、`同一标的物关联_合同`，查询时注意自环展开。

---

## 四、执行

```bash
# Neo4j Browser / cypher-shell 依次执行
cypher-shell -a bolt://localhost:7687 -u neo4j -p <password> -f 01_neo4j_ddl.cypher
cypher-shell -a bolt://localhost:7687 -u neo4j -p <password> -f 02_neo4j_init_data.cypher
```

自检：

```cypher
MATCH (n:ZSTP) RETURN labels(n) AS labels, count(*) AS cnt ORDER BY cnt DESC;
MATCH (:ZSTP)-[r]->(:ZSTP) RETURN type(r) AS rel_type, count(*) AS cnt ORDER BY cnt DESC;

// 隐性关联关系全链路探查
MATCH p = (q:ZSTP:`企业` {object_key:'QY_HXJS'})-[*1..6]->(:ZSTP) RETURN p LIMIT 50;
```
