# MCP + SQL Server Demo Prompts

This guide is a live prompt script to demonstrate how MCP helps you quickly understand an unfamiliar SQL Server database.

Audience: developers, DBAs, analysts, and platform engineers onboarding to unknown systems.

## Demo Goal

Show that we can go from:

- no prior domain knowledge
- unknown schema
- unknown data quality

to:

- clear database map
- business-domain understanding
- prioritized follow-up actions

## Demo Setup Assumption

- SQL Server container is running
- `AdventureWorks2022` is restored
- MCP SQL tools are available
- A server profile exists for `localhost`

Use the verification flow in `README.md` first if needed.

## Presentation Structure (15 minutes)

1. Connect and establish context
2. Discover schema and relationships
3. Ask business-oriented questions
4. Validate data quality assumptions
5. Produce a concise onboarding summary

---

## Prompt Script

Use these prompts in order. Each one is designed to show a different MCP strength.

### 1) Zero-knowledge orientation

**Prompt**

"I just connected to an unknown SQL Server. Use MCP SQL tools to identify what server and database I’m connected to, list available databases, and recommend the best candidate for business analysis. Explain your reasoning briefly."

**What this demonstrates**

- Tool-driven environment discovery
- Fast initial triage without manual SQL typing

---

### 2) Database shape in one pass

**Prompt**

"Switch to the most relevant business database and build a high-level schema inventory: schemas, top tables by likely business importance, key views, and available functions. Return a structured summary with likely business domains."

**What this demonstrates**

- Rapid metadata exploration
- Automatic organization of raw DB objects into domain language

---

### 3) Relationship-first understanding

**Prompt**

"Use MCP to infer likely relationships between core entities (customers, orders, products, employees) from table names and keys. Show a practical mental model of how transactional flow probably works in this database."

**What this demonstrates**

- Turning schema details into system understanding
- Building a conceptual model quickly

---

### 4) Read-only business insight generation

**Prompt**

"Generate and run safe read-only queries to answer: top customers by spend, monthly sales trend, and product category performance. Summarize the findings in plain English for a non-DBA audience."

**What this demonstrates**

- Analytics from unknown systems with guardrails
- Translation of SQL results into business narratives

---

### 5) Data quality and trust checks

**Prompt**

"Run a lightweight data quality audit on key tables: null hotspots, duplicate risk on natural keys, obvious outliers, and date-range sanity checks. Return findings and confidence level."

**What this demonstrates**

- Early risk detection before deeper analysis
- Better confidence framing for stakeholders

---

### 6) Safety posture and least risk

**Prompt**

"Before executing any query, enforce a read-only safety policy for this session. Avoid destructive operations, and explain if any request would violate the policy."

**What this demonstrates**

- Operational safety controls in AI-assisted workflows
- Trustworthy behavior in production-like environments

---

### 7) Onboarding summary for a new engineer

**Prompt**

"Create a one-page onboarding brief for this database: major domains, critical tables/views, common joins, top 5 diagnostic queries, and first-week learning path for a new engineer."

**What this demonstrates**

- High-value documentation generation from live metadata
- Faster team onboarding

---

### 8) Incident-style investigation

**Prompt**

"Pretend revenue dropped 20% last month. Use MCP to propose a hypothesis-driven investigation plan, run the first 3 validating queries, and tell me the most likely causes to investigate next."

**What this demonstrates**

- Hypothesis-driven debugging in unfamiliar systems
- MCP as an incident acceleration layer

---

### 9) Performance triage starter

**Prompt**

"Identify potentially expensive query patterns in our analysis so far and propose index or query-shape improvements. Keep recommendations low-risk and explain expected impact."

**What this demonstrates**

- Practical optimization guidance from context
- Performance-aware analysis loop

---

### 10) Final executive recap

**Prompt**

"Summarize everything we learned about this previously unfamiliar database in 10 bullets: what it does, how data flows, where the risks are, and what we should do next this week."

**What this demonstrates**

- End-to-end value: discovery → understanding → action

## Optional Advanced Prompts

### Security posture

"Inspect for potentially sensitive data locations (PII-like columns by naming pattern) and provide a masking/governance checklist."

### Change impact analysis

"If we modify order pricing logic, which tables/views/functions are most likely impacted? Provide a cautious impact map."

### Reporting acceleration

"Create a starter set of reusable SQL snippets for common business reporting questions in this database."

## Demo Tips

- Keep queries read-only (`SELECT`) during the public demo.
- Ask for concise tables + short narrative summaries.
- After each prompt, ask: "What assumptions are you making?"
- If a result is surprising, ask for a verification query.
- End with a clear next-step action list.

## Success Criteria for the Demo

By the end, the audience should see that MCP:

1. Reduces time-to-understanding for unknown databases.
2. Makes schema exploration more conversational and structured.
3. Produces actionable insights without unsafe operations.
4. Improves onboarding, troubleshooting, and analysis workflows.
