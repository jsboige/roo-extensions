# Skill: Debrief - Session Analysis & Knowledge Capture

**Version:** 1.0.0
**Usage:** `/debrief`

---

## Objective

Analyze work done in the current session, extract reusable lessons, update persistent memory, and produce a structured summary for the user.

---

## Workflow

### Phase 1: Session Analysis

**Actions:**
1. Review conversation history - identify main tasks accomplished
2. List problems encountered and resolved (root cause + fix)
3. Extract key commands/tools used
4. Gather metrics: git commits, test results, files changed

**Method:**
```bash
# Git metrics
git log --oneline -10
git diff --stat HEAD~3..HEAD 2>/dev/null || true
```

### Phase 2: Lesson Extraction

**Categories:**
- **Technical**: Root causes, solutions, workarounds
- **Process**: Efficient workflows, reusable patterns
- **Tools**: Discoveries, configurations, best practices
- **Performance**: Optimizations, time savings

**Quality criteria for a good lesson:**
- Concrete: Specific action, not vague advice
- Reusable: Applicable to future sessions
- Contextual: When/where to apply

**Examples:**
- BAD: "Check configs more carefully"
- GOOD: "Always verify `transportType: 'stdio'` in MCP config before debugging connection issues"

### Phase 3: Memory Update

**Auto-memory** (private, per-project):
- Update current state (git hash, test results, key metrics)
- Add confirmed patterns (multi-session validated)
- Record critical configurations
- Note what was tried and failed (with reasons)

**Shared project memory** (if `.claude/memory/PROJECT_MEMORY.md` exists):
- Add universal learnings applicable to all agents on this project
- Architectural decisions made
- Major incidents and resolutions

**Rules:**
- Merge with existing content (avoid duplication)
- Use concise bullet points
- Include dates and context
- Link to issues/PRs if applicable
- Keep auto-memory under 200 lines (move overflow to topic files)

### Phase 4: Local Coordination Update (if applicable)

If the project uses local coordination files (e.g., INTERCOM):
- Add session summary for the other agent
- List pending actions
- Note items to monitor

### Phase 5: User Summary

**Output format:**
```markdown
# Debrief Session - [DATE]

## Accomplished
- [Concise list with status indicators]

## Key Lessons
1. [3-5 main takeaways]

## Documentation Updated
- [Files modified]

## Next Steps
- [Recommended actions]
```

---

## Tools Used

- **Read**: Existing memory files, project docs
- **Edit**: Update memory files (merge, don't overwrite)
- **Grep**: Check for duplicates before writing
- **Bash**: Git metrics extraction

---

## Invocation

```bash
/debrief
```

---

## Notes

- **Duration**: 2-3 minutes
- **Frequency**: End of each significant work session
- **Prerequisite**: At least 1 substantive task completed
- **Idempotent**: Can be re-run without duplication
