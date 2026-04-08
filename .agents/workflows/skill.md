---
description: solo cuando se trabaje con viax
---

---
name: promptbase
description: Production deployment workflow for Viax backend changes.
---

# AGENT SKILL — SAFE PRODUCTION DEPLOY

You are working on the Viax production backend.

Deployment is mandatory after every backend code change and must avoid unnecessary migrations or worker restarts.

SECURITY POLICY (MANDATORY):

* Do not run Git commands on production backend servers.
* Do not use `git pull`, `git checkout`, `git reset`, `git clean`, or similar on server.
* Backend updates must be applied only by uploading changed files and running `deploy.sh`.
* Reason: prevent legacy or unintended code from being introduced on production.

---

# MANDATORY BACKEND CHANGE RULE

If any file under backend/ is modified, the agent MUST execute this full deploy workflow in the same turn.

Only exception: user explicitly says not to deploy yet.

If deployment cannot be executed, report:

DEPLOYMENT NOT EXECUTED

---

# STEP 1 — Upload modified backend files

Upload modified files only.

Example:

scp backend/user/create_trip_request.php root@SERVER_IP:/var/www/viax/backend/user/create_trip_request.php

---

# STEP 2 — Connect to server

ssh root@SERVER_IP

cd /var/www/viax/backend

---

# STEP 3 — NO GIT ON PRODUCTION (MANDATORY)

Do not execute any Git command on the server.

Do not update code through repository sync.

Code updates must come only from uploaded files in Step 1.

---

# STEP 4 — Run migrations ONLY if new migrations exist

Check pending migrations:

php scripts/check_pending_migrations.php

If result is:

NO_PENDING_MIGRATIONS

DO NOT run migrations.

If result is:

PENDING_MIGRATIONS_FOUND

Then run:

php scripts/run_migrations.php

If a migration already executed was edited, run_migrations.php must fail with RuntimeException.

Migration safety policy (MANDATORY):

* No migration may modify current production data by default.
* Data-mutation migrations (UPDATE/DELETE/TRUNCATE) are blocked unless explicitly approved for a controlled release.
* Never run legacy runner: php migrations/run_migrations.php
* Always use safe runner: php scripts/run_migrations.php

---

# STEP 5 — Execute deployment script

Before running deploy.sh, pass changed files from this deployment when available:

export DEPLOY_CHANGED_FILES="workers/surge_pricing_worker.php\nuser/create_trip_request.php"

chmod +x deploy.sh
./deploy.sh

---

# STEP 6 — Restart workers ONLY if worker code changed

deploy.sh decides worker restart automatically.

Workers restart only if files inside these folders changed:

/workers/
/queue/
/dispatch/
/pricing/

If worker logic was NOT modified, workers are not restarted.

If worker logic WAS modified and supervisorctl exists, deploy.sh restarts:

viax_dispatch_worker
viax_zone_cache_worker
viax_surge_pricing_worker
viax_driver_reposition_worker

If changed-file context is unavailable, deploy.sh defaults to no worker restart.

---

# STEP 7 — Verify Redis

redis-cli ping

Expected response:

PONG

---

# STEP 8 — Verify workers

supervisorctl status

Workers must show:

RUNNING

---

# STEP 9 — Endpoint smoke tests

curl -X POST http://127.0.0.1/user/create_trip_request.php -H "Content-Type: application/json" -d "{}"

curl -X POST http://127.0.0.1/conductor/update_trip_status.php -H "Content-Type: application/json" -d "{}"

curl -X POST http://127.0.0.1/user/trip_preview.php -H "Content-Type: application/json" -d "{}"

Expected result: validation errors (not server errors).

---

# STEP 10 — Health check

curl http://127.0.0.1/health.php

Expected HTTP code:

200

---

# FINAL RULE

Deployment is complete only if:

* files uploaded  
* no Git command executed on production  
* deploy.sh executed  
* migrations executed only when necessary  
* workers restarted only if needed  
* Redis verified  
* endpoints tested  
* health check passed

If backend files changed, finishing without deploy is not allowed.

---

# MANDATORY EXECUTION OVERRIDE

If the user explicitly requests forced deployment (examples: "despliega si o si", "ejecuta el despliegue ahora", "debes desplegar"), the agent MUST:

1. Execute the full deployment workflow in this skill end-to-end in the current turn.
2. Perform verification steps (Redis, workers, smoke endpoints, health check) itself.
3. Report concrete command outcomes (success/failure) instead of a plan.

Only skip execution when there is a real blocker outside agent control (for example: no SSH access, network outage, or missing credentials).

If deployment cannot be executed, report:

DEPLOYMENT NOT EXECUTED

---

# MANDATORY FLUTTER ANALYZE RULE

If any file under `lib/`, `test/`, `integration_test/`, or `pubspec.yaml` is modified, the agent MUST run Flutter static analysis in the same turn before finishing.

Minimum required command:

flutter analyze

Optional faster pre-check for focused edits (can be run first, but does NOT replace full analyze):

flutter analyze lib/path/to/changed_file.dart

If `flutter analyze` reports errors, the agent MUST:

1. Fix all errors introduced by the current change.
2. Re-run `flutter analyze` until errors are resolved or a real blocker exists.
3. Report concrete analyze output summary (error count and key files).

If analysis cannot be executed, report:

FLUTTER ANALYZE NOT EXECUTED

---

# HOUSEKEEPING RULE (MANDATORY)

If the agent creates temporary support files during troubleshooting or implementation (for example: files for fix, test, debug, or query), it MUST remove them at the end of the turn if they are not required by the system.

The repository must be left clean of unnecessary helper artifacts.

---

# LANGUAGE AND COMMENTING RULE (MANDATORY)

When documenting or commenting code for this project, the agent MUST write comments and explanations in Spanish to improve team readability.