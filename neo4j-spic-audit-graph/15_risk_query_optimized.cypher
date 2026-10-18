// =============================================================================
// 国电投 AI+审计 知识图谱 · 风险穿透查询
// -----------------------------------------------------------------------------
// 图结构（与可视化一致）:
//
//   线索实体1 -[:股东持股*1..3]-> ... -> 国电投企业 -[:签订合同]-> 合同
//        |                                                    ^
//        +----[:触发风险_企业]-> 风险线索 <-[:触发风险_企业]----+
//                                         ^                   |
//   线索实体2 -[:股东持股*1..3]-> ... -> 外部企业 -[:签订合同]-+
//
// 口径:
//   1. 先找同签一份合同的双方:一侧是国电投企业,一侧是外部企业。
//      多份共同合同时,取签订时间最早的一份(边上 sign_time 优先,空值回落合同节点)。
//   2. 从国电投签约企业、外部签约企业分别沿"股东持股（%）企业-企业"向上追溯,
//      最多 3 层,得到两个不同实体。
//   3. 这两个实体都必须通过"触发风险_企业"挂到同一条风险线索上,
//      且风险类型为"企业电话相同"。
//
// 与上一版的区别:
//   上一版把"触发风险的企业"直接当成"签约企业",要求它自己去签合同。
//   本版签约方与线索实体是两组节点:签约方在合同两端,线索实体在持股链上游。
//
// 国电投 / 外部 判定:
//   生产数据用 flag_gdtqy = '是' / 非'是'。
//   当前 mock 大多未填该标志,未标注时用企业名称是否含"国电投"区分,以便命中示例图。
// =============================================================================


// =============================================================================
// 一、主查询:返回四段路径,可在 Browser 中还原整张图
// =============================================================================
MATCH (g:ZSTP:`企业`)-[rg:`签订合同`]->(c:ZSTP:`合同`)<-[rw:`签订合同`]-(w:ZSTP:`企业`)
WHERE g <> w
  AND (
        g.flag_gdtqy = '是'
        OR (g.flag_gdtqy IS NULL AND g.org_name CONTAINS '国电投')
      )
  AND (
        w.flag_gdtqy = '否'
        OR (w.flag_gdtqy IS NULL AND NOT coalesce(w.org_name, '') CONTAINS '国电投')
      )
WITH g, w, c, coalesce(rg.sign_time, rw.sign_time, c.sign_time) AS signTime
ORDER BY signTime ASC, c.object_key ASC
WITH g, w, collect(c)[0] AS c
MATCH p1 = shortestPath((e1:ZSTP:`企业`)-[:`股东持股（%）企业-企业`*1..3]->(g))
MATCH p2 = shortestPath((e2:ZSTP:`企业`)-[:`股东持股（%）企业-企业`*1..3]->(w))
WHERE e1 <> e2
MATCH (e1)-[:`触发风险_企业`]->(r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(e2)
MATCH p0 = (g)-[:`签订合同`]->(c)<-[:`签订合同`]-(w)
MATCH p3 = (e1)-[:`触发风险_企业`]->(r)<-[:`触发风险_企业`]-(e2)
RETURN p0, p1, p2, p3;


// =============================================================================
// 二、明细输出版(核查字段,不返回路径)
// =============================================================================
// MATCH (g:ZSTP:`企业`)-[rg:`签订合同`]->(c:ZSTP:`合同`)<-[rw:`签订合同`]-(w:ZSTP:`企业`)
// WHERE g <> w
//   AND (g.flag_gdtqy = '是' OR (g.flag_gdtqy IS NULL AND g.org_name CONTAINS '国电投'))
//   AND (w.flag_gdtqy = '否' OR (w.flag_gdtqy IS NULL AND NOT coalesce(w.org_name, '') CONTAINS '国电投'))
// WITH g, w, c, coalesce(rg.sign_time, rw.sign_time, c.sign_time) AS signTime
// ORDER BY signTime ASC, c.object_key ASC
// WITH g, w, collect(c)[0] AS c, collect(signTime)[0] AS signTime
// MATCH p1 = shortestPath((e1:ZSTP:`企业`)-[:`股东持股（%）企业-企业`*1..3]->(g))
// MATCH p2 = shortestPath((e2:ZSTP:`企业`)-[:`股东持股（%）企业-企业`*1..3]->(w))
// WHERE e1 <> e2
// MATCH (e1)-[:`触发风险_企业`]->(r:ZSTP:`风险线索` {risk_type: '企业电话相同'})<-[:`触发风险_企业`]-(e2)
// RETURN g.org_name AS 国电投签约企业,
//        w.org_name AS 外部签约企业,
//        c.contract_name AS 合同,
//        signTime AS 最早签订时间,
//        e1.org_name AS 线索实体1, length(p1) AS 持股层数1,
//        e2.org_name AS 线索实体2, length(p2) AS 持股层数2,
//        r.object_key AS 风险线索, r.risk_type AS 风险类型;
