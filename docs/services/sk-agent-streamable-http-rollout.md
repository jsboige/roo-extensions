# sk-agent streamable-http — Rollout Runbook (OWUI + MCP proxy)

**Issue:** #3412 (parent #794, crosses #3401) | **Status:** plan proposed, awaiting ai-01 validation
**Validated from:** myia-po-2026 (consumer-side), 2026-09-04 | **Execution lane:** myia-ai-01 (Docker + OWUI access)

Goal: make the streamable-http container the canonical surface for remote consumers
(OWUI tenants, MCP proxy), with no duplicated model config on the consumer side.

---

## 1. Validated surface (evidence, po-2026 2026-09-04)

### Transport legs — unauthenticated POST `initialize` → 401 everywhere

| Leg | URL | Result (no auth) |
|---|---|---|
| sk-agent container (IIS proxy) | `https://skagents.myia.io/mcp` | **401** (0.21 s) |
| MCP proxy (ai-01, LAN) | `http://192.168.0.47:9090/sk-agent/mcp` | **401** (0.005 s) |
| MCP proxy (public) | `https://mcp-tools.myia.io/sk-agent/mcp` | **401** (0.07 s) |
| MCP proxy (po-2026 local, :9092→9090) | `http://localhost:9092/sk-agent/mcp` | **401** (0.012 s) |

Proxy routing: per-server paths (`/<server>/mcp`) — Go mcp-proxy behind bearer
`authTokens` (values in local config, never in Git).

### Authenticated smoke via proxy (streamable-http MCP, Bearer)

| Check | Result |
|---|---|
| `initialize` | 200 — `sk-agent` v1.0.0, FastMCP protocol |
| `tools/list` | 200 — **9 tools** (canonical inventory) |
| Text — `call_agent` | 200 — exact echo reply, `conversation_id` returned, `model_used: glm-5.1` (cloud) |
| Vision — `call_agent` + PNG attachment (URL) | 200 — `vision-analyst` / glm-4.6v: "solid red square", `images_analyzed: 1` |
| Conversation — `run_conversation` | 200 — multi-agent preset completed |
| Attachment inline base64 | **Rejected by design** — `attachment` takes a path/URL/JSON array of paths; container needs a reachable URL (e.g. `http://host.docker.internal:<port>/file`) |

Smoke protocol = exactly what OWUI's MCP Tool Server client sends
(initialize → initialized → tools/list → tools/call, POST + Bearer). No code path
specific to the smoke client.

### Authentication & health model (hardened code, submod `7519afe4`)

- `/healthz` public (no auth): `{"status":"healthy","config":"valid","models_enabled":N,"manager":"..."}`, cached 5 s.
- All other paths: `Authorization: Bearer <SK_AGENT_API_KEY>` — `secrets.compare_digest`, 401 otherwise.
- `main()` refuses to start streamable-http without the key (fallback bearer removed, #3405).
- Dockerfile `HEALTHCHECK` curls `/healthz` unauthenticated (30 s interval).
- Key injection: `${SK_AGENT_API_KEY:?...}` in compose — mandatory, from a gitignored env file (`myia.env` on ai-01). Port bound to `127.0.0.1:8100` (host), exposure via IIS reverse proxy `skagents.myia.io`.

### Findings (gates for the rollout)

| # | Finding | Impact | Action |
|---|---|---|---|
| A | **Deployed `skagents.myia.io` runs pre-hardening build** — `/healthz` answers 401 (hardened build exempts it); auth itself IS enforced (key injected, ai-01 verified sane #3405) | No public health probe; Docker HEALTHCHECK of hardened image would fail against old behavior | Gate 0: merge parent bump #3417 → rebuild image → `up -d --force-recreate` → verify `/healthz` 200 public |
| B | `owui-*` agents 401 against `https://open-webui.myia.io/openai` from **po-2026's** config (no key set) | sk-agent→OWUI-model direction broken on this machine only; rollout targets ai-01's container (doc: key in `myia.env`) | ai-01: confirm `owui-*` models carry the OWUI key in ITS config before OWUI pilot; else `enabled:false` per graceful-degradation note |
| C | `myia-mcp-proxy` container healthcheck is `CMD true` (no-op) | Container shows "healthy" regardless of upstream state | Ops: replace with real probe (401 on `/<server>/mcp` = alive) |
| D | Proxy returns 404 (not 401) for unknown paths without auth | Path enumeration possible; MCP paths remain gated | Acceptable — note only |

---

## 2. Alias model — no physical ID at the consumer

Consumers reference **stable names only**; the physical model name lives in exactly
one file (`sk_agent_config.json`), bind-mounted read-only:

```
OWUI tenant ──(agent ID)──> sk-agent agent (e.g. owui-analyst | vision-analyst)
                                 │ config: agent.model = models[].id (stable alias)
                                 ▼
                            models[].model_id + base_url  ← ONLY place the physical
                                                               name appears (e.g.
                                                               Local.qwen3.6-35b-a3b)
```

- Agent swap / model swap = 1 line in config + `up -d --force-recreate` (container
  restart, seconds; stdio consumers unaffected — they spawn their own process).
- **Grace period (old/new name)** is served at the model-provider layer (claudish
  dual-name, decision #3402 §4: **2 weeks**, both `qwen3.6-35b-a3b` and `local-coding`
  answer). The sk-agent layer needs no grace mechanism: consumers never see the name.
- For OWUI `config`-table model references (the 21–28 hardcoded occurrences across the
  7 schools), migration is #3402 Étape 6 (UPDATE SQL per school) — **out of scope here**;
  this runbook only covers the MCP Tool Server surface, which has no such trap.

---

## 3. Connection spec (what each consumer registers)

| Consumer | Connection | Auth |
|---|---|---|
| OWUI tenant (Tool Server) | `https://skagents.myia.io/mcp` (streamable-http) | Bearer key = `SK_AGENT_API_KEY` (from `myia.env`, ai-01) |
| MCP proxy upstream | stdio in-container (`python /opt/sk-agent/sk_agent.py`) — already wired | n/a (proxy-internal) |
| LAN consumers | `http://192.168.0.47:9090/sk-agent/mcp` | Bearer `authTokens` (proxy config) |

Post-registration smoke (per consumer, ~1 min):

```
1. unauth POST initialize            → expect 401
2. auth    initialize + tools/list   → expect 200, 9 tools
3. auth    call_agent (text)         → expect reply + conversation_id
4. auth    call_agent (vision, attachment URL) → expect image_seen / images_analyzed
5. auth    run_conversation          → expect multi-agent reply
```

---

## 4. Sequential rollout — 7 schools (+ OWUI interne)

Order: harden → internal → pilot → soak → remaining schools ascending size.
**One school at a time. No parallel steps.**

| Step | What | Owner | Exit criteria |
|---|---|---|---|
| **0. Gate hardening** | Merge #3417 (parent bump) → ai-01 rebuild image → `--force-recreate` → `/healthz` public 200, `docker ps` healthy, auth smoke (5 checks above) | ai-01 | healthz 200 + smoke 5/5 |
| **1. OWUI interne (ai-01)** | Register Tool Server in internal tenant (URL + Bearer); exercise text (`analyst`), vision/document (`vision-analyst` + attachment), conversation (`run_conversation`) from OWUI chat | ai-01 | 3 agent classes used from OWUI UI; logs show `Request [POST]` |
| **2. École pilote** | Pick 1 school tenant (criteria: smallest user base / volunteer, ai-01+ops choice); same registration; **1-week soak** | ai-01 + ops-schools | 7 days no ERROR in `docker logs sk-agent`; tool calls succeed |
| **3–9. Remaining schools** | One per day: pre-check (leg 401 + healthz) → register → 5-check smoke → monitor 24 h → next | ai-01 + ops-schools | Each school smoke 5/5 before advancing |
| **10. Close** | Verify no OWUI tenant references a physical model ID for tool-server purposes; keep #3402 Étape 6 model-alias migration on its own track (2-week dual-name grace) | ai-01 | grep school `config` tables clean of physical names (model surface) |

Total calendar: ~2 weeks (pilot soak dominates). Steps 3–9 add 7 days.

---

## 5. Rollback (no downtime, per layer)

| Layer | Rollback | Downtime |
|---|---|---|
| OWUI tenant | Disable the Tool Server connection (admin UI) — chat keeps working via direct models; sk-agent tools disappear only | 0 (feature-level) |
| sk-agent container | Keep previous image tagged `sk-agent:<yyyymmdd>` before each redeploy; `docker tag` back + `up -d --force-recreate` (~seconds) | seconds, in-flight calls only |
| Config | `sk_agent_config.json` previous copy retained (`.bak-<date>`); restore + `--force-recreate` | seconds |
| MCP proxy | Container recreate; stdio upstreams unchanged | seconds |
| Consumers | Nothing to roll back — they reference agent IDs, which are unchanged by any of the above | 0 |

Rule: never roll back by editing a live container (`docker exec`); always
recreate from versioned image + config file so state stays reproducible.

---

## 6. Verification matrix (per school, evidence for #3412 acceptance)

| Acceptance item | Evidence produced |
|---|---|
| 401 sans auth + smoke authentifié via proxy | Done po-2026 (§1) for proxy legs; ai-01 repeats on `skagents.myia.io` after Gate 0 |
| OWUI interne + école pilote appellent texte, vision/document, conversation | Steps 1–2 evidence (ai-01 lane) |
| Aucun ID physique requis côté consommateur | By construction (§2): consumers use agent IDs; verified in config + code (`get_model` / `model_id` indirection) |
| Plan séquentiel validé pour les sept écoles | This doc — **awaiting ai-01/user validation** |

---

**Secrets policy:** this document contains no key material. Bearer references point to
`myia.env` (ai-01) and proxy local configs only.
