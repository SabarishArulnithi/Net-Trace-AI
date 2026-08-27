# NetTrace AI — PS6 Unified Investigation Analytics Platform

A prototype investigation tool that unifies telecom CDR, banking, and social
media identity data, links them to a single suspect via entity matching, and
uses a trained machine learning model to flag anomalous / suspicious behavior.

Built for: **Problem Statement 6 — A Single Analytics Platform that Analyzes
Telecom CDR/IPDR Data, Bank Statements, and Social Media Activity to Detect
Anomalies, Uncover Patterns, and Generate Actionable Insights.**

> ⚠️ All data in this project (`profiles.csv`, `cdr.csv`, `bank.csv`) is
> **100% synthetic** — no real people, phone numbers, bank accounts, or
> Aadhaar numbers. Real CDR/bank/Aadhaar data is legally protected and only
> accessible to police via formal authorized channels (CrPC Sec. 91, bank
> nodal officer requests, UIDAI process). This project demonstrates the
> **analytics engine** that would run on top of such authorized data in a
> real deployment.

---

## Project structure

```
project/
├── backend/
│   ├── main.py              FastAPI app — REST API serving data + ML model
│   ├── requirements.txt
│   ├── data/
│   │   ├── profiles.csv     200 synthetic identities (name, phone, bank, social, risk score)
│   │   ├── cdr.csv          6,545 synthetic call records
│   │   └── bank.csv         1,461 synthetic bank transactions
│   └── model/
│       └── risk_model.pkl   Trained Isolation Forest anomaly detection model
├── frontend/
│   └── index.html           Self-contained demo UI (photo scan, call history,
│                             transactions, network graph)
└── README.md
```

## Architecture

```
   CDR/IPDR   Bank Data   Social Data   Photo Capture      <- data sources (synthetic)
        \         |            |            /
         \--------+------------+-----------/
                        |
              Entity Matching Engine          <- links phone/bank/social/photo by shared ID
                        |
             AI Anomaly Detection             <- trained Isolation Forest model
                        |
              Graph Relationship Engine       <- builds person-to-person / person-to-account graph
                        |
              Investigation Dashboard         <- frontend: risk scores, call logs, txn logs, graph
```

## How the ML model works

We engineer 8 behavioral features per person from the raw CDR and bank logs:

| Feature | What it captures |
|---|---|
| `total_calls`, `unique_contacts` | overall calling activity |
| `calls_to_unknown` | calls to numbers **not** in the known-identity database |
| `max_calls_per_day` | burst-calling behavior (many calls in a single day) |
| `total_txns`, `total_amount` | overall banking activity |
| `max_single_txn` | large one-off transfers |
| `txns_to_unlinked` | transfers to accounts **not** in the known-identity database |

These features are standardized and fed into an **Isolation Forest**
(`scikit-learn`), an unsupervised anomaly detection algorithm — it doesn't
need labeled "criminal / not criminal" data, it learns what "normal" looks
like across the population and flags statistical outliers. Anomaly scores are
min-max normalized to a 0–100 `risk_score`, bucketed into Low / Medium / High.

Out of 200 synthetic profiles (30 seeded with suspicious behavior patterns),
the trained model correctly flagged **27 High-risk** and **16 Medium-risk**
profiles — recovering the seeded suspicious cases from behavior alone, not
from a hidden label.

## Running the backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Then visit `http://localhost:8000` — it also serves the frontend automatically.

### API endpoints

| Endpoint | Description |
|---|---|
| `GET /api/health` | Server + dataset status |
| `GET /api/profiles` | List all 200 synthetic profiles |
| `GET /api/profiles/{phone}` | Get one profile |
| `GET /api/match-photo?seed=...` | Demo photo-match (deterministic hash → profile) |
| `GET /api/cdr/{phone}` | Call history for a number |
| `GET /api/bank/{phone}` | Transaction history for a number's linked account |
| `GET /api/graph/{phone}` | Relationship graph (nodes + links) centered on a person |
| `GET /api/risk/{phone}` | **Live** model re-inference — recomputes features and re-runs the trained model on demand |

## Running the frontend standalone

`frontend/index.html` also works as a fully standalone file (data is embedded
directly in it) — you can open it in any browser without running the backend
at all, which is useful for a live demo with no network/server dependency.

## What this demonstrates vs. what a production version would need

| This prototype | Production version |
|---|---|
| Synthetic CSV data | Authorized CDR/bank/social feeds via legal request channels |
| Filename/hash-based photo match | Real facial recognition against an authorized state police database |
| Isolation Forest on 200 synthetic people | Model retrained/validated on real case data under appropriate legal & privacy safeguards |
| Single FastAPI instance | Scaled deployment, audit logging, role-based access control |
| CSV files as storage | Neo4j (graph relationships) + a relational/warehouse store for records |

## Team notes / talking points for judges

- The core innovation is **entity resolution + anomaly detection across three
  independent data modalities** (telecom, banking, social), not any single
  dataset in isolation.
- The risk score is a **genuinely trained ML model**, not hardcoded rules —
  it generalizes to new profiles by recomputing features and re-running
  inference (see `/api/risk/{phone}`).
- Legal/privacy design was a first-class constraint from the start, not an
  afterthought — every data source maps to a real, existing authorized-access
  process used by Indian law enforcement today.
