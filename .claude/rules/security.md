# Securite — Regles Agents

**Version:** 1.0.0 (harmonized Claude + Roo, #1051)
**MAJ:** 2026-04-08

---

## Secrets et Credentials

- **JAMAIS** de cles API, tokens, mots de passe dans le code, commits, issues, ou commentaires GitHub
- **JAMAIS** committer `.env`, `credentials.json`, fichiers contenant des secrets
- Les secrets partagés entre machines passent par **RooSync** (GDrive), PAS par git
- Si un secret est detecte dans un commit : **revoquer immediatement**, puis nettoyer l'historique git

## Fichiers sensibles (ne JAMAIS committer)

- `.env`, `.env.*` (variables d'environnement avec cles)
- `~/.claude.json` (config MCP avec potentiels tokens)
- `credentials.json`, `*.key`, `*.pem`
- Tout fichier contenant `API_KEY`, `SECRET`, `TOKEN`, `PASSWORD`

## Pre-commit

Avant chaque commit, verifier :
- `git diff --cached` ne contient pas de patterns secrets (`API_KEY=`, `sk-`, `ghp_`, `Bearer`)
- Aucun `.env` n'est dans le staging area (`git diff --cached --name-only | grep -i env`)

## GitHub Secret Scanning

- Les alertes GitHub secret scanning doivent etre resolues **immediatement**
- Un secret expose = incident majeur → revoquer la cle, notifier le coordinateur

## Acces et Permissions

- Ne pas escalader les permissions sans approbation utilisateur
- Ne pas modifier les branch protection rules
- Ne pas desactiver les hooks pre-commit (`--no-verify` INTERDIT sauf demande explicite)

---

**Applicable a :** Claude Code ET Roo Code (memes regles pour les deux agents).
