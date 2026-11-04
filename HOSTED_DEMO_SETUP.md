# Hosted interview demo: Render + Neon + Groq

Prepared on 2026-11-04. This is a deployment candidate, not an already live service. Free tiers have quotas and can change. No paid plan, hosting account or external API key has been provisioned by this code change.

## What runs where

The APK calls one HTTPS Render service. Its container runs one backend worker and one loopback-only meal-model worker. PostgreSQL lives on Neon. Groq provides optional educational report narration. Meal generation does not require Groq. A Groq outage/quota limit leaves recorded report statistics available.

The `render.yaml` Blueprint explicitly selects the free web plan and does not create a paid/private service or Render database. The container excludes local environments, credentials, backups, old ZIPs and Flutter build files. It includes the current reference meal dataset and original classifier artifacts. Do not use a public repository until the source/data and earlier exposed credentials have been reviewed and credentials rotated.

## Accounts and secret entry

1. Sign up/sign in to [Neon](https://console.neon.tech/) and select its **Free** plan. Create an empty demo database near the Render region you choose. Use the **direct** database endpoint for the initial demo, not the transaction-pooler endpoint. Copy its `postgresql://...?...sslmode=require` connection string into Render's secret form when requested. The backend converts it to asyncpg and verifies TLS certificates/hostname. Do not post the string in chat or commit it.
2. Sign up/sign in to [Groq](https://console.groq.com/), keep the account on the free plan, and create a backend API key. Confirm that `openai/gpt-oss-20b` appears among your accessible models and inspect your account's limits. The `openai/` model prefix identifies an open-weight model served by Groq; it does not require a ChatGPT subscription or OpenAI API key.
3. Sign up/sign in to [Render](https://dashboard.render.com/) using your GitHub account. Use a private, reviewed deployment repository containing the project-root Dockerfile, Blueprint and the referenced backend/ML directories. Nested existing Git repositories must be packaged deliberately; do not blindly stage the entire workspace or convert them without reviewing existing changes/history.
4. Choose **New → Blueprint**, select that repository and `render.yaml`. Verify the service plan says **Free**. Enter `DATABASE_URL` from Neon and `LLM_API_KEY` from Groq into the prompted secret fields. Render generates `JWT_SECRET`. Keep paid upgrades disabled. If the dashboard no longer offers a free plan for this configuration, stop rather than selecting a paid substitute.

The final repository upload and dashboard deployment remain pending. A separate allowlisted checkout is available in `hosted-release`; it excludes nested Git histories, local secrets and DB exports. Use a private repository for it. The user has now created the Render/Neon/Groq accounts and retained the database string/key privately.

## Startup and database contents

Container startup creates missing tables, missing health-goal/diet lookup IDs, and a reference food catalog. It does not copy local users, credentials, tracker records or the DB backup. Unknown portions/fiber/GI remain unspecified rather than inferred. The idempotent seed leaves existing rows intact. Use a **new empty demo database**, not an existing production database with a different schema. Existing databases still need their explicit migration procedure.

Registration/login, profiles, treatment, tracking, reports and meal generation are the core demo path. SMTP password-reset delivery and Cloudinary image uploads require additional separately configured credentials; they are not supplied by this Blueprint. Android password-reset deep links and device-level testing are still pending. Do not claim every optional integration works until it has been configured and tested.

## Local container check before deployment

Docker Desktop's Linux engine must be running. From the project root:

```powershell
docker build -t nutricare-demo .
docker run --rm --name nutricare-demo --env-file path/to/PRIVATE.hosted.env -p 10000:10000 nutricare-demo
```

The private env file must contain a development PostgreSQL URL, strong JWT secret, and optionally the Groq settings from `ANALYSIS_PROVIDER_SETUP.md`. Keep that file outside Git; do not use the supplied placeholder credentials. Do not use `localhost` inside the container for a database on Windows; use a hosted development database or a deliberately configured `host.docker.internal` endpoint.

Check `http://localhost:10000/health/ready`. Readiness requires PostgreSQL and a loaded meal classifier; it does not call Groq. The ML port is not published. If either server exits, the supervisor stops the container. On 2026-11-05 the Linux image built successfully and passed an isolated PostgreSQL smoke test under a 512-MB RAM/0.5-CPU cap. Measured memory after the single-user flow was about 261 MiB. This is not concurrent-load, cold-start-on-Render or hosted Neon/Groq verification. Do not upgrade automatically if the free instance runs out of memory; first measure and optimize it.

## Hosted verification and APK

After a successful deploy, check `https://YOUR-SERVICE.onrender.com/health/ready`. Using a fictional demo account, test registration/login, onboarding, combined treatment, meal generation, glucose tracking and report generation. Test Groq with three unique recording dates and verify the provider label plus unverified-draft notice. Test quota/failure fallback separately. Never put hosting/API/database credentials in the mobile app.

For a local live-provider contract check after configuring the backend `.env`, run `./venv/Scripts/python.exe -m app.scripts.smoke_narration` from the backend directory. This explicitly sends fictional measurements to the configured provider and may consume its quota; it prints no key or report content. It was not run during deployment preparation because no Groq account/key was available.

Then build from `fyp-main/fyp-main`:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Release signing and physical-device checks remain separate required steps. A release APK must use HTTPS, never the current localhost default. Free Render instances sleep after inactivity; the first request can be slow. Warm the demo by opening readiness before an interview, then test from mobile data with your laptop off. This is a demo preparation step, not an always-on guarantee or a reason to run artificial keepalive traffic.

## Current limits and primary references

- [Render free services](https://render.com/docs/free): idle spin-down and resource/usage restrictions. [Blueprint spec](https://render.com/docs/blueprint-spec).
- [Neon plans](https://neon.com/docs/introduction/plans): free compute/storage/transfer quotas and scale-to-zero. Inspect current dashboard allowances before creating resources.
- [Groq rate limits](https://console.groq.com/docs/rate-limits): free-tier model/account restrictions. [Model list](https://console.groq.com/docs/models).

No free-tier arrangement establishes clinical suitability or guarantees permanent free availability. Use fictional demonstration accounts until the clinical and deployment reviews are complete.
