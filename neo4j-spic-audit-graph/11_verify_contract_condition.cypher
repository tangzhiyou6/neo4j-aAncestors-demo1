// =============================================================================
// 11 自包含验证脚本：风险线索 → 3 层控股穿透 → 电话相同 → 且 a、b 同签一份合同
// -----------------------------------------------------------------------------
// 用途：单个文件即可跑完"建数据 → 执行查询 → 断言校验 → 清理"，不依赖 08/10。
// 数据前缀：MOCK3_（与 08/10 的 MOCK2_ 互不干扰）
//
// 业务链路（本脚本要验证的）：
//   1) 风险线索 risk_type = '企业电话相同'
//   2) (:企业)-[:触发风险_企业]->(:风险线索)  反向查出涉事企业 a
//   3) a 沿 (:企业)-[:股东持股（%）企业-企业]->(:企业) 最多穿透 3 层得到 b
//   4) 校验 b.phonenumber = a.phonenumber
//   5) ★ 新增：a、b 通过同一份合同相连
//        (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
//        多份共同合同时，取签订时间最早的一条
//
// 执行方式：整份复制进 Neo4j Browser / cypher-shell 依次执行，
//           第 3 节每条校验都会返回 检查项 / 期望 / 实际 / 判定(PASS|FAIL)。
// =============================================================================


// =============================================================================
// 一、最小数据集（幂等 MERGE，可重复执行）
// =============================================================================
// 图结构（.phonenumber 标注）：
//   甲企业(010-1000-0000) ──持股──► 控股平台H1 ──持股──► 乙企业(010-1000-0000)   ← 2 层，应命中
//   甲企业 ──持股──► P1 ──► P2 ──► P3 ──► 远端企业E(010-1000-0000)                ← 4 层，应排除
//   识别依据：甲企业触发风险线索；甲↔乙 共签 2 份合同；甲↔远端E 共签 1 份合同（验证层数优先）
//   反例：甲↔反例企业C(010-9999-9999) 也共签 1 份合同，但无控股关系、电话不同 → 不应命中

// --- 风险线索 ---
MERGE (n:ZSTP:`风险线索` {object_key: 'MOCK3_FX_PHONE'})
  ON CREATE SET n.risk_type    = '企业电话相同',
                n.risk_desc    = '两家企业工商登记电话完全一致',
                n.risk_summary = '企业电话相同',
                n.schema_name  = '风险线索';

// --- 企业 ---
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_A'})
  ON CREATE SET n.org_name='MOCK3 甲企业', n.phonenumber='010-1000-0000',
                n.reglocation='北京市西城区甲路 1 号', n.uscc='91110000MOCK3A001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_H1'})
  ON CREATE SET n.org_name='MOCK3 控股平台H1', n.phonenumber='010-2000-0001',
                n.reglocation='北京市海淀区H1路 2 号', n.uscc='91110000MOCK3H1001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_B'})
  ON CREATE SET n.org_name='MOCK3 乙企业', n.phonenumber='010-1000-0000',
                n.reglocation='北京市西城区乙路 3 号', n.uscc='91110000MOCK3B001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_P1'})
  ON CREATE SET n.org_name='MOCK3 中间层P1', n.phonenumber='010-3000-0001',
                n.reglocation='上海市P1路 1 号', n.uscc='91310000MOCK3P1001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_P2'})
  ON CREATE SET n.org_name='MOCK3 中间层P2', n.phonenumber='010-3000-0002',
                n.reglocation='上海市P2路 2 号', n.uscc='91310000MOCK3P2001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_P3'})
  ON CREATE SET n.org_name='MOCK3 中间层P3', n.phonenumber='010-3000-0003',
                n.reglocation='上海市P3路 3 号', n.uscc='91310000MOCK3P3001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_E'})
  ON CREATE SET n.org_name='MOCK3 远端企业E', n.phonenumber='010-1000-0000',
                n.reglocation='广州市E路 4 号', n.uscc='91440000MOCK3E001', n.schema_name='企业';
MERGE (n:ZSTP:`企业` {object_key: 'MOCK3_C'})
  ON CREATE SET n.org_name='MOCK3 反例企业C', n.phonenumber='010-9999-9999',
                n.reglocation='广州市C路 9 号', n.uscc='91440000MOCK3C001', n.schema_name='企业';

// --- 合同（字段名对齐 DDL）---
MERGE (n:ZSTP:`合同` {object_key: 'MOCK3_HT1'})
  ON CREATE SET n.contract_code='HT-MOCK3-2026-001', n.contract_name='甲乙方 1 号合同',
                n.gategory_name='设备采购合同', n.contract_amount=3000000.0,
                n.sign_time='2026-03-01', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK3_HT2'})
  ON CREATE SET n.contract_code='HT-MOCK3-2026-002', n.contract_name='甲乙方 2 号合同',
                n.gategory_name='技术服务合同', n.contract_amount=900000.0,
                n.sign_time='2026-05-20', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK3_HT3'})
  ON CREATE SET n.contract_code='HT-MOCK3-2026-003', n.contract_name='甲丙方合同（反例）',
                n.gategory_name='咨询服务合同', n.contract_amount=200000.0,
                n.sign_time='2026-02-01', n.status_name='履行中', n.schema_name='合同';
MERGE (n:ZSTP:`合同` {object_key: 'MOCK3_HT4'})
  ON CREATE SET n.contract_code='HT-MOCK3-2026-004', n.contract_name='甲远端E合同（层数反例）',
                n.gategory_name='购销合同', n.contract_amount=500000.0,
                n.sign_time='2026-01-01', n.status_name='履行中', n.schema_name='合同';

// --- 触发风险_企业 边（企业 → 风险线索）---
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (r:ZSTP:`风险线索` {object_key: 'MOCK3_FX_PHONE'})
MERGE (a)-[e:`触发风险_企业` {object_key: 'MOCK3_REL_A_FX'}]->(r);

// --- 股东持股（%）企业-企业 边 ---
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK3_H1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK3_GT_A_H1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=60.0,
                e.capital_amomon='6000万元人民币', e.capital_time='2020-06-30',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_H1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK3_B'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK3_GT_H1_B'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=55.0,
                e.capital_amomon='5500万元人民币', e.capital_time='2021-03-15',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK3_P1'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK3_GT_A_P1'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=70.0, e.capital_time='2019-01-10',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_P1'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK3_P2'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK3_GT_P1_P2'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=65.0, e.capital_time='2020-02-10',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_P2'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK3_P3'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK3_GT_P2_P3'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=62.0, e.capital_time='2021-07-10',
                e.schema_name='股东持股（%）企业-企业';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_P3'})
MERGE (b:ZSTP:`企业` {object_key: 'MOCK3_E'})
MERGE (a)-[e:`股东持股（%）企业-企业` {object_key: 'MOCK3_GT_P3_E'}]->(b)
  ON CREATE SET e.ft_shareholding='是', e.capital_percent=58.0, e.capital_time='2022-08-10',
                e.schema_name='股东持股（%）企业-企业';

// --- 签订合同 边 ---
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT1'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_A_HT1'}]->(c)
  ON CREATE SET e.contract_amount='300万元', e.contract_status='履行中',
                e.sign_time='2026-03-01', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_B'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT1'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_B_HT1'}]->(c)
  ON CREATE SET e.contract_amount='300万元', e.contract_status='履行中',
                e.sign_time='2026-03-01', e.schema_name='签订合同';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT2'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_A_HT2'}]->(c)
  ON CREATE SET e.contract_amount='90万元', e.contract_status='履行中',
                e.sign_time='2026-05-20', e.schema_name='签订合同';
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_B'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT2'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_B_HT2'}]->(c)
  ON CREATE SET e.contract_amount='90万元', e.contract_status='履行中',
                e.sign_time='2026-05-20', e.schema_name='签订合同';

MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT3'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_A_HT3'}]->(c);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_C'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT3'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_C_HT3'}]->(c);

MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_A'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT4'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_A_HT4'}]->(c);
MERGE (a:ZSTP:`企业` {object_key: 'MOCK3_E'})
MERGE (c:ZSTP:`合同` {object_key: 'MOCK3_HT4'})
MERGE (a)-[e:`签订合同` {object_key: 'MOCK3_E_HT4'}]->(c);


// =============================================================================
// 二、主查询（这就是要验证的目标语句）
// =============================================================================
// 风险线索 → 3 层控股穿透 → 电话相同 → 且 a、b 同签一份合同（多份取签订时间最早的一条）
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''

MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber

MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)

WITH p0, p1, a, b, c, p2
ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH p0, p1, a, b,
     collect(p2)[0] AS p2,
     collect(c)[0]  AS 合同
RETURN p0 AS `路径0_风险线索`,
       p1 AS `路径1_控股链`,
       p2 AS `路径2_共同合同`,
       合同.contract_code AS `合同编号`,
       合同.sign_time     AS `签订时间`,
       合同.status_name   AS `合同状态`,
       a.org_name         AS `风险企业`,
       b.org_name         AS `被控股企业`,
       a.phonenumber      AS `共同电话`,
       length(p1)         AS `持股穿透层数`;


// =============================================================================
// 三、断言式校验（每条返回 检查项 / 期望 / 实际 / 判定，应全部 PASS）
// =============================================================================

// --- 校验 1：触发风险的企业只有 1 家（甲企业）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WITH collect(a.org_name) AS 企业列表
RETURN '校验1 触发风险的企业' AS `检查项`,
       '1 家：MOCK3 甲企业' AS `期望`,
       toString(size(企业列表)) + ' 家：' + reduce(s='', x IN 企业列表 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(企业列表) = 1 AND 企业列表[0] = 'MOCK3 甲企业' THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 2：控股穿透 ≤3 层 且 电话相同 的组合只有 1 组（甲 → 乙，2 层）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
WITH collect(b.org_name + '(' + toString(length(p1)) + '层)') AS 组合列表
RETURN '校验2 控股穿透+电话相同的组合' AS `检查项`,
       '1 组：MOCK3 乙企业(2层)' AS `期望`,
       toString(size(组合列表)) + ' 组：' + reduce(s='', x IN 组合列表 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(组合列表) = 1 AND 组合列表[0] = 'MOCK3 乙企业(2层)' THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 3：甲 ↔ 乙 的共同合同有 2 份（提前验证"多份只取一条"确有多份可选）---
MATCH (a:ZSTP:`企业` {object_key: 'MOCK3_A'})-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b:ZSTP:`企业` {object_key: 'MOCK3_B'})
WITH collect(c.contract_code) AS 合同列表
RETURN '校验3 甲↔乙 共同合同份数' AS `检查项`,
       '2 份' AS `期望`,
       toString(size(合同列表)) + ' 份：' + reduce(s='', x IN 合同列表 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(合同列表) = 2 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 4：主查询（必中版）返回 1 行，且合同取了签订时间最早的 HT-MOCK3-2026-001 ---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH a, b, c ORDER BY coalesce(c.sign_time, ''), c.object_key
WITH a, b, collect(c)[0] AS 合同
WITH collect(合同.contract_code) AS 编号列表, count(*) AS 行数
RETURN '校验4 主查询结果（多份取一条）' AS `检查项`,
       '1 行，合同 HT-MOCK3-2026-001' AS `期望`,
       toString(行数) + ' 行，合同 ' + CASE WHEN 行数 = 1 THEN 编号列表[0] ELSE '（多条）' END AS `实际`,
       CASE WHEN 行数 = 1 AND 编号列表[0] = 'HT-MOCK3-2026-001' THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 5：4 层远的远端企业E 被层数上限排除（尽管电话相同、且与甲共签 HT4）---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH collect(b.org_name) AS 命中企业
RETURN '校验5 4 层远端企业E 是否被排除' AS `检查项`,
       '不出现 MOCK3 远端企业E' AS `期望`,
       CASE WHEN 'MOCK3 远端企业E' IN 命中企业 THEN '出现了' ELSE '未出现' END AS `实际`,
       CASE WHEN NOT 'MOCK3 远端企业E' IN 命中企业 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 6：反例企业C（与甲共签 HT3 但无控股关系、电话不同）不得出现 ---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH collect(b.org_name) AS 命中企业
RETURN '校验6 反例企业C 是否被排除（合同不能单独放行）' AS `检查项`,
       '不出现 MOCK3 反例企业C' AS `期望`,
       CASE WHEN 'MOCK3 反例企业C' IN 命中企业 THEN '出现了' ELSE '未出现' END AS `实际`,
       CASE WHEN NOT 'MOCK3 反例企业C' IN 命中企业 THEN 'PASS' ELSE 'FAIL' END AS `判定`;

// --- 校验 7：对照版（不取一条）能列出甲↔乙的全部 2 份共同合同 ---
MATCH (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
MATCH (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
WITH collect(c.contract_code) AS 全部合同
RETURN '校验7 对照版列出的全部共同合同' AS `检查项`,
       '2 份（HT-MOCK3-2026-001、HT-MOCK3-2026-002）' AS `期望`,
       toString(size(全部合同)) + ' 份：' + reduce(s='', x IN 全部合同 | s + CASE WHEN s='' THEN x ELSE '、' + x END) AS `实际`,
       CASE WHEN size(全部合同) = 2 THEN 'PASS' ELSE 'FAIL' END AS `判定`;


// =============================================================================
// 四、宽松版（可选）：OPTIONAL CALL 保留没有共同合同的控股组合（Neo4j 5.24+）
// =============================================================================
// 本数据集里甲↔乙 有共同合同，因此该版本同样返回 1 行；把 MOCK3_HT1/HT2 的
// 签订合同边删掉（见第五节）即可看到它返回 1 行且合同为 null 的效果。
MATCH p0 = (r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(a:ZSTP:`企业`)
WHERE a.phonenumber IS NOT NULL AND trim(a.phonenumber) <> ''
MATCH p1 = shortestPath((a)-[:`股东持股（%）企业-企业`*1..3]->(b:ZSTP:`企业`))
WHERE b <> a
  AND b.phonenumber IS NOT NULL AND trim(b.phonenumber) <> ''
  AND b.phonenumber = a.phonenumber
OPTIONAL CALL (a, b) {
  MATCH p2 = (a)-[:`签订合同`]->(c:ZSTP:`合同`)<-[:`签订合同`]-(b)
  RETURN p2, c ORDER BY coalesce(c.sign_time, ''), c.object_key LIMIT 1
}
RETURN p0, p1, p2,
       coalesce(c.contract_code, '（无共同合同）') AS `合同编号`,
       CASE WHEN c IS NULL THEN '仅有控股关系' ELSE '控股关系 + 同签合同' END AS `证据类型`,
       a.org_name AS `风险企业`, b.org_name AS `被控股企业`;


// =============================================================================
// 五、可选：临时移除"甲↔乙 共同合同"以验证宽松版（三、四节跑完后使用）
// =============================================================================
// 删除甲↔乙 的 HT1/HT2 签订合同边（保留合同节点）：
//   MATCH (:ZSTP:`企业` {object_key:'MOCK3_A'})-[e:`签订合同`]->(c:ZSTP:`合同`)
//   WHERE c.object_key IN ['MOCK3_HT1','MOCK3_HT2'] DELETE e;
//   MATCH (:ZSTP:`企业` {object_key:'MOCK3_B'})-[e:`签订合同`]->(c:ZSTP:`合同`)
//   WHERE c.object_key IN ['MOCK3_HT1','MOCK3_HT2'] DELETE e;
// 此时：主查询（第二节）返回 0 行；宽松版（第四节）返回 1 行、合同编号为"（无共同合同）"。
// 恢复：重新执行第一节即可（MERGE 幂等）。


// =============================================================================
// 六、清理本脚本的全部数据
// =============================================================================
// MATCH (n:ZSTP) WHERE n.object_key STARTS WITH 'MOCK3_' DETACH DELETE n;
