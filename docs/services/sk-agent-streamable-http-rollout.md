# sk-agent streamable-http — Rollout Runbook (OWUI + MCP proxy)

**Issue:** #3412 (parent #794, crosses #3401) | **Status:** Gate 0 executed 2026-09-07; Step 0.5 (proxy canonicalization) decision pending
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

### Authenticated smoke via proxy (streamable-http MCP, Bearer) — 04/09, instance attribution uncertain

Route smoked: `/sk-agent/mcp` on a proxy leg reached from po-2026, with the proxy
Bearer read from local config at runtime. The exact instance was **not recorded**,
and attribution cannot be pinned down from po-2026 today: the local `:9092` listener
no longer exists, and that leg is described as `:9092→9090` (forwards to the
`.47:9090` production proxy). Caveat: an authenticated `tools/list` run from po-2026
on 09/09 against the production proxy (`http://192.168.0.47:9090/sk-agent/mcp` =
`mcp-tools.myia.io`) returns **13 tools, serverInfo v1.0.0** (finding E — frozen
stdio copy, image built 2026-02-28), so the 04/09 9-tool observation cannot be
reproduced on that leg. The recorded `v1.0.0 + 9 tools` combination matches neither
instance cleanly (production proxy = v1.0.0 + 13 tools; HTTP container = v1.30.0 +
9 tools) — itself the symptom of the unrecorded attribution.

| Check | Result |
|---|---|
| `initialize` | 200 — `sk-agent` v1.0.0, FastMCP protocol *(version matches the frozen stdio copy — see attribution caveat)* |
| `tools/list` | 200 — **9 tools** *(container-shaped inventory — see attribution caveat)* |
| Text — `call_agent` | 200 — exact echo reply, `conversation_id` returned, `model_used: glm-5.1` (cloud) |
| Vision — `call_agent` + PNG attachment (URL) | 200 — `vision-analyst` / glm-4.6v: "solid red square", `images_analyzed: 1` |
| Conversation — `run_conversation` | 200 — multi-agent preset completed |
| Attachment inline base64 | **Rejected by design** — `attachment` takes a path/URL/JSON array of paths; container needs a reachable URL (e.g. `http://host.docker.internal:<port>/file`) |

Smoke protocol = exactly what OWUI's MCP Tool Server client sends
(initialize → initialized → tools/list → tools/call, POST + Bearer). No code path
specific to the smoke client.

**Reconciliation (finding E, ai-01 08/09):** the 04/09 "9 tools" observation above
carries uncertain instance attribution (ran from po-2026; local `:9092` forwards to
`.47:9090`, i.e. the production proxy). Re-measured firsthand from po-2026 on
09/09 (authenticated): the production proxy (`mcp-tools.myia.io` / `192.168.0.47:9090`)
serves **13 tools, v1.0.0** (frozen stdio copy baked 2026-02-28), while the HTTP
container (`skagents.myia.io`, port 8100) serves **9 tools, v1.30.0**. Therefore
**the legacy baseline = 13 tools** (production proxy); the 9-tool inventory is the
post-canonicalization target (Step 0.5-C), not the legacy baseline.

### Authentication & health model (hardened code, submod `7519afe4`)

- `/healthz` public (no auth): `{"status":"healthy","config":"valid","models_enabled":N,"manager":"..."}`, cached 5 s.
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
| E | **Proxy leg and container are two instances** (found ai-01 08/09): `mcp-tools.myia.io/sk-agent` serves a stdio copy baked into `myia-mcp-proxy:latest` (built 2026-02-28, 13 tools, v1.0.0), not the HTTP container (9 tools, v1.30.0). 24 commits of drift; divergence in both directions (`diagnostics`/`review_pr` missing on proxy; `analyze_*`/`ask`/`list_models`/`zoom_image` missing on container) | Rebuilding the sk-agent container never updates the proxy leg; a consumer's tool surface depends on which leg it is on. Not a security hole (proxy stdio has no HTTP surface of its own; gated by `authTokens`) | **Step 0.5** below — decision A/B/C (recommendation: C, url-relay) |

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
| MCP proxy upstream | **frozen stdio copy — divergent (finding E)**; target state after Step 0.5: url-relay `http://host.docker.internal:8100/mcp` | Bearer `SK_AGENT_API_KEY` in gitignored proxy config (same file as `authTokens`) |
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
the proxy already supports url-relay upstreams.

| Option | Proxy `/sk-agent` serves | Drift | Effort | Rollback | Consumer impact |
|---|---|---|---|---|---|
| **A. Status quo** (stdio, frozen Feb build) | 13 tools, v1.0.0 | grows forever (24 commits behind already) | none | n/a | none — but the proxy leg never gets hardening #1085 or later fixes |
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
| 401 sans auth + smoke authentifié via proxy | Done po-2026 (§1) for proxy legs; repeated ai-01 08/09 on both legs (3-leg 401 matrix, authenticated smoke, positive + negative auth controls); healthz 200 re-verified po-2026 09/09 |
| OWUI interne + école pilote appellent texte, vision/document, conversation | Steps 1–2 evidence (ai-01 lane) |
| Aucun ID physique requis côté consommateur | By construction (§2): consumers use agent IDs; verified in config + code (`get_model` / `model_id` indirection) |
| Plan séquentiel validé pour les sept écoles | This doc — **awaiting ai-01/user validation** |

---

**Secrets policy:** this document contains no key material. Bearer references point to
`myia.env` (ai-01) and proxy local configs only.
