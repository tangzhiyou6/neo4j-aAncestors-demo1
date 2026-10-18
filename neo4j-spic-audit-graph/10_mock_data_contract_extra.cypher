// =============================================================================
// 10 追加模拟数据：让"a、b 同签一份合同"这个新条件可被验证
// -----------------------------------------------------------------------------
// 依赖：先执行 08_mock_data_risk_type.cypher（本文件在其基础上追加）
// 全部 object_key 带 MOCK2_ 前缀，全 MERGE 幂等，可重复执行。
//
// 本文件追加的用例：
//   ① 字段名对齐 DDL：把 08 里的 1号合同 从自造字段名改成 DDL 定义的
//      contract_code / contract_name / contract_amount / sign_time / status_name
//   ② 多合同场景：股东企业甲 与 某国电投企业 共同签订【两份】合同
//      （HT_002 签订于 2026-03-01、HT_003 签订于 2026-05-20）
//      → 验证"有多条合同数据只取其中一条"（按签订时间升序取 HT_002）
//   ③ 无共同合同场景：股东企业乙 与 外部企业 控股链成立、电话相同，
//      但两家【没有】共同签订的合同
//      → 09 第一节（必中版）不返回该组合；09 第三节（OPTIONAL 版）返回且合同为空
//   ④ 反例：股东企业乙 与 无关企业丙 签了同一份合同，但二者既非控股关系、
//      电话也不同 → 任何版本都不应命中
// =============================================================================


// =============================================================================
// 一、字段名对齐 DDL（修正 08 中 1号合同 的自造字段）
// =============================================================================
MATCH (c:ZSTP:`合同` {object_key: 'MOCK2_HT_001'})
SET c.contract_code   = 'HT-MOCK2-2026-001',
    c.contract_name   = '1号合同',
    c.contract_amount = 5200000.0,
    c.sign_time       = '2026-01-15',
    c.status_name     = '履行中',
    c.schema_name     = '合同'
REMOVE c.contract_no, c.contract_status;


// =============================================================================
// 二、多合同场景：股东企业甲 ↔ 某国电投企业 共同签订两份合同
// =============================================================================
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_002'})
  ON CREATE SET c.contract_code   = 'HT-MOCK2-2026-002',
                c.contract_name   = '2号合同（设备采购）',
                c.gategory_name   = '设备采购合同',
                c.contract_amount = 8600000.0,
                c.sign_time       = '2026-03-01',
                c.status_name     = '履行中',
                c.payment_direction = '付款',
                c.schema_name     = '合同';
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_003'})
  ON CREATE SET c.contract_code   = 'HT-MOCK2-2026-003',
                c.contract_name   = '3号合同（技术服务）',
                c.gategory_name   = '技术服务合同',
                c.contract_amount = 2400000.0,
                c.sign_time       = '2026-05-20',
                c.status_name     = '履行中',
                c.payment_direction = '付款',
                c.schema_name     = '合同';

// 甲 签 HT_002 / HT_003
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_002'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_SHJIA_HT002'}]->(c)
  ON CREATE SET e.contract_amount='860万元', e.contract_status='履行中',
                e.sign_time='2026-03-01', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_JIA'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_003'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_SHJIA_HT003'}]->(c)
  ON CREATE SET e.contract_amount='240万元', e.contract_status='履行中',
                e.sign_time='2026-05-20', e.schema_name='签订合同';

// 某国电投企业 也签 HT_002 / HT_003（与甲同签同一合同 → 构成共同合同）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SPIC'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_002'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_SPIC_HT002'}]->(c)
  ON CREATE SET e.contract_amount='860万元', e.contract_status='履行中',
                e.sign_time='2026-03-01', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SPIC'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_003'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_SPIC_HT003'}]->(c)
  ON CREATE SET e.contract_amount='240万元', e.contract_status='履行中',
                e.sign_time='2026-05-20', e.schema_name='签订合同';


// =============================================================================
// 三、反例：乙方链上签了同一份合同，但不构成命中
// =============================================================================
// 股东企业乙 与 无关企业丙 共同签订 HT_004：
//   二者无控股关系（乙控股 B1→B2→外部企业，丙是甲的子公司）、电话也不同
//   → 任何版本都不应命中（用于验证条件之间是 AND 关系，不会因合同单独放行）
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_004'})
  ON CREATE SET c.contract_code   = 'HT-MOCK2-2026-004',
                c.contract_name   = '4号合同（咨询）',
                c.gategory_name   = '咨询服务合同',
                c.contract_amount = 300000.0,
                c.sign_time       = '2026-02-11',
                c.status_name     = '履行中',
                c.schema_name     = '合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_SH_YI'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_004'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_SHYI_HT004'}]->(c)
  ON CREATE SET e.contract_amount='30万元', e.contract_status='履行中',
                e.sign_time='2026-02-11', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK2_OTH'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK2_HT_004'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK2_OTH_HT004'}]->(c)
  ON CREATE SET e.contract_amount='30万元', e.contract_status='履行中',
                e.sign_time='2026-02-11', e.schema_name='签订合同';


// =============================================================================
// 四、核验查询与预期结果
// =============================================================================
// 4.1 甲 与 国电投 的共同合同（应为 2 份）
// MATCH (a:ZSTP:`企业` {object_key:'MOCK2_SH_JIA'})-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b:ZSTP:`企业` {object_key:'MOCK2_SPIC'})
// RETURN c.contract_code, c.sign_time ORDER BY c.sign_time;
//   预期：HT-MOCK2-2026-002 (2026-03-01)、HT-MOCK2-2026-003 (2026-05-20)

// 4.2 乙 与 外部企业 的共同合同（应为 0 份）
// MATCH (a:ZSTP:`企业` {object_key:'MOCK2_SH_YI'})-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b:ZSTP:`企业` {object_key:'MOCK2_WB'})
// RETURN c;
//   预期：无返回

// 4.3 09 第一节（必中版）预期返回 1 行：
//   股东企业甲 → 某国电投企业，合同取 HT-MOCK2-2026-002（签订时间最早的那份）
// 4.4 09 第三节（OPTIONAL 版）预期返回 2 行：
//   甲 → 某国电投企业   合同 HT-MOCK2-2026-002   证据类型"控股关系 + 同签合同"
//   乙 → 外部企业       合同 （无共同合同）        证据类型"仅有控股关系"


// =============================================================================
// 五、清理（连同 08 的数据一起删）
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK2_' DETACH DELETE n;
