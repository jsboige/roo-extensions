# Roo Scheduler - Orchestration Automatique

## Vue d'ensemble

Le Roo Scheduler utilise la fonctionnalite native de **Roo Code** (VS Code) pour lancer des taches planifiees. Roo demarre en mode `orchestrator-simple`, lit l'INTERCOM, execute les taches, et rapporte les resultats.

## Architecture

```
.roo/
  schedules.json              # Config Roo Scheduler (declencheurs + taches)

roo-config/scheduler/
  prompts/
    orchestrator-scheduled.md  # Prompt pour le mode planifie
  README.md                    # Cette documentation
```

## Workflow

1. **Roo Scheduler** declenche une tache a intervalle configure
2. Roo demarre en mode **orchestrator-simple**
3. Lit le prompt `orchestrator-scheduled.md`
4. Execute le workflow en 5 etapes :
   - Etape 1 : Lire l'INTERCOM (urgences, taches de Claude Code)
   - Etape 2 : Verifier l'etat du workspace (git status)
   - Etape 3 : Executer les taches (deleguer aux modes -simple/-complex)
   - Etape 4 : Rapporter dans l'INTERCOM ([DONE] ou [ERROR])
   - Etape 5 : Ne PAS commiter (Claude Code validera)
5. En cas d'erreur critique, ecrire [ERROR] dans l'INTERCOM

## Escalade

Si une erreur critique est detectee :
- Roo ecrit un message [ERROR] dans l'INTERCOM
- Claude Code le voit lors de son prochain tour de sync
- Claude Code analyse et corrige

## Configuration

Le fichier `.roo/schedules.json` est configure par l'utilisateur dans les settings Roo Code.

## Regles de securite

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Verifier `git status` AVANT toute modification
4. Lire INTERCOM EN PREMIER (urgences possibles)
5. Deleguer uniquement aux modes `-simple` ou `-complex`
6. Ne JAMAIS faire `git checkout`/`git pull` dans le submodule

## Historique

L'ancienne infrastructure (PowerShell Task Scheduler + orchestration-engine.ps1) a ete retiree en fevrier 2026. L'approche actuelle utilise le Roo Scheduler natif integre a VS Code.
