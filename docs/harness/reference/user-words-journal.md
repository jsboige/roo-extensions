# user-words-journal — what the user said survives the session

**Script:** [`scripts/hooks/user-words-journal.js`](../../../scripts/hooks/user-words-journal.js)
**Tests:** [`scripts/hooks/tests/user-words-journal.test.js`](../../../scripts/hooks/tests/user-words-journal.test.js) (22 assertions, run in CI, static job)
**Origin:** user, 20/10/2026.
- « si tu n'as pris aucune note de tout ce que je t'ai dit entre hier et aujourd'hui, c'est comme si je pissais dans un violon car tu auras tout oublié demain »
- « un resserrage de harnais pour lutter non pas seulement contre l'entropie, mais aussi sur l'amnésie systémique »

## The failure it closes

- Agent memory records what the agent **did**: cycles, merges, decisions. It does not record what the user **said**.
- Within a session, every compaction summary is written by the agent itself, so a directive it under-weighted disappears without a trace.
- Across sessions, nothing re-reads a transcript.

Measured on ai-01, 18-20/10, one coordinator session: 13 compactions, 16 human messages, 7 of them sent mid-turn. The prose rule written for the same failure on 02/10 did not prevent it.

## Mechanism

| Event | Role |
|---|---|
| `Stop`, `PreCompact` (and `SessionEnd` if wired) | **capture**: incremental scan of the transcript from a stored byte offset; every entry marked `origin.kind == "human"` is appended verbatim to the journal |
| `SessionStart` (`startup`, `resume`, `clear`, `compact`) | **recall**: last 7 days of the journal, chronological, injected as `additionalContext` (budget 8000 characters, newest kept, overflow named) |

Two transcript shapes carry human words. Both were measured on 20/10, Claude Code 2.1.301:
- `type:"user"` with `origin.kind:"human"` is a typed prompt;
- `type:"attachment"` with `attachment.type:"queued_command"` and `attachment.origin.kind:"human"` is a message sent **mid-turn**. That is the founding case, so a capture that misses it misses the point.

Never captured, because they carry no human origin:
- cron-fired prompts;
- task notifications (`origin.kind:"task-notification"`);
- skill bodies (`isMeta`);
- compaction summaries;
- tool results.

A typed slash command is kept as `/cmd args` only when it has arguments.

**Files** sit in the workspace's own memory directory, `<dir of transcript_path>/memory/`:
- `user-words-journal.jsonl`: one line per message, `{ts, session_id, key, text}`;
- `user-words-journal.state.json`: byte offset per transcript, plus the last 2000 seen keys used for dedup.

**Cost** (measured on a 33 MB transcript): first scan 0.2 s, incremental scans about 0.1 s. Every hook path exits 0, so it never blocks a turn or a session.

## Installation

1. `settings.template.json` carries the three entries. `Deploy-GlobalConfig.ps1` adds them, resolving `<<repo>>` to the main checkout.
   - Signatures are scoped per event since this change: before it, a command already wired on `Stop` counted as present on `PreCompact` and `SessionStart` too, so it was never added there.
2. Backfill once, so the first recall is not empty:
   `node <repo>/scripts/hooks/user-words-journal.js --backfill "%USERPROFILE%\.claude\projects\<hash>" 7`
3. Effect: hooks added to `settings.json` are read when a session starts, not live. A running session picks them up at its next start or resume.

## Rules that go with it

- **The journal is not memory.** It drops out of recall after 7 days. A directive that must last longer is promoted into a memory fiche with the verbatim quote before the end of the cycle.
- **A directive already given is never asked again.** The recall header says so to the model.
- **Privacy:** the journal holds the same text as the transcripts it copies, in the same user profile. It is never versioned, posted or sent.
