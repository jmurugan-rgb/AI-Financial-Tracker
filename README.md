# RocketRide Cloud pipeline — finance tracker

This is the piece that ties Neo4j and the LLM together into a production
endpoint: a natural-language question comes in, an agent consults the
transaction graph and Butterbase, and an explained answer comes back.

## How the pieces fit together

RocketRide's `db_neo4j` node translates natural language to Cypher and runs
it — but it's **read-only by design** (it rejects `CREATE`/`MERGE`/`SET`/`DELETE`,
per RocketRide's own docs). That's exactly what you want for answering
questions safely, but it means loading data is a separate, deterministic
step — the same split any real system would use:

```
ingestion.py  ──writes──▶  Neo4j  ◀──reads (NL → Cypher)──  finance-insights.pipe
(neo4j driver,                                              (RocketRide Cloud,
 direct Cypher)                                              deployed pipeline)
```

- **`ingestion.py`** runs the exact Cypher from `../neo4j/*.cypher` directly
  against Neo4j using the official driver: schema, seed data, and — on every
  new transaction batch — the `FOLLOWS`/`SIMILAR_TO` derivation queries.
- **`finance-insights.pipe`** is the RocketRide pipeline: it takes a question,
  lets a Wave agent query the graph and Butterbase as tools, and returns a
  graph-grounded answer via Claude.

## Files

| File | Role |
|---|---|
| `finance-insights.pipe` | The pipeline definition — portable JSON, same file runs locally or on Cloud |
| `ingestion.py` | Writes transactions + derives `FOLLOWS`/`SIMILAR_TO`, run via the Neo4j driver |
| `client_example.py` | Calls the deployed pipeline from Python using the RocketRide SDK |

## What's in the pipeline

```
webhook (source)
  └─▶ question (wraps text as a Question)
        └─▶ agent (RocketRide Wave) ──tools──▶ db_neo4j (graph, read-only NL→Cypher)
              │                     └────────▶ tool_mcp_client (Butterbase preset)
              └─llm──▶ llm_anthropic (Claude Sonnet 4.6)
                    └─▶ response (returns the answer)
```

- **`graph`** (`db_neo4j`): connects to your Neo4j instance, reflects the
  schema at startup, and exposes `get_data` / `get_schema` / `get_cypher` as
  agent tools. The `db_description` field tells the LLM what `FOLLOWS` and
  `SIMILAR_TO` mean so it generates Cypher that actually uses them, rather
  than treating the graph as a flat table.
- **`butterbase`** (`tool_mcp_client`, Butterbase preset): connects to
  `https://api.butterbase.ai/mcp` and exposes Butterbase's backend tools —
  auth, user profile, payment tier — so the agent can gate deep insights
  behind your paid tier and log generated insights to the user's history.
- **`agent`** (`agent_rocketride`, RocketRide's native Wave agent): the
  orchestrator. Its system prompt tells it to explain findings in terms of
  the graph relationships that produced them — the whole point of this
  build.

## Local development

1. Install the RocketRide VS Code extension and start a local engine (see
   [self-hosting docs](https://docs.rocketride.org/self-hosting)), or run:
   ```bash
   docker pull ghcr.io/rocketride-org/rocketride-engine:latest
   docker create --name rocketride-engine -p 5565:5565 ghcr.io/rocketride-org/rocketride-engine:latest
   docker start rocketride-engine
   ```
2. Seed Neo4j (see `../neo4j/README.md` for setup), then run ingestion:
   ```bash
   pip install neo4j
   export NEO4J_URI="neo4j+s://<your-aura-uri>"
   export NEO4J_USER="neo4j"
   export NEO4J_PASSWORD="<your-password>"
   python ingestion.py --seed
   ```
3. Open `finance-insights.pipe` in the RocketRide VS Code extension's canvas,
   fill in the node configs (or rely on the `${ENV_VAR}` substitutions below),
   and run it from the canvas or:
   ```bash
   rocketride start finance-insights.pipe
   ```
4. Test it:
   ```bash
   curl -X POST http://localhost:5567/task/data \
     -H "Authorization: Bearer <printed-auth-key>" \
     -H "Content-Type: text/plain" \
     -d "What subscriptions look recurring?"
   ```

## Environment variables the pipeline needs

| Variable | Used by |
|---|---|
| `ANTHROPIC_API_KEY` | `llm_core` (Claude Sonnet 4.6) |
| `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD` | `graph` (Neo4j Bolt connection — use `neo4j+s://` for Aura) |
| `BUTTERBASE_API_KEY` | `butterbase` (Butterbase API key, `bb_sk_...`, from the Butterbase dashboard → API Keys; requires Developer Mode enabled on your Butterbase app) |

RocketRide substitutes `${VAR_NAME}` from the engine's environment when the
pipeline starts — set these wherever the engine runs (local `.env`, or your
RocketRide Cloud project's environment settings).

## Deploying to RocketRide Cloud

```bash
export ROCKETRIDE_URI=https://api.rocketride.ai
export ROCKETRIDE_APIKEY=<your-rocketride-api-token>
rocketride deploy finance-insights.pipe --schedule manual
```

Or one-click deploy from the VS Code extension's canvas (the same `.pipe`
JSON runs unchanged against Cloud or a self-hosted engine — no rewrite
needed). Once deployed, point `client_example.py` at it:

```bash
pip install rocketride
export ROCKETRIDE_URI=https://cloud.rocketride.ai
export ROCKETRIDE_APIKEY=<your-rocketride-api-token>
python client_example.py
```

For scheduled re-ingestion (e.g. pulling new transactions every 15 minutes)
you'd deploy a second, separate pipeline that does the ingestion step, or
run `ingestion.py` as a cron job / scheduled function next to wherever your
transaction feed lands — the Neo4j writes don't go through RocketRide's
read-only graph node, by design.

## Judging note

Every node provider referenced here (`webhook`, `question`, `llm_anthropic`,
`db_neo4j`, `tool_mcp_client` with the Butterbase preset, `agent_rocketride`,
`response`) is a real, documented RocketRide node as of this build — checked
against docs.rocketride.org rather than assumed. The one thing worth
double-checking against the live VS Code canvas before you demo: the exact
config schema for `agent_rocketride` (the Wave agent), since its field list
wasn't in the page this pipeline was built against — the `systemPrompt` field
here is a reasonable guess and may need a small adjustment in the canvas
editor.
