// ============================================================
// Finance Tracker — derive relationships
// Run after seed-data.cypher. These are the queries your
// RocketRide Cloud pipeline re-runs every time new transactions
// land, so the graph stays current.
// ============================================================

// --- 1. FOLLOWS: chain consecutive transactions at the same merchant ---
// This is what recurrence detection walks in insight-queries.cypher.
// Generic — works for any merchant, not hardcoded to streaming services.
MATCH (m:Merchant)<-[:AT_MERCHANT]-(t:Transaction)
WITH m, t ORDER BY t.date
WITH m, collect(t) AS txs
UNWIND range(0, size(txs) - 2) AS i
WITH txs[i] AS t1, txs[i + 1] AS t2
MERGE (t1)-[f:FOLLOWS]->(t2)
SET f.days_between = duration.between(t1.date, t2.date).days;

// --- 2. SIMILAR_TO (baseline, no GDS plugin required) ---
// Merchants in the same category are similar. Weight by how close
// their typical charge amounts are, so "similar" means more than
// just "same category label."
MATCH (m1:Merchant)-[:IN_CATEGORY]->(c:Category)<-[:IN_CATEGORY]-(m2:Merchant)
WHERE m1.name < m2.name
MATCH (m1)<-[:AT_MERCHANT]-(t1:Transaction)
MATCH (m2)<-[:AT_MERCHANT]-(t2:Transaction)
WITH m1, m2, avg(t1.amount) AS avg1, avg(t2.amount) AS avg2
WITH m1, m2, 1.0 / (1.0 + abs(avg1 - avg2)) AS score
MERGE (m1)-[s:SIMILAR_TO]->(m2)
SET s.score = score
MERGE (m2)-[s2:SIMILAR_TO]->(m1)
SET s2.score = score;

// ============================================================
// --- 3. SIMILAR_TO (GDS-enhanced, optional) ---
// Requires the Graph Data Science library (available on
// self-managed Neo4j with the GDS plugin, or AuraDS).
// Node Similarity over the (Transaction)-(Merchant) bipartite
// graph catches co-usage patterns a simple category match misses
// — e.g. two merchants a user always charges in the same week.
// ============================================================

// CALL gds.graph.project(
//   'merchantSimilarity',
//   ['Transaction', 'Merchant'],
//   { AT_MERCHANT: { orientation: 'UNDIRECTED' } }
// );
//
// CALL gds.nodeSimilarity.write('merchantSimilarity', {
//   writeRelationshipType: 'SIMILAR_TO',
//   writeProperty: 'score',
//   similarityCutoff: 0.3
// })
// YIELD nodesCompared, relationshipsWritten
// RETURN nodesCompared, relationshipsWritten;
//
// CALL gds.graph.drop('merchantSimilarity');
