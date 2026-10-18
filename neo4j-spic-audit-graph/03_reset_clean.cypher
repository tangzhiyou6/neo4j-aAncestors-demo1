// =============================================================================
// 国电投 AI+审计 知识图谱  ·  数据清空 / 重置脚本
// -----------------------------------------------------------------------------
// 用途 : 清空图库中的顶点与边数据，可按需选择"只清数据 / 连约束索引一起清 /
//        物理级清空"。请只执行你需要的那个章节，不要整文件顺序执行。
//
// ⚠️ 警告：DETACH DELETE 与 DROP 均为不可逆操作。执行前请确认：
//    1) 已备份（脱机备份 `neo4j-admin database dump` 或导出 Cypher）
//    2) 确认连接的是正确的数据库（`SHOW DATABASES;`）
//    3) 生产库请勿在业务高峰执行全量删除
// =============================================================================


// =============================================================================
// 方式一（推荐）：只删除本图谱的数据 —— 精确、安全、不动其他数据
// 说明：本图谱所有顶点均带通用标签 :ZSTP，因此可精准圈定。
// =============================================================================
MATCH (n:ZSTP) DETACH DELETE n;

// 若库中只有本图谱、想省事，等价写法：
// MATCH (n:ZSTP:`企业` OR n:ZSTP:`自然人` OR n:ZSTP:`合同`) DETACH DELETE n;


// =============================================================================
// 方式二：清空整库所有节点与关系（不限标签，会连其他数据一并删除）
// =============================================================================
// MATCH (n) DETACH DELETE n;
//
// 注意：Neo4j 5 中的 `DETACH DELETE` 会先删关系再删节点，一条语句即可清空。
// 老版本写法（先删关系再删节点，Neo4j 4.x 及更早）：
//   MATCH ()-[r]->() DELETE r;
//   MATCH (n) DELETE n;


// =============================================================================
// 方式三：只清空关系，保留所有顶点
// =============================================================================
// MATCH ()-[r]->() DELETE r;
//
// 属性图里关系都是有向的，一条语句即可覆盖全部关系。
// 如需只删本图谱参与的关系：
//   MATCH (a:ZSTP)-[r]->() DELETE r;


// =============================================================================
// 方式四：大数据量分批删除（节点数 > 10 万时务必用这个，否则可能 OOM / 事务日志爆掉）
// -----------------------------------------------------------------------------
// 4.1 原生分批（无需 APOC，Neo4j 5.x 直接可用）
//     必须在"自动提交事务"中执行（Neo4j Browser / cypher-shell 直接跑即可），
//     不能包在显式 BEGIN...COMMIT 里。
// =============================================================================
// MATCH (n:ZSTP)
// CALL { WITH n DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;

// Neo4j 5.23+ 起推荐的新写法（变量作用域子查询）：
// MATCH (n:ZSTP)
// CALL (n) { DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;


// =============================================================================
// 4.2 APOC 分批（需安装 APOC 插件）
// =============================================================================
// CALL apoc.periodic.iterate(
//   'MATCH (n:ZSTP) RETURN n',
//   'DETACH DELETE n',
//   {batchSize: 10000, parallel: false, iterateList: true}
// ) YIELD batches, total, timeTaken, committedOperations
// RETURN batches, total, timeTaken, committedOperations;
//
// 全库分批（不限标签）：
// CALL apoc.periodic.iterate(
//   'MATCH (n) RETURN n',
//   'DETACH DELETE n',
//   {batchSize: 10000, parallel: false}
// ) YIELD batches, total RETURN batches, total;


// =============================================================================
// 方式五：物理级清空（最快，适合整库重置；需停库操作）
// -----------------------------------------------------------------------------
// Community 版只能这样清库（不能 DROP DATABASE）：
//
//   # 1. 停库
//   ~/neo4j/bin/neo4j stop
//
//   # 2. 删除该库的数据文件与事务日志（默认库名 neo4j）
//   rm -rf ~/neo4j/data/databases/neo4j
//   rm -rf ~/neo4j/data/transactions/neo4j
//
//   # 3. 起库（会自动重建空库，同时需要重新执行 01_neo4j_ddl.cypher）
//   ~/neo4j/bin/neo4j start
//
// Docker 部署：
//   docker compose down
//   rm -rf ./neo4j/data/databases/neo4j ./neo4j/data/transactions/neo4j
//   docker compose up -d
//
// Enterprise 版可用 SQL 级操作（无需停库）：
//   STOP DATABASE neo4j;
//   DROP DATABASE neo4j;
//   CREATE DATABASE neo4j;
// =============================================================================


// =============================================================================
// 方式六：连约束与索引一起删除（把库恢复到"全新未建模"状态）
// -----------------------------------------------------------------------------
// 注意：删除顶点唯一约束会同时删掉其背后的支撑索引；
//       idx_* 这些独立属性索引需要单独删除。
//       以下语句由 01_neo4j_ddl.cypher 自动提取生成，可安全重复执行。
// =============================================================================

// ===== 顶点唯一约束（28） =====
DROP CONSTRAINT cst_qy_object_key IF EXISTS;
DROP CONSTRAINT cst_zrr_object_key IF EXISTS;
DROP CONSTRAINT cst_ht_object_key IF EXISTS;
DROP CONSTRAINT cst_bd_object_key IF EXISTS;
DROP CONSTRAINT cst_fp_object_key IF EXISTS;
DROP CONSTRAINT cst_zjls_object_key IF EXISTS;
DROP CONSTRAINT cst_yhzh_object_key IF EXISTS;
DROP CONSTRAINT cst_cwpz_object_key IF EXISTS;
DROP CONSTRAINT cst_wl_object_key IF EXISTS;
DROP CONSTRAINT cst_rk_object_key IF EXISTS;
DROP CONSTRAINT cst_ck_object_key IF EXISTS;
DROP CONSTRAINT cst_jrlxm_object_key IF EXISTS;
DROP CONSTRAINT cst_qtlxm_object_key IF EXISTS;
DROP CONSTRAINT cst_jjlxm_object_key IF EXISTS;
DROP CONSTRAINT cst_dnygdd_object_key IF EXISTS;
DROP CONSTRAINT cst_xtcp_object_key IF EXISTS;
DROP CONSTRAINT cst_xtdczc_object_key IF EXISTS;
DROP CONSTRAINT cst_ylqfqszd_object_key IF EXISTS;
DROP CONSTRAINT cst_ylzrzd_object_key IF EXISTS;
DROP CONSTRAINT cst_ylrzzd_object_key IF EXISTS;
DROP CONSTRAINT cst_fxxs_object_key IF EXISTS;
DROP CONSTRAINT cst_flss_object_key IF EXISTS;
DROP CONSTRAINT cst_pccz_object_key IF EXISTS;
DROP CONSTRAINT cst_xzcf_object_key IF EXISTS;
DROP CONSTRAINT cst_sxbzxr_object_key IF EXISTS;
DROP CONSTRAINT cst_jchy_object_key IF EXISTS;
DROP CONSTRAINT cst_jchyyt_object_key IF EXISTS;
DROP CONSTRAINT cst_ejdwgfjc_object_key IF EXISTS;

// ===== 边唯一约束（60） =====
DROP CONSTRAINT rel_qy_gdcgbfb_object_key IF EXISTS;
DROP CONSTRAINT rel_zrr_gdcgqy_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_qd_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_csfp_object_key IF EXISTS;
DROP CONSTRAINT rel_dnegdd_csfp_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_kjjsfp_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_yyzh_object_key IF EXISTS;
DROP CONSTRAINT rel_yhzh_jy_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_skfk_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_skfk_object_key IF EXISTS;
DROP CONSTRAINT rel_fp_yjfpskfk_object_key IF EXISTS;
DROP CONSTRAINT rel_zjls_zjlsskfkzh_object_key IF EXISTS;
DROP CONSTRAINT rel_zjls_scpz_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_acghtrk_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_axshtck_object_key IF EXISTS;
DROP CONSTRAINT rel_wl_lywl_object_key IF EXISTS;
DROP CONSTRAINT rel_wl_xhwl_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_psdd_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_fqdd_object_key IF EXISTS;
DROP CONSTRAINT rel_bd_lsht_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_tybdwgl_object_key IF EXISTS;
DROP CONSTRAINT rel_fp_tybdwgl_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_fb_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_cy_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_zb_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_scxzbs_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_fqxm_jrlxm_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_fqxm_qtlxm_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_fqxm_jjlxm_object_key IF EXISTS;
DROP CONSTRAINT rel_jrlxm_ct_object_key IF EXISTS;
DROP CONSTRAINT rel_jrlxm_tx_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_fqjchy_object_key IF EXISTS;
DROP CONSTRAINT rel_jchy_hytlyt_object_key IF EXISTS;
DROP CONSTRAINT rel_jchyyt_jjlxm_object_key IF EXISTS;
DROP CONSTRAINT rel_jchyyt_qtlxm_object_key IF EXISTS;
DROP CONSTRAINT rel_jchyyt_jrlxm_object_key IF EXISTS;
DROP CONSTRAINT rel_zrr_cyyt_object_key IF EXISTS;
DROP CONSTRAINT rel_zrr_drcrqyfr_object_key IF EXISTS;
DROP CONSTRAINT rel_zrr_rzqy_object_key IF EXISTS;
DROP CONSTRAINT rel_ylqfqszd_sczrzd_object_key IF EXISTS;
DROP CONSTRAINT rel_ylqfzd_yyrz_object_key IF EXISTS;
DROP CONSTRAINT rel_ylzrzd_gldcght_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_qfzd_srf_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_qfzd_crf_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_cghtscqfzd_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_zrzd_crf_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_zrzd_srf_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_sqrz_srf_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_sqrz_crf_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_sjss_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_sjpccz_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_sdxzcf_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_blwsxzxr_object_key IF EXISTS;
DROP CONSTRAINT rel_qy_cffx_object_key IF EXISTS;
DROP CONSTRAINT rel_zzr_cffx_object_key IF EXISTS;
DROP CONSTRAINT rel_bd_cffx_object_key IF EXISTS;
DROP CONSTRAINT rel_ht_cffx_object_key IF EXISTS;
DROP CONSTRAINT rel_ylqfqszd_cffx_object_key IF EXISTS;
DROP CONSTRAINT rel_fxxs_fp_object_key IF EXISTS;
DROP CONSTRAINT rel_ejdwgfjc_dyqy_object_key IF EXISTS;

// ===== 属性索引（27） =====
DROP INDEX idx_qy_org_name IF EXISTS;
DROP INDEX idx_qy_credit_code IF EXISTS;
DROP INDEX idx_zrr_name IF EXISTS;
DROP INDEX idx_ht_contract_code IF EXISTS;
DROP INDEX idx_bd_packno IF EXISTS;
DROP INDEX idx_fp_fp_hm IF EXISTS;
DROP INDEX idx_zjls_bill_num IF EXISTS;
DROP INDEX idx_yhzh_bank_acc_no IF EXISTS;
DROP INDEX idx_cwpz_post_bh IF EXISTS;
DROP INDEX idx_wl_matnr IF EXISTS;
DROP INDEX idx_rk_mblnr IF EXISTS;
DROP INDEX idx_ck_vbeln IF EXISTS;
DROP INDEX idx_jrlxm_deal_name IF EXISTS;
DROP INDEX idx_qtlxm_item_name IF EXISTS;
DROP INDEX idx_jjlxm_proj_name IF EXISTS;
DROP INDEX idx_dnygdd_order_no IF EXISTS;
DROP INDEX idx_xtcp_product_code IF EXISTS;
DROP INDEX idx_ylqfqszd_bill_no IF EXISTS;
DROP INDEX idx_ylzrzd_bill_no IF EXISTS;
DROP INDEX idx_ylrzzd_sub_bill_id IF EXISTS;
DROP INDEX idx_fxxs_risk_type IF EXISTS;
DROP INDEX idx_flss_case_no IF EXISTS;
DROP INDEX idx_xzcf_punish_number IF EXISTS;
DROP INDEX idx_sxbzxr_casecode IF EXISTS;
DROP INDEX idx_jchy_meeting_code IF EXISTS;
DROP INDEX idx_jchyyt_subject_code IF EXISTS;
DROP INDEX idx_ejdw_short_name IF EXISTS;
// 一键生成版的替代做法（Neo4j 5.x，无需手写名字）：
//   SHOW CONSTRAINTS YIELD name RETURN 'DROP CONSTRAINT `' + name + '`;' AS stmt;
//   SHOW INDEXES YIELD name WHERE type <> 'LOOKUP' RETURN 'DROP INDEX `' + name + '`;' AS stmt;
// 把返回结果逐条执行即可。Neo4j 5.22 及更早版本可用已废弃的 CALL db.constraints() / CALL db.indexes()。


// =============================================================================
// 七、执行后校验（应为 0 / 空）
// =============================================================================
// MATCH (n) RETURN count(n) AS 节点总数;
// MATCH ()-[r]->() RETURN count(r) AS 关系总数;
// MATCH (n:ZSTP) RETURN count(n) AS 本图谱节点数;
// SHOW CONSTRAINTS;
// SHOW INDEXES;
//
// 清缓存（可选，避免旧查询计划残留）：
// CALL db.clearQueryCaches();


// =============================================================================
// 八、清空前的备份建议（强烈推荐先做）
// =============================================================================
// Cypher 导出（需 APOC）：
//   CALL apoc.export.cypher.all('/backup/spic_graph_backup.cypher', {format:'cypher-shell'});
//
// 脱机备份（需停库）：
//   neo4j-admin database dump neo4j --to-path=/backup
//   # 恢复：neo4j-admin database load neo4j --from-path=/backup --overwrite-destination=true
