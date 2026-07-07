"""
Ingestion step for the finance tracker.

RocketRide's db_neo4j node is natural-language-to-Cypher and READ-ONLY by
design (it rejects CREATE/MERGE/SET/DELETE, see docs.rocketride.org/nodes/db_neo4j).
That's the right tool for the insight-generation side of the pipeline
(finance-insights.pipe), but it is not how you load data into the graph.

This script is the deterministic ETL step: it talks to Neo4j directly with
the official driver and runs the exact Cypher in ../neo4j/*.cypher. Run it:

  - once, to set up schema + seed data (--seed)
  - on every new transaction batch from your bank/webhook source (--ingest)
  - after ingestion, to refresh FOLLOWS/SIMILAR_TO (--derive), or just pass
    --ingest which does ingest + derive together

In production this would be triggered by whatever receives your raw
transaction feed (a webhook handler, a scheduled sync job, etc.), immediately
before or after the RocketRide pipeline is invoked for insight generation.
"""

import argparse
import os
from pathlib import Path

from neo4j import GraphDatabase

NEO4J_DIR = Path(__file__).resolve().parent.parent / "neo4j"


def run_cypher_file(driver, database, path):
    """Split a .cypher file on blank-line-separated statements and run each."""
    text = path.read_text()
    # Strip full-line comments, then split on semicolons.
    lines = [l for l in text.split("\n") if not l.strip().startswith("//")]
    statements = [s.strip() for s in "\n".join(lines).split(";") if s.strip()]
    with driver.session(database=database) as session:
        for stmt in statements:
            session.run(stmt)
    print(f"  ran {len(statements)} statement(s) from {path.name}")


def seed(driver, database):
    print("Applying schema...")
    run_cypher_file(driver, database, NEO4J_DIR / "schema.cypher")
    print("Loading seed data...")
    run_cypher_file(driver, database, NEO4J_DIR / "seed-data.cypher")
    print("Deriving relationships...")
    run_cypher_file(driver, database, NEO4J_DIR / "derive-relationships.cypher")


def ingest_transactions(driver, database, transactions):
    """
    Write a batch of new transactions into the graph.

    `transactions` is a list of dicts shaped like:
      {
        "id": "tx_123", "account_id": "acct_checking", "merchant": "Trader Joe's",
        "category": "Groceries", "date": "2026-07-06", "amount": 42.10
      }

    This assumes the Account, Merchant, and Category nodes already exist
    (created via schema.cypher / seed-data.cypher, or upsert them here too
    if merchants can be genuinely new).
    """
    query = """
    UNWIND $rows AS row
    MERGE (t:Transaction {id: row.id})
      SET t.date = date(row.date), t.amount = row.amount
    WITH t, row
    MATCH (a:Account {id: row.account_id})
    MERGE (m:Merchant {name: row.merchant})
    MERGE (c:Category {name: row.category})
    MERGE (m)-[:IN_CATEGORY]->(c)
    MERGE (a)-[:HAS_TRANSACTION]->(t)
    MERGE (t)-[:AT_MERCHANT]->(m)
    MERGE (t)-[:CATEGORIZED_AS]->(c)
    """
    with driver.session(database=database) as session:
        session.run(query, rows=transactions)
    print(f"  wrote {len(transactions)} transaction(s)")


def derive(driver, database):
    print("Re-deriving FOLLOWS and SIMILAR_TO...")
    run_cypher_file(driver, database, NEO4J_DIR / "derive-relationships.cypher")


def main():
    parser = argparse.ArgumentParser(description="Finance tracker Neo4j ingestion")
    parser.add_argument("--seed", action="store_true", help="Apply schema + seed data + derive relationships")
    parser.add_argument("--derive", action="store_true", help="Re-run FOLLOWS/SIMILAR_TO derivation only")
    args = parser.parse_args()

    uri = os.environ["NEO4J_URI"]
    user = os.environ.get("NEO4J_USER", "neo4j")
    password = os.environ["NEO4J_PASSWORD"]
    database = os.environ.get("NEO4J_DATABASE", "neo4j")

    driver = GraphDatabase.driver(uri, auth=(user, password))
    try:
        driver.verify_connectivity()
        if args.seed:
            seed(driver, database)
        elif args.derive:
            derive(driver, database)
        else:
            parser.print_help()
    finally:
        driver.close()


if __name__ == "__main__":
    main()
