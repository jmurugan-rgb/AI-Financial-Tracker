// ============================================================
// Finance Tracker — insight queries
// Each query below maps directly to one card in the dashboard.
// Run schema.cypher, seed-data.cypher, and derive-relationships.cypher
// first.
// ============================================================


// ============================================================
// Insight 1 — Recurring subscription detection
// Walks the FOLLOWS chain per merchant and flags merchants whose
// billing interval barely varies (near-constant days_between).
// This is the query behind the "Recurring cluster detected" card.
// ============================================================
MATCH (t1:Transaction)-[f:FOLLOWS]->(t2:Transaction)
MATCH (t1)-[:AT_MERCHANT]->(m:Merchant)
WITH m, collect(f.days_between) AS intervals, collect(t1.amount) AS amounts
WITH m, intervals, amounts, size(intervals) AS n,
     reduce(s = 0.0, x IN intervals | s + x) / size(intervals) AS avgInterval
WITH m, n, avgInterval, amounts,
     sqrt(reduce(s = 0.0, x IN intervals | s + (x - avgInterval) ^ 2) / n) AS stdDevInterval,
     reduce(s = 0.0, x IN amounts | s + x) / size(amounts) AS avgAmount
WHERE n >= 2 AND stdDevInterval <= 5          // near-constant cadence = recurring
RETURN m.name AS merchant,
       round(avgInterval) AS avg_days_between,
       round(stdDevInterval * 10) / 10.0 AS interval_stddev,
       round(avgAmount * 100) / 100.0 AS avg_charge,
       round(avgAmount * 30.0 / avgInterval * 100) / 100.0 AS approx_monthly_cost
ORDER BY approx_monthly_cost DESC;

// Roll-up: total recurring spend (feeds the "$64.45/mo" stat)
MATCH (t1:Transaction)-[f:FOLLOWS]->(t2:Transaction)
MATCH (t1)-[:AT_MERCHANT]->(m:Merchant)
WITH m, collect(f.days_between) AS intervals, collect(t1.amount) AS amounts
WITH m, intervals, amounts, size(intervals) AS n,
     reduce(s = 0.0, x IN intervals | s + x) / size(intervals) AS avgInterval
WITH m, n, avgInterval, amounts,
     sqrt(reduce(s = 0.0, x IN intervals | s + (x - avgInterval) ^ 2) / n) AS stdDevInterval,
     reduce(s = 0.0, x IN amounts | s + x) / size(amounts) AS avgAmount
WHERE n >= 2 AND stdDevInterval <= 5
RETURN round(sum(avgAmount) * 100) / 100.0 AS total_recurring_monthly_spend;


// ============================================================
// Insight 2 — Anomaly detection
// A transaction is anomalous when its merchant has no SIMILAR_TO
// neighbors (nothing like it in the graph) AND the amount is a
// statistical outlier against the user's own transaction history.
// This is the query behind the "Anomaly flagged" card.
// ============================================================
MATCH (u:User)-[:OWNS]->(:Account)-[:HAS_TRANSACTION]->(t:Transaction)
WITH u, collect(t.amount) AS allAmounts
WITH u,
     reduce(s = 0.0, x IN allAmounts | s + x) / size(allAmounts) AS meanAmt,
     allAmounts
WITH u, meanAmt,
     sqrt(reduce(s = 0.0, x IN allAmounts | s + (x - meanAmt) ^ 2) / size(allAmounts)) AS stdAmt
MATCH (u)-[:OWNS]->(:Account)-[:HAS_TRANSACTION]->(t:Transaction)-[:AT_MERCHANT]->(m:Merchant)
WHERE NOT (m)-[:SIMILAR_TO]-(:Merchant)         // isolated in the graph
  AND t.amount > meanAmt + 2 * stdAmt            // and a statistical outlier
RETURN t.id AS transaction_id,
       m.name AS merchant,
       t.amount AS amount,
       round(meanAmt * 100) / 100.0 AS user_avg_transaction,
       round((t.amount - meanAmt) / stdAmt * 100) / 100.0 AS z_score
ORDER BY amount DESC;


// ============================================================
// Insight 3 — Savings opportunity via cluster overlap
// Within a cluster of mutually SIMILAR_TO merchants, rank by how
// often the user actually uses each one and surface the
// lowest-value members as cancellation candidates.
//
// avg_monthly_uses would come from real product-usage events in
// production (e.g. app opens logged via Butterbase) — seeded here
// for the demo so the ranking has something to sort on.
// ============================================================
UNWIND [
  {name: 'Netflix',  avg_monthly_uses: 18},
  {name: 'Spotify',  avg_monthly_uses: 22},
  {name: 'Hulu',     avg_monthly_uses: 3},
  {name: 'Disney+',  avg_monthly_uses: 2},
  {name: 'HBO Max',  avg_monthly_uses: 4}
] AS row
MATCH (m:Merchant {name: row.name})
SET m.avg_monthly_uses = row.avg_monthly_uses;

MATCH (m:Merchant)-[:IN_CATEGORY]->(:Category {name: 'Streaming'})
MATCH (m)<-[:AT_MERCHANT]-(t:Transaction)
WITH m, avg(t.amount) AS monthly_cost
WITH m, monthly_cost ORDER BY m.avg_monthly_uses ASC
WITH collect({merchant: m.name, uses: m.avg_monthly_uses, cost: monthly_cost}) AS ranked
WITH ranked[0..2] AS cancel_candidates
UNWIND cancel_candidates AS c
RETURN c.merchant AS merchant_to_reconsider,
       c.uses AS avg_monthly_uses,
       round(c.cost * 100) / 100.0 AS monthly_cost
ORDER BY monthly_cost DESC;

// ============================================================
// Optional GDS upgrade: once you have more than one obviously
// clustered category, don't assume "same category = same cluster" —
// let Louvain discover the clusters from SIMILAR_TO edge weights.
// ============================================================
// CALL gds.graph.project(
//   'merchantGraph', 'Merchant',
//   { SIMILAR_TO: { properties: 'score', orientation: 'UNDIRECTED' } }
// );
// CALL gds.louvain.stream('merchantGraph')
// YIELD nodeId, communityId
// RETURN gds.util.asNode(nodeId).name AS merchant, communityId
// ORDER BY communityId;
// CALL gds.graph.drop('merchantGraph');
