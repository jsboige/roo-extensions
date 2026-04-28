# Audit Pression Disque — myia-web1

**Date :** 2026-04-28T23:45:00Z
**Machine :** myia-web1
**Issue :** #1807
**Agent :** Roo Code (code-complex, GLM-5.1)

---

## A. Vue d'ensemble disque

| Volume | Utilisé | Libre | Total | % Utilisation | Niveau |
|--------|---------|-------|-------|---------------|--------|
| C:\    | 83.13 GB | 16.52 GB | 99.66 GB | **83.4%** | 🟡 |

**Niveau d'alerte : 🟡 70-85%** — Zone de vigilance. Pas critique mais à surveiller.

---

## B. Top consommateurs

### B.1 Répertoires principaux (Depth 4)

| Répertoire | Taille |
|------------|--------|
| `C:\Windows\WinSxS` | 10.61 GB |
| `C:\Users\Administrator\.vscode` | 2.64 GB |
| `C:\Windows\Installer` | 2.51 GB |
| `C:\ProgramData` | 2.23 GB |
| `C:\Program Files` | 2.27 GB |
| `C:\Program Files (x86)` | 1.80 GB |
| `C:\Users\Administrator\Downloads` | 0.70 GB |
| `C:\dev\roo-extensions` | 0.28 GB |
| `C:\Users\Administrator\.claude` | 0.17 GB |
| `C:\Users\Administrator\.nuget` | 0.09 GB |
| `C:\Drive` (GDrive) | 0.03 GB |

### B.2 VS Code Extensions (Top 10)

| Extension | Taille |
|-----------|--------|
| ms-dotnettools.csharp-2.130.5 | 302 MB |
| ms-vscode.powershell-2025.4.0 | 301 MB |
| anthropic.claude-code-2.1.121 | 250 MB |
| anthropic.claude-code-2.1.120 | 249 MB |
| ms-vscode.cpptools-1.32.1 | 241 MB |
| continue.continue-1.2.22 | 229 MB |
| ms-dotnettools.csdevkit-3.10.14 | 170 MB |
| redhat.java-1.54.0 | 168 MB |
| databricks.databricks-2.10.6 | 161 MB |
| rooveterinaryinc.roo-cline-3.53.0 | 150 MB |

**Total extensions : ~2.22 GB**

### B.3 Top 10 fichiers les plus volumineux

| Taille | Fichier |
|--------|---------|
| 241.5 MB | `.vscode/extensions/anthropic.claude-code-2.1.121/.../claude` (binaire) |
| 240.2 MB | `.vscode/extensions/anthropic.claude-code-2.1.120/.../claude` (binaire) |
| 206.3 MB | `Downloads/dotnet-sdk-10.0.102-win-x64.exe` |
| 205.0 MB | `Downloads/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle` |
| 109.6 MB | `Downloads/PowerShell-7.6.0-win-x64.msi` |
| 76.5 MB | `.vscode/extensions/ms-vscode.cpptools-1.32.1/.../clang-tidy.exe` |
| 67.0 MB | `Downloads/Git-2.49.0-64-bit.exe` |
| 67.0 MB | `Downloads/Git-2.49.0-64-bit (1).exe` (doublon) |
| 63.0 MB | `.vscode/extensions/databricks.databricks-2.10.6/.../terraform.exe` |
| 53.2 MB | `.vscode/extensions/continue.continue-1.2.22/.../extension.js` |

### B.4 Claude sessions

| Répertoire | Taille |
|------------|--------|
| projects/ | 135.31 MB |
| telemetry/ | 6.92 MB |
| file-history/ | 1.98 MB |
| backups/ | 0.12 MB |
| **Total .claude/** | **~144.6 MB** |

### B.5 Roo globalStorage

| Répertoire | Taille |
|------------|--------|
| .skeletons/ | 7.25 MB |
| tasks/ | 3.07 MB |
| cache/ | 0.88 MB |
| settings/ | 0.76 MB |
| **Total Roo** | **~723 MB** |

> Note : La taille totale de 723 MB pour le globalStorage Roo semble élevée par rapport aux sous-répertoires listés. Le reste est probablement dans des fichiers de state SQLite (`state.vscdb`) et autres fichiers non énumérés.

---

## C. Docker

**Docker n'est PAS installé** sur myia-web1. La commande `docker system df` retourne "Le terme «docker» n'est pas reconnu".

**Impact :** 0 MB — Pas d'espace occupé par Docker.

---

## D. Qdrant

**Qdrant n'est PAS installé** sur myia-web1. Aucun répertoire qdrant trouvé dans les chemins standards (`C:\qdrant`, `C:\ProgramData\qdrant`, `C:\Users\Administrator\qdrant`, `C:\dev\qdrant`, `C:\Drive\qdrant`).

**Impact :** 0 MB — Pas d'espace occupé par Qdrant.

---

## E. Fichiers temporaires

| Fichier | Taille |
|---------|--------|
| MpCmdRun.log | 0.87 MB |
| MpSigStub.log | 0.84 MB |
| RazorEngine_* (8 fichiers) | ~0.32 MB |
| **Total C:\Windows\Temp** | **2.86 MB** |

**Impact négligeable.**

---

## F. Google Drive

| Répertoire | Taille |
|------------|--------|
| Mon Drive/CardPen/ | 19.81 MB |
| Mon Drive/roo/ | 0.11 MB |
| Tests divers (fichiers vides) | ~0 MB |
| **Total GDrive** | **~27 MB** |

**Impact négligeable.**

---

## G. Classification provisoire

### G.1 Sessions historiques légitimes → PRÉSERVER

- `.claude/projects/` (135 MB) — Sessions de travail Claude Code, légitimes
- Roo globalStorage (723 MB) — State, skeletons, cache — **PRÉSERVER**

### G.2 À investiguer

- **VS Code extensions doublons** : `anthropic.claude-code-2.1.120` (249 MB) est une version antérieure de `2.1.121` (250 MB). L'ancienne version pourrait être supprimée.
- **Downloads non nettoyés** : 720 MB dont des installateurs déjà utilisés (dotnet-sdk, PowerShell, Git) et un doublon `Git-2.49.0-64-bit (1).exe`.

### G.3 Candidates suppression (après validation)

| Cible | Taille estimée | Risque |
|-------|---------------|--------|
| Claude-code extension v2.1.120 (ancienne) | ~249 MB | Faible (v2.1.121 active) |
| Downloads/installateurs déjà installés | ~550 MB | Faible (déjà installés) |
| Git doublon dans Downloads | ~67 MB | Nul |
| **Total récupérable** | **~866 MB** | |

---

## H. Recommandations

### H.1 Actions immédiates (safe, sans risque)

1. **Supprimer l'extension Claude Code v2.1.120** : `~249 MB` — v2.1.121 est active
2. **Nettoyer Downloads** : Supprimer les installateurs déjà utilisés : `dotnet-sdk-10.0.102-win-x64.exe` (206 MB), `PowerShell-7.6.0-win-x64.msi` (110 MB), `Git-2.49.0-64-bit.exe` + doublon (134 MB) = `~450 MB`
3. **Gain estimé : ~700 MB** → Disque passerait de 83.4% à ~82.7%

### H.2 Actions différées

1. **Extensions VS Code inutilisées** : Évaluer si csharp (302 MB), java (168 MB), databricks (161 MB), cpptools (241 MB) sont nécessaires sur web1. Potentiel `~870 MB` supplémentaires.
2. **WinSxS cleanup** : `Dism /Online /Cleanup-Image /StartComponentCleanup` — Potentiel 1-3 GB mais nécessite redémarrage potentiel.

### H.3 Estimation gain total

| Action | Gain | Priorité |
|--------|------|----------|
| Extension Claude v120 + Downloads | ~700 MB | Immédiate |
| Extensions inutilisées | ~870 MB | Différée |
| WinSxS cleanup | 1-3 GB | Différée |
| **Total potentiel** | **2.6-4.6 GB** | |

Après cleanup complet : disque passerait de 83.4% à ~78-80% (🟢).

---

## I. Résumé exécutif

| Métrique | Valeur |
|----------|--------|
| Disque C:\ | 83.4% utilisé (🟡) |
| Espace libre | 16.52 GB |
| Docker | Non installé |
| Qdrant | Non installé |
| Temp files | 2.86 MB (négligeable) |
| Plus gros poste | WinSxS (10.6 GB) + VS Code ext (2.6 GB) |
| Gain cleanup immédiat | ~700 MB |
| Gain cleanup total | 2.6-4.6 GB |

**web1 est en zone 🟡 mais pas critique.** Pas de pression Docker/Qdrant. Les principaux gains sont sur les extensions VS Code et les Downloads.

---

*Rapport généré par Roo Code (myia-web1) — Issue #1807*
