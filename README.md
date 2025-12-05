Resilient Multi-Tool Agent (Text-to-SQL + Policy RAG)
======================================================
<img width="2004" height="1251" alt="image" src="https://github.com/user-attachments/assets/cf929564-0d1d-44e1-b4e0-5b2a9982f817" />

What it does
------------
- Routes queries between SQL, docs, and hybrid modes using LLM + a deterministic keyword check for policy terms.
- Injects business rules from `data/policies.md` (e.g., VIP > $1,000 in last 12 months) into SQL generation so constraints are enforced even if the user forgets them.
- Generates SQLite-safe, SELECT-only SQL with a retry-and-correct loop.
- Masks PII (email, phone, address) in result rows; blocks explicit PII requests.
- Emits JSONL trace logs for each step to `logs/trace.jsonl`.


Routing pipeline
----------------
1. Pre-router normalizes the query.
2. Policy router flags obvious policy terms (deterministic fast-path).
3. Embedding router hook (currently placeholder) can hint docs/sql once embeddings are wired in.
4. LLM-based boolean router decides `requires_sql` / `requires_policy`.
5. Final routing decision fan-outs into three deterministic pipelines:
   - **Case 1 — SQL only**: `[SQL1]` SQL generation → `[SQL2]` retry/correct loop → `[SQL3]` SQLite execution → `[SQL4]` PII guardrail filter → final result.
   - **Case 2 — Docs only**: `[DOC1]` retrieve policy context → policy-only answer.
   - **Case 3 — Hybrid**: `[H1]` policy extraction → `[H2]` policy-injected SQL generation → `[H3]` retry/correct loop → `[H4]` SQLite execution → `[H5]` PII guardrail filter → returns SQL result (policy text is only used to shape the SQL).
6. Every stage emits a structured trace log so you can audit decisions end-to-end (see `logs/trace.jsonl`).

Project layout
--------------
- `app/agent.py` — orchestrates routing, SQL/doc handling, PII guardrail.
- `app/router.py` — classifies queries (sql/docs/hybrid).
- `app/docs_loader.py` — loads and searches policy docs.
- `app/sql_executor.py` — SQLite executor with retry + LLM correction.
- `app/pii.py` — PII detection and masking helpers.
- `app/llm.py` — OpenAI wrapper for routing, SQL, and policy responses.
- `app/logger.py` — structured JSON logging.
- `data/store.db` — sample SQLite database (customers + orders).
- `data/policies.md` — example business rules.
- `main.py` — CLI entry point.
- `requirements.txt` — dependencies (OpenAI SDK).

Setup
-----
1) Install dependencies:
```
pip install -r requirements.txt  # use python3/pip3 if needed
```
2) (Optional) Set your key for live LLM calls:
```
export OPENAI_API_KEY=sk-...
```
An OpenAI API key is required; without it, LLM calls will fail and should be retried after the key is configured.

Run the CLI demo
----------------
```
python main.py "List VIP customers"
```
Or interactively:
```
python main.py
Enter a query: show orders per customer
```

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

PII guardrails
--------------
- Requests for raw `email`, `phone`, or `address` are rejected with a safe message.
- Any result set containing those fields is masked before returning.

Logs
----
- JSONL traces are written to `logs/trace.jsonl`. Each line includes `step`, timestamps, and context.

Notes
-----
- The sample DB is small and intended for local testing; swap `data/store.db` with your dataset as needed.
- Only SELECT statements are executed; destructive SQL is blocked.
