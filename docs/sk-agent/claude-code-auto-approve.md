# Auto-Approbation call_agent dans Claude Code

**Issue:** #2059
**Date:** 2026-05-08
**Machines concernees:** po-2023, po-2024, po-2025, po-2026

## Probleme

Le tool `call_agent` du MCP sk-agent nécessite une approbation utilisateur a CHAQUE appel dans Claude Code. Cela bloque les workflows autonomes (cycles 24h+) car l'utilisateur doit etre present pour approuver chaque appel.

## Solution: Configuration d'auto-approbation

Ajouter cette configuration dans `~/.claude/settings.json` (global, pas project-level):

```json
{
  "permissions": {
    "allow": [
      "mcp__sk-agent__call_agent",
      "mcp__sk-agent__list_agents",
      "mcp__sk-agent__list_conversations",
      "mcp__sk-agent__run_conversation",
      "mcp__sk-agent__end_conversation",
      "mcp__sk-agent__list_tools",
      "mcp__sk-agent__review_pr",
      "mcp__sk-agent__install_libreoffice",
      "mcp__sk-agent__diagnostics"
    ]
  }
}
```

## Pourquoi tous les outils sk-agent ?

`call_agent` est l'outil unifie multi-agents (vision incluse). Les anciens alias dedies (`analyze_image`, `analyze_document`, `analyze_video`, `zoom_image`, `ask`, `list_models`) ont ete **retires** lors de la consolidation #522 (#2307 Phase 2) — passer desormais par `call_agent`. Auto-approuver l'ensemble des outils sk-agent **servis** garantit un fonctionnement autonome complet:

1. `call_agent` est l'outil principal documenté (remplace les anciens alias vision)
2. Les autres outils servis (`run_conversation`, `list_agents`, `list_conversations`, `list_tools`, `end_conversation`, `review_pr`, `install_libreoffice`, `diagnostics`) couvrent les workflows multi-agents et le diagnostic
3. La liste d'outils a auto-approuver doit couvrir TOUS les outils sk-agent servis pour un fonctionnement autonome complet

## Verification

Apres avoir ajoute la configuration:

1. Redemarrer la session Claude Code
2. Tester un appel `call_agent` — il ne doit plus y avoir de prompt d'approbation
3. Verifier que les autres outils sk-agent fonctionnent aussi sans approbation

## Note sur Roo Code

Dans Roo Code, l'auto-approbation est geree via `mcp_settings.json` avec le champ `alwaysAllow`. Voir [`roo-config/mcp/reference-alwaysallow.json`](../../roo-config/mcp/reference-alwaysallow.json).

## Tools sk-agent exposes (9 servis)

| Tool | Description |
|------|-------------|
| `call_agent` | Appel unifie vers un agent sk-agent (vision incluse) |
| `list_agents` | Lister les agents disponibles |
| `list_conversations` | Lister les conversations |
| `run_conversation` | Lancer une conversation multi-agent |
| `end_conversation` | Terminer une conversation |
| `list_tools` | Lister les outils disponibles |
| `review_pr` | Review de PR multi-agents |
| `install_libreoffice` | Installer LibreOffice (conversion documents) |
| `diagnostics` | Diagnostics du serveur sk-agent |
