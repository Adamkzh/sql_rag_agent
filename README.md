Resilient Multi-Tool Agent (Text-to-SQL + Policy RAG)
======================================================
<img width="2004" height="1251" alt="image" src="https://github.com/user-attachments/assets/cf929564-0d1d-44e1-b4e0-5b2a9982f817" />

What it does
------------
- Routes queries between SQL, docs, and hybrid modes using a multi-layer router (pre, policy keyword, embedding hook, LLM).
- Injects business rules from `data/policies.md` (e.g., VIP > $1,000 in last 12 months) into SQL generation so constraints are enforced even if the user forgets them.
- Generates SQLite-safe, SELECT-only SQL with a retry-and-correct loop.
- Masks PII (email, phone, address) in result rows; blocks explicit PII requests.
- Emits JSONL trace logs for each step to `logs/trace.jsonl`.


Setup Instructions
------------------
1) Install Python deps: `pip install -r requirements.txt` (use `python3/pip3` if needed).  
2) Configure your OpenAI API key (required): `export OPENAI_API_KEY=sk-...`  
3) Run the agent:  
   - One-off: `python main.py "List VIP customers"`  
   - Interactive: `python main.py` then type a query.  


Project layout
--------------
- `app/agent.py` — orchestrates routing, SQL/doc handling, PII guardrail.
- `app/router/` — multi-layer routing (pre, policy keyword, embedding hook, LLM, dynamic).
- `app/docs_loader.py` — loads and searches policy docs.
- `app/sql_executor.py` — SQLite executor with retry + LLM correction.
- `app/pii.py` — PII detection and masking helpers.
- `app/llm.py` — OpenAI wrapper for routing, SQL, and policy responses.
- `app/logger.py` — structured JSON logging.
- `data/store.db` — sample SQLite database (customers + orders).
- `data/policies.md` — example business rules.
- `main.py` — CLI entry point.
- `requirements.txt` — dependencies (OpenAI SDK).


Architecture (Self-Correction + PII)
------------------------------------
High-level routing: `pre-router → policy/embedding hints → LLM router → (docs | sql | hybrid pipelines)`.

- **Self-Correction Loop (SQL2)**  
  - `agent._generate_sql` asks the LLM for SELECT-only SQL (policy constraints injected when hybrid).  
  - `sql_executor.execute_with_retry` runs the query with guardrails (`_is_safe` blocks non-SELECT).  
  - On SQLite errors or empty result sets, `llm.correct_sql` gets the failing SQL, schema summary, and error context to produce a revised query; retries up to `max_attempts`.  
  - Logging stages: `stage_sql1_generation`, `stage_sql2_self_correction_loop`, `stage_sql3_sqlite_execution`.

- **PII Filter (SQL4 + request guard)**  
  - Request-time: `agent.handle` blocks queries asking for `email/phone/address/pii` and returns a safe message.  
  - Response-time: `sql_executor._mask_rows` detects columns in `PII_FIELDS` and masks via `mask_record`; logs `stage_sql4_pii_guardrail` with whether masking applied.  
  - Only SELECT statements are ever executed (`stage_sql_guardrail_check`).


HTTP API + React UI
-------------------
Backend (FastAPI):
```
uvicorn server:app --reload --port 8000
```

Frontend (React/Vite):
```
cd ui
npm install   # first time only
npm run dev
```
The UI expects the API at `http://localhost:8000`. Override with `VITE_API_URL` if needed.


Logs
----
- JSONL traces are written to `logs/trace.jsonl`. Each line includes `step`, timestamps, and context.


Notes
-----
- The sample DB is small and intended for local testing; swap `data/store.db` with your dataset as needed.
- Only SELECT statements are executed; destructive SQL is blocked.
