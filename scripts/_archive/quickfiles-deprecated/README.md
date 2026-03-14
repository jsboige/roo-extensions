# QuickFiles MCP Scripts (Archived - Deprecated)

**Archived:** 2026-03-13
**Reason:** QuickFiles MCP was deprecated and replaced by native Read/Write tools
**Status:** MCP removed from project (Issue #368, CONS-1)

---

## Scripts Archived

### Configuration & Validation
- `configure-quickfiles-sddd.ps1` - SDDD configuration script
- `validate-quickfiles-config.ps1` - Config validation
- `quickfiles-simple-validation.ps1` - Simple validation

### Testing & Accessibility
- `test-quickfiles-80-plus.ps1` - Testing 80+ tools
- `test-quickfiles-accessibility.ps1` - Accessibility tests
- `test-quickfiles-validation-20251102.ps1` - Dated validation test

### Optimization
- `optimize-quickfiles.ps1` - Full optimization
- `optimize-quickfiles-simple.ps1` - Simple optimization

---

## Migration Notes

**QuickFiles MCP was replaced by:**
- Native `Read` tool for file reading
- Native `Write` tool for file creation/modification
- Native `Glob` tool for file pattern matching

No special MCP configuration needed anymore.

---

**Archived by:** myia-po-2026 (Claude Code)
**Issue:** #656 - Idle Scheduler Improvement
**Reference:** Issue #368 - Migration from github-projects-mcp to gh CLI
