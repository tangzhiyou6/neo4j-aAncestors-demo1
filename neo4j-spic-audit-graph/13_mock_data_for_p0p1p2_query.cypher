// =============================================================================
// 13 目标查询专属模拟数据（对应"风险线索 → 3 层控股穿透 → 电话相同 → 同签一份合同"）
// -----------------------------------------------------------------------------
// 目标查询（原样引用，未做任何修改）：
//
//   MATCH p0=(r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
//   WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
//   MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
//   WHERE b <> a
//   AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
//   AND b.phonenumber = a.phonenumber
//   MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
//   WITH r, p0, p1, p2, a, b, c
//   ORDER BY coalesce(c.sign_time, ''), c.object_key
//   WITH r, p0, p1, a, b, collect(p2)[0] AS p2, collect(c)[0] AS 合同
//   RETURN p0,p1,p2
//
// -----------------------------------------------------------------------------
// 数据前缀：MOCK5_（与 MOCK_/MOCK2_/MOCK3_/MOCK4_ 互不干扰），全 MERGE 幂等
// 依赖：无（自包含，可单独执行）；建议先执行 01_neo4j_ddl.cypher 建约束
//
// 图结构（括号内为 phonenumber；甲、乙均触发同一条风险线索）：
//
//   线索 MOCK5_FX_PHONE (risk_type='企业电话相同')
//     ▲触发风险_企业
//     ├── 甲企业(0755-5000-0000)
//     └── 乙企业(0755-5000-0000)
//
//   ① 甲 ──持股──► H1 ──持股──► 丙企业(0755-5000-0000)        2 层 + 共签 HT1/HT2  → 命中
//   ② 乙 ──持股──► M1 ──持股──► M2 ──持股──► 壬企业(0755-5000-0000)  3 层 + 共签 HT5  → 命中（卡 3 层边界）
//   ③ 甲 ──持股──► H2 ──持股──► 己企业(0755-5000-0000)        2 层但【无共同合同】      → 排除
//   ④ 甲 ──持股──► H2 ──持股──► 庚企业(0755-6000-0000)        2 层且共签 HT3，但【电话不同】→ 排除
//   ⑤ 甲 ──持股──► P1 ──► P2 ──► P3 ──持股──► 戊企业(0755-5000-0000)  4 层            → 排除（超 3 层上限）
//   ⑥ 辛企业(0755-5000-0000) 与甲共签 HT4，但【图上无控股链路】                        → 排除
//   ⑦ 中间层 H1/H2/P1/P2/P3/M1/M2 电话均不同                                          → 不误报
//
// 预期返回 2 行（详见第七节）：
//   行1：a=甲企业 → b=丙企业（2 层），取 p2 为 HT-MOCK5-2026-001
//   行2：a=乙企业 → b=壬企业（3 层），取 p2 为 HT-MOCK5-2026-005
//
// 字段口径：工商注册号用 DDL 定义的 `org_credit_code`（早期 mock 用的 uscc 不在 DDL 的
//           `企业` 字段表内）；`schema_name` 为图谱自有溯源属性。边属性名同样对齐 DDL：
//           股东持股边 ft_shareholding/capital_amomon/capital_percent/capital_time，
//           签订合同边 contract_amount/contract_status/sign_time。
// =============================================================================


// =============================================================================
// 一、风险线索节点
// =============================================================================
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK5_FX_PHONE'})
  ON CREATE SET n.risk_type    = '企业电话相同',
                n.risk_desc    = '多家企业工商登记电话完全一致，疑似同一实际控制人或代持安排',
                n.risk_summary = '企业电话相同',
                n.schema_name  = '风险线索';


// =============================================================================
// 二、企业节点
// =============================================================================

// --- 触发风险的企业（两家，电话相同，都挂在同一条线索上）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_A'})
  ON CREATE SET n.org_name='国电投示范产业投资集团有限公司（甲企业）',
                n.org_credit_code='91110000MOCK5A0001', n.reglocation='北京市西城区示范路 1 号院',
                n.regstatus='存续', n.phonenumber='0755-5000-0000', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_B'})
  ON CREATE SET n.org_name='国电投协同发展有限公司（乙企业）',
                n.org_credit_code='91110000MOCK5B0001', n.reglocation='北京市西城区示范路 2 号院',
                n.regstatus='存续', n.phonenumber='0755-5000-0000', n.schema_name='企业';

// --- 控股链中间层（电话刻意不同，用于验证中间层不被误报）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_H1'})
  ON CREATE SET n.org_name='示范控股平台 H1 有限公司',
                n.org_credit_code='91110000MOCK5H1001', n.reglocation='北京市海淀区中关南路 8 号',
                n.phonenumber='0755-5001-0001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_H2'})
  ON CREATE SET n.org_name='示范控股平台 H2 有限公司',
                n.org_credit_code='91110000MOCK5H2001', n.reglocation='北京市海淀区中关北路 9 号',
                n.phonenumber='0755-5001-0002', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_P1'})
  ON CREATE SET n.org_name='远端中间层 P1 有限公司',
                n.org_credit_code='91110000MOCK5P1001', n.reglocation='上海市浦东新区甲路 1 号',
                n.phonenumber='0755-5002-0001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_P2'})
  ON CREATE SET n.org_name='远端中间层 P2 有限公司',
                n.org_credit_code='91110000MOCK5P2001', n.reglocation='上海市浦东新区甲路 2 号',
                n.phonenumber='0755-5002-0002', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_P3'})
  ON CREATE SET n.org_name='远端中间层 P3 有限公司',
                n.org_credit_code='91110000MOCK5P3001', n.reglocation='上海市浦东新区甲路 3 号',
                n.phonenumber='0755-5002-0003', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_M1'})
  ON CREATE SET n.org_name='协同中间层 M1 有限公司',
                n.org_credit_code='91110000MOCK5M1001', n.reglocation='上海市浦东新区乙路 1 号',
                n.phonenumber='0755-5003-0001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_M2'})
  ON CREATE SET n.org_name='协同中间层 M2 有限公司',
                n.org_credit_code='91110000MOCK5M2001', n.reglocation='上海市浦东新区乙路 2 号',
                n.phonenumber='0755-5003-0002', n.schema_name='企业';

// --- 末端企业：命中样本（电话与涉事企业相同）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_C'})
  ON CREATE SET n.org_name='某国电投丙企业',
                n.org_credit_code='91110000MOCK5C0001', n.reglocation='北京市西城区示范路 1 号院 3 号楼',
                n.phonenumber='0755-5000-0000', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_R'})
  ON CREATE SET n.org_name='外部壬企业',
                n.org_credit_code='91110000MOCK5R0001', n.reglocation='广州市天河区协同大道 7 号',
                n.phonenumber='0755-5000-0000', n.schema_name='企业';

// --- 末端企业：反例（分别用于验证层数上限、共同合同缺省、电话不等、无控股链路）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_E'})
  ON CREATE SET n.org_name='远端戊企业（4 层反例）',
                n.org_credit_code='91110000MOCK5E0001', n.reglocation='广州市天河区远端大道 4 号',
                n.phonenumber='0755-5000-0000', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_F'})
  ON CREATE SET n.org_name='某己企业（无共同合同反例）',
                n.org_credit_code='91110000MOCK5F0001', n.reglocation='天津市和平区反例路 5 号',
                n.phonenumber='0755-5000-0000', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_G'})
  ON CREATE SET n.org_name='某庚企业（电话不同反例）',
                n.org_credit_code='91110000MOCK5G0001', n.reglocation='天津市和平区反例路 6 号',
                n.phonenumber='0755-6000-0000', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK5_X'})
  ON CREATE SET n.org_name='某辛企业（无控股链路反例）',
                n.org_credit_code='91110000MOCK5X0001', n.reglocation='重庆市渝中区孤立路 1 号',
                n.phonenumber='0755-5000-0000', n.schema_name='企业';


// =============================================================================
// 三、合同节点（字段名对齐 DDL：contract_code/contract_name/gategory_name/
//     contract_amount/sign_time/status_name）
// =============================================================================
MERGE (n:ZSTP:`合同` {object_key: 'MOCK5_HT1'})
  ON CREATE SET n.contract_code='HT-MOCK5-2026-001', n.contract_name='甲丙 1 号合同',
                n.gategory_name='设备采购合同', n.contract_amount=4200000.0,
                n.sign_time='2026-04-10', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK5_HT2'})
  ON CREATE SET n.contract_code='HT-MOCK5-2026-002', n.contract_name='甲丙 2 号合同',
                n.gategory_name='技术服务合同', n.contract_amount=1800000.0,
                n.sign_time='2026-06-20', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK5_HT3'})
  ON CREATE SET n.contract_code='HT-MOCK5-2026-003', n.contract_name='甲庚合同（电话不等反例）',
                n.gategory_name='咨询服务合同', n.contract_amount=650000.0,
                n.sign_time='2026-02-11', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK5_HT4'})
  ON CREATE SET n.contract_code='HT-MOCK5-2026-004', n.contract_name='甲辛合同（无控股链路反例）',
                n.gategory_name='购销合同', n.contract_amount=980000.0,
                n.sign_time='2026-01-15', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK5_HT5'})
  ON CREATE SET n.contract_code='HT-MOCK5-2026-005', n.contract_name='乙壬 3 层合同',
                n.gategory_name='工程服务合同', n.contract_amount=2700000.0,
                n.sign_time='2026-03-05', n.status_name='履行中', n.schema_name='合同';


// =============================================================================
// 四、触发风险_企业 边（企业 → 风险线索）
// =============================================================================
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK5_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK5_REL_A_FX'}]->(r)
  ON CREATE SET e.schema_name='触发风险_企业';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_B'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK5_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK5_REL_B_FX'}]->(r)
  ON CREATE SET e.schema_name='触发风险_企业';


// =============================================================================
// 五、股东持股（%）企业-企业 边（股东 → 被控股企业，有向；与 p1 的 -> 方向一致）
// =============================================================================
// ① 甲 → H1 → 丙（2 层）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_H1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_A_H1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=60.0,
                e.capital_amomon='6000万元人民币', e.capital_time='2020-06-30',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_H1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_C'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_H1_C'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=55.0,
                e.capital_amomon='5500万元人民币', e.capital_time='2021-03-15',
                e.schema_name='股东持股（%）企业-企业';

// ② 乙 → M1 → M2 → 壬（3 层，卡边界）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_B'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_M1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_B_M1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=68.0,
                e.capital_amomon='6800万元人民币', e.capital_time='2019-09-01',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_M1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_M2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_M1_M2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=62.0,
                e.capital_amomon='6200万元人民币', e.capital_time='2020-11-20',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_M2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_R'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_M2_R'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=51.0,
                e.capital_amomon='5100万元人民币', e.capital_time='2022-04-01',
                e.schema_name='股东持股（%）企业-企业';

// ③④ 甲 → H2 → 己（2 层，无共同合同）、甲 → H2 → 庚（2 层，电话不同）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_H2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_A_H2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=70.0,
                e.capital_amomon='7000万元人民币', e.capital_time='2019-01-10',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_H2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_F'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_H2_F'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=58.0,
                e.capital_amomon='5800万元人民币', e.capital_time='2021-07-10',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_H2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_G'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_H2_G'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=45.0,
                e.capital_amomon='4500万元人民币', e.capital_time='2022-01-06',
                e.schema_name='股东持股（%）企业-企业';

// ⑤ 甲 → P1 → P2 → P3 → 戊（4 层，应被 1..3 层上限排除）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_P1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_A_P1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=65.0,
                e.capital_amomon='6500万元人民币', e.capital_time='2018-05-18',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_P1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_P2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_P1_P2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=63.0,
                e.capital_amomon='6300万元人民币', e.capital_time='2019-08-08',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_P2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_P3'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_P2_P3'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=57.0,
                e.capital_amomon='5700万元人民币', e.capital_time='2020-02-14',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_P3'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK5_E'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK5_GT_P3_E'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=50.0,
                e.capital_amomon='5000万元人民币', e.capital_time='2021-12-01',
                e.schema_name='股东持股（%）企业-企业';
// 注：辛企业(MOCK5_X) 刻意【不】建任何持股边 —— 用于验证"仅凭合同+同电话不能命中"


// =============================================================================
// 六、签订合同 边（企业 → 合同；同一对 (a,b) 共同指向同一合同 = 共同合同）
// =============================================================================
// ① 甲 ↔ 丙：两份（HT1 2026-04-10、HT2 2026-06-20）→ 查询按 sign_time 升序只取 HT1
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT1'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_A_HT1'}]->(c)
  ON CREATE SET e.contract_amount='420万元', e.contract_status='履行中',
                e.sign_time='2026-04-10', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_C'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT1'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_C_HT1'}]->(c)
  ON CREATE SET e.contract_amount='420万元', e.contract_status='履行中',
                e.sign_time='2026-04-10', e.schema_name='签订合同';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT2'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_A_HT2'}]->(c)
  ON CREATE SET e.contract_amount='180万元', e.contract_status='履行中',
                e.sign_time='2026-06-20', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_C'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT2'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_C_HT2'}]->(c)
  ON CREATE SET e.contract_amount='180万元', e.contract_status='履行中',
                e.sign_time='2026-06-20', e.schema_name='签订合同';

// ④ 甲 ↔ 庚：有共同合同，但庚电话不同 → 应在 p1 的 WHERE 处被排除
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT3'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_A_HT3'}]->(c)
  ON CREATE SET e.contract_amount='65万元', e.contract_status='履行中',
                e.sign_time='2026-02-11', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_G'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT3'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_G_HT3'}]->(c)
  ON CREATE SET e.contract_amount='65万元', e.contract_status='履行中',
                e.sign_time='2026-02-11', e.schema_name='签订合同';

// ⑥ 甲 ↔ 辛：电话相同 + 有共同合同，但图上无控股链路 → 应在 p1 处无匹配而排除
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT4'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_A_HT4'}]->(c)
  ON CREATE SET e.contract_amount='98万元', e.contract_status='履行中',
                e.sign_time='2026-01-15', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_X'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT4'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_X_HT4'}]->(c)
  ON CREATE SET e.contract_amount='98万元', e.contract_status='履行中',
                e.sign_time='2026-01-15', e.schema_name='签订合同';

// ② 乙 ↔ 壬：共同合同 HT5（配合 3 层控股 → 命中）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_B'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT5'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_B_HT5'}]->(c)
  ON CREATE SET e.contract_amount='270万元', e.contract_status='履行中',
                e.sign_time='2026-03-05', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK5_R'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK5_HT5'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK5_R_HT5'}]->(c)
  ON CREATE SET e.contract_amount='270万元', e.contract_status='履行中',
                e.sign_time='2026-03-05', e.schema_name='签订合同';

// 注：己企业(MOCK5_F)、戊企业(MOCK5_E) 刻意【不】与甲、乙 建任何共同合同


// =============================================================================
// 七、预期结果（跑完第六节后，执行第二节的目标查询，应返回 2 行）
// =============================================================================
// 行1：p0 = 线索 ←甲企业；p1 = 甲企业 →H1→ 丙企业（2 层）；
//      p2 = 甲企业 →HT1← 丙企业，合同 HT-MOCK5-2026-001（sign_time 2026-04-10，两份中最早）
// 行2：p0 = 线索 ←乙企业；p1 = 乙企业 →M1→M2→ 壬企业（3 层）；
//      p2 = 乙企业 →HT5← 壬企业，合同 HT-MOCK5-2026-005
//
// 被正确排除的 4 类反例：
//   己企业：2 层控股 + 电话相同，但无共同合同          → 卡在 p2
//   庚企业：2 层控股 + 有共同合同，但电话不同          → 卡在 p1 的 WHERE phone
//   辛企业：电话相同 + 有共同合同，但无控股链路        → 卡在 p1 无匹配
//   戊企业：电话相同，但需 4 层才可达（超 1..3 上限）  → 卡在 p1 无匹配
// 另外：中间层 H1/H2/P1/P2/P3/M1/M2 电话均不同，不会被误报为末端企业。
//
// 如需自查"只筛 1..3 层、不筛电话、不筛合同"的中间结果（应返回 11 行）：
//   甲企业 → H1(1层) / 丙企业(2层) / H2(1层) / 己企业(2层) / 庚企业(2层)
//            / P1(1层) / P2(2层) / P3(3层)
//   乙企业 → M1(1层) / M2(2层) / 壬企业(3层)
//   戊企业【不出现】——它距甲企业 4 层，超出 1..3 上限
//   MATCH (r:ZSTP:`风险线索` {risk_type:'企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
//   WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
//   MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
//   RETURN a.org_name AS 企业A, b.org_name AS 企业B, b.phonenumber AS B电话,
//          length(p1) AS 层数 ORDER BY 企业A, 层数;


// =============================================================================
// 八、清理
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK5_' DETACH DELETE n;
//
// 校验残留（应为 0）：
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK5_' RETURN count(n) AS 节点数;
