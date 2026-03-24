# No Deletion Without Proof — Anti-Destruction Rule

**Version:** 1.0.0
**Created:** 2026-03-24
**Issue:** #815 (QUALITY anti-patterns)

---

## Rule

**No code file or exported function may be deleted without PROOF that its functionality is preserved elsewhere.**

"Dead code" is a dangerous label. Code that appears unused may be:
- Temporarily disconnected by a previous agent's incomplete refactor
- Called dynamically (string-based imports, tool registry, MCP dispatch)
- Part of a pipeline being incrementally built (stubs = implementation targets)

---

## What Counts as Proof

Before deleting any file or function, the agent MUST provide:

### For file deletion

1. **Functional equivalence**: Name the replacement file/function and cite specific lines
2. **Import migration**: Show that all importers of the old file now import from the replacement
3. **Test coverage**: The replacement passes the same tests (or the tests were updated)
4. **git grep confirmation**: `git grep "old-name"` returns zero results in active code

### For function/method removal

1. **Caller audit**: `git grep "functionName"` shows zero callers in active code
2. **History check**: `git log -S "functionName" --since="30 days ago"` — if recently added, it may be in-progress work
3. **Registry check**: Search tool registries, MCP dispatch tables, and dynamic invocations

---

## Circular Dependency Chain Prevention

**Anti-pattern identified in #815:**
```
A imports B → B deleted ("consolidated into C") →
A has no importers → A declared "dead code" → A deleted
Result: functionality of BOTH A and B lost
```

**Prevention protocol:**
1. Before declaring code "dead" due to zero importers, check `git log -S "import.*FileName"` for RECENT deletions of importers
2. If an importer was deleted in the last 30 days, the code is NOT dead — it was disconnected
3. Trace the full chain: who imported the importer? Was THAT deletion legitimate?
4. When in doubt, do NOT delete. Flag for human review instead.

---

## Protected Directories

These directories contain strategic code. Deletion requires **explicit user approval**:

| Directory | Content | Reason |
|-----------|---------|--------|
| `src/services/synthesis/` | LLM synthesis pipeline | 3 prior destructions, investment in progress |
| `src/services/narrative/` | NarrativeContextBuilder | Phase 3 stubs = implementation targets |

**Stubs in protected directories are NOT dead code.** They are placeholders for planned implementation.

---

## When Deletion IS Legitimate

- File was created in error (wrong name, duplicate, test artifact)
- Feature was explicitly abandoned by the user (documented in issue)
- Code was migrated AND the old location has a forwarding comment for 30 days
- Deprecated export maintained for backward compatibility AND all callers migrated

---

## Enforcement

- **PR review checklist** (`.claude/rules/pr-mandatory.md`) includes anti-destruction checks
- **Anti-stub CI tests** (`anti-stub-detection.test.ts`) catch exported stubs
- **This rule** is auto-loaded in every Claude Code conversation
- Roo equivalent: `.roo/rules/` should have matching rule

---

## References

- Issue #815: Anti-patterns detected
- Issue #810: Git archaeology report
- Issue #821: 3rd synthesis pipeline destruction prevented
- `.claude/rules/pr-mandatory.md`: PR review checklist
- `src/services/__tests__/anti-stub-detection.test.ts`: CI gate

---

**Last updated:** 2026-03-24
