---
description: Analyze current session, extract lessons, update memory files
allowed-tools: Read, Edit, Grep, Bash, Glob
---

# /debrief - Session Analysis & Knowledge Capture

Analyze work done in this session, extract reusable lessons, update persistent memory, and produce a structured summary.

## What This Command Does

1. **Analyze Session**: Review tasks accomplished, problems solved, tools used
2. **Extract Lessons**: Identify reusable patterns (technical, process, tools)
3. **Update Memory**: Merge learnings into auto-memory and shared project memory
4. **Coordination**: Update local coordination files if applicable (INTERCOM, etc.)
5. **Git Postcondition**: If the session mutated a repo, run the end-of-cycle Git postcondition (see skill Phase 5) and attach the verdict to the summary
6. **Summarize**: Output concise recap with accomplishments, lessons, and next steps

## When to Use

- End of a work session (before context runs out)
- After resolving a complex problem (>1h of work)
- After completing assigned tasks
- Before handing off to another agent or session

## Output

A structured markdown summary including:
- Tasks accomplished with status
- 3-5 key lessons learned
- Files updated (memory, docs)
- Git postcondition verdict (or motivated `[SKIP-CHECK]` if read-only session)
- Recommended next steps
