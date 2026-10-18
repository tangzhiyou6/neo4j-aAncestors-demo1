// =============================================================================
// 08 模拟数据：风险线索（risk_type）驱动的 3 层控股 + 电话相同 场景
// -----------------------------------------------------------------------------
// 对应示意图的结构：
//
//   风险线索(risk_type='企业电话相同') ◄──触发风险_企业── 股东企业甲 / 股东企业乙
//        股东企业甲 ──股东持股──► 控股平台甲 ──股东持股──► 某国电投企业   (2 层)
//        股东企业乙 ──股东持股──► 中间层B1 ──► 中间层B2 ──► 外部企业     (3 层，卡边界)
//        某国电投企业 ──签订合同──► 1号合同 ◄──签订合同── 外部企业
//        某国电投企业 ──开具/接收发票──► 发票 ◄──开具/接收发票── 外部企业
//
// 刻意埋的边界用例：
//   ✔ 命中：股东企业甲 →(2 层)→ 某国电投企业，电话相同
//   ✔ 命中：股东企业乙 →(3 层)→ 外部企业，电话相同（验证层数边界）
//   × 排除：股东企业甲 →(1 层)→ 无关企业丙，图上可达但【电话不同】
//   × 排除：中间层节点自身电话不同，不会被误报
//
// 全部 object_key 带 MOCK2_ 前缀；全 MERGE 幂等，可重复执行。
// 一键清理见文件末尾第八节。
// =============================================================================


// =============================================================================
// 一、风险线索节点（risk_type 取值对应示意图中的 6 类）
// =============================================================================
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK2_FX_PHONE'})
  ON CREATE SET n.risk_type    = '企业电话相同',
                n.risk_desc    = '两家企业工商登记电话完全一致，疑似同一实际控制人或代持安排',
                n.risk_summary = '企业电话相同',
                n.schema_name  = '风险线索';

MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK2_FX_ADDR'})
  ON CREATE SET n.risk_type    = '注册地址相同',
                n.risk_desc    = '两家企业注册地址完全一致，疑似空壳或关联方',
                n.risk_summary = '注册地址相同',
                n.schema_name  = '风险线索';

// 其余 4 类线索类型仅建节点占位，便于演示 risk_type 驱动的通用性
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK2_FX_MGR'})
  ON CREATE SET n.risk_type = '高管姓名相同',        n.risk_summary = '高管姓名相同',       n.schema_name = '风险线索';
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK2_FX_SHZRR'})
  ON CREATE SET n.risk_type = '股东相同（自然人）',  n.risk_summary = '股东相同（自然人）', n.schema_name = '风险线索';
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK2_FX_SHQY'})
  ON CREATE SET n.risk_type = '股东相同（企业）',    n.risk_summary = '股东相同（企业）',   n.schema_name = '风险线索';
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK2_FX_BOTH'})
  ON CREATE SET n.risk_type = '股东与高管姓名相同',  n.risk_summary = '股东与高管姓名相同', n.schema_name = '风险线索';


// =============================================================================
// 二、企业节点
// =============================================================================

// --- 触发风险的企业（示意图中的两个"股东企业"）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
  ON CREATE SET n.org_name='国电投示范产业投资集团有限公司（股东企业甲）',
                n.phonenumber='010-88886666', n.reglocation='北京市西城区示范路 1 号院',
                n.uscc='91110000MOCK2SHJ1A', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_SH_YI'})
  ON CREATE SET n.org_name='国电投协同发展有限公司（股东企业乙）',
                n.phonenumber='010-88886666', n.reglocation='北京市西城区示范路 1 号院',
                n.uscc='91110000MOCK2SHY1B', n.schema_name='企业';

// --- 控股链中间层（电话刻意不同，验证中间层不被误报）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_HOLD_A'})
  ON CREATE SET n.org_name='示范控股平台有限公司',
                n.phonenumber='010-66665555', n.reglocation='北京市海淀区中关南路 8 号',
                n.uscc='91110000MOCK2HOLA1', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_MID_B1'})
  ON CREATE SET n.org_name='协同资本管理有限公司',
                n.phonenumber='010-77778888', n.reglocation='上海市浦东新区协同路 100 号',
                n.uscc='91310000MOCK2MIDB1', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_MID_B2'})
  ON CREATE SET n.org_name='协同实业投资有限公司',
                n.phonenumber='010-77779999', n.reglocation='上海市浦东新区协同路 200 号',
                n.uscc='91310000MOCK2MIDB2', n.schema_name='企业';

// --- 控股链末端（示意图中的"某国电投企业"和"外部企业"，电话与股东企业相同）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_SPIC'})
  ON CREATE SET n.org_name='某国电投企业',
                n.phonenumber='010-88886666', n.reglocation='北京市西城区示范路 1 号院 3 号楼',
                n.uscc='91110000MOCK2SPIC1', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_WB'})
  ON CREATE SET n.org_name='外部企业',
                n.phonenumber='010-88886666', n.reglocation='北京市西城区示范路 1 号院 5 号楼',
                n.uscc='91110000MOCK2WB001', n.schema_name='企业';

// --- 反例：图上可达但电话不同，必须被查询排除 ---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK2_OTH'})
  ON CREATE SET n.org_name='无关企业丙',
                n.phonenumber='010-12345678', n.reglocation='广州市天河区无关大道 9 号',
                n.uscc='91440000MOCK2OTH01', n.schema_name='企业';


// =============================================================================
// 三、合同与发票（示意图下半部分的业务边）
// =============================================================================
MERGE (n:ZSTP:`合同` {object_key: 'MOCK2_HT_001'})
  ON CREATE SET n.contract_name='1号合同', n.contract_no='HT-MOCK2-2026-001',
                n.contract_amount=5200000.0, n.contract_status='履行中',
                n.schema_name='合同';
MERGE (n:ZSTP:`发票` {object_key: 'MOCK2_FP_001'})
  ON CREATE SET n.invoice_code='FP-MOCK2-001', n.invoice_no='04403190021011',
                n.invoice_amt=5200000.0, n.schema_name='发票';


// =============================================================================
// 四、触发风险_企业 边（企业 → 风险线索）
// =============================================================================
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK2_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK2_REL_SHJIA_FXPHONE'}]->(r);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_YI'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK2_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK2_REL_SHYI_FXPHONE'}]->(r);

// 两家股东企业同时也触发"注册地址相同"线索（地址也一致）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK2_FX_ADDR'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK2_REL_SHJIA_FXADDR'}]->(r);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_YI'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK2_FX_ADDR'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK2_REL_SHYI_FXADDR'}]->(r);


// =============================================================================
// 五、股东持股（%）企业-企业 边（股东 → 被控股企业）
// -----------------------------------------------------------------------------

// 甲链：股东企业甲 →(1 层)→ 控股平台甲 →(2 层)→ 某国电投企业
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK2_HOLD_A'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK2_SH_JIA_GT_HOLD_A'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=60.0,
                e.capital_amomon='6000万元人民币', e.capital_time='2020-06-30',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_HOLD_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK2_SPIC'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK2_HOLD_A_GT_SPIC'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=55.0,
                e.capital_amomon='5500万元人民币', e.capital_time='2021-03-15',
                e.schema_name='股东持股（%）企业-企业';

// 乙链：股东企业乙 →(1)→ 中间层B1 →(2)→ 中间层B2 →(3)→ 外部企业（正好卡 3 层边界）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_YI'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK2_MID_B1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK2_SH_YI_GT_B1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=51.0,
                e.capital_amomon='5100万元人民币', e.capital_time='2019-09-20',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_MID_B1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK2_MID_B2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK2_B1_GT_B2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=60.0,
                e.capital_amomon='3000万元人民币', e.capital_time='2020-12-01',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_MID_B2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK2_WB'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK2_B2_GT_WB'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=50.0,
                e.capital_amomon='2000万元人民币', e.capital_time='2022-05-18',
                e.schema_name='股东持股（%）企业-企业';

// 反例：股东企业甲 →(1 层)→ 无关企业丙（图上可达，但电话不同）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK2_OTH'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK2_SH_JIA_GT_OTH'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=80.0,
                e.capital_amomon='8000万元人民币', e.capital_time='2018-04-10',
                e.schema_name='股东持股（%）企业-企业';


// =============================================================================
// 六、签订合同 / 开具接收发票 边（企业 → 合同/发票）
// =============================================================================
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SPIC'})
MERGE (b:ZSTP:`合同` {object_key: 'MOCK2_HT_001'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_SPIC_HT001'}]->(b)
  ON CREATE SET e.contract_amount='520万元', e.contract_status='履行中',
                e.sign_time='2026-01-15', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_WB'})
MERGE (b:ZSTP:`合同` {object_key: 'MOCK2_HT_001'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_WB_HT001'}]->(b)
  ON CREATE SET e.contract_amount='520万元', e.contract_status='履行中',
                e.sign_time='2026-01-20', e.schema_name='签订合同';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SPIC'})
MERGE (b:ZSTP:`发票` {object_key: 'MOCK2_FP_001'})
MERGE (a)-[e:`开具接收发票` {object_key: 'MOCK2_SPIC_FP001'}]->(b);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_WB'})
MERGE (b:ZSTP:`发票` {object_key: 'MOCK2_FP_001'})
MERGE (a)-[e:`开具接收发票` {object_key: 'MOCK2_WB_FP001'}]->(b);


// =============================================================================
// 七、核验查询（灌完数据后逐条跑，对照预期结果）
// =============================================================================

// 7.1 触发"企业电话相同"线索的企业应为 2 家
// MATCH (r:ZSTP:`风险线索` {risk_type:'企业电话相同'})<-[:`触发风险_企业`]-(a)
// RETURN a.org_name, a.phonenumber;
// 预期：股东企业甲 / 股东企业乙，电话均为 010-88886666

// 7.2 核心查询（07 文件第一节）：预期命中 2 行
//   国电投示范产业投资集团有限公司（股东企业甲） → 某国电投企业   2 层
//   国电投协同发展有限公司（股东企业乙）         → 外部企业       3 层

// 7.3 第三节全景查询：额外可见"无关企业丙 1 层 × 电话不同"的反例行

// 7.4 第五节末端企业配对：预期 1 行
//   某国电投企业 ↔ 外部企业，共同电话 010-88886666


// =============================================================================
// 八、一键清理本套模拟数据
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK2_' DETACH DELETE n;
