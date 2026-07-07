# Neo4j layer — finance tracker

Graph model + queries behind the three dashboard insights. Run the files in
this order against a fresh Aura (free tier is fine for the baseline queries)
or local Neo4j instance.

## Setup order

```bash
# 1. Open Neo4j Browser (or cypher-shell) connected to your instance
# 2. Run each file's contents in order:
schema.cypher              # constraints + indexes
seed-data.cypher           # users, accounts, merchants, categories, transactions
derive-relationships.cypher # FOLLOWS chains + SIMILAR_TO edges
insight-queries.cypher      # the three queries the dashboard calls
```

Using `cypher-shell` from the command line instead:

```bash
cat schema.cypher seed-data.cypher derive-relationships.cypher | \
  cypher-shell -a <your-aura-uri> -u neo4j -p <your-password>
```

## What each file does

| File | Role |
|---|---|
| `schema.cypher` | Uniqueness constraints on `User`, `Account`, `Transaction`, `Merchant`, `Category` + supporting indexes on date/amount |
| `seed-data.cypher` | Same sample transactions as the dashboard prototype, so both stay consistent |
| `derive-relationships.cypher` | Builds `FOLLOWS` chains (consecutive transactions per merchant) and `SIMILAR_TO` edges (shared category + charge-amount closeness). This is the step your RocketRide Cloud pipeline re-runs on every new transaction batch. |
| `insight-queries.cypher` | The three queries mapped to dashboard cards — recurring detection, anomaly detection, savings via cluster ranking |

## How each insight actually uses the graph

**Recurring cluster detected** — walks `FOLLOWS` edges per merchant and flags
ones where the interval between charges barely varies (low standard
deviation). This is a graph traversal, not a `GROUP BY` — it has to walk the
chain to compute the interval sequence.

**Anomaly flagged** — a transaction counts as anomalous only when *both* are
true: its merchant has zero `SIMILAR_TO` neighbors (nothing like it exists in
the graph), and its amount is a statistical outlier against the user's own
history. Neither signal alone is enough; the graph structure is what makes it
trustworthy instead of a blunt "large charge" rule.

**Savings opportunity** — ranks merchants inside a `SIMILAR_TO` cluster by
actual usage and surfaces the lowest-value ones. The baseline query assumes
same-category-implies-same-cluster, which works for this seed data. The
commented GDS Louvain query at the bottom of `insight-queries.cypher` is the
real version — once you have merchants that don't cluster neatly by category
label (e.g. two different genres of app that a user happens to use together),
Louvain finds the cluster from edge weights instead of you hardcoding it.

## Judging note

The GDS (Graph Data Science) library queries are commented out because they
require either a self-managed Neo4j instance with the GDS plugin installed,
or AuraDS — not the plain Aura free tier. The baseline queries work on free
tier and already satisfy the "traverse relationships, don't just use it as a
key-value store" requirement. Uncomment and use the GDS versions if your
instance supports them — it strengthens the submission.

## Next step

Wire `derive-relationships.cypher` into the RocketRide Cloud pipeline so it
runs automatically after each transaction ingestion batch, and have
`insight-queries.cypher` called from the pipeline's insight-generation step
(feeding results to the LLM call via Butterbase's AI gateway for the
natural-language summary).
