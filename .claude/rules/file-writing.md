# File Writing Patterns - Claude Code

**Version:** 1.0.0
**Created:** 2026-03-24
**Issue:** #848

---

## Tool Selection

| Situation | Tool | Notes |
|-----------|------|-------|
| **Modify existing file** | `Edit` | MUST `Read` first. Preserves indentation. Preferred. |
| **Create new file** | `Write` | Only for new files or full rewrites. `Read` first if file exists. |
| **Append content** | `Edit` (match last block, replace with block + new content) | Never use `Write` to append (overwrites). |
| **Shell-generated output** | `Bash` with redirection | For script-generated files only. |

### Key Constraints

- **`Edit` requires `Read` first** -- the tool will fail otherwise, even for `replace_all`.
- **`Edit` old_string must be unique** -- provide enough surrounding context. Use `replace_all` only for renames.
- **`Write` overwrites entirely** -- never use it on an existing file without reading it first and preserving all content.

---

## Encoding and Platform

**PowerShell BOM, Join-Path, and line ending gotchas are documented in `~/.claude/CLAUDE.md` (global).** Do not duplicate here. Key point: if you must write files via `Bash` using PowerShell, use `[System.IO.File]::WriteAllText()` with UTF-8 no-BOM.

For `Edit` and `Write` tools: encoding is handled automatically (UTF-8 no-BOM). No special action needed.

---

## INTERCOM / Log Files -- Append-Only

INTERCOM files (`.claude/local/INTERCOM-*.md`) are **append-only, chronological**. See `intercom-protocol.md` for the full protocol.

Summary:
1. **Read** the file first.
2. **Edit** by matching the last separator `---` and replacing it with the last separator + new message + new separator.
3. **Never** insert at the top. **Never** overwrite with `Write`.

---

## Backup Before Destructive Operations

Before any operation that replaces large sections of a file:
1. Read the file and verify you understand its structure.
2. If replacing >50% of the content, consider whether `Write` (full rewrite) is safer than `Edit` (partial match risk).
3. For critical files (configs, registries), verify with `Bash` after writing: `wc -l`, `head -5`, or a syntax check.

---

## References

- Roo equivalent: `.roo/rules/08-file-writing.md` (Qwen 3.5 size limits, `write_to_file` / `replace_in_file`)
- Global gotchas: `~/.claude/CLAUDE.md` section "Windows / PowerShell Gotchas"
- INTERCOM protocol: `.claude/rules/intercom-protocol.md`

---

**Last updated:** 2026-03-24
