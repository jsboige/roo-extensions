# Hook `block-placeholder` — garde anti envoi-first (#3367)

**Script :** [`scripts/hooks/block-placeholder.js`](../../../scripts/hooks/block-placeholder.js)
**Origine :** hook Tier-1 du groupe NanoClaw (ai-01), mandat Emerjesse 01/09 14:39Z
**Preuve de valeur :** 8 interceptions le seul 01/09 (chaque interception = un envoi-first parasite évité)

---

## Ce que ça protège

La règle Tier 1 : **le premier tool call d'un tour (cron ou interactif) doit être une LECTURE** (dashboard, `gh api` lecture, Read) — jamais un envoi Telegram. Née du réflexe récurrent du 30/08 (ids 35985→36187, 5 occurrences en un jour). La règle prose seule ne tient pas sous compaction ; le hook est le seul garde structurel fiable.

## Contrat du script

| Entrée/Sortie | Comportement |
|---|---|
| stdin | payload JSON du PreToolUse — inspecte `tool_input.text` |
| exit 2 + stderr | **BLOCAGE** si le texte matche `^\s*placeholder\s*$` (insensible à la casse) |
| exit 0 | laisser passer — y compris sur erreur de parse (**fail-open** : un hook cassé ne coupe jamais l'outil) |

## Câblage par groupe (settings harness — [INTERACTIVE-ONLY] sur la machine hôte)

Dans le `~/.claude/settings.json` (harness de la machine, jamais dans le repo) du groupe concerné :

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__nanoclaw__send_message",
        "hooks": [
          {
            "type": "command",
            "command": "node \"c:\\dev\\roo-extensions\\scripts\\hooks\\block-placeholder.js\""
          }
        ]
      }
    ]
  }
}
```

Adapter le chemin au clone local du repo sur la machine hôte. Après édition : **restart de la session** du groupe (les hooks se chargent au démarrage).

## Limites connues (déclarées, pas corrigées)

- **Ne couvre que la signature littérale « placeholder ».** L'extension au cas général « tout `send_message` en 1er tool call d'un tour cron » exige un état *position-dans-le-tour* qu'un PreToolUse stateless n'a pas. Pistes (option #3367.2, à discuter) : compteur de tool calls par session en fichier temp, ou hook `SessionStart` qui arme le garde pour les N premières secondes.
- **Matcher `mcp__nanoclaw__send_message`** — les groupes sans MCP NanoClaw ne tirent jamais (matcher sans effet, pas d'erreur).

## Historique

| Date | Événement |
|---|---|
| 30/08 | Incident fondateur : 5 envois-first en un jour (ids 35985→36187) côté NanoClaw |
| 01/09 | Hook créé côté NanoClaw (ai-01) — 8 interceptions le même jour |
| 01/09 | #3367 : port au repo (script canonique + cette doc) pour adoption par les autres groupes |
