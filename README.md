Resilient Multi-Tool Agent (Text-to-SQL + Policy RAG)
======================================================
<img width="2004" height="1251" alt="image" src="https://github.com/user-attachments/assets/cf929564-0d1d-44e1-b4e0-5b2a9982f817" />

What it does
------------
- Multi-layer router (preprocess → policy keyword → embedding hint placeholder → LLM tools) decides docs vs. SQL vs. hybrid vs. unknown.
- Hybrid SQL path injects business rules from `data/policies.md` (VIP > $88 in last 12 months, returns/refunds, restocking) even if the user omits them.
- Policy-only path selects relevant snippets from the policy doc and answers strictly from that context.
- SQLite pipeline generates SELECT-only SQL from the schema summary and retries with LLM correction on SQLite errors or empty result sets; non-SELECT is blocked.
- Safety guardrails: blocks explicit PII requests and blocks result sets that include PII columns (`email`, `phone`, `address`).
- Structured JSONL traces for each step are written to `logs/trace.jsonl`; the API returns the trace payload for the UI.


Setup Instructions
------------------
1) Install Python deps: `pip install -r requirements.txt` (use `python3/pip3` if needed).  
2) Configure your OpenAI API key (required for routing/SQL/doc answers): `export OPENAI_API_KEY=sk-...`  
3) Run the agent (CLI):  
   - One-off: `python main.py "List VIP customers"`  
   - Interactive: `python main.py` then type a query.  
   The agent will return a friendly message if the input is nonsense/unknown.


Project layout
--------------
- `app/agent.py` — orchestrates routing, SQL/doc/hybrid handling, and PII guardrails.
- `app/router/` — preprocess, policy keyword detection, embedding hint placeholder, LLM router, dynamic merger.
- `app/docs_loader.py` — loads the policy doc; LLM later narrows to relevant snippets.
- `app/llm.py` — OpenAI helper for routing classification, SQL generation/correction, and doc answering.
- `app/sql_executor.py` — SQLite executor with SELECT-only guard, schema summary cache, retries, and PII column blocking.
- `app/pii.py` — PII constants and masking helpers (blocking enforced in `SQLExecutor`).
- `app/logger.py` — structured JSON logging.
- `data/store.db` — sample SQLite database (customers + orders).
- `data/policies.md` — example business rules.
- `main.py` — CLI entry point.
- `server.py` — FastAPI HTTP API.
- `ui/` — React/Vite front-end that consumes the API.
- `requirements.txt` — dependencies (OpenAI SDK, FastAPI, Uvicorn).


Routing + execution
-------------------
- Router flow: preprocess/normalize → policy keyword hit (only toggles `requires_policy`) → embedding router placeholder → LLM tool-call classifier. Decisions are merged into docs/sql/hybrid/unknown.
- Policy/hybrid: full policy doc is loaded, then `select_policy_context` trims to relevant snippets; `answer_from_docs` answers strictly from the provided context.
- SQL generation: schema summary is passed to the LLM; business rules are injected on hybrid paths; SQL is forced to SELECT-only.
- Self-correction loop: SQLite errors or empty result sets trigger LLM-driven `correct_sql` retries (up to 3 attempts) with the schema included.
- PII guardrails: query-time PII keyword detection blocks requests; execution-time PII column detection blocks responses (no raw PII is returned).


HTTP API + React UI
-------------------
Backend (FastAPI):
```
uvicorn server:app --reload --port 8000
```
`POST /query` returns both the agent response and a step-by-step trace; `GET /health` is a basic liveness check.

Frontend (React/Vite):
```
cd ui
npm install   # first time only
npm run dev
```
The UI expects the API at `http://localhost:8000`. Override with `VITE_API_URL` if needed.


Logs
----
- JSONL traces are written to `logs/trace.jsonl`. Each line includes `step`, timestamps, and context. The FastAPI handler also returns the trace for downstream consumers.


Notes
-----
- The sample DB is small and intended for local testing; swap `data/store.db` with your dataset as needed.
- Only SELECT statements are executed; destructive SQL is blocked.
- LLM access requires `OPENAI_API_KEY` in the environment. If missing/unreachable, the agent returns a clear error message instead of routing.
