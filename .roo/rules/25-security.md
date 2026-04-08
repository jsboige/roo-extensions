# Securite — Regles Agents

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/security.md)
**MAJ:** 2026-04-08

## Secrets et Credentials

- **JAMAIS** de cles API, tokens, mots de passe dans le code, commits, issues, ou commentaires
- **JAMAIS** committer `.env`, `credentials.json`, fichiers contenant des secrets
- Secrets partages entre machines : **RooSync** (GDrive), PAS git
- Secret detecte dans un commit : **revoquer immediatement**, puis nettoyer

## Fichiers sensibles (ne JAMAIS committer)

`.env`, `.env.*`, `~/.claude.json`, `credentials.json`, `*.key`, `*.pem`, tout fichier avec `API_KEY`/`SECRET`/`TOKEN`/`PASSWORD`

## Pre-commit

Verifier : pas de patterns secrets (`API_KEY=`, `sk-`, `ghp_`, `Bearer`), pas de `.env` dans staging.

## GitHub Secret Scanning

Alertes = resolution **immediate**. Secret expose = incident majeur.

## Acces et Permissions

Pas d'escalade permissions sans approbation. Pas de modification branch protection. Pas de `--no-verify` (INTERDIT sauf demande explicite).

---
**Historique versions completes :** Git history avant 2026-04-08
