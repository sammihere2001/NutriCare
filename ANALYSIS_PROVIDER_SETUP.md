# Report narration providers

The meal recommender and report narrator are separate services. Changing narration providers does not retrain the meal model or establish medical validity.

The backend defaults to `LLM_PROVIDER=disabled`. Existing `OPENAI_API_KEY` values are ignored. The application still returns recorded statistics without an external request. No live external provider was called during development verification.

## Local option without per-request API charges

Install Ollama on the machine hosting the backend and choose a locally installed model appropriate to its hardware. In the backend `.env`, set:

```dotenv
LLM_PROVIDER=ollama
LLM_BASE_URL=http://127.0.0.1:11434/v1
LLM_MODEL=YOUR_INSTALLED_LOCAL_MODEL
LLM_API_KEY=
LLM_TIMEOUT=60
```

Restart the backend. Ollama must be running with that model installed. This configuration calls the local server; it does not install/download a model automatically. Memory, speed and output quality depend on the hardware/model. An APK calls your backend; the phone does not need to host this model. Docker container networking will require an explicit host URL rather than container localhost.

Official local endpoint documentation: https://docs.ollama.com/api/openai-compatibility

## DeepSeek hosted option

DeepSeek's developer API is billed by token usage; it is not a guaranteed free API. Check current terms/prices before enabling it: https://api-docs.deepseek.com/quick_start/pricing/

```dotenv
LLM_PROVIDER=deepseek
LLM_BASE_URL=https://api.deepseek.com/v1
LLM_MODEL=deepseek-flash
LLM_API_KEY=YOUR_BACKEND_ONLY_KEY
LLM_TIMEOUT=30
```

Model name checked against official documentation on 2026-11-04; availability can change. The adapter requests JSON output with thinking disabled. Never put the key into Flutter source, build arguments, APK assets or Git.

## Groq free-tier demo option

```dotenv
LLM_PROVIDER=groq
LLM_BASE_URL=https://api.groq.com/openai/v1
LLM_MODEL=openai/gpt-oss-20b
LLM_API_KEY=YOUR_GROQ_KEY
LLM_TIMEOUT=30
```

This uses Groq's service/key, not an OpenAI API account. Model access and free-tier quotas must be confirmed in your Groq account. Do not enable a paid upgrade for the free demo. Requests that exceed quota return the recorded-statistics fallback; they are not automatically retried. The adapter uses `max_completion_tokens` and low reasoning effort for GPT-OSS models. Model and JSON support require a live test after configuration.

Official references: https://console.groq.com/docs/models and https://console.groq.com/docs/rate-limits

## Other compatible providers

`LLM_PROVIDER=compatible` accepts a configured HTTPS base URL, model and key for providers implementing `/chat/completions` with JSON response-format support. Compatibility requires an actual provider smoke check; a free quota cannot be assumed. Local HTTP is permitted only on loopback. Do not paste full `/chat/completions` into the base URL.

## Behavior and limits

- Three distinct dates containing a glucose reading are required before narration is attempted. This is a software threshold, not clinical evidence sufficiency.
- Only numeric glucose, exercise and sleep fields are sent, labelled by relative day. Names, email, account IDs, dates, notes, prescription text and unverified water units are omitted. Measurements remain health data; external deployment needs appropriate consent and provider/data-handling review.
- Risk scores, health scores, action matrices and causal interpretations are not accepted as structured report fields. Output is marked as an unverified AI draft. Prompts restrict recommendations to tracking and clinician discussion; prompt instructions cannot guarantee medically correct prose.
- Missing/disabled configuration, timeouts, HTTP failures, malformed/truncated output or invalid field types fall back to recorded-data-only output. Requests are not retried automatically or redirected. Provider response bodies and exception strings are not logged.
- The real local/hosted narration path remains unverified until a model/key is configured. Transport-mocked contract and failure tests pass. No model quality or medical-safety claim follows from these tests.

Run backend checks from `backendApiNutricare NEW/backendApiNutricare NEW`:

```powershell
./venv/Scripts/python.exe -m unittest discover -s tests -v
```
