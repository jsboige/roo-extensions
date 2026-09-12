# Hook `guard-pdf-read` — borne les lectures PDF multimodales (#3579)

**Script :** [`scripts/hooks/guard-pdf-read.js`](../../../scripts/hooks/guard-pdf-read.js)
**Origine :** incident CoursIA 10/09/2026 — session bloquée toute une nuit par un seul `Read` PDF (issue #3579)
**Statut d'interception :** **VÉRIFIÉ par test reproductible** le 2026-09-11 sur po-2026 (Claude Code 2.1.41) — voir § Statut d'interception

---

## Ce que ça protège

Mesures firsthand dans le JSONL de la session incidentée :

| Métrique | Valeur |
|---|---|
| Pages demandées (`pages: "1-15"`) | 15 JPEG base64 |
| Poids par page | 203 284 – 342 952 caractères |
| Record JSONL du tool result | **4 388 885 octets** (injectés en UN bloc) |
| Requête suivante | `context_length_exceeded` |
| `/continue` | reproduit l'erreur à chaque fois |
| `/compact` | **impossible** — sa requête hérite du contexte excessif |
| Transcript au diagnostic | 54 139 366 octets |

Reproduction upstream : [anthropics/claude-code#81792 (commentaire)](https://github.com/anthropics/claude-code/issues/81792#issuecomment-5630535354) · aussi #80449, #26018, #13480.

Le built-in `Read` autorise jusqu'à **20 pages PDF par appel**, n'expose **aucun budget d'octets**,
**aucun mode texte-only**, et ne bénéficie pas du chemin de persistance/troncature des gros
résultats **texte** quand il rend des images.

## Les trois budgets — à ne jamais confondre

L'incident a exposé une confusion entre trois limites distinctes :

| # | Budget | Qui le règle | Couvre l'incident ? |
|---|--------|--------------|---------------------|
| 1 | **Tokens / contexte** | `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | **Non** — ce sont des seuils de compaction client ; ils ne plafonnent pas un tool result avant injection |
| 2 | **Octets sérialisés de la requête** | Le backend/route (limite de payload HTTP ou tokens réels du modèle mappé) | **Non** — c'est lui qui rejette (`context_length_exceeded`), *après* l'injection |
| 3 | **Résultat multimodal atomique** | **RIEN nativement** — c'est le trou #3579 | C'est ce que ce hook borne |

Conséquence : « une grande fenêtre n'est jamais dangereuse » est vrai **pour le budget 1 seul**
(compaction tokenique). Pour le budget 3, une grande fenêtre rend le défaut *moins visible* et
laisse accumuler davantage de payload binaire avant le rejet.

## Contrat du script

| Entrée/Sortie | Comportement |
|---|---|
| stdin | payload JSON du PreToolUse — inspecte `tool_input.file_path` et `tool_input.pages` |
| exit 2 + stderr | **BLOCAGE** si `file_path` finit par `.pdf` (insensible à la casse) ET (`pages` absent OU nombre de pages > plafond) |
| exit 0 | laisser passer — y compris non-PDF, PDF borné, et sur erreur de parse (**fail-open** : un hook cassé ne coupe jamais l'outil) |

- **Plafond :** `PDF_READ_MAX_PAGES` (env, défaut **2**).
- `pages` absent = blocage : le défaut du built-in lit jusqu'à 20 pages.
- Formats `pages` comptés : `"3"`, `"1-15"`, plages séparées par virgule (`"1-2, 5"`).
- Le message de blocage remonté au modèle contient la règle de remplacement (texte d'abord, tranches 1-2 pages).

## Statut d'interception — VÉRIFIÉ (tests reproductibles)

La question ouverte (#3579, proposition 2) : les hooks `PreToolUse` peuvent-ils intercepter
fiablement le built-in `Read` sur un binaire, ou le pipeline natif PDF→image les contourne-t-il ?

**Réponse mesurée : le hook intercepte AVANT le pipeline natif.** Le contournement redouté
n'existe pas à ce niveau — le blocage empêche l'appel d'atteindre la couche de rendu.

### Tests synthétiques (payloads directs, 8/8 PASS — 2026-09-11)

```bash
H=scripts/hooks/guard-pdf-read.js
echo '{"tool_input":{"file_path":"C:/x/readme.txt"}}'            | node $H  # exit 0 (non-PDF)
echo '{"tool_input":{"file_path":"C:/x/doc.pdf","pages":"1-15"}}'| node $H  # exit 2 (15 > 2)
echo '{"tool_input":{"file_path":"C:/x/doc.pdf","pages":"1-2"}}' | node $H  # exit 0 (borné)
echo '{"tool_input":{"file_path":"C:/x/doc.pdf","pages":"3"}}'   | node $H  # exit 0 (1 page)
echo '{"tool_input":{"file_path":"C:/x/doc.pdf"}}'               | node $H  # exit 2 (pages absent)
echo '{"tool_input":{"file_path":"C:/x/DOC.PDF","pages":"1-9"}}' | node $H  # exit 2 (casse)
echo 'not json at all'                                           | node $H  # exit 0 (fail-open)
echo '{"tool_input":{}}'                                         | node $H  # exit 0 (fail-open)
```

### Test e2e (`claude -p` réel, 2026-09-11, po-2026, Claude Code 2.1.41)

```bash
# 1. Settings jetables câblant le hook sur le matcher "Read"
mkdir -p /tmp/pdf-hook-test && cat > /tmp/pdf-hook-test/settings.json <<'EOF'
{ "hooks": { "PreToolUse": [ { "matcher": "Read", "hooks": [ { "type": "command",
  "command": "node <REPO>/scripts/hooks/guard-pdf-read.js" } ] } ] } }
EOF

# 2. Session headless demandant la lecture interdite (CLAUDECODE unset = bypass légitime du garde anti-nesting)
env -u CLAUDECODE claude -p "Use the Read tool to read the file <PDF> with pages 1-15. \
  Whatever happens, report in one sentence exactly what the tool returned." \
  --settings /tmp/pdf-hook-test/settings.json --allowedTools "Read"
```

Résultats observés :

- **`pages 1-15` → BLOQUÉ.** La réponse du modèle paraphrase le message stderr du hook
  (« blocked by a PreToolUse hook (`guard-pdf-read`) … advising to extract text first with
  pdftotext or re-read in slices of 2 pages maximum »). Les images n'entrent jamais dans le contexte.
- **`pages 1-2` → PASSE le hook** (l'appel a bien été exécuté — sur po-2026 il échoue ensuite
  au rendu `pdftoppm` absent, ce qui prouve que l'exécution a eu lieu : couche différente).

**Nuance Poppler :** le rendu PDF→image du built-in nécessite `pdftoppm` (Poppler). Absent de
po-2026 → `Read` PDF y échoue au rendu (donc po-2026 n'est pas exposée au vecteur aigu). Les
machines où l'incident PEUT se produire ont Poppler — et Poppler fournit aussi `pdftotext` :
la procédure text-first y est exécutable nativement.

## Procédure PDF — text-first, vision bornée

1. **Texte d'abord, toujours.** `pdftotext` (sur cette flotte : `C:\Program Files\Git\mingw64\bin\pdftotext.exe`),
   `pypdf`/`pymupdf` (python), ou markitdown (MCP Roo). Contrôle de rendement avant d'aller plus loin :
   ```bash
   pdftotext doc.pdf - | wc -c   # rendement texte de TOUT le document
   ```
   Mesure réelle (11/09, PDF 17 pages) : **56 738 chars de texte pour tout le document — moins
   qu'UNE SEULE page rendue en image** (203-343k chars/page). Ordre de grandeur ~10×.
2. **Vision bornée, seulement si nécessaire** (tableau, figure, scan sans couche texte) :
   `Read` avec `pages: "N"` ou `"N-M"` où `M-N+1 ≤ 2`. Jamais 10-20 pages en un appel.
3. **Jamais relire le PDF après une erreur de contexte** (`context_length_exceeded`,
   erreur 413, etc.) dans la même session : le payload est déjà dans l'historique, `/compact`
   en hérite et ne peut pas produire de résumé. La seule réparation est une **session fraîche**.
4. Le transcript JSONL reste **SANCTUAIRE** — preuve intacte, jamais tronqué (cf.
   [context-explosion-runbook](context-explosion-runbook.md)).

## Câblage (settings harness — [INTERACTIVE-ONLY] sur la machine hôte)

Dans le `~/.claude/settings.json` (harness de la machine, jamais dans le repo) :

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          { "type": "command",
            "command": "node \"c:\\dev\\roo-extensions\\scripts\\hooks\\guard-pdf-read.js\"" }
        ]
      }
    ]
  }
}
```

Adapter le chemin au clone local. Plafond personnalisé : `"env": {"PDF_READ_MAX_PAGES": "2"}`
dans le même bloc `command` n'existe pas — poser la variable au niveau du système ou s'en tenir
au défaut 2. Après édition : **restart de la session** (les hooks se chargent au démarrage).

## Arbitrage flotte (enregistré 2026-09-11, #3579)

| Option | Décision | Motif |
|---|---|---|
| **Règle opératoire versionnée** (`.claude/rules/context-window.md`, auto-chargée partout) | **RETENUE** | Seul vecteur qui tient fleet-wide sans toucher au canon : Hermes (11/09) a vérifié que les 3 variables de l'incident sont portées par le canon `hc-claude-settings-1.0.1` (mode `enforce-value`, #3544) — un garde en `CLAUDE.local.md` serait écrasé à la vague d'harmonisation suivante |
| **Garde hook opt-in** (`guard-pdf-read.js`, câblage par machine/groupe) | **RETENUE** | Le statut d'interception est VÉRIFIÉ (ci-dessus) ; chaque groupe décide de l'armer selon son exposition réelle aux PDF |
| **Deny global `Read(**/*.pdf)`** | **REJETÉ** (révisable) | Trop radical : usages légitimes (CoursIA, docs specs) ; le hook borné couvre le risque aigu sans couper la lecture 1-2 pages. Réviser si le bisect Sol (ci-dessous) révèle une fenêtre backend encore plus étroite — **résolu 12/09 : pas plus étroite (§ Mesure), le rejet tient** |

Toute évolution vers un canon (nouvelle clé ou fenêtre corrigée) = décision coordinateur/user.

## Mesure de la fenêtre effective de la route Sol — MESURÉE (2026-09-12, po-204)

**Pourquoi :** le canon pose `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` et
`CLAUDE_CODE_AUTO_COMPACT_WINDOW=280000`, mais la fenêtre effective est celle du **modèle mappé
par le proxy** (mesuré Hermes 11/09 : Claudish `.50`/`.46` mappent sonnet→glm-5.3 et servent
`gpt-5.6-sol` ; `.51` mappe glm-5.2). Si le backend acceptait < 280k, l'autocompact client ne se
déclencherait **jamais** avant le rejet backend — dérive chronique pour toute session longue.

**Méthode (reproductible) :** bisect authentifié depuis **po-204** (siège porteur d'une clé
Claudish valide — `x-proxy-key` du `~/.claude/settings.json` local, jamais loggée) contre le hub
`http://192.168.0.50:3000` : requêtes `POST /v1/messages` à padding gradué (`"a "` répété,
calibré 1,14 tok/paire sur la sonde 100 tok, overhead constant +14), `max_tokens=16`, lecture du
`usage.input_tokens` **renvoyé par la route** sur chaque succès. Script jetable hors repo.
19 requêtes au total. (po-2025/ai-01 aussi éligibles ; po-2026 exclu — 401, Hermes 11/09.)

**Résultats — route Sol (`gpt-5.6-sol`) :**

| Padding (tokens visés) | `input_tokens` servi | Verdict |
|---|---|---|
| 100 puis 60k→800k (8 paliers) | exact (+14 constant) | **PASS** |
| 900k (2 runs, re-confirmé) | 900 014 | **PASS** |
| 925k / 950k / 990k / 1 000k | 280 000 (artefact, ci-dessous) | **FAIL** `context_length_exceeded` |

**Fenêtre effective Sol ∈ (900 k, 925 k) tokens.** Comparaison route sonnet
(`claude-sonnet-5[1m]` → glm-5.3) : PASS à 300k et 850k — aucun rejet observé sous 850k.

**Conclusions contre les trois variables du canon :**

1. `AUTO_COMPACT_WINDOW=280000` : **SÛR** — les deux routes mesurées acceptent ≥ 850k ; le seuil
   de compaction tire à 280k, ~3× sous les fenêtres effectives. L'hypothèse de **dérive
   chronique** (rejet backend avant autocompact) est **falsifiée** pour ces deux routes.
2. `MAX_CONTEXT_TOKENS=1000000` : **SURÉVALUÉ pour Sol** — fenêtre effective ~900k.
   Arithmétique de l'incident : 4 388 885 octets ≈ ≥ 1,1 M tokens (base64 ≈ chars/4) dépassent
   la fenêtre effective **à eux seuls**, quel que soit le contexte préalable — la lecture de
   15 pages n'était faisable sur **aucune** fenêtre ; la croyance 1 M l'a juste fait paraître
   plausible côté client.
3. `AUTOCOMPACT_PCT_OVERRIDE=95` : facteur client du budget 1 — non observable via API brute,
   inchangé par la mesure.

**Arbitrage (suite) :** la fenêtre backend n'est **pas** plus étroite que le seuil de
compaction → le REJET du deny global `Read(**/*.pdf)` **tient**. Nouveau finding pour
coordinateur/user : la valeur canon `MAX_CONTEXT_TOKENS=1000000` surévalue la route Sol de ~10 %
— toute correction du canon reste décision coordinateur/user (gouvernance § Arbitrage).

**Artefact observé (RAPPORTÉ, non expliqué) :** les rejets Sol reviennent en HTTP **200** avec
`input_tokens=280000` et l'erreur `context_length_exceeded` embarquée dans le texte de sortie.
Le hub ne clamppe PAS l'entrée à 280k (800k servi intégral par la même route) ; le chiffre
apparaissant sur les échecs n'est pas la taille servie. Non bloquant — à instruire côté lane
claudish si souhaité.

## Limites connues (déclarées, pas corrigées)

- **Stateless sur les pages, pas les octets** : le hook compte les pages demandées, pas le poids
  réel — une page dense scannée peut peser 340k chars. Le plafond 2 pages borne à ~0,7 MB/appel.
- **Ne couvre que le built-in `Read`** (matcher `Read`) : paste d'images, autres outils MCP
  retournant des images = hors périmètre.
- **Fail-open** : un hook cassé ne bloque rien (cohérent avec `block-placeholder`).

## Historique

| Date | Événement |
|---|---|
| 10/09 | Incident CoursIA : `Read` PDF `pages "1-15"` → 4,39 MB injectés, session bloquée toute la nuit |
| 11/09 | #3579 ouvert (mesures JSONL firsthand + repro upstream) ; Hermes : exposition canon fleet-wide, gardes locaux contournés par le canon, bisect Sol à déléguer |
| 11/09 | Script + tests synthétiques 8/8 + e2e VÉRIFIÉ sur po-2026 (Claude Code 2.1.41) + cette doc |
| 12/09 | Bisect Sol exécuté depuis po-204 (siège Claudish) : fenêtre effective ∈ (900k, 925k) — 280k sûr, 1M surévalué ~10 %, dérive chronique falsifiée ; critère 5 de #3579 soldé |
