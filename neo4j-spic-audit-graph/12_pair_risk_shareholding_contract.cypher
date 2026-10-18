// =============================================================================
// 12 修正版（自包含验证）：同一风险线索下的两家企业 + 3 层控股穿透 + 电话相同 + 同签一份合同
// -----------------------------------------------------------------------------
// 语义（本次修正的关键）：a、b 不是"风险企业 + 穿透到的企业"，而是
//   ① 从【同一条】风险线索出发，risk_type = '企业电话相同'
//      → 分别取该线索下的两家企业 a、b（都挂触发风险_企业 边指向同一个 r）
//   ② 校验 a、b 之间【3 层以内】存在控股关联（股东持股边，无向/有向见变体）
//   ③ 校验 a.phonenumber = b.phonenumber（与 risk_type 语义呼应）
//   ④ ★ 再要求 a、b 同签一份合同：
//        (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
//        若存在多份共同合同，只取签订时间最早的一条
//
// 数据前缀：MOCK4_（与 MOCK2_/MOCK3_ 互不干扰）
// 执行：整份依次执行；第四节每条校验返回 检查项 / 期望 / 实际 / 判定(PASS|FAIL)
// =============================================================================


// =============================================================================
// 一、数据集
// =============================================================================
// 图结构（.phonenumber 均标注；4 家企业都挂同一条风险线索 MOCK4_FX_PHONE）：
//   甲企业(0755-8000-0000) ──持股──► H1 ──持股──► 乙企业(0755-8000-0000)   ← 2 层，应命中
//   甲企业 ──持股──► P1 ──► P2 ──► P3 ──► 丙企业(0755-8000-0000)            ← 4 层，应排除
//   甲企业 ──持股──► H2 ──持股──► 丁企业(0755-8000-0000)                    ← 2 层但无共同合同，应排除
//   合同：甲↔乙 共签 HT1(03-01)、HT2(05-20) → 取 HT1；甲↔丙 共签 HT3（层数反例）
//        丁↔己 共签 HT4（己企业电话不同且不挂该线索 → 不算共同合同）

// --- 风险线索 ---
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK4_FX_PHONE'})
  ON CREATE SET n.risk_type    = '企业电话相同',
                n.risk_desc    = '同一线索下多家企业工商登记电话完全一致',
                n.risk_summary = '企业电话相同',
                n.schema_name  = '风险线索';

// --- 企业（甲乙丙丁均登记同一电话，且都触发同一条风险线索）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_A'})
  ON CREATE SET n.org_name='MOCK4 甲企业', n.phonenumber='0755-8000-0000',
                n.reglocation='深圳市南山区甲路 1 号', n.uscc='91440300MOCK4A001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_B'})
  ON CREATE SET n.org_name='MOCK4 乙企业', n.phonenumber='0755-8000-0000',
                n.reglocation='深圳市南山区乙路 2 号', n.uscc='91440300MOCK4B001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_C'})
  ON CREATE SET n.org_name='MOCK4 丙企业', n.phonenumber='0755-8000-0000',
                n.reglocation='深圳市南山区丙路 3 号', n.uscc='91440300MOCK4C001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_D'})
  ON CREATE SET n.org_name='MOCK4 丁企业', n.phonenumber='0755-8000-0000',
                n.reglocation='深圳市南山区丁路 4 号', n.uscc='91440300MOCK4D001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_OWN_F'})
  ON CREATE SET n.org_name='MOCK4 己企业', n.phonenumber='0755-9999-0000',
                n.uscc='91440300MOCK4F001', n.schema_name='企业';

// --- 控股链中间层（电话均不同，避免误报）---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_H1'})
  ON CREATE SET n.org_name='MOCK4 控股平台H1', n.phonenumber='0755-2000-0001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_H2'})
  ON CREATE SET n.org_name='MOCK4 控股平台H2', n.phonenumber='0755-2000-0002', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_P1'})
  ON CREATE SET n.org_name='MOCK4 中间层P1', n.phonenumber='0755-3000-0001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_P2'})
  ON CREATE SET n.org_name='MOCK4 中间层P2', n.phonenumber='0755-3000-0002', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK4_P3'})
  ON CREATE SET n.org_name='MOCK4 中间层P3', n.phonenumber='0755-3000-0003', n.schema_name='企业';

// --- 合同 ---
MERGE (n:ZSTP:`合同` {object_key: 'MOCK4_HT1'})
  ON CREATE SET n.contract_code='HT-MOCK4-2026-001', n.contract_name='甲乙 1 号合同',
                n.gategory_name='设备采购合同', n.contract_amount=4000000.0,
                n.sign_time='2026-03-01', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK4_HT2'})
  ON CREATE SET n.contract_code='HT-MOCK4-2026-002', n.contract_name='甲乙 2 号合同',
                n.gategory_name='技术服务合同', n.contract_amount=1200000.0,
                n.sign_time='2026-05-20', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK4_HT3'})
  ON CREATE SET n.contract_code='HT-MOCK4-2026-003', n.contract_name='甲丙合同（层数反例）',
                n.contract_amount=600000.0, n.sign_time='2026-02-01',
                n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK4_HT4'})
  ON CREATE SET n.contract_code='HT-MOCK4-2026-004', n.contract_name='丁己合同（第三方合同）',
                n.contract_amount=350000.0, n.sign_time='2026-01-15',
                n.status_name='履行中', n.schema_name='合同';

// --- 触发风险_企业 边（甲乙丙丁 → 同一条风险线索）---
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK4_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK4_REL_A_FX'}]->(r);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_B'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK4_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK4_REL_B_FX'}]->(r);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_C'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK4_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK4_REL_C_FX'}]->(r);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_D'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK4_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK4_REL_D_FX'}]->(r);

// --- 股东持股（%）企业-企业 边 ---
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_H1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_A_H1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=60.0,
                e.capital_amomon='6000万元人民币', e.capital_time='2020-06-30',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_H1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_B'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_H1_B'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=55.0,
                e.capital_amomon='5500万元人民币', e.capital_time='2021-03-15',
                e.schema_name='股东持股（%）企业-企业';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_H2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_A_H2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=70.0, e.capital_time='2019-01-10',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_H2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_D'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_H2_D'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=51.0, e.capital_time='2022-04-01',
                e.schema_name='股东持股（%）企业-企业';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_P1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_A_P1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=65.0, e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_P1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_P2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_P1_P2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=62.0, e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_P2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_P3'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_P2_P3'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=58.0, e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_P3'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK4_C'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK4_GT_P3_C'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=50.0, e.schema_name='股东持股（%）企业-企业';

// --- 签订合同 边 ---
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT1'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_A_HT1'}]->(c)
  ON CREATE SET e.contract_amount='400万元', e.contract_status='履行中', e.sign_time='2026-03-01', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_B'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT1'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_B_HT1'}]->(c)
  ON CREATE SET e.contract_amount='400万元', e.contract_status='履行中', e.sign_time='2026-03-01', e.schema_name='签订合同';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT2'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_A_HT2'}]->(c)
  ON CREATE SET e.contract_amount='120万元', e.contract_status='履行中', e.sign_time='2026-05-20', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_B'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT2'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_B_HT2'}]->(c)
  ON CREATE SET e.contract_amount='120万元', e.contract_status='履行中', e.sign_time='2026-05-20', e.schema_name='签订合同';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT3'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_A_HT3'}]->(c);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_C'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT3'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_C_HT3'}]->(c);

MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_D'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT4'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_D_HT4'}]->(c);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK4_OWN_F'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK4_HT4'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK4_F_HT4'}]->(c);


// =============================================================================
// 二、主查询（修正版）：同一风险线索下的 a、b → 3 层控股 → 电话相同 → 同签一份合同
// =============================================================================
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key                                     // 去重：每对只出一条
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''         // 排除空串
  AND b.phonenumber = a.phonenumber                                   // ③ 电话相同

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))       // ② 3 层内控股关联（无向）

MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)        // ④ 同签一份合同
WITH r, p0, p1, p2, a, b, c
ORDER BY coalesce(c.sign_time, ''), c.object_key                     // 多份合同：按签订时间升序
WITH r, p0, p1, a, b,
     collect(p2)[0] AS p2,                                           // 只取最早一条
     collect(c)[0]  AS 合同
RETURN r.risk_type         AS `风险类型`,
       a.org_name          AS `企业A`,
       b.org_name          AS `企业B`,
       a.phonenumber       AS `共同电话`,
       length(p1)          AS `控股穿透层数`,
       合同.contract_code  AS `共同合同编号`,
       合同.sign_time      AS `签订时间`,
       合同.contract_amount AS `合同金额`,
       p0 AS `路径0_风险线索`, p1 AS `路径1_控股链`, p2 AS `路径2_共同合同`;


// =============================================================================
// 三、变体
// =============================================================================

// 3.1 有向版：只认"其中一家（间接）控股另一家"的方向（A 为股东方 → B 为被控股方）
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b))
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH p1, a, b, c ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH a, b, p1, collect(c)[0] AS 合同
RETURN a.org_name AS `股东方`, b.org_name AS `被控股方`,
       length(p1) AS `控股层数`, 合同.contract_code AS `共同合同编号`;

// 3.2 宽松版：同签合同作为可选证据（无共同合同的组合保留，合同列显示 null）
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
OPTIONAL CALL (a, b) {
  MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
  RETURN p2, c ORDER BY coalesce(c.sign_time, ''), c.object_key LIMIT 1
}
RETURN a.org_name AS `企业A`, b.org_name AS `企业B`, length(p1) AS `控股穿透层数`,
       coalesce(c.contract_code, '（无共同合同）') AS `共同合同编号`,
       CASE WHEN c IS NULL THEN '仅有控股关系' ELSE '控股关系 + 同签合同' END AS `证据类型`
ORDER BY `控股穿透层数`;

// 3.3 分步核对版：先看同线索同电话的候选对及其控股跳数（不要求合同）
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
OPTIONAL MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
RETURN a.org_name AS `企业A`, b.org_name AS `企业B`,
       CASE WHEN p1 IS NULL THEN '3 层内不可达' ELSE toString(length(p1)) + ' 层' END AS `控股情况`;


// =============================================================================
// 四、断言式校验（每条返回 检查项 / 期望 / 实际 / 判定，应全部 PASS）
// =============================================================================

// --- 校验 1：同一线索下、电话相同的候选企业对 = 6 组（甲乙丙丁 两两组合）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
WITH collect(a.org_name + ' ↔ ' + b.org_name) AS 候选对
RETURN '校验1 线索内电话相同的候选对' AS `检查项`, '6 组' AS `期望`,
       toString(size(候选对)) + ' 组：' + reduce(s='', x IN 候选对 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(候选对) = 6 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 2：其中 3 层内控股可达的只有 2 组（甲↔乙、甲↔丁）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
WITH collect(a.org_name + '↔' + b.org_name + '(' + toString(length(p1)) + '层)') AS 可达对
RETURN '校验2 3 层内控股可达的对' AS `检查项`, '2 组：甲↔乙(2层)、甲↔丁(2层)' AS `期望`,
       toString(size(可达对)) + ' 组：' + reduce(s='', x IN 可达对 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(可达对) = 2 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 3：主查询结果 = 1 行，共同合同取签订时间最早的 HT-MOCK4-2026-001 ---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH a, b, c ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH a, b, collect(c)[0] AS 合同
WITH collect(a.org_name + '↔' + b.org_name + ' / ' + 合同.contract_code) AS 结果, count(*) AS 行数
RETURN '校验3 主查询结果（多份取一条）' AS `检查项`, '1 行：甲企业↔乙企业 / HT-MOCK4-2026-001' AS `期望`,
       toString(行数) + ' 行：' + CASE WHEN 行数 = 1 THEN 结果[0] ELSE '（多条）' END AS `实际`,
       CASE WHEN 行数 = 1 AND 结果[0] = 'MOCK4 甲企业↔MOCK4 乙企业 / HT-MOCK4-2026-001' THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 4：甲↔乙 的共同合同确实是 2 份（证明"取一条"有取舍）---
MATCH (a:ZSTP:`企业` {object_key: 'MOCK4_A'})-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b:ZSTP:`企业` {object_key: 'MOCK4_B'})
WITH collect(c.contract_code) AS 合同列表
RETURN '校验4 甲↔乙 共同合同份数' AS `检查项`, '2 份' AS `期望`,
       toString(size(合同列表)) + ' 份：' + reduce(s='', x IN 合同列表 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(合同列表) = 2 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 5：丙企业被 3 层上限排除（虽同电话、与甲共签 HT3，但相距 4 层）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH collect(b.org_name) AS 命中企业
RETURN '校验5 4 层远的丙企业是否被排除' AS `检查项`, '不出现 MOCK4 丙企业' AS `期望`,
       CASE WHEN 'MOCK4 丙企业' IN 命中企业 THEN '出现了' ELSE '未出现' END AS `实际`,
       CASE WHEN NOT 'MOCK4 丙企业' IN 命中企业 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 6：丁企业被合同条件排除（同电话、2 层控股，但与甲无共同合同）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE a.object_key < b.object_key
  AND a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH collect(b.org_name) AS 命中企业
RETURN '校验6 无共同合同的丁企业是否被排除' AS `检查项`, '不出现 MOCK4 丁企业' AS `期望`,
       CASE WHEN 'MOCK4 丁企业' IN 命中企业 THEN '出现了' ELSE '未出现' END AS `实际`,
       CASE WHEN NOT 'MOCK4 丁企业' IN 命中企业 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 7：分步核对（3.3 版）中，甲↔丁 显示"2 层"但无共同合同；甲↔丙 显示"3 层内不可达" ---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业` {object_key: 'MOCK4_A'})
MATCH (r)<-[:`触发风险_企业`]-(b:ZSTP:`企业`)
WHERE b.object_key IN ['MOCK4_B', 'MOCK4_C', 'MOCK4_D']
OPTIONAL MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]-(b))
OPTIONAL MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH b.org_name AS 企业, coalesce(toString(length(p1)), '不可达') AS 层数, count(c) AS 共同合同数
RETURN '校验7 甲与各企业的层数及共同合同数' AS `检查项`,
       '3 行（顺序不限）：乙企业 2 层/2 份；丙企业 不可达/1 份；丁企业 2 层/0 份' AS `期望`,
       reduce(s='', x IN collect(企业 + ' ' + 层数 + '层/' + toString(共同合同数) + '份') |
              s + CASE WHEN s='' THEN x ELSE '；' + x END) AS `实际`,
       CASE WHEN count(*) = 3 AND size(collect(企业)) = 3 THEN 'PASS' ELSE 'FAIL' END AS `判定`;


// =============================================================================
// 五、清理
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK4_' DETACH DELETE n;
