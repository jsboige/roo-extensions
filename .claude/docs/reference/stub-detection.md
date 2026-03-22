# Stub Detection Protocol — Anti-Fake Data

**Version:** 1.0.0
**Created:** 2026-03-22
**Context:** Stub crisis #767-#786 — 11+ methods returning fake data via exposed MCP tools

---

## Rule

**Every MCP-exposed method MUST return real data or an explicit error. Never return hardcoded values that look real.**

---

## Stub Patterns to Detect

| Pattern | Example | Risk |
|---------|---------|------|
| Hardcoded confidence | `return 0.85` | Agents trust the score |
| Hardcoded metrics | `{ completeness: 0.9, accuracy: 0.85 }` | Metrics appear meaningful |
| Empty mock objects | `{ themes: [], patterns: [] }` | Looks like "no results" instead of "not implemented" |
| Placeholder strings | `themes: ['theme1', 'theme2']` | Looks like real analysis |
| Return null placeholder | `return null; // Phase 1` | Caller can't distinguish "no data" from "not implemented" |
| Console.log stub | `console.log('TODO'); return;` | Silent failure |
| Timer without action | `setInterval(() => { /* TODO */ })` | CPU waste, false liveness |

## When Reviewing Code

1. **Check if the method is reachable from a tool handler** (trace from `src/tools/` → service)
2. If reachable: **verify the return value is REAL**, not hardcoded
3. If not reachable: mark with `@internal` and document in the issue

## When Writing Tests

1. **Never mock the service you're testing** — mock its DEPENDENCIES instead
2. **Never assert hardcoded values** from stubs (e.g., `expect(confidence).toBe(0.85)`)
3. Tests that assert `null`, `[]`, or `{}` must explain WHY that's the expected value
4. Tests marked "Phase 1 stub" should use `test.todo()` not `test()`

## When Creating New Features

1. **Phase 1 skeleton methods** must throw `NotImplementedError`, not return fake data
2. Tools with skeleton backends must not be registered in ListTools
3. Use `@experimental` or `@stub` JSDoc tags for work-in-progress methods
4. Document the phase plan in the issue, not just in code comments

---

## Reference

- Issue #788: Plan d'attaque complet
- Issues #767-#786: Individual stubs
- Commit `84f5ace8`: Synthesis pipeline disabled

---

**Last updated:** 2026-03-22
