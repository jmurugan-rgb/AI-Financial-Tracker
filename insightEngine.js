const dayMs = 24 * 60 * 60 * 1000;

export function money(value) {
  const formatted = Math.abs(value).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return value < 0 ? `-$${formatted}` : `$${formatted}`;
}

export function parseCsv(text) {
  const lines = text.trim().split(/\r?\n/).filter(Boolean);
  if (!lines.length) return [];
  const headers = splitCsvLine(lines[0]).map((h) => h.trim().toLowerCase());
  return lines.slice(1).map((line, index) => {
    const values = splitCsvLine(line);
    const row = Object.fromEntries(headers.map((h, i) => [h, values[i]?.trim() ?? ""]));
    return {
      id: row.id || `csv_${Date.now()}_${index}`,
      date: row.date,
      merchant: row.merchant || row.description || "Unknown merchant",
      category: row.category || "Uncategorized",
      amount: Number(row.amount || 0),
      accountId: row.accountid || row.account_id || row.account || "acct_credit",
    };
  }).filter((tx) => tx.date && Number.isFinite(tx.amount));
}

function splitCsvLine(line) {
  const out = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') quoted = !quoted;
    else if (ch === "," && !quoted) { out.push(cur); cur = ""; }
    else cur += ch;
  }
  out.push(cur);
  return out;
}

function merchantStats(transactions) {
  const map = new Map();
  for (const tx of transactions) {
    if (!map.has(tx.merchant)) map.set(tx.merchant, []);
    map.get(tx.merchant).push(tx);
  }
  return [...map.entries()].map(([merchant, rows]) => {
    const sorted = rows.slice().sort((a, b) => new Date(a.date) - new Date(b.date));
    const intervals = sorted.slice(1).map((tx, i) => Math.round((new Date(tx.date) - new Date(sorted[i].date)) / dayMs));
    const avgAmount = rows.reduce((s, tx) => s + tx.amount, 0) / rows.length;
    const avgInterval = intervals.length ? intervals.reduce((a, b) => a + b, 0) / intervals.length : 0;
    const stdInterval = intervals.length ? Math.sqrt(intervals.reduce((s, x) => s + (x - avgInterval) ** 2, 0) / intervals.length) : 0;
    return { merchant, rows, category: rows[0].category, avgAmount, avgInterval, stdInterval, count: rows.length };
  });
}

export function buildInsights(transactions) {
  const stats = merchantStats(transactions);
  const recurring = stats.filter((s) => s.count >= 3 && s.avgInterval >= 25 && s.avgInterval <= 35 && s.stdInterval <= 4);
  const recurringTotal = recurring.reduce((sum, s) => sum + s.avgAmount, 0);

  const amounts = transactions.map((t) => t.amount);
  const mean = amounts.reduce((a, b) => a + b, 0) / Math.max(amounts.length, 1);
  const std = Math.sqrt(amounts.reduce((s, x) => s + (x - mean) ** 2, 0) / Math.max(amounts.length, 1)) || 1;
  const anomaly = transactions
    .map((tx) => ({ ...tx, z: (tx.amount - mean) / std }))
    .filter((tx) => tx.z > 2 || (tx.amount > mean * 4 && tx.amount > 250))
    .sort((a, b) => b.amount - a.amount)[0];

  const byCategory = transactions.reduce((acc, tx) => {
    acc[tx.category] = (acc[tx.category] || 0) + tx.amount;
    return acc;
  }, {});
  const topCategory = Object.entries(byCategory).sort((a, b) => b[1] - a[1])[0] || ["None", 0];
  const cancelCandidates = recurring.slice().sort((a, b) => a.avgAmount - b.avgAmount).slice(0, 2);
  const savings = cancelCandidates.reduce((sum, s) => sum + s.avgAmount, 0);

  return [
    {
      id: "recurring",
      tone: "teal",
      title: "Recurring subscriptions detected",
      stat: money(recurringTotal) + "/mo",
      body: recurring.length
        ? `${recurring.map((r) => r.merchant).join(", ")} bill on a near-monthly cadence. The tracker found this by comparing consecutive charge dates per merchant.`
        : "No strong monthly recurrence pattern was found yet. Add more history for better detection.",
      merchants: recurring.map((r) => r.merchant),
    },
    {
      id: "anomaly",
      tone: "coral",
      title: anomaly ? "Anomaly flagged" : "No anomaly flagged",
      stat: anomaly ? money(anomaly.amount) : "Clear",
      body: anomaly
        ? `${anomaly.merchant} is unusually large compared with your normal transaction pattern. Its z-score is ${anomaly.z.toFixed(2)}.`
        : "No transaction currently crosses the anomaly threshold.",
      merchants: anomaly ? [anomaly.merchant] : [],
    },
    {
      id: "savings",
      tone: "gold",
      title: "Savings opportunity",
      stat: money(savings) + "/mo",
      body: savings
        ? `The easiest cut is reviewing ${cancelCandidates.map((c) => c.merchant).join(" and ")}. Your highest spend category is ${topCategory[0]} at ${money(topCategory[1])}.`
        : `Your highest spend category is ${topCategory[0]} at ${money(topCategory[1])}. More recurring transactions will improve savings suggestions.`,
      merchants: cancelCandidates.map((c) => c.merchant),
    },
  ];
}

export function buildGraph(transactions) {
  const merchants = [...new Map(transactions.map((tx) => [tx.merchant, tx])).values()];
  const center = { id: "hub", label: "All accounts", x: 90, y: 250, r: 28, category: "hub" };
  const nodes = [center];
  merchants.forEach((m, i) => {
    const angle = (Math.PI * 2 * i) / merchants.length;
    const radius = 170 + (i % 3) * 36;
    nodes.push({
      id: m.merchant,
      label: m.merchant,
      x: Math.round(410 + Math.cos(angle) * radius),
      y: Math.round(250 + Math.sin(angle) * radius),
      r: m.amount > 500 ? 22 : 16,
      category: m.category,
    });
  });
  const edges = merchants.map((m) => ({ from: "hub", to: m.merchant, kind: "transaction" }));
  for (let i = 0; i < merchants.length; i += 1) {
    for (let j = i + 1; j < merchants.length; j += 1) {
      if (merchants[i].category === merchants[j].category && merchants[i].category !== "Uncategorized") {
        edges.push({ from: merchants[i].merchant, to: merchants[j].merchant, kind: "similar" });
      }
    }
  }
  return { nodes, edges };
}
