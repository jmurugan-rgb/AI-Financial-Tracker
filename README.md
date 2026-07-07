# AI Financial Tracker

A functional local-first AI financial tracker built from the uploaded frontend, Neo4j, and RocketRide assets.

## What works now

- React/Vite dashboard
- Account summary and net-worth view
- Transaction ledger
- Add transactions in the UI
- Import and export CSV transactions
- LocalStorage persistence
- Explainable AI-style insights:
  - recurring subscription detection
  - anomaly detection
  - savings opportunity suggestions
- Interactive transaction graph highlighting the merchants behind each insight

## Run locally

### Option A: no install

Open `standalone/index.html` directly in your browser. This version has no build step and no external dependencies.

### Option B: React/Vite source

```bash
npm install
npm run dev
```

Open the URL printed by Vite, usually `http://localhost:5173`.

## CSV import format

The importer accepts a header row with these columns:

```csv
id,date,merchant,category,amount,accountId
```

`id` is optional. `accountId` can be `acct_checking`, `acct_credit`, or `acct_savings`.

## Project structure

```text
src/
  App.jsx
  FinanceTracker.jsx       # main dashboard and interactions
  data.js                  # seeded accounts and transactions
  insightEngine.js         # deterministic insight logic
  styles.css               # app styling
integrations/
  neo4j/                   # schema, seed data, relationship derivation, insight queries
  rocketride/              # RocketRide pipeline, ingestion script, Python client example
```

## Optional Neo4j setup

The app runs without Neo4j. To use the included graph database layer, run the Cypher files in this order:

```bash
schema.cypher
seed-data.cypher
derive-relationships.cypher
insight-queries.cypher
```

See `integrations/neo4j/README.md` for details.

## Optional RocketRide/Butterbase setup

The included RocketRide assets show how an LLM agent can answer finance questions using Neo4j as a graph tool and Butterbase for user/profile/tier context.

Set these environment variables before using the Python examples:

```bash
ROCKETRIDE_URI=https://cloud.rocketride.ai
ROCKETRIDE_APIKEY=your_token
ANTHROPIC_API_KEY=your_key
NEO4J_URI=your_neo4j_uri
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_password
BUTTERBASE_API_KEY=your_key
```

Then review `integrations/rocketride/client_example.py` and `integrations/rocketride/ingestion.py`.
