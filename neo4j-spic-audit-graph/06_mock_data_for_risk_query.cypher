// =============================================================================
// 隐性关联关系查询 · 模拟测试数据（配套 05_risk_hidden_relation_phone_addr.cypher）
// -----------------------------------------------------------------------------
// 目的：构造一套"预期结果可精确预测"的小图，用于验证
//       ① 电话相同 + ≤3 跳 的命中逻辑
//       ② [*1..3] 的层数边界是否正确排除第 4 跳
//       ③ 属性相同但图上不连通时是否正确排除
//       ④ 地址相同、电话+地址同时相同 的差异
//
// 全部使用 MERGE，可重复执行。object_key 统一以 MOCK_ 开头，便于事后清理。
// 顶点标签与关系类型完全沿用本图谱模型（:ZSTP + 中文业务标签）。
// =============================================================================


// =============================================================================
// 一、顶点
// =============================================================================

// ---------- 1. 企业（12 家）----------
// 关键设计：5 家企业共用电话 010-88886666（甲/乙/戊/己/三级股东）
//          3 家企业共用地址 北京市西城区金融大街1号（甲/乙/丙）

// 甲：国电投控股企业（两条命中链路的核心）
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_A'})
SET n.org_name = '北京某电力有限公司', n.org_credit_code = 'MOCK9111000000000001X',
    n.phonenumber = '010-88886666', n.reglocation = '北京市西城区金融大街1号',
    n.regstatus = '存续', n.sfgq = '是', n.flag_gdtqy = '是', n.flag_cg = '是',
    n.sfkh = '否', n.sfgys = '否', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 乙：外部企业 —— 与甲【同电话 + 同地址】，且 2 跳可达 → 强规则命中
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_B'})
SET n.org_name = '京华电力工程有限公司', n.org_credit_code = 'MOCK9111000000000002X',
    n.phonenumber = '010-88886666', n.reglocation = '北京市西城区金融大街1号',
    n.regstatus = '存续', n.sfgq = '否', n.flag_gdtqy = '否', n.flag_cg = '否',
    n.sfkh = '否', n.sfgys = '是', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 丙：外部企业 —— 与甲【同地址、不同电话】，3 跳可达 → 地址规则命中
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_C'})
SET n.org_name = '北方电气设备有限公司', n.org_credit_code = 'MOCK9111000000000003X',
    n.phonenumber = '010-66668888', n.reglocation = '北京市西城区金融大街1号',
    n.regstatus = '存续', n.sfgq = '否', n.flag_gdtqy = '否', n.flag_cg = '否',
    n.sfkh = '否', n.sfgys = '是', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 丁：外部企业 —— 属性与谁都不同，但 2 跳可达 → "有关联但属性不同"应排除
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_D'})
SET n.org_name = '西南机械制造有限公司', n.org_credit_code = 'MOCK9111000000000004X',
    n.phonenumber = '028-77777777', n.reglocation = '成都市高新区天泰路9号',
    n.regstatus = '存续', n.sfgq = '否', n.flag_gdtqy = '否', n.flag_cg = '否',
    n.sfkh = '否', n.sfgys = '是', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 戊：孤立企业 —— 与甲【同电话】但图上完全无关联 → 应排除
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_E'})
SET n.org_name = '孤岛贸易有限公司', n.org_credit_code = 'MOCK9111000000000005X',
    n.phonenumber = '010-88886666', n.reglocation = '上海市浦东新区世纪大道100号',
    n.regstatus = '存续', n.sfgq = '否', n.flag_gdtqy = '否', n.flag_cg = '否',
    n.sfkh = '是', n.sfgys = '否', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 一级股东
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_S1'})
SET n.org_name = '国电投资控股平台有限公司', n.phonenumber = '010-11111111',
    n.reglocation = '北京市东城区安定门大街2号', n.regstatus = '存续',
    n.sourcesystem = 'MOCK', n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 二级股东
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_S2'})
SET n.org_name = '国电投资能源控股有限公司', n.phonenumber = '010-22222222',
    n.reglocation = '北京市东城区安定门大街3号', n.regstatus = '存续',
    n.sourcesystem = 'MOCK', n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 三级股东 —— 与甲【同电话】，恰好 3 跳可达 → 3 层股权穿透边界命中
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_S3'})
SET n.org_name = '国电投资集团资本有限公司', n.phonenumber = '010-88886666',
    n.reglocation = '北京市东城区安定门大街4号', n.regstatus = '存续',
    n.sourcesystem = 'MOCK', n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 己：与甲【同电话】，但需要 4 跳才能连通 → 应被 [*1..3] 正确排除
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_X'})
SET n.org_name = '远东资本运营有限公司', n.phonenumber = '010-88886666',
    n.reglocation = '深圳市福田区深南大道5000号', n.regstatus = '存续',
    n.sourcesystem = 'MOCK', n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// 庚 / 辛 / 壬：4 跳链路的中转企业（属性均唯一，不参与命中）
MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_Y1'})
SET n.org_name = '环宇投资管理有限公司', n.phonenumber = '010-33333333',
    n.reglocation = '北京市丰台区科技园8号', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_Y2'})
SET n.org_name = '恒泰资本有限公司', n.phonenumber = '010-44444444',
    n.reglocation = '天津市和平区南京路66号', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

MERGE (n:ZSTP:`企业` {object_key:'MOCK_QY_Y3'})
SET n.org_name = '汇通控股有限公司', n.phonenumber = '010-55555555',
    n.reglocation = '重庆市江北区观音桥1号', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_qy';

// ---------- 2. 自然人（2 人）----------
// 张三：同时担任甲、乙两家企业高管 → 让甲↔乙形成 2 跳"人事链"
MERGE (n:ZSTP:`自然人` {object_key:'MOCK_ZRR_Z'})
SET n.name = '张三', n.post_name = '董事', n.is_key_person = '是',
    n.is_emp = '是', n.source_system = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_zrr';

MERGE (n:ZSTP:`自然人` {object_key:'MOCK_ZRR_L'})
SET n.name = '李四', n.post_name = '股东', n.is_key_person = '否',
    n.is_emp = '否', n.source_system = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_zrr';

// ---------- 3. 合同 / 发票 / 电能e购订单 ----------
MERGE (n:ZSTP:`合同` {object_key:'MOCK_HT_1'})
SET n.contract_code = 'MOCK-HT-001', n.contract_name = '1号合同',
    n.contract_amount = 12000000.0, n.sign_time = datetime('2024-03-15T00:00:00'),
    n.status_name = '已生效', n.sourcesystem = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_ht';

MERGE (n:ZSTP:`发票` {object_key:'MOCK_FP_1'})
SET n.fp_hm = '11009999', n.fpje = '1356000', n.kprq = datetime('2024-04-10T00:00:00'),
    n.xmmc = '高压开关柜', n.system_source = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_fp';

MERGE (n:ZSTP:`电能e购订单` {object_key:'MOCK_DNYGDD_1'})
SET n.order_no = 20240600001, n.final_price = 904000.0,
    n.order_time = datetime('2024-05-25T14:00:00'), n.system_source = 'MOCK',
    n.schema_name = 'dws_dsjsj_zstp_vertex_dnygdd';


// =============================================================================
// 二、边   （括号内标注该边贡献的跳数关系）
// =============================================================================

// 甲/乙/丁 共用同一份合同 —— 甲↔乙 2 跳、甲↔丁 2 跳
MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_A'}), (b:ZSTP:`合同` {object_key:'MOCK_HT_1'})
MERGE (a)-[r:`签订合同` {object_key:'MOCK_E_HT_A'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_qd';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_B'}), (b:ZSTP:`合同` {object_key:'MOCK_HT_1'})
MERGE (a)-[r:`签订合同` {object_key:'MOCK_E_HT_B'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_qd';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_D'}), (b:ZSTP:`合同` {object_key:'MOCK_HT_1'})
MERGE (a)-[r:`签订合同` {object_key:'MOCK_E_HT_D'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_qd';

// 合同 → 订单 → 发票 → 甲，丙挂在订单上
// 甲↔丙 3 跳：甲-发票-订单-丙 ；乙↔丙 3 跳：乙-合同-订单-丙
MATCH (a:ZSTP:`合同` {object_key:'MOCK_HT_1'}), (b:ZSTP:`电能e购订单` {object_key:'MOCK_DNYGDD_1'})
MERGE (a)-[r:`派生订单` {object_key:'MOCK_E_HT_PSDD'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_ht_psdd';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_C'}), (b:ZSTP:`电能e购订单` {object_key:'MOCK_DNYGDD_1'})
MERGE (a)-[r:`发起订单` {object_key:'MOCK_E_QY_FQDD'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_fqdd';

MATCH (a:ZSTP:`电能e购订单` {object_key:'MOCK_DNYGDD_1'}), (b:ZSTP:`发票` {object_key:'MOCK_FP_1'})
MERGE (a)-[r:`产生发票` {object_key:'MOCK_E_DNEGDD_CSFP'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_dnegdd_csfp';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_A'}), (b:ZSTP:`发票` {object_key:'MOCK_FP_1'})
MERGE (a)-[r:`产生发票_企业` {object_key:'MOCK_E_QY_CSFP'}]->(b)
SET r.schema_name = 'dws_dsjsj_zstp_edge_qy_csfp';

// 股权链 三级股东 → 二级股东 → 一级股东 → 甲
// 甲↔三级股东 恰好 3 跳（对应图中"股东持股（%）企业（3层）"）
MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_S1'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_A'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_S1_A'}]->(b)
SET r.capital_percent = '60', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_S2'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_S1'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_S2_S1'}]->(b)
SET r.capital_percent = '80', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_S3'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_S2'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_S3_S2'}]->(b)
SET r.capital_percent = '100', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

// 4 跳链路：己 → 庚 → 辛 → 壬 → 甲（用于验证 [*1..3] 的层数边界）
MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_X'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_Y1'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_X_Y1'}]->(b)
SET r.capital_percent = '100', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_Y1'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_Y2'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_Y1_Y2'}]->(b)
SET r.capital_percent = '100', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_Y2'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_Y3'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_Y2_Y3'}]->(b)
SET r.capital_percent = '100', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_Y3'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_A'})
MERGE (a)-[r:`股东持股（%）企业-企业` {object_key:'MOCK_E_GD_Y3_A'}]->(b)
SET r.capital_percent = '40', r.schema_name = 'dws_dsjsj_zstp_edge_qy_gdcgbfb';

// 人事链：张三同时是甲、乙的高管
MATCH (a:ZSTP:`自然人` {object_key:'MOCK_ZRR_Z'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_A'})
MERGE (a)-[r:`担任/曾任企业高管` {object_key:'MOCK_E_RZ_Z_A'}]->(b)
SET r.position = '董事', r.schema_name = 'dws_dsjsj_zstp_edge_zrr_rzqy';

MATCH (a:ZSTP:`自然人` {object_key:'MOCK_ZRR_Z'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_B'})
MERGE (a)-[r:`担任/曾任企业高管` {object_key:'MOCK_E_RZ_Z_B'}]->(b)
SET r.position = '副总经理', r.schema_name = 'dws_dsjsj_zstp_edge_zrr_rzqy';

// 李四持甲 5%
MATCH (a:ZSTP:`自然人` {object_key:'MOCK_ZRR_L'}), (b:ZSTP:`企业` {object_key:'MOCK_QY_A'})
MERGE (a)-[r:`股东持股（%）企业-自然人` {object_key:'MOCK_E_GD_L_A'}]->(b)
SET r.capital_percent = '5', r.schema_name = 'dws_dsjsj_zstp_edge_zrr_gdcgqy';


// =============================================================================
// 三、设计说明：各企业对之间的实际跳数（跑查询前先看一眼，好对照结果）
// -----------------------------------------------------------------------------
//  电话 010-88886666 共 5 家：甲、乙、戊、己、三级股东
//  地址 北京市西城区金融大街1号 共 3 家：甲、乙、丙
//
//  甲 ↔ 乙        2 跳（甲-合同-乙 / 甲-张三-乙）   同电话 + 同地址  → 命中
//  甲 ↔ 丙        3 跳（甲-发票-订单-丙）            同地址          → 命中
//  甲 ↔ 三级股东  3 跳（甲-一级-二级-三级）          同电话          → 命中
//  甲 ↔ 戊        ∞（戊为孤立节点）                  同电话          → 排除(不连通)
//  甲 ↔ 己        4 跳（甲-壬-辛-庚-己）             同电话          → 排除(超 3 层)
//  甲 ↔ 丁        2 跳（甲-合同-丁）                 属性均不同      → 排除(属性)
//  乙 ↔ 丙        3 跳（乙-合同-订单-丙）            同地址          → 命中
//  乙 ↔ 三级股东  5 跳                                                → 排除(超 3 层)
// =============================================================================


// =============================================================================
// 四、预期结果（用于对照）
// =============================================================================
// 1.1 电话相同的企业对        → 10 组（5 家共用同一电话，C(5,2)=10）
// 1.2 注册地址相同的企业对    → 3 组（甲/乙/丙 → C(3,2)=3）
// 1.3 电话或地址相同          → 12 组
// 2.1 电话相同 + ≤3 跳        → 2 组：甲-乙(2跳)、甲-三级股东(3跳)
// 2.2 地址相同 + ≤3 跳        → 3 组：甲-乙(2跳)、甲-丙(3跳)、乙-丙(3跳)
// 2.3 电话+地址同时相同 + ≤3  → 1 组：甲-乙(2跳)
// 4.  仅走股权/人事边 + ≤3 跳 → 2 组：甲-乙(2跳, 高管链)、甲-三级股东(3跳, 股权链)
// =============================================================================


// =============================================================================
// 五、逐对核验查询：打印甲与所有同电话企业的"实际跳数"和命中判定
// -----------------------------------------------------------------------------
// 这条查询最能说明问题：一眼看出谁是"距离超限"被排除、谁是"不连通"被排除。
// =============================================================================
MATCH (a:ZSTP:`企业` {object_key:'MOCK_QY_A'}), (b:ZSTP:`企业`)
WHERE b.object_key <> a.object_key
  AND b.phonenumber = a.phonenumber
OPTIONAL MATCH p = shortestPath((a)-[*1..6]-(b))
RETURN b.org_name AS 对方企业,
       b.reglocation AS 对方注册地址,
       CASE WHEN p IS NULL THEN '不连通' ELSE toString(length(p)) + ' 跳' END AS 实际距离,
       CASE WHEN p IS NOT NULL AND length(p) <= 3 THEN '命中' ELSE '排除' END AS 判定;


// =============================================================================
// 六、清理（测试完把模拟数据删掉，可整段取消注释执行）
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK_' DETACH DELETE n;
//
// 校验应返回 0：
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK_' RETURN count(n);
