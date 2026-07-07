import { useMemo, useState } from "react";
import { AlertTriangle, BrainCircuit, CreditCard, Download, PiggyBank, Plus, RotateCcw, Upload, Wallet } from "lucide-react";
import { seedAccounts, seedTransactions } from "./data.js";
import { buildGraph, buildInsights, money, parseCsv } from "./insightEngine.js";

const accountIcon = { checking: Wallet, credit: CreditCard, savings: PiggyBank };

export default function FinanceTracker() {
  const [accounts] = useState(() => JSON.parse(localStorage.getItem("aft_accounts") || "null") || seedAccounts);
  const [transactions, setTransactions] = useState(() => JSON.parse(localStorage.getItem("aft_transactions") || "null") || seedTransactions);
  const [form, setForm] = useState({ date: "2026-07-07", merchant: "", category: "Shopping", amount: "", accountId: "acct_credit" });
  const insights = useMemo(() => buildInsights(transactions), [transactions]);
  const [selectedId, setSelectedId] = useState("recurring");
  const selected = insights.find((i) => i.id === selectedId) || insights[0];
  const graph = useMemo(() => buildGraph(transactions), [transactions]);
  const netWorth = accounts.reduce((s, a) => s + a.balance, 0);
  const monthlySpend = transactions.reduce((s, t) => s + t.amount, 0);

  function persist(next) {
    setTransactions(next);
    localStorage.setItem("aft_transactions", JSON.stringify(next));
  }

  function addTransaction(event) {
    event.preventDefault();
    if (!form.merchant || !form.amount) return;
    persist([{ ...form, id: `tx_${Date.now()}`, amount: Number(form.amount) }, ...transactions]);
    setForm({ ...form, merchant: "", amount: "" });
  }

  function resetDemo() {
    localStorage.removeItem("aft_transactions");
    localStorage.removeItem("aft_accounts");
    setTransactions(seedTransactions);
  }

  async function importCsv(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    const rows = parseCsv(await file.text());
    persist([...rows, ...transactions]);
    event.target.value = "";
  }

  function exportCsv() {
    const header = "id,date,merchant,category,amount,accountId";
    const rows = transactions.map((t) => [t.id, t.date, t.merchant, t.category, t.amount, t.accountId].map((v) => `"${String(v).replaceAll('"', '""')}"`).join(","));
    const blob = new Blob([[header, ...rows].join("\n")], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "transactions.csv";
    link.click();
    URL.revokeObjectURL(url);
  }

  const highlighted = new Set(["hub", ...(selected?.merchants || [])]);

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand"><BrainCircuit size={22} /> AI Financial Tracker</div>
        <p className="muted">Graph-powered personal finance dashboard with AI-style insights, anomaly detection, CSV import, and local persistence.</p>
        <h3>Accounts</h3>
        {accounts.map((account) => {
          const Icon = accountIcon[account.type] || Wallet;
          return <div className="account" key={account.id}><Icon size={18} /><span>{account.name}</span><strong>{money(account.balance)}</strong></div>;
        })}
        <h3>Integrations included</h3>
        <div className="stack">Neo4j Cypher graph model</div>
        <div className="stack">RocketRide insight pipeline</div>
        <div className="stack">Butterbase-ready agent config</div>
      </aside>

      <section className="content">
        <header className="hero">
          <div>
            <p className="eyebrow">Functional demo · local-first</p>
            <h1>{money(netWorth)}</h1>
            <p className="muted">Current tracked spend: {money(monthlySpend)} across {transactions.length} transactions.</p>
          </div>
          <div className="actions">
            <label className="button"><Upload size={16} /> Import CSV<input type="file" accept=".csv" hidden onChange={importCsv} /></label>
            <button onClick={exportCsv}><Download size={16} /> Export CSV</button>
            <button onClick={resetDemo}><RotateCcw size={16} /> Reset</button>
          </div>
        </header>

        <section className="cards">
          {insights.map((insight) => <button key={insight.id} onClick={() => setSelectedId(insight.id)} className={`insight ${insight.tone} ${selectedId === insight.id ? "active" : ""}`}><span>{insight.title}</span><strong>{insight.stat}</strong><p>{insight.body}</p></button>)}
        </section>

        <section className="grid">
          <div className="panel graph-panel">
            <div className="panel-title">Transaction graph</div>
            <svg viewBox="0 0 820 520" role="img" aria-label="Transaction graph">
              {graph.edges.map((edge, index) => {
                const a = graph.nodes.find((n) => n.id === edge.from);
                const b = graph.nodes.find((n) => n.id === edge.to);
                const active = highlighted.has(edge.from) && highlighted.has(edge.to);
                return <line key={`${edge.from}-${edge.to}-${index}`} x1={a.x} y1={a.y} x2={b.x} y2={b.y} className={`${edge.kind} ${active ? "active" : ""}`} />;
              })}
              {graph.nodes.map((node) => <g key={node.id} className={highlighted.has(node.id) ? "node active" : "node"}><circle cx={node.x} cy={node.y} r={node.r} /><text x={node.x} y={node.y + node.r + 15}>{node.label.length > 18 ? node.label.slice(0, 17) + "…" : node.label}</text></g>)}
            </svg>
          </div>

          <div className="panel">
            <div className="panel-title">Add transaction</div>
            <form onSubmit={addTransaction} className="tx-form">
              <input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
              <input placeholder="Merchant" value={form.merchant} onChange={(e) => setForm({ ...form, merchant: e.target.value })} />
              <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>{["Streaming", "Groceries", "Gas", "Coffee", "Shopping", "Travel", "Uncategorized"].map((c) => <option key={c}>{c}</option>)}</select>
              <input type="number" step="0.01" placeholder="Amount" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} />
              <select value={form.accountId} onChange={(e) => setForm({ ...form, accountId: e.target.value })}>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
              <button type="submit"><Plus size={16} /> Add</button>
            </form>
            <div className="agent-note"><AlertTriangle size={16} /> The “AI” logic in this demo is deterministic and explainable. Optional RocketRide/LLM integration is included under integrations/rocketride.</div>
          </div>
        </section>

        <section className="panel ledger">
          <div className="panel-title">Recent transactions</div>
          <table><tbody>{transactions.slice().sort((a,b) => new Date(b.date) - new Date(a.date)).slice(0, 12).map((tx) => <tr key={tx.id}><td>{tx.date}</td><td>{tx.merchant}</td><td><span>{tx.category}</span></td><td>{accounts.find((a) => a.id === tx.accountId)?.name || tx.accountId}</td><td>{money(tx.amount)}</td></tr>)}</tbody></table>
        </section>
      </section>
    </main>
  );
}
