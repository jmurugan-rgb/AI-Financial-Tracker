// ============================================================
// Finance Tracker — seed data
// Mirrors the sample data used in the dashboard prototype so the
// two stay consistent while you wire the real pipeline in.
// Run after schema.cypher.
// ============================================================

// --- User + accounts ---
MERGE (u:User {id: 'user_1'}) SET u.name = 'Demo User';

MERGE (checking:Account {id: 'acct_checking'})
  SET checking.name = 'Checking', checking.type = 'checking', checking.balance = 4218.42;
MERGE (credit:Account {id: 'acct_credit'})
  SET credit.name = 'Credit card', credit.type = 'credit', credit.balance = -1362.17;
MERGE (savings:Account {id: 'acct_savings'})
  SET savings.name = 'Savings', savings.type = 'savings', savings.balance = 12500.00;

MATCH (u:User {id: 'user_1'}), (a:Account) WHERE a.id STARTS WITH 'acct_'
MERGE (u)-[:OWNS]->(a);

// --- Categories ---
UNWIND ['Streaming', 'Groceries', 'Gas', 'Coffee', 'Shopping', 'Travel', 'Uncategorized'] AS catName
MERGE (:Category {name: catName});

// --- Merchants (linked to their category) ---
UNWIND [
  {name: 'Netflix', category: 'Streaming'},
  {name: 'Spotify', category: 'Streaming'},
  {name: 'Hulu', category: 'Streaming'},
  {name: 'Disney+', category: 'Streaming'},
  {name: 'HBO Max', category: 'Streaming'},
  {name: 'Whole Foods', category: 'Groceries'},
  {name: "Trader Joe's", category: 'Groceries'},
  {name: 'Starbucks', category: 'Coffee'},
  {name: 'Shell', category: 'Gas'},
  {name: 'Amazon', category: 'Shopping'},
  {name: 'Target', category: 'Shopping'},
  {name: 'Delta', category: 'Travel'},
  {name: 'Unfamiliar overseas merchant', category: 'Uncategorized'}
] AS row
MERGE (m:Merchant {name: row.name})
WITH m, row
MATCH (c:Category {name: row.category})
MERGE (m)-[:IN_CATEGORY]->(c);

// --- Transactions ---
// Streaming merchants get 3 monthly charges each (recurrence signal).
// Everything else gets 1-2 irregular charges. The anomaly gets exactly one.
UNWIND [
  {id: 'tx_netflix_1', merchant: 'Netflix',   account: 'acct_credit',   date: date('2026-05-05'), amount: 15.49, category: 'Streaming'},
  {id: 'tx_netflix_2', merchant: 'Netflix',   account: 'acct_credit',   date: date('2026-06-05'), amount: 15.49, category: 'Streaming'},
  {id: 'tx_netflix_3', merchant: 'Netflix',   account: 'acct_credit',   date: date('2026-07-05'), amount: 15.49, category: 'Streaming'},

  {id: 'tx_spotify_1', merchant: 'Spotify',   account: 'acct_credit',   date: date('2026-05-02'), amount: 11.99, category: 'Streaming'},
  {id: 'tx_spotify_2', merchant: 'Spotify',   account: 'acct_credit',   date: date('2026-06-02'), amount: 11.99, category: 'Streaming'},
  {id: 'tx_spotify_3', merchant: 'Spotify',   account: 'acct_credit',   date: date('2026-07-02'), amount: 11.99, category: 'Streaming'},

  {id: 'tx_hulu_1',    merchant: 'Hulu',      account: 'acct_credit',   date: date('2026-04-29'), amount: 12.99, category: 'Streaming'},
  {id: 'tx_hulu_2',    merchant: 'Hulu',      account: 'acct_credit',   date: date('2026-05-29'), amount: 12.99, category: 'Streaming'},
  {id: 'tx_hulu_3',    merchant: 'Hulu',      account: 'acct_credit',   date: date('2026-06-29'), amount: 12.99, category: 'Streaming'},

  {id: 'tx_disney_1',  merchant: 'Disney+',   account: 'acct_credit',   date: date('2026-05-04'), amount: 13.99, category: 'Streaming'},
  {id: 'tx_disney_2',  merchant: 'Disney+',   account: 'acct_credit',   date: date('2026-06-04'), amount: 13.99, category: 'Streaming'},
  {id: 'tx_disney_3',  merchant: 'Disney+',   account: 'acct_credit',   date: date('2026-07-04'), amount: 13.99, category: 'Streaming'},

  {id: 'tx_hbo_1',     merchant: 'HBO Max',   account: 'acct_credit',   date: date('2026-05-10'), amount: 9.99,  category: 'Streaming'},
  {id: 'tx_hbo_2',     merchant: 'HBO Max',   account: 'acct_credit',   date: date('2026-06-10'), amount: 9.99,  category: 'Streaming'},
  {id: 'tx_hbo_3',     merchant: 'HBO Max',   account: 'acct_credit',   date: date('2026-07-10'), amount: 9.99,  category: 'Streaming'},

  {id: 'tx_wf_1',      merchant: 'Whole Foods',    account: 'acct_checking', date: date('2026-06-12'), amount: 91.10, category: 'Groceries'},
  {id: 'tx_wf_2',      merchant: 'Whole Foods',    account: 'acct_checking', date: date('2026-07-04'), amount: 86.40, category: 'Groceries'},

  {id: 'tx_tj_1',      merchant: "Trader Joe's",   account: 'acct_checking', date: date('2026-06-28'), amount: 54.10, category: 'Groceries'},

  {id: 'tx_sb_1',      merchant: 'Starbucks',      account: 'acct_checking', date: date('2026-06-30'), amount: 6.75,  category: 'Coffee'},

  {id: 'tx_shell_1',   merchant: 'Shell',          account: 'acct_credit',   date: date('2026-07-03'), amount: 42.00, category: 'Gas'},

  {id: 'tx_amzn_1',    merchant: 'Amazon',         account: 'acct_credit',   date: date('2026-07-01'), amount: 128.30, category: 'Shopping'},

  {id: 'tx_target_1',  merchant: 'Target',         account: 'acct_credit',   date: date('2026-06-20'), amount: 64.20, category: 'Shopping'},

  {id: 'tx_delta_1',   merchant: 'Delta',          account: 'acct_credit',   date: date('2026-06-26'), amount: 340.00, category: 'Travel'},

  {id: 'tx_anomaly_1', merchant: 'Unfamiliar overseas merchant', account: 'acct_credit', date: date('2026-07-05'), amount: 1240.00, category: 'Uncategorized'}
] AS row
MERGE (t:Transaction {id: row.id})
  SET t.date = row.date, t.amount = row.amount
WITH t, row
MATCH (a:Account {id: row.account})
MATCH (m:Merchant {name: row.merchant})
MATCH (c:Category {name: row.category})
MERGE (a)-[:HAS_TRANSACTION]->(t)
MERGE (t)-[:AT_MERCHANT]->(m)
MERGE (t)-[:CATEGORIZED_AS]->(c);
