// =============================================================================
// 14 模拟数据：企业 ──`签订合同`──► 合同 ◄──`签订合同`── 企业（两家企业同签一份合同）
// -----------------------------------------------------------------------------
// 语义（对应你给出的结构与 elementId 示例）：
//
//     企业(甲) ──`签订合同`──► 合同(1号合同) ◄──`签订合同`── 企业(乙)
//                              （企业-合同-企业）
//
//   两家企业共同指向同一份合同 → 即"共同合同"，正是"a、b 同签一份合同"的判定依据：
//     MATCH (a:企业)-[:`签订合同`]->(c:合同)<-[:`签订合同`]-(b:企业)
//   边方向固定为 企业 → 合同（与 DDL 一致），不需要反向边。
//
// -----------------------------------------------------------------------------
// 数据前缀：MOCK6_（与 MOCK_/MOCK2_~MOCK5_ 互不干扰），全 MERGE 幂等，可重复执行
// 依赖：无（自包含）；建议先执行 01_neo4j_ddl.cypher 建好唯一约束
//
// 字段口径（对齐 01_neo4j_ddl.cypher）：
//   企业  : org_name, org_credit_code, reglocation, regstatus, phonenumber, schema_name
//   合同  : contract_code, contract_name, gategory_name, contract_amount,
//           sign_time, status_name, schema_name
//   签订合同边: contract_amount, contract_status, sign_time, schema_name
// =============================================================================


// =============================================================================
// 一、企业节点（两家，模拟"同签一份合同"的双方）
// =============================================================================
MERGE (n:ZSTP:`企业` {object_key: 'MOCK6_ENT_A'})
  ON CREATE SET n.org_name         = '国电投示范产业投资集团有限公司',
                n.org_credit_code  = '91110000MOCK6ENA01',
                n.reglocation      = '北京市西城区示范路 1 号院',
                n.regstatus        = '存续',
                n.phonenumber      = '010-6000-0001',
                n.schema_name      = '企业';

MERGE (n:ZSTP:`企业` {object_key: 'MOCK6_ENT_B'})
  ON CREATE SET n.org_name         = '国电投协同发展有限公司',
                n.org_credit_code  = '91110000MOCK6ENB01',
                n.reglocation      = '北京市西城区示范路 2 号院',
                n.regstatus        = '存续',
                n.phonenumber      = '010-6000-0002',
                n.schema_name      = '企业';


// =============================================================================
// 二、合同节点
// =============================================================================
// 共同合同：甲乙两家企业都指向它
MERGE (n:ZSTP:`合同` {object_key: 'MOCK6_HT_001'})
  ON CREATE SET n.contract_code   = 'HT-MOCK6-2026-001',
                n.contract_name   = '设备采购合同（甲乙共同签订）',
                n.gategory_name   = '设备采购合同',
                n.contract_amount = 5200000.0,
                n.sign_time       = '2026-04-10',
                n.status_name     = '履行中',
                n.schema_name     = '合同';

// 反例合同：只有甲企业单方指向 → 不构成"共同合同"
MERGE (n:ZSTP:`合同` {object_key: 'MOCK6_HT_002'})
  ON CREATE SET n.contract_code   = 'HT-MOCK6-2026-002',
                n.contract_name   = '技术服务合同（仅甲方签订）',
                n.gategory_name   = '技术服务合同',
                n.contract_amount = 1300000.0,
                n.sign_time       = '2026-07-01',
                n.status_name     = '履行中',
                n.schema_name     = '合同';


// =============================================================================
// 三、签订合同 边（企业 → 合同；两家企业指向同一合同 = 共同合同）
// =============================================================================
// 甲 ──► 1 号合同
MERGE (a:ZSTP:`企业` {object_key: 'MOCK6_ENT_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK6_HT_001'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK6_A_HT001'}]->(c)
  ON CREATE SET e.contract_amount = '520万元',
                e.contract_status = '履行中',
                e.sign_time       = '2026-04-10',
                e.schema_name     = '签订合同';

// 乙 ──► 1 号合同（与甲指向同一合同）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK6_ENT_B'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK6_HT_001'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK6_B_HT001'}]->(c)
  ON CREATE SET e.contract_amount = '520万元',
                e.contract_status = '履行中',
                e.sign_time       = '2026-04-10',
                e.schema_name     = '签订合同';

// 甲 ──► 2 号合同（单方，反例：不应被判为共同合同）
MERGE (a:ZSTP:`企业` {object_key: 'MOCK6_ENT_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK6_HT_002'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK6_A_HT002'}]->(c)
  ON CREATE SET e.contract_amount = '130万元',
                e.contract_status = '履行中',
                e.sign_time       = '2026-07-01',
                e.schema_name     = '签订合同';


// =============================================================================
// 四、验证（把下面几条贴进 Browser 执行，验证"企业-合同-企业"结构）
// =============================================================================
// 4.1 结构本身：应返回 1 条路径（甲 → 1号合同 ← 乙）
// MATCH p = (a:ZSTP:`企业`)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b:ZSTP:`企业`)
// RETURN p;
//
// 4.2 共同合同判定：应返回 1 行 —— HT-MOCK6-2026-001
// MATCH (a:ZSTP:`企业`)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b:ZSTP:`企业`)
// WHERE a.object_key < b.object_key
// RETURN a.org_name AS 企业A, b.org_name AS 企业B,
//        c.contract_code AS 共同合同, c.sign_time AS 签订时间, c.contract_amount AS 金额;
//
// 4.3 对照：把边方向改成"一方签了合同、另一方也签了同一份"，但换成按合同反查签署方
// MATCH (c:ZSTP:`合同` {object_key: 'MOCK6_HT_001'})<-[:`签订合同`]-(a:ZSTP:`企业`)
// RETURN c.contract_code AS 合同编号, collect(a.org_name) AS 签署企业;
//   预期：['国电投示范产业投资集团有限公司', '国电投协同发展有限公司']（2 家）
//   对照 2 号合同 MOCK6_HT_002 → 仅 1 家，故不构成共同合同


// =============================================================================
// 五、清理
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK6_' DETACH DELETE n;
//
// 校验残留（应为 0）：
// MATCH (n) WHERE n.object_key STARTS WITH 'MOCK6_' RETURN count(n) AS 节点数;
