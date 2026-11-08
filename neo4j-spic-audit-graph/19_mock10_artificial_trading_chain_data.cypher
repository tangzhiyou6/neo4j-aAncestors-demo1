// =============================================================================
// SPIC-CW-0107 疑似人为增加交易环节 · 新模拟数据（MOCK10_ 前缀，可重复执行）
// -----------------------------------------------------------------------------
// 配套查询：17_artificial_trading_chain_query.cypher
// 本文件只灌数据，不含断言。
//
// 命中口径（主查询）：
//   同一物料 m 贯通 采购入库 / 中间销售出库 / 最终销售出库；
//   签约链 s1(外)→gA(国电投)→gB(国电投)→s2(外)；
//   且 (s1,gA) 与 (gB,s2) 各挂同一条 0101 风险线索。
//
// 用例设计：
//   A 正例：同一物料两条完整合同链，验证"取最早" → 命中 P01/M01/S01
//   B 正例：另一行业（电缆），四方均不同          → 命中
//   C 反例：链条完整但无任何 0101 线索             → 不命中
//   D 反例：仅左侧 (s1,gA) 有线索                  → 不命中
//   E 反例：入库物料 ≠ 出库物料（物料不贯通）       → 不命中
//   F 反例：中间 gB 不是国电投企业                 → 不命中
//   G 变体B专用：同一 matnr 挂在 3 个物料节点上    → 主查询不命中，变体B命中
//
// 注意：17 号文件注释称 s1、s2 允许相同，但主查询 WHERE 含 s1 <> s2，
//       实际会排除闭环。本文件正例均使用不同主体。
//
// 重跑提示：关系为 MERGE + ON CREATE SET，改属性后需先清理再灌：
//   MATCH (n) WHERE n.object_key STARTS WITH 'MOCK10_' DETACH DELETE n;
// =============================================================================


// -----------------------------------------------------------------------------
// 一、企业
// -----------------------------------------------------------------------------
// —— A 正例（双链取最早）——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_A'})  ON CREATE SET n.org_name='华信数智科技（北京）有限公司', n.flag_gdtqy='否', n.org_credit_code='91110108MA01HX2T3K', n.phonenumber='010-67891234', n.reglocation='北京市海淀区中关村南大街5号', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_A'}) ON CREATE SET n.org_name='国家电投集团数字科技有限公司', n.flag_gdtqy='是', n.org_credit_code='91110000710935214M', n.phonenumber='010-66298000', n.reglocation='北京市西城区金融大街28号', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_A'}) ON CREATE SET n.org_name='国家电投集团信息技术有限公司', n.flag_gdtqy='是', n.org_credit_code='91110000100001234X', n.phonenumber='010-66298111', n.reglocation='北京市西城区金融大街28号', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_A'})  ON CREATE SET n.org_name='中电科汇智（天津）贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91120116MA05R7KQ8L', n.phonenumber='022-58761234', n.reglocation='天津市滨海新区华苑产业区', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— B 正例（电缆）——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_B'})  ON CREATE SET n.org_name='江苏远东特种电缆有限公司', n.flag_gdtqy='否', n.org_credit_code='91320282250216789K', n.phonenumber='0510-87231288', n.reglocation='江苏省宜兴市官林镇工业集中区', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_B'}) ON CREATE SET n.org_name='国家电投集团江苏电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91320000134763504L', n.phonenumber='025-86730000', n.reglocation='江苏省南京市鼓楼区中山北路2号', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_B'}) ON CREATE SET n.org_name='国家电投集团能源科技工程有限公司', n.flag_gdtqy='是', n.org_credit_code='91310115MA1K3X8F2P', n.phonenumber='021-50158000', n.reglocation='上海市浦东新区世纪大道100号', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_B'})  ON CREATE SET n.org_name='上海申能物资贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91310101132234567T', n.phonenumber='021-63218866', n.reglocation='上海市黄浦区中山南路315号', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— C 反例1：链条完整、无线索 ——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_C'})  ON CREATE SET n.org_name='北京中科云创科技有限公司', n.flag_gdtqy='否', n.org_credit_code='91110105MA01C8YX4R', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_C'}) ON CREATE SET n.org_name='国家电投集团北京电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91110000101123456A', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_C'}) ON CREATE SET n.org_name='国家电投集团河北电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91130000104321098B', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_C'})  ON CREATE SET n.org_name='河北建投能源物资有限公司', n.flag_gdtqy='否', n.org_credit_code='91130100107788990C', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— D 反例2：仅左侧线索 ——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_D'})  ON CREATE SET n.org_name='山东鲁电电气设备有限公司', n.flag_gdtqy='否', n.org_credit_code='91370100789123456D', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_D'}) ON CREATE SET n.org_name='国家电投集团山东电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91370000163001234E', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_D'}) ON CREATE SET n.org_name='国家电投集团山东能源有限公司', n.flag_gdtqy='是', n.org_credit_code='91370000163005678F', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_D'})  ON CREATE SET n.org_name='青岛海纳电气贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91370200123456789G', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— E 反例3：物料不贯通 ——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_E'})  ON CREATE SET n.org_name='浙江晨光管业有限公司', n.flag_gdtqy='否', n.org_credit_code='91330500123456789H', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_E'}) ON CREATE SET n.org_name='国家电投集团浙江电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91330000142901234J', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_E'}) ON CREATE SET n.org_name='国家电投集团浙江新能源有限公司', n.flag_gdtqy='是', n.org_credit_code='91330000MA2A12345K', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_E'})  ON CREATE SET n.org_name='宁波甬能物资有限公司', n.flag_gdtqy='否', n.org_credit_code='91330200123456789L', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— F 反例4：中间主体非国电投 ——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_F'})  ON CREATE SET n.org_name='广东南粤机电设备有限公司', n.flag_gdtqy='否', n.org_credit_code='91440101123456789M', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_F'}) ON CREATE SET n.org_name='国家电投集团广东电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91440000123456789N', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_F'}) ON CREATE SET n.org_name='广东粤电工程有限公司', n.flag_gdtqy='否', n.org_credit_code='91440101123456789P', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_F'})  ON CREATE SET n.org_name='深圳前海能源贸易有限公司', n.flag_gdtqy='否', n.org_credit_code='91440300123456789Q', n.schema_name='dws_dsjsj_zstp_vertex_qy';

// —— G 变体B专用：物料主数据未对齐 ——
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_G'})  ON CREATE SET n.org_name='四川蜀能电力设备有限公司', n.flag_gdtqy='否', n.org_credit_code='91510100123456789R', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_G'}) ON CREATE SET n.org_name='国家电投集团四川电力有限公司', n.flag_gdtqy='是', n.org_credit_code='91510000123456789S', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_G'}) ON CREATE SET n.org_name='国家电投集团西南能源有限公司', n.flag_gdtqy='是', n.org_credit_code='91510000MA6A12345T', n.schema_name='dws_dsjsj_zstp_vertex_qy';
MERGE (n:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_G'})  ON CREATE SET n.org_name='成都锦江物资有限公司', n.flag_gdtqy='否', n.org_credit_code='91510100123456789U', n.schema_name='dws_dsjsj_zstp_vertex_qy';


// -----------------------------------------------------------------------------
// 二、物料
// -----------------------------------------------------------------------------
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'})  ON CREATE SET n.matnr='MOCK10-MAT-001',  n.maktx='MOCK10_联想ThinkSystem服务器',        n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_B'})  ON CREATE SET n.matnr='MOCK10-MAT-002',  n.maktx='MOCK10_高压电缆YJV22-8.7/15kV',      n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_C'})  ON CREATE SET n.matnr='MOCK10-MAT-003',  n.maktx='MOCK10_单晶硅光伏组件550W',          n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_D'})  ON CREATE SET n.matnr='MOCK10-MAT-004',  n.maktx='MOCK10_干式变压器SCB13-1600kVA',     n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_EA'}) ON CREATE SET n.matnr='MOCK10-MAT-005A', n.maktx='MOCK10_不锈钢无缝管（入库）',        n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_EB'}) ON CREATE SET n.matnr='MOCK10-MAT-005B', n.maktx='MOCK10_不锈钢无缝管（出库）',        n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_F'})  ON CREATE SET n.matnr='MOCK10-MAT-006',  n.maktx='MOCK10_燃气轮机备件',                n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_GA'}) ON CREATE SET n.matnr='MOCK10-MAT-007',  n.maktx='MOCK10_断路器LW36-126kV',            n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_GB'}) ON CREATE SET n.matnr='MOCK10-MAT-007',  n.maktx='MOCK10_断路器LW36-126kV',            n.schema_name='dws_dsjsj_zstp_vertex_wl';
MERGE (n:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_GC'}) ON CREATE SET n.matnr='MOCK10-MAT-007',  n.maktx='MOCK10_断路器LW36-126kV',            n.schema_name='dws_dsjsj_zstp_vertex_wl';


// -----------------------------------------------------------------------------
// 三、合同
// -----------------------------------------------------------------------------
// A
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P01'}) ON CREATE SET n.contract_code='HT-2024-CG-0101', n.contract_name='MOCK10_服务器采购合同',            n.payment_direction='采购', n.contract_amount=8600000.0,  n.sign_time='2024-03-05', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M01'}) ON CREATE SET n.contract_code='HT-2024-XS-0158', n.contract_name='MOCK10_服务器中间销售合同',        n.payment_direction='销售', n.contract_amount=9180000.0,  n.sign_time='2024-04-12', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S01'}) ON CREATE SET n.contract_code='HT-2024-XS-0233', n.contract_name='MOCK10_服务器销售合同',            n.payment_direction='销售', n.contract_amount=9750000.0,  n.sign_time='2024-05-20', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P02'}) ON CREATE SET n.contract_code='HT-2024-CG-0288', n.contract_name='MOCK10_服务器采购合同（第二批）',    n.payment_direction='采购', n.contract_amount=5200000.0,  n.sign_time='2024-09-02', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M02'}) ON CREATE SET n.contract_code='HT-2024-XS-0411', n.contract_name='MOCK10_服务器中间销售合同（第二批）', n.payment_direction='销售', n.contract_amount=5580000.0,  n.sign_time='2024-10-08', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S02'}) ON CREATE SET n.contract_code='HT-2024-XS-0507', n.contract_name='MOCK10_服务器销售合同（第二批）',    n.payment_direction='销售', n.contract_amount=5960000.0,  n.sign_time='2024-11-15', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// B
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P03'}) ON CREATE SET n.contract_code='HT-2024-CG-0132', n.contract_name='MOCK10_电缆采购合同',            n.payment_direction='采购', n.contract_amount=4300000.0,  n.sign_time='2024-06-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M03'}) ON CREATE SET n.contract_code='HT-2024-XS-0201', n.contract_name='MOCK10_电缆中间销售合同',        n.payment_direction='销售', n.contract_amount=4620000.0,  n.sign_time='2024-06-25', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S03'}) ON CREATE SET n.contract_code='HT-2024-XS-0288', n.contract_name='MOCK10_电缆销售合同',            n.payment_direction='销售', n.contract_amount=4950000.0,  n.sign_time='2024-07-10', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// C
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P04'}) ON CREATE SET n.contract_code='HT-2024-CG-0055', n.contract_name='MOCK10_光伏组件采购合同',        n.payment_direction='采购', n.contract_amount=12600000.0, n.sign_time='2024-02-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M04'}) ON CREATE SET n.contract_code='HT-2024-XS-0066', n.contract_name='MOCK10_光伏组件中间销售合同',    n.payment_direction='销售', n.contract_amount=13200000.0, n.sign_time='2024-02-15', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S04'}) ON CREATE SET n.contract_code='HT-2024-XS-0077', n.contract_name='MOCK10_光伏组件销售合同',        n.payment_direction='销售', n.contract_amount=13900000.0, n.sign_time='2024-03-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// D
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P05'}) ON CREATE SET n.contract_code='HT-2024-CG-0166', n.contract_name='MOCK10_变压器采购合同',          n.payment_direction='采购', n.contract_amount=6800000.0,  n.sign_time='2024-04-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M05'}) ON CREATE SET n.contract_code='HT-2024-XS-0188', n.contract_name='MOCK10_变压器中间销售合同',      n.payment_direction='销售', n.contract_amount=7250000.0,  n.sign_time='2024-04-20', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S05'}) ON CREATE SET n.contract_code='HT-2024-XS-0221', n.contract_name='MOCK10_变压器销售合同',          n.payment_direction='销售', n.contract_amount=7680000.0,  n.sign_time='2024-05-10', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// E
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P06'}) ON CREATE SET n.contract_code='HT-2024-CG-0301', n.contract_name='MOCK10_无缝管采购合同',          n.payment_direction='采购', n.contract_amount=3100000.0,  n.sign_time='2024-08-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M06'}) ON CREATE SET n.contract_code='HT-2024-XS-0345', n.contract_name='MOCK10_无缝管中间销售合同',      n.payment_direction='销售', n.contract_amount=3320000.0,  n.sign_time='2024-08-10', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S06'}) ON CREATE SET n.contract_code='HT-2024-XS-0399', n.contract_name='MOCK10_无缝管销售合同',          n.payment_direction='销售', n.contract_amount=3550000.0,  n.sign_time='2024-08-20', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// F
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P07'}) ON CREATE SET n.contract_code='HT-2024-CG-0420', n.contract_name='MOCK10_燃机备件采购合同',        n.payment_direction='采购', n.contract_amount=15200000.0, n.sign_time='2024-10-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M07'}) ON CREATE SET n.contract_code='HT-2024-XS-0455', n.contract_name='MOCK10_燃机备件中间销售合同',    n.payment_direction='销售', n.contract_amount=16100000.0, n.sign_time='2024-10-15', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S07'}) ON CREATE SET n.contract_code='HT-2024-XS-0498', n.contract_name='MOCK10_燃机备件销售合同',        n.payment_direction='销售', n.contract_amount=17050000.0, n.sign_time='2024-11-01', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
// G
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P08'}) ON CREATE SET n.contract_code='HT-2025-CG-0012', n.contract_name='MOCK10_断路器采购合同',          n.payment_direction='采购', n.contract_amount=8900000.0,  n.sign_time='2025-01-05', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M08'}) ON CREATE SET n.contract_code='HT-2025-XS-0023', n.contract_name='MOCK10_断路器中间销售合同',      n.payment_direction='销售', n.contract_amount=9450000.0,  n.sign_time='2025-01-20', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';
MERGE (n:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S08'}) ON CREATE SET n.contract_code='HT-2025-XS-0041', n.contract_name='MOCK10_断路器销售合同',          n.payment_direction='销售', n.contract_amount=9980000.0,  n.sign_time='2025-02-10', n.status_name='已生效', n.schema_name='dws_dsjsj_zstp_vertex_ht';


// -----------------------------------------------------------------------------
// 四、入库 / 出库
// -----------------------------------------------------------------------------
// A
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_A1'}) ON CREATE SET n.mblnr='RK-2024-0315', n.menge='120',  n.budat='2024-03-18',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A2'}) ON CREATE SET n.vbeln='CK-2024-0420', n.meins='PC',   n.wadat_ist='2024-04-22',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A3'}) ON CREATE SET n.vbeln='CK-2024-0528', n.meins='PC',   n.wadat_ist='2024-05-28',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_A2'}) ON CREATE SET n.mblnr='RK-2024-0910', n.menge='80',   n.budat='2024-09-10',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A4'}) ON CREATE SET n.vbeln='CK-2024-1015', n.meins='PC',   n.wadat_ist='2024-10-15',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A5'}) ON CREATE SET n.vbeln='CK-2024-1120', n.meins='PC',   n.wadat_ist='2024-11-20',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
// B
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_B1'}) ON CREATE SET n.mblnr='RK-2024-0605', n.menge='3000', n.budat='2024-06-05',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_B2'}) ON CREATE SET n.vbeln='CK-2024-0628', n.meins='M',    n.wadat_ist='2024-06-28',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_B3'}) ON CREATE SET n.vbeln='CK-2024-0712', n.meins='M',    n.wadat_ist='2024-07-12',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
// C
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_C1'}) ON CREATE SET n.mblnr='RK-2024-0205', n.menge='500',  n.budat='2024-02-05',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_C2'}) ON CREATE SET n.vbeln='CK-2024-0218', n.meins='PCS',  n.wadat_ist='2024-02-18',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_C3'}) ON CREATE SET n.vbeln='CK-2024-0304', n.meins='PCS',  n.wadat_ist='2024-03-04',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
// D
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_D1'}) ON CREATE SET n.mblnr='RK-2024-0403', n.menge='40',   n.budat='2024-04-03',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_D2'}) ON CREATE SET n.vbeln='CK-2024-0425', n.meins='TAI',  n.wadat_ist='2024-04-25',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_D3'}) ON CREATE SET n.vbeln='CK-2024-0512', n.meins='TAI',  n.wadat_ist='2024-05-12',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
// E
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_E1'}) ON CREATE SET n.mblnr='RK-2024-0803', n.menge='600',  n.budat='2024-08-03',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_E2'}) ON CREATE SET n.vbeln='CK-2024-0812', n.meins='M',    n.wadat_ist='2024-08-12',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_E3'}) ON CREATE SET n.vbeln='CK-2024-0822', n.meins='M',    n.wadat_ist='2024-08-22',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
// F
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_F1'}) ON CREATE SET n.mblnr='RK-2024-1003', n.menge='12',   n.budat='2024-10-03',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_F2'}) ON CREATE SET n.vbeln='CK-2024-1018', n.meins='SET',  n.wadat_ist='2024-10-18',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_F3'}) ON CREATE SET n.vbeln='CK-2024-1105', n.meins='SET',  n.wadat_ist='2024-11-05',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
// G
MERGE (n:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_G1'}) ON CREATE SET n.mblnr='RK-2025-0108', n.menge='30',   n.budat='2025-01-08',      n.schema_name='dws_dsjsj_zstp_vertex_rk';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_G2'}) ON CREATE SET n.vbeln='CK-2025-0123', n.meins='TAI',  n.wadat_ist='2025-01-23',  n.schema_name='dws_dsjsj_zstp_vertex_ck';
MERGE (n:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_G3'}) ON CREATE SET n.vbeln='CK-2025-0212', n.meins='TAI',  n.wadat_ist='2025-02-12',  n.schema_name='dws_dsjsj_zstp_vertex_ck';


// -----------------------------------------------------------------------------
// 五、风险线索（0101 结果）
// -----------------------------------------------------------------------------
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_A'}) ON CREATE SET n.risk_type='企业电话相同',       n.risk_desc='MOCK10: 华信数智与国电投数字科技登记电话一致',       n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_A'}) ON CREATE SET n.risk_type='注册地址相同',       n.risk_desc='MOCK10: 国电投信息技术与中电科汇智登记地址一致',     n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_B'}) ON CREATE SET n.risk_type='股东相同（自然人）', n.risk_desc='MOCK10: 江苏远东与江苏电力自然人股东重合',           n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_B'}) ON CREATE SET n.risk_type='高管姓名相同',       n.risk_desc='MOCK10: 能源科技工程与上海申能高管同名',             n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_D'}) ON CREATE SET n.risk_type='企业电话相同',       n.risk_desc='MOCK10: 山东鲁电与山东电力登记电话一致',             n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_E'}) ON CREATE SET n.risk_type='股东相同（企业）',   n.risk_desc='MOCK10: 浙江晨光与浙江电力股东重合',                 n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_E'}) ON CREATE SET n.risk_type='注册地址相同',       n.risk_desc='MOCK10: 浙江新能源与宁波甬能登记地址一致',           n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_F'}) ON CREATE SET n.risk_type='企业电话相同',       n.risk_desc='MOCK10: 广东南粤与广东电力登记电话一致',             n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_F'}) ON CREATE SET n.risk_type='高管姓名相同',       n.risk_desc='MOCK10: 广东粤电工程与深圳前海能源高管同名',         n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_G'}) ON CREATE SET n.risk_type='股东相同（自然人）', n.risk_desc='MOCK10: 四川蜀能与四川电力自然人股东重合',           n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';
MERGE (n:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_G'}) ON CREATE SET n.risk_type='企业电话相同',       n.risk_desc='MOCK10: 西南能源与成都锦江登记电话一致',             n.risk_summary='交易双方存在异常关联关系', n.schema_name='dws_dsjsj_zstp_vertex_fxxs';

// =============================================================================
// 六、关系
// =============================================================================

// ===== A 正例：签约链（链条一，早）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A01'}]->(b) ON CREATE SET e.sign_time='2024-03-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A02'}]->(b) ON CREATE SET e.sign_time='2024-03-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A03'}]->(b) ON CREATE SET e.sign_time='2024-04-12', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A04'}]->(b) ON CREATE SET e.sign_time='2024-04-12', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A05'}]->(b) ON CREATE SET e.sign_time='2024-05-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S01'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A06'}]->(b) ON CREATE SET e.sign_time='2024-05-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// ===== A 正例：签约链（链条二，晚）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P02'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A07'}]->(b) ON CREATE SET e.sign_time='2024-09-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P02'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A08'}]->(b) ON CREATE SET e.sign_time='2024-09-02', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M02'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A09'}]->(b) ON CREATE SET e.sign_time='2024-10-08', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M02'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A10'}]->(b) ON CREATE SET e.sign_time='2024-10-08', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S02'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A11'}]->(b) ON CREATE SET e.sign_time='2024-11-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_A'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S02'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_A12'}]->(b) ON CREATE SET e.sign_time='2024-11-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
// ===== A 正例：物流（链条一）=====
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P01'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_A1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_A1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M01'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S01'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// ===== A 正例：物流（链条二）=====
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P02'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_A2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_A2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M02'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A4'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_A03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A4'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_A03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S02'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A5'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_A04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_A'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_A5'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_A04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
// ===== A 正例：风险线索 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_A01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_A02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_A03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_A'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_A'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_A04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== B 正例 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_B'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_B01'}]->(b) ON CREATE SET e.sign_time='2024-06-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_B'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_B02'}]->(b) ON CREATE SET e.sign_time='2024-06-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_B'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_B03'}]->(b) ON CREATE SET e.sign_time='2024-06-25', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_B'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_B04'}]->(b) ON CREATE SET e.sign_time='2024-06-25', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_B'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_B05'}]->(b) ON CREATE SET e.sign_time='2024-07-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_B'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S03'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_B06'}]->(b) ON CREATE SET e.sign_time='2024-07-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P03'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_B1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_B'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_B1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M03'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_B2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_B'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_B2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S03'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_B3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_B02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_B'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_B3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_B02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_B01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_B02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_B03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_B'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_B'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_B04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== C 反例1：链条完整、无线索 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_C01'}]->(b) ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_C02'}]->(b) ON CREATE SET e.sign_time='2024-02-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_C03'}]->(b) ON CREATE SET e.sign_time='2024-02-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_C04'}]->(b) ON CREATE SET e.sign_time='2024-02-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_C05'}]->(b) ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_C'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S04'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_C06'}]->(b) ON CREATE SET e.sign_time='2024-03-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P04'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_C1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_C'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_C1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M04'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_C2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_C'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_C2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_C01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S04'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_C3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_C02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_C'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_C3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_C02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';

// ===== D 反例2：仅左侧线索 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_D01'}]->(b) ON CREATE SET e.sign_time='2024-04-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_D02'}]->(b) ON CREATE SET e.sign_time='2024-04-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_D03'}]->(b) ON CREATE SET e.sign_time='2024-04-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_D04'}]->(b) ON CREATE SET e.sign_time='2024-04-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_D05'}]->(b) ON CREATE SET e.sign_time='2024-05-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_D'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S05'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_D06'}]->(b) ON CREATE SET e.sign_time='2024-05-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P05'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_D1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_D'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_D1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M05'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_D2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_D'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_D2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S05'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_D3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_D02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_D'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_D3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_D02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_D'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_D'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_D01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_D'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_D'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_D02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== E 反例3：物料不贯通（入库 WL_EA，出库 WL_EB）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_E01'}]->(b) ON CREATE SET e.sign_time='2024-08-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_E02'}]->(b) ON CREATE SET e.sign_time='2024-08-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_E03'}]->(b) ON CREATE SET e.sign_time='2024-08-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_E04'}]->(b) ON CREATE SET e.sign_time='2024-08-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_E05'}]->(b) ON CREATE SET e.sign_time='2024-08-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_E'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S06'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_E06'}]->(b) ON CREATE SET e.sign_time='2024-08-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P06'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_E1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_EA'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_E1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M06'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_E2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_EB'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_E2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S06'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_E3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_E02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_EB'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_E3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_E02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_E'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_E'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_E01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_E'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_E'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_E02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_E'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_E'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_E03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_E'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_E'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_E04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== F 反例4：中间主体 GDTB_F 非国电投 =====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P07'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_F01'}]->(b) ON CREATE SET e.sign_time='2024-10-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P07'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_F02'}]->(b) ON CREATE SET e.sign_time='2024-10-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M07'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_F03'}]->(b) ON CREATE SET e.sign_time='2024-10-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M07'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_F04'}]->(b) ON CREATE SET e.sign_time='2024-10-15', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S07'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_F05'}]->(b) ON CREATE SET e.sign_time='2024-11-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_F'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S07'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_F06'}]->(b) ON CREATE SET e.sign_time='2024-11-01', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P07'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_F1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_F'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_F1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M07'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_F2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_F'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_F2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S07'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_F3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_F02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_F'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_F3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_F02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_F'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_F'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_F01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_F'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_F'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_F02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_F'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_F'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_F03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_F'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_F'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_F04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';

// ===== G 变体B专用：三个物料节点同 matnr（主查询不命中，变体B命中）=====
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_G'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P08'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_G01'}]->(b) ON CREATE SET e.sign_time='2025-01-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_G'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P08'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_G02'}]->(b) ON CREATE SET e.sign_time='2025-01-05', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_G'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M08'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_G03'}]->(b) ON CREATE SET e.sign_time='2025-01-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_G'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M08'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_G04'}]->(b) ON CREATE SET e.sign_time='2025-01-20', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_G'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S08'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_G05'}]->(b) ON CREATE SET e.sign_time='2025-02-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_G'}),(b:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S08'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_qd {object_key:'MOCK10_E_QD_G06'}]->(b) ON CREATE SET e.sign_time='2025-02-10', e.schema_name='dws_dsjsj_zstp_edge_qy_qd';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_P08'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_G1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_acghtrk {object_key:'MOCK10_E_AC_G01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_acghtrk';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_GA'}),(b:dws_dsjsj_zstp_vertex_rk {object_key:'MOCK10_RK_G1'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_lywl {object_key:'MOCK10_E_LY_G01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_lywl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_M08'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_G2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_G01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_GB'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_G2'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_G01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_ht {object_key:'MOCK10_HT_S08'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_G3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_ht_axshtck {object_key:'MOCK10_E_AX_G02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_ht_axshtck';
MATCH (a:dws_dsjsj_zstp_vertex_wl {object_key:'MOCK10_WL_GC'}),(b:dws_dsjsj_zstp_vertex_ck {object_key:'MOCK10_CK_G3'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_wl_xhwl {object_key:'MOCK10_E_XH_G02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_wl_xhwl';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_SUP_G'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_G'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_G01'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTA_G'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_L_G'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_G02'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_GDTB_G'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_G'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_G03'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';
MATCH (a:dws_dsjsj_zstp_vertex_qy {object_key:'MOCK10_QY_BUY_G'}),(b:dws_dsjsj_zstp_vertex_fxxs {object_key:'MOCK10_FXXS_R_G'}) MERGE (a)-[e:dws_dsjsj_zstp_edge_qy_cffx {object_key:'MOCK10_E_FX_G04'}]->(b) ON CREATE SET e.schema_name='dws_dsjsj_zstp_edge_qy_cffx';


// =============================================================================
// 七、清理（确认不再需要时执行）
// =============================================================================
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK10_' DETACH DELETE n;
