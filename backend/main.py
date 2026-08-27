"""
NetTrace AI - Backend API
Serves synthetic profile, CDR, and bank data, plus predictions from the
trained Isolation Forest risk model, for PS6 (Unified Investigation Platform).

Run with:  uvicorn main:app --reload --port 8000
"""

import csv
import hashlib
from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
MODEL_DIR = BASE_DIR / "model"

app = FastAPI(title="NetTrace AI Backend", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------- Load data + model once at startup ----------------

with open(DATA_DIR / "profiles.csv") as f:
    PROFILES = list(csv.DictReader(f))

CDR_DF = pd.read_csv(DATA_DIR / "cdr.csv", dtype=str)
CDR_DF["duration_sec"] = pd.to_numeric(CDR_DF["duration_sec"])

BANK_DF = pd.read_csv(DATA_DIR / "bank.csv", dtype=str)
BANK_DF["amount_inr"] = pd.to_numeric(BANK_DF["amount_inr"])

PROFILE_BY_PHONE = {p["phone"]: p for p in PROFILES}
PROFILE_BY_BANK = {p["bank_acc"]: p for p in PROFILES}
KNOWN_PHONES = set(PROFILE_BY_PHONE.keys())
KNOWN_BANKS = set(PROFILE_BY_BANK.keys())

bundle = joblib.load(MODEL_DIR / "risk_model.pkl")
RISK_MODEL = bundle["model"]
SCALER = bundle["scaler"]
FEATURE_COLS = bundle["feature_cols"]
ANOMALY_MIN = bundle["anomaly_min"]
ANOMALY_MAX = bundle["anomaly_max"]


# ---------------- Helpers ----------------

def compute_features(phone: str, bank_acc: str) -> dict:
    """Recompute the same behavioral features used at training time, live, for any phone/account."""
    my_calls = CDR_DF[CDR_DF.caller_phone == phone]
    my_txns = BANK_DF[BANK_DF.from_account == bank_acc]

    total_calls = len(my_calls)
    unique_contacts = my_calls.receiver_phone.nunique() if total_calls else 0
    calls_to_unknown = (~my_calls.receiver_phone.isin(KNOWN_PHONES)).sum() if total_calls else 0
    if total_calls:
        tmp = my_calls.copy()
        tmp["date"] = pd.to_datetime(tmp.timestamp).dt.date
        max_calls_per_day = int(tmp.groupby("date").size().max())
    else:
        max_calls_per_day = 0

    total_txns = len(my_txns)
    total_amount = float(my_txns.amount_inr.sum()) if total_txns else 0.0
    max_single_txn = float(my_txns.amount_inr.max()) if total_txns else 0.0
    txns_to_unlinked = (~my_txns.to_account.isin(KNOWN_BANKS)).sum() if total_txns else 0

    return {
        "total_calls": total_calls, "unique_contacts": unique_contacts,
        "calls_to_unknown": int(calls_to_unknown), "max_calls_per_day": max_calls_per_day,
        "total_txns": total_txns, "total_amount": total_amount,
        "max_single_txn": max_single_txn, "txns_to_unlinked": int(txns_to_unlinked),
    }


def predict_risk(features: dict) -> dict:
    """Run the trained Isolation Forest on a feature vector and return a 0-100 risk score.
    Uses the same min/max normalization bounds computed at training time, so scores here
    are directly comparable to the pre-computed risk_score in profiles.csv."""
    X = pd.DataFrame([features])[FEATURE_COLS].fillna(0)
    X_scaled = SCALER.transform(X)
    raw = RISK_MODEL.decision_function(X_scaled)[0]
    anomaly = -raw
    span = (ANOMALY_MAX - ANOMALY_MIN) or 1e-9
    score = max(0, min(100, (anomaly - ANOMALY_MIN) / span * 100))
    flag = "High" if score >= 65 else "Medium" if score >= 35 else "Low"
    return {"risk_score": round(score, 1), "risk_flag": flag}


# ---------------- API routes ----------------

@app.get("/api/health")
def health():
    return {"status": "ok", "profiles": len(PROFILES), "cdr_rows": len(CDR_DF), "bank_rows": len(BANK_DF)}


@app.get("/api/profiles")
def list_profiles():
    return PROFILES


@app.get("/api/profiles/{phone}")
def get_profile(phone: str):
    p = PROFILE_BY_PHONE.get(phone)
    if not p:
        raise HTTPException(404, "Profile not found in demo dataset")
    return p


@app.get("/api/match-photo")
def match_photo(seed: str):
    """
    Demo-mode face match: takes a client-provided seed (e.g. a hash of the
    captured image) and deterministically maps it to one of the synthetic
    profiles, simulating a biometric match against an authorized database.
    """
    idx = int(hashlib.md5(seed.encode()).hexdigest(), 16) % len(PROFILES)
    return PROFILES[idx]


@app.get("/api/cdr/{phone}")
def get_cdr(phone: str):
    if phone not in KNOWN_PHONES:
        raise HTTPException(404, "No CDR records for this number in the demo dataset")
    rows = CDR_DF[CDR_DF.caller_phone == phone].sort_values("timestamp", ascending=False)
    return rows.to_dict(orient="records")


@app.get("/api/bank/{phone}")
def get_bank(phone: str):
    p = PROFILE_BY_PHONE.get(phone)
    if not p:
        raise HTTPException(404, "No linked bank account for this number in the demo dataset")
    rows = BANK_DF[BANK_DF.from_account == p["bank_acc"]].sort_values("timestamp", ascending=False)
    return rows.to_dict(orient="records")


@app.get("/api/graph/{phone}")
def get_graph(phone: str):
    p = PROFILE_BY_PHONE.get(phone)
    if not p:
        raise HTTPException(404, "Profile not found in demo dataset")

    nodes = {phone: {"id": phone, "label": p["name"], "type": "person", "risk": p["risk_flag"]}}
    links = []

    calls = CDR_DF[CDR_DF.caller_phone == phone]
    for _, c in calls.iterrows():
        rp = c.receiver_phone
        known = PROFILE_BY_PHONE.get(rp)
        nodes.setdefault(rp, {
            "id": rp, "label": known["name"] if known else rp,
            "type": "person" if known else "unknown",
            "risk": known["risk_flag"] if known else "Low",
        })
        links.append({"source": phone, "target": rp, "type": "call", "flagged": bool(c.flag)})

    txns = BANK_DF[BANK_DF.from_account == p["bank_acc"]]
    for _, t in txns.iterrows():
        acc_id = "acct:" + t.to_account
        known = PROFILE_BY_BANK.get(t.to_account)
        nodes.setdefault(acc_id, {
            "id": acc_id, "label": known["name"] if known else t.to_account,
            "type": "person" if known else "unknown",
            "risk": known["risk_flag"] if known else "Low",
        })
        links.append({"source": phone, "target": acc_id, "type": "txn", "flagged": bool(t.flag)})

    return {"nodes": list(nodes.values()), "links": links}


@app.get("/api/risk/{phone}")
def get_live_risk(phone: str):
    """Recompute features and re-run the trained model live (demonstrates the model isn't just static lookup)."""
    p = PROFILE_BY_PHONE.get(phone)
    if not p:
        raise HTTPException(404, "Profile not found in demo dataset")
    features = compute_features(phone, p["bank_acc"])
    prediction = predict_risk(features)
    return {"phone": phone, "name": p["name"], "features": features, **prediction}


# Serve the frontend as static files (place index.html in ../frontend)
FRONTEND_DIR = BASE_DIR.parent / "frontend"
if FRONTEND_DIR.exists():
    app.mount("/", StaticFiles(directory=str(FRONTEND_DIR), html=True), name="frontend")
