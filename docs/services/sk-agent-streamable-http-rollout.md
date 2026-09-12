# sk-agent streamable-http — Rollout Runbook (OWUI + MCP proxy)

**Issue:** #3412 (parent #794, crosses #3401) | **Status:** Gate 0 executed 2026-09-07 (persisting, re-verified 09/09 + 11/09 + 12/09); Step 0.5 (proxy canonicalization) decision pending — dossier updated 12/09 (**finding G: the root cause of finding F is identified in code — a pre-lazy-loading init latch, fixed upstream 2026-04-30; the frozen Feb build cannot recover from one failed init without a container restart**)
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

### Authenticated smoke via proxy (streamable-http MCP, Bearer) — 04/09; attribution RESOLVED 11/09

Route smoked: `/sk-agent/mcp` on a proxy leg reached from po-2026, with the proxy
Bearer read from local config at runtime. **Attribution resolved (po-2026, 11/09):**
the recorded `v1.0.0 + 9 tools` combination matches the **po-2026 local proxy leg**
exactly (`:9092`, own `myia-mcp-proxy` container — NOT a forwarder to `.47:9090`;
its `sk-agent` entry is a local stdio child from an image built **2026-05-28**,
serving the 9-tool post-refactor surface before the `1.30.0` version bump). There
are therefore **three instance variants**, not two:

| Instance | Image built | Surface | Version |
|---|---|---|---|
| po-2026 local proxy stdio copy | 2026-05-28 | 9 tools | v1.0.0 |
| Production proxy stdio copy (ai-01, `.47:9090` = `mcp-tools.myia.io`) | 2026-02-28 | 13 tools | v1.0.0 |
| HTTP container (`skagents.myia.io` / `:8100`) | 2026-09-07 | 9 tools | v1.30.0 |

Re-measured firsthand 11/09 from po-2026 (authenticated, token read at runtime —
same fleet-shared proxy `authTokens` accepted by all three proxy legs): initialize
200 + tools/list **9 tools** on the local leg; **13 tools** on production
(`:9090` LAN and `mcp-tools.myia.io` public). See finding F for the functional
breakage this re-measurement exposed on the production leg.

| Check | Result |
|---|---|
| `initialize` | 200 — `sk-agent` v1.0.0, FastMCP protocol *(po-2026 local proxy leg — attribution resolved 11/09)* |
| `tools/list` | 200 — **9 tools** *(po-2026 local proxy leg, image 2026-05-28)* |
| Text — `call_agent` | 200 — exact echo reply, `conversation_id` returned, `model_used: glm-5.1` (cloud) |
| Vision — `call_agent` + PNG attachment (URL) | 200 — `vision-analyst` / glm-4.6v: "solid red square", `images_analyzed: 1` |
| Conversation — `run_conversation` | 200 — multi-agent preset completed |
| Attachment inline base64 | **Rejected by design** — `attachment` takes a path/URL/JSON array of paths; container needs a reachable URL (e.g. `http://host.docker.internal:<port>/file`) |

**Attributed re-run (po-2026, 11/09, local `:9092` leg — 5/5):** unauth 401 · initialize 200 (v1.0.0) · tools/list 200 (9 tools) · text `call_agent` 200 in 12.4 s (exact echo `PROBE-OK-3412`, `conversation_id`, `glm-5.1`) · vision 200 in 6.5 s (`vision-analyst`, `glm-5.3-flash` — the vision alias moved on from 04/09's `glm-4.6v`, consumer-invisible) · `run_conversation` 200 in 4.4 s (4 agents, 1 round, coherent reply). Attachment URL served from the consumer host via `http://host.docker.internal:<port>/` — same pattern OWUI fixtures will need.

Smoke protocol = exactly what OWUI's MCP Tool Server client sends
(initialize → initialized → tools/list → tools/call, POST + Bearer). No code path
specific to the smoke client.

**Reconciliation (finding E, ai-01 08/09; attribution closed po-2026 11/09):** the
04/09 "9 tools" observation was served by the **po-2026 local proxy leg** (own
container, stdio copy, image 2026-05-28) — not the production proxy and not the
HTTP container. The production proxy (`mcp-tools.myia.io` / `192.168.0.47:9090`)
serves **13 tools, v1.0.0** (frozen stdio copy baked 2026-02-28), while the HTTP
container (`skagents.myia.io`, port 8100) serves **9 tools, v1.30.0**. Therefore
**the legacy baseline = 13 tools** (production proxy); the 9-tool inventory is the
post-canonicalization target (Step 0.5-C), not the legacy baseline. The 04/09
smoke's transport/protocol validity is unaffected — it ran the exact OWUI client
sequence through a mcp-proxy streamable-http leg — but its functional evidence
applies to the local instance, and was **re-run attributed 11/09** (5/5 checks on
the local leg, plus the production-leg differential of finding F).

### Authentication & health model (hardened code, submod `7519afe4`)

- `/healthz` public (no auth): `{"status":"healthy","config":"valid","models_enabled":N,"manager":"..."}`, cached 5 s.
- `manager` shows `not_initialized` until the **first tool call** builds the manager (lazy init) — **re-verified 12/09 from po-2025 on the hardened container: `models_enabled: 11, manager: not_initialized` is its normal steady state, not a fault.** The public probe is deliberately coarse: it carries **no error detail**. After a *failed* init the field stays `not_initialized` too — the cause is only visible via the **authenticated `diagnostics` tool** (`last_init_error`, `agents_created`), which exists only in builds ≥ `3e9ba2c55` (finding G).
- All other paths: `Authorization: Bearer <SK_AGENT_API_KEY>` — `secrets.compare_digest`, 401 otherwise.
- `main()` refuses to start streamable-http without the key (fallback bearer removed, #3405).
- Dockerfile `HEALTHCHECK` curls `/healthz` unauthenticated (30 s interval).
- Key injection: `${SK_AGENT_API_KEY:?...}` in compose — mandatory, from a gitignored env file (`myia.env` on ai-01). Port bound to `127.0.0.1:8100` (host), exposure via IIS reverse proxy `skagents.myia.io`.

### Findings (gates for the rollout)

| # | Finding | Impact | Action |
|---|---|---|---|
| A | **Deployed `skagents.myia.io` runs pre-hardening build** — `/healthz` answers 401 (hardened build exempts it); auth itself IS enforced (key injected, ai-01 verified sane #3405) | No public health probe; Docker HEALTHCHECK of hardened image would fail against old behavior | **DONE 2026-09-07 18:25Z** (ai-01 deploy; healthz 200 public verified po-2026 09/09) |
| B | `owui-*` agents 401 against `https://open-webui.myia.io/openai` from **po-2026's** config (no key set) | sk-agent→OWUI-model direction broken on this machine only; rollout targets ai-01's container (doc: key in `myia.env`) | ai-01: confirm `owui-*` models carry the OWUI key in ITS config before OWUI pilot; else `enabled:false` per graceful-degradation note |
| C | `myia-mcp-proxy` container healthcheck is `CMD true` (no-op) | Container shows "healthy" regardless of upstream state | Ops: replace with real probe (401 on `/<server>/mcp` = alive) — confirmed firsthand ai-01 08/09 |
| D | Proxy returns 404 (not 401) for unknown paths without auth | Path enumeration possible; MCP paths remain gated | Acceptable — note only |
| E | **Proxy leg and container are two instances** (found ai-01 08/09): `mcp-tools.myia.io/sk-agent` serves a stdio copy baked into `myia-mcp-proxy:latest` (built 2026-02-28, 13 tools, v1.0.0), not the HTTP container (9 tools, v1.30.0). **25 commits** of drift as of 11/09 (24 on 08/09 — grows by itself); divergence in both directions (`diagnostics`/`review_pr` missing on proxy; `analyze_*`/`ask`/`list_models`/`zoom_image` missing on container) | Rebuilding the sk-agent container never updates the proxy leg; a consumer's tool surface depends on which leg it is on. Not a security hole (proxy stdio has no HTTP surface of its own; gated by `authTokens`) | **Step 0.5** below — decision A/B/C (recommendation: C, url-relay) |
| F | **Production proxy leg cannot complete LLM tool calls** (po-2026, 11/09, authenticated): `list_agents` 200 in 38 ms (plumbing fine, roster correct), but `call_agent` (text, `analyst`) **hangs ≥180 s then the next attempt returns `{"error": "No agents initialized"}` instantly**. Differential: the po-2026 local leg (same stdio-through-proxy architecture, image 2026-05-28, current repo config) completes the identical call in 12.4 s — the breakage is specific to the production instance (Feb code and/or its env on ai-01), not the architecture. Root cause **IDENTIFIED in code 12/09 — see finding G**; the mechanism is deterministic, not an environment mystery | The production proxy leg is **functionally broken today** for any consumer needing an agent call, while looking healthy to handshake-level probes (401/initialize/tools_list — all previous probes stopped there). An OWUI tenant registered on this leg pre-canonicalization would see tools hang | Strengthens Step 0.5-C decisively (option A preserves a leg broken by a bug fixed 2026-04-30 — see §4bis); ai-01: capture `docker logs myia-mcp-proxy` during one `call_agent` to confirm the latch (expect a hang/traceback in the init path, then the instant `No agents initialized` on retry) |
| G | **Root cause of finding F: the frozen Feb build carries a self-poisoning init latch** (po-2025, 12/09, code forensics on the submodule — no ai-01 access required). Pre-lazy `_get_manager()` assigned the global **before** awaiting init: `_manager = SKAgentManager(_config)` then `await _manager.start()`. If `start()` hangs or raises, `_manager` stays **set** to a half-built object whose `_sk_agents` is empty — every later call short-circuits on `_manager is not None` and returns instantly. The Feb build inits **eagerly** (`_init_model_pool` → `_init_mcp_pool`, spawning MCP stdio children → `_create_agent` for all **32** agents; each `memory.enabled` agent builds a `QdrantMemoryStore` against `https://qdrant.myia.io:443`). In this repo's config `analyst` alone carries 3 MCP plugins + memory, so any single init step hanging blocks `start()` forever. `list_agents` keeps answering 200 because its roster comes from **config**, not `_sk_agents` — which is why every handshake-level probe looked healthy. **Two independent code-vintage proofs:** (1) the captured string `No agents initialized` was renamed to `No agents configured` in `9b03bbf85` (2026-03-08) — it cannot exist in any newer code; (2) the resilience fix `3e9ba2c55` (« on failure, `_manager` stays None so the next call retries », #1408) landed **2026-04-30** and is an ancestor of current submod HEAD `5511f0d1`. The frozen 2026-02-28 image predates both | Finding F is **not** an unresolved environment incident — it is an already-fixed bug still served only by the legacy leg. Option A would ship a surface that is broken by construction and cannot self-heal without a container restart; the current container (v1.30.0) carries both fixes | No ai-01 code fix is needed — Step 0.5 (B or C) resolves it. Residual ai-01 action is **confirmation only**: `docker logs myia-mcp-proxy` during one `call_agent` to see *which* init step hangs (MCP stdio spawn vs Qdrant/embeddings), documenting the trigger rather than the mechanism. The concurrent embeddings-key rotation is a plausible **trigger**, no longer the mechanism |

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
| MCP proxy upstream | **frozen stdio copy — divergent (finding E) and functionally broken for LLM calls (finding F)**; target state after Step 0.5: url-relay `http://host.docker.internal:8100/mcp` | Bearer `SK_AGENT_API_KEY` in gitignored proxy config (same file as `authTokens`) |
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
| **0. Gate hardening** | Merge #3417 (parent bump) → ai-01 rebuild image → `--force-recreate` → `/healthz` public 200, `docker ps` healthy, auth smoke (5 checks above) | ai-01 | healthz 200 + smoke 5/5 — **DONE 2026-09-07** |
| **0.5. Proxy canonicalization** | Decide A/B/C (§4bis). If C: switch proxy `sk-agent` entry to url-relay (+ optional `sk-agent-legacy` stdio entry for the grace period), then run the 5-check smoke against `/sk-agent/mcp` | ai-01 (+ user if legacy consumers found) | proxy `/sk-agent/mcp` tools/list = 9 tools, v1.30.0; legacy entry (if kept) still serves 13 |
| **1. OWUI interne (ai-01)** | Register Tool Server in internal tenant (URL + Bearer); exercise text (`analyst`), vision/document (`vision-analyst` + attachment), conversation (`run_conversation`) from OWUI chat | ai-01 | 3 agent classes used from OWUI UI; logs show `Request [POST]` |
| **2. École pilote** | Pick 1 school tenant (criteria: smallest user base / volunteer, ai-01+ops choice); same registration; **1-week soak** | ai-01 + ops-schools | 7 days no ERROR in `docker logs sk-agent`; tool calls succeed |
| **3–9. Remaining schools** | One per day: pre-check (leg 401 + healthz) → register → 5-check smoke → monitor 24 h → next | ai-01 + ops-schools | Each school smoke 5/5 before advancing |
| **10. Close** | Verify no OWUI tenant references a physical model ID for tool-server purposes; keep #3402 Étape 6 model-alias migration on its own track (2-week dual-name grace) | ai-01 | grep school `config` tables clean of physical names (model surface) |

Total calendar: ~2 weeks (pilot soak dominates). Steps 3–9 add 7 days.

### 4bis. Step 0.5 — proxy canonicalization (decision dossier)

Finding E must be resolved **before** Step 1: OWUI tenants are registered against
one leg, and their tool surface depends on which one. The original framing
("rebuild the proxy, or is divergence intentional?") missed a third option —
the proxy already supports url-relay upstreams. **Update 11/09 (po-2026):** finding
F removes the main appeal of option A — the production frozen leg does not actually
serve working agent calls today, so "keep it untouched" preserves a broken surface,
not a working one. The relay switch (C) replaces a hang with the container's
measured-working handshake path; the container's authenticated `tools/call` smoke
(5 checks) remains to be run by ai-01 post-switch — it is the one leg whose
functional smoke has never been recorded (po-2026 holds no `SK_AGENT_API_KEY`, by
design).

| Option | Proxy `/sk-agent` serves | Drift | Effort | Rollback | Consumer impact |
|---|---|---|---|---|---|
| **A. Status quo** (stdio, frozen Feb build) | 13 tools, v1.0.0 | grows forever (25 commits behind as of 11/09) | none | n/a | ~~none~~ **falsified by measurement 11/09** — the production leg's LLM calls are already broken (finding F: hang → "No agents initialized"); it also never gets hardening #1085 or later fixes. **Mechanism identified 12/09 (finding G): an init latch fixed upstream on 2026-04-30** — the frozen build cannot recover from a single failed init without a container restart |
| **B. Rebuild proxy image** (re-bake the stdio copy) | 9 tools, v1.30.0 | resumes immediately (same mechanism that produced the drift) | image rebuild + recreate | retag image | −6 tools (`analyze_document`, `analyze_image`, `analyze_video`, `ask`, `list_models`, `zoom_image`), +2 (`diagnostics`, `review_pr`) |
| **C. Switch entry to url-relay** (config-only) | 9 tools, v1.30.0 — **tracks the container** | **eliminated at the root** | edit gitignored `config.json` + `up -d --force-recreate` | revert one entry + recreate (seconds) | same −6/+2 as B |

**Recommendation: C.** It is the only option that satisfies this issue's objective
(container = canonical surface), and every mechanism it needs is already proven:

- url-relay pattern runs in this exact proxy today: the `roo-state-manager` entry
  (`http://host.docker.internal:9091/...` + Bearer header — `config.template.json`),
  route registered on the production proxy: unauthenticated POST → 401 (po-2026
  09/09). **Scope of that proof:** the pre-auth 401 attests the route is registered
  and auth-gated only — it does **not** exercise the relay to its URL upstream, so
  it is not end-to-end proof of the url-relay mechanism. End-to-end relay
  confirmation comes from the authenticated 5-check smoke against `/sk-agent/mcp`
  in Step 0.5 after the switch (no additional authenticated test exists yet).
- relay target live and hardened (po-2026 09/09): `http://192.168.0.47:8100/healthz`
  → 200 public (7 ms); `/mcp` → 401 unauth. Inside the proxy container the same
  endpoint is `http://host.docker.internal:8100/mcp` (host-gateway already declared
  in `docker/docker-compose.yml`).

Config diff — gitignored `docker/mcp-proxy/config.json` on ai-01 (key stays out of Git):

```json
"sk-agent": {
  "url": "http://host.docker.internal:8100/mcp",
  "headers": { "Authorization": "Bearer <SK_AGENT_API_KEY from myia.env>" },
  "timeout": "5m"
}
```

**Grace period (ancien/nouveau — same pattern as the model aliases of §2):**
mcp-proxy serves one route per `mcpServers` key, so during migration keep the
frozen copy under a second name (`"sk-agent-legacy": {command…}`) — consumers of
the 13-tool surface migrate at their pace, then the legacy entry is removed at
Step 2 exit.

**Prerequisite (ai-01, ~minutes):** inventory who calls `/sk-agent/mcp` today and
with which tools. Per this runbook no OWUI tenant is registered yet (Steps 1–2
pending) and fleet machines use local stdio — if the inventory is empty, drop the
legacy entry immediately. If a consumer calls the 6 legacy tools directly, keep
the legacy entry until migrated (the capability itself remains reachable via
`call_agent` + `attachment`, which accepts image/video/PDF/PPTX/DOCX/XLSX paths or URLs).

---

## 5. Rollback (no downtime, per layer)

| Layer | Rollback | Downtime |
|---|---|---|
| OWUI tenant | Disable the Tool Server connection (admin UI) — chat keeps working via direct models; sk-agent tools disappear only | 0 (feature-level) |
| sk-agent container | Keep previous image tagged `sk-agent:<yyyymmdd>` before each redeploy; `docker tag` back + `up -d --force-recreate` (~seconds) | seconds, in-flight calls only |
| Config | `sk_agent_config.json` previous copy retained (`.bak-<date>`); restore + `--force-recreate` | seconds |
| MCP proxy | Container recreate; under Step 0.5-C, revert the url-relay entry (legacy stdio entry if kept) | seconds |
| Consumers | Nothing to roll back — they reference agent IDs, which are unchanged by any of the above | 0 |

Rule: never roll back by editing a live container (`docker exec`); always
recreate from versioned image + config file so state stays reproducible.

---

## 6. Verification matrix (per school, evidence for #3412 acceptance)

| Acceptance item | Evidence produced |
|---|---|
| 401 sans auth + smoke authentifié via proxy | Done po-2026 (§1) for proxy legs; repeated ai-01 08/09 on both legs (3-leg 401 matrix, authenticated smoke, positive + negative auth controls); healthz 200 re-verified po-2026 09/09; **full 5-check smoke re-run with clean attribution po-2026 11/09** (local leg 5/5; production leg handshake OK but LLM calls broken — finding F); **3-leg 401 matrix + `/healthz` 200 re-verified po-2025 12/09** (0.03 s / 0.06 s / 0.002 s — the 06/09 hairpin latency variance did not reproduce; relay target `:8100` 200 in 3.5 ms) |
| OWUI interne + école pilote appellent texte, vision/document, conversation | Steps 1–2 evidence (ai-01 lane) |
| Aucun ID physique requis côté consommateur | By construction (§2): consumers use agent IDs; verified in config + code (`get_model` / `model_id` indirection) |
| Plan séquentiel validé pour les sept écoles | This doc — **awaiting ai-01/user validation** |

---

**Secrets policy:** this document contains no key material. Bearer references point to
`myia.env` (ai-01) and proxy local configs only.
