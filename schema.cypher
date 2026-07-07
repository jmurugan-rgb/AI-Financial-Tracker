// ============================================================
// Finance Tracker — Neo4j schema
// Run this once against a fresh Aura / local instance.
// ============================================================

// --- Node key constraints (also creates a backing index) ---
CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.id IS UNIQUE;

CREATE CONSTRAINT account_id IF NOT EXISTS
FOR (a:Account) REQUIRE a.id IS UNIQUE;

CREATE CONSTRAINT transaction_id IF NOT EXISTS
FOR (t:Transaction) REQUIRE t.id IS UNIQUE;

CREATE CONSTRAINT merchant_name IF NOT EXISTS
FOR (m:Merchant) REQUIRE m.name IS UNIQUE;

CREATE CONSTRAINT category_name IF NOT EXISTS
FOR (c:Category) REQUIRE c.name IS UNIQUE;

// --- Supporting indexes for the query patterns below ---
CREATE INDEX transaction_date IF NOT EXISTS
FOR (t:Transaction) ON (t.date);

CREATE INDEX transaction_amount IF NOT EXISTS
FOR (t:Transaction) ON (t.amount);

// ============================================================
// Graph model
// ============================================================
// (User)-[:OWNS]->(Account)
// (Account)-[:HAS_TRANSACTION]->(Transaction)
// (Transaction)-[:AT_MERCHANT]->(Merchant)
// (Transaction)-[:CATEGORIZED_AS]->(Category)
// (Merchant)-[:IN_CATEGORY]->(Category)
// (Transaction)-[:FOLLOWS {days_between: float}]->(Transaction)
//     — chains consecutive transactions at the same merchant,
//       ordered by date. This is what recurrence detection walks.
// (Merchant)-[:SIMILAR_TO {score: float}]->(Merchant)
//     — derived edge: merchants that co-occur in the same category
//       and/or cluster together under GDS node similarity.
// ============================================================
