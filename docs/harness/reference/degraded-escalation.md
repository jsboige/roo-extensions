# Environnement dégradé — escalade immédiate, sonnerie à 2 cycles

**Version :** 1.1.0 · **Issue :** #4517 · #4746 · **MAJ :** 2026-11-15
**Source canonique :** ce fichier. Déployé flotte (tous workspaces) par
`.claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target rules`.

---

## Incident fondateur (po-2025 `CoursIA`, 01 → 03/11/2026)

Pendant deux jours, une lane a contourné un MCP qu'elle croyait mort
(`jupyter-papermill`) et a présenté son travail comme normal. Le 03/11, la sonde
de siège rend **6 LIVE, 0 DEAD** ; `jupyter-papermill` répondait en **1,18 s**
avec ses 25 outils. **Le serveur n'était pas cassé : la lane ne l'avait jamais
vérifié.**

Verbatim user (2026-11-03) :

> « Attention c'est un manquement grave au stop&repair obligatoire. Vous ne devez
> pas travailler avec des environnements dégradés, tu aurais dû escalader
> immédiatement et réclamer réparation en instruisant les autres agents de me
> prévenir si je n'arrivais pas dans les temps entre 2 cycles. Pas de workaround
> consacré. »

La règle « réparer, jamais contourner » existait déjà. Elle n'a pas mordu parce
que **rien ne bornait le temps** qu'une lane peut passer dans un environnement
dégradé **en silence** : « escalader » restait une intention portée par la
mémoire de l'agent qui l'avait posée.

---

## La règle

1. **Escalade immédiate.** Un environnement dégradé — MCP absent ou muet, kernel
   manquant, service indisponible, sonde incapable de mesurer — s'escalade
   **avant** toute tentative de contournement. « Le temps de voir » n'est pas un
   état : c'est déjà le contournement.

2. **L'échéance est dérivée, jamais déclarée.** Le post `[DEGRADED]` sur le
   dashboard `workspace` suffit ; le mécanisme calcule l'échéance
   (`posté + 2 cycles`). Un agent sous pression n'a rien à calculer, et rien à
   se rappeler.

3. **Les autres agents sont instruits explicitement.** Toute lane qui exécute
   l'organe (voir ci-dessous) pendant son cycle voit l'échéance et **alerte le
   user** quand elle est dépassée. L'instruction vit dans le mécanisme, pas dans
   le post de la lane défaillante.

4. **Aucun workaround ne se consacre.** Une sortie produite pendant la panne ne
   se rapporte pas comme un résultat normal : elle se rapporte **dégradée, avec
   la panne**. C'est la règle SOTA/Stop&Repair appliquée au cas « mon outil est
   absent », et pas seulement « l'outil a produit moins bien ».

5. **Seul `[REPAIRED]` ferme une escalade.** Un `[DONE]` ne la ferme pas — sinon
   le cycle normal consacre précisément la sortie dégradée que le mandat
   interdit. Le `[REPAIRED]` doit venir de la **même lane** ; le `[REPAIRED]`
   d'une autre lane ne ferme rien.
   **Nommer l'escalade quand la lane en a plusieurs** (#4746) : sans portée, un
   `[REPAIRED]` ferme **toutes** les escalades antérieures de la lane ; pour
   n'en fermer qu'une, ajouter une ligne dédiée `scope: <messageId | #NNNN |
   HH:MMZ>` (ou `portée:`) — la prose ne compte jamais.

`[DEGRADED]` ≠ `[BLOCKED]` : bloqué = j'attends quelqu'un d'autre ; dégradé =
**mon** environnement est cassé et je ne produis plus de résultat normal.

---

## L'organe : `scripts/diagnostic/check-degraded-escalations.py`

```bash
python scripts/diagnostic/check-degraded-escalations.py                # commande canonique : store PG, bearer lu automatiquement
python scripts/diagnostic/check-degraded-escalations.py --json
python scripts/diagnostic/check-degraded-escalations.py --ring         # sonnerie ASK-USER sur le global — tout siège équipé du bearer, une seule entrée par lot et par jour
python scripts/diagnostic/check-degraded-escalations.py --dashboard-file <copie.md>   # rejeu forensic
python scripts/diagnostic/check-degraded-escalations.py --env-file <chemin>   # autre fichier CLE=valeur (vide = aucun)
python scripts/diagnostic/check-degraded-escalations.py --selftest
```

| Exit | Sens | Ce que fait l'automate |
|---|---|---|
| `0` | aucune escalade `[DEGRADED]` dans la fenêtre lue | rien |
| `3` | escalade(s) ouverte(s), échéance non dépassée | rien — mais ce n'est **pas** « tout va bien » |
| `2` | au moins une échéance dépassée sans `[REPAIRED]` | **sonner le user** |
| `1` | erreur d'instrument (illisible, miroir gelé, **mesure dégradée**), ou `--ring` demandé et non parti | réparer l'instrument, ne pas conclure |

Défauts : **2 cycles × 4 h** = 8 h, la cadence des crons flotte (`41 */4`).
`--cycles` / `--cycle-hours` les remplacent là où la cadence diffère.

**#4672 — le bearer se lit tout seul, et la sortie survit au cp1252.** La
commande canonique ne demande **aucun sourcing manuel** : l'organe lit
`--env-file` (défaut `%USERPROFILE%\.roo-state-manager\stall-detector.env`, le
fichier que dépose le lanceur compagnon ; entre les deux, la variable de siège
`ORGAN_ENV_FILE`, qui porte le **chemin** d'un autre fichier du siège — #4901)
avec la précédence **CLI >
environnement du processus > fichier > défaut d'URL**. Le fichier n'est jamais
*sourcé* : seules les lignes nommées `MCP_PROXY_BEARER` / `MCP_PROXY_BASE_URL` /
`MCP_PROXY_URL` sont analysées, aucune autre valeur n'est matérialisée. Fichier
absent = pas une erreur (ai-01 porte son bearer dans l'environnement de son
lanceur) ; fichier illisible ou mal formé = warning **qui n'imprime aucune
valeur** (les clés lisibles du fichier restent utilisées), et
le fail-closed existant reste la garantie (sans bearer lisible, pas de lecture
store, sortie `1`). Les flux stdout/stderr sont forcés en UTF-8
(`errors="replace"`) : sous la console Windows cp1252, un extrait portant une
flèche `U+2192` faisait lever `UnicodeEncodeError` dans `report()` et le crash
rendait **exit 1 à la place du verdict 2** (mesuré po-2028, 13/11).

**Un `--ring-bearer ""` explicite veut dire « aucun bearer »** (suite de la
review de #4677) : il masque l'environnement **et** le fichier. Seul l'argument
absent laisse parler les étages suivants. Mesure qui a motivé la règle : la
suite de tests, lancée avec un bearer factice dans l'environnement, passait
`--ring-bearer ""` et l'organe reprenait le bearer ambiant — sur un siège qui
exporte un vrai bearer, lancer les tests aurait pu sonner pour de bon.

**Sonnerie : chaque siège sonne, une seule entrée arrive.** La règle demande à
chaque lane de sonner sur un exit `2` ; la clé d'idempotence ne porte donc
**pas** l'hôte. Elle vaut `empreinte du lot trié + jour` : deux sièges qui
mesurent le même lot le même jour calculent le même identifiant, et l'append
du dashboard ignore un identifiant déjà présent (#3276, archives de
condensation comprises #3782). Le second siège lit alors « sonnerie déjà
présente … aucune nouvelle entrée » et sort `2` comme le premier — une
sonnerie dédoublonnée **existe**, ce n'est pas une sonnerie non partie.
Un seul publieur désigné aurait rendu la sonnerie muette le jour où ce siège
est celui qui tombe. Limites : deux sièges qui lisent à des instants différents
peuvent voir deux lots différents (une escalade de plus est échue entre-temps)
— deux identifiants, deux entrées, et c'est voulu : le lot a changé. De même,
le jour de la clé est compté en UTC : le même lot sonné par un siège avant
minuit UTC et par un autre après fait deux entrées, comme la re-sonnerie
quotidienne.

**Déclaration ≠ mention** (review #4519) : une escalade est **déclarée** par la
ligne `[tags: … DEGRADED …]` ou par le token en **premier token du corps**.
Un post qui **cite** le tag en pleine prose — la review qui le commente, le
`[DONE]` qui l'explique — n'ouvre rien : les deux posts réels du 03/11 qui
citaient le tag produisaient des escalades fantômes qui sonnaient le user pour
rien. Même discipline pour `[REPAIRED]` : seule une déclaration de la même lane
ferme.

**#4746 — portée optionnelle du `[REPAIRED]`.** Le contrat d'origine (un
`[REPAIRED]` = déclaration de LANE, il ferme tout ce qui le précède) rendait le
mécanisme dangereux pour une lane qui porte plusieurs escalades : mesuré deux
fois en une heure le 15/11. ai-01 `claudish` a **retenu** un `[REPAIRED]` vrai
(playwright), parce qu'il aurait aussi fermé son escalade du 13/11 toujours
vraie ; ai-01 `roo-extensions` a posté le sien pour `review_pr`, et il a **aussi**
fermé l'escalade du conteneur sk-agent `:8100` (#4741), non réparée. L'organe
poussait donc la lane soit à se taire sur une réparation vraie, soit à consacrer
une sortie dégradée — ce que la règle 4 interdit. La portée se marque sur
une **ligne dédiée** du post : `scope: <messageId | #NNNN | HH:MMZ>` (ou
`portée:`). Trois formes de valeur nomment l'escalade : son `messageId`,
une référence d'issue présente dans son corps (`#4741`), ou son heure de
**pose** `HH:MMZ` (pas l'heure de la réparation). **La prose ne scope
jamais** (review ai-01 15/11) : les `[REPAIRED]` réels citent presque
toujours une heure ou une issue en prose, et la première tête de la PR y
lisait la portée — 27 réparations historiques re-basculaient
`repaired → overdue` sur le store live. Un `[REPAIRED]` **sans** ligne de
portée garde le comportement d'origine ; quand il ferme **plus d'une**
escalade, l'organe l'imprime (`REPAIRED <lane> <ts> a fermé N escalade(s) :
…`, `repair_notices` en JSON) pour que la lane voie ce qu'elle vient de
fermer. Une portée qui ne correspond à **aucune** escalade ne ferme **rien** :
l'escalade reste due au cycle suivant (fail-visible), jamais « tout fermer »
par défaut — c'est exactement le défaut que #4746 ferme. La seconde passe
d'archives applique la même règle : une fermeture scopée ne tient pas un
poste pour clos.

**Sources, dans l'ordre** (review #4519) : `--dashboard-file` = rejeu forensic
(sans plafond) → sinon le **store PG**, via le même transport que la sonnerie
(fenêtre des 200 dernières entrées par dashboard) → sinon repli **miroir G:**,
qui **dégrade** la mesure : si PG était configuré, l'organe agit sur ce que le
miroir a dit (rapport + sonnerie) puis sort **1** — jamais un `0` confiant sur
une source de repli. Plafond de fraîcheur du miroir : la plus récente entrée
doit dater de moins d'un cycle, sinon `1` sans sonnerie (un G: gelé depuis le
cut #4131 répond un faux « rien à signaler » sur des données mortes).

**#4643 — les archives de condensation sont lues aussi.** La condensation
retire les messages du vif sur les deux surfaces ; un `[REPAIRED]` ou une
escalade consommés par une condensation entre deux passages de l'organe
restaient invisibles (sonnerie récurrente après réparation documentée — cas du
10/11 — et faux négatif pour l'escalade archivée — cas du 03/11). En mode
store, l'organe lit en plus chaque archive posée dans la fenêtre
`--archive-window-hours` (défaut **48 h** : 2 cycles d'échéance + la
re-sonnerie quotidienne ; `0` désactive). Listing d'archives illisible =
erreur d'instrument (« fenêtre d'archives AVEUGLE »), jamais « aucune
archive » ; une archive sans horodatage parsable reste lue. Les déclarations
crossPostées (même auteur, même horodatage) se dédoublonnent sur
`(lane, poste)`.

**#4661 — la passe d'archives est bornée par un budget global.** Mesure
motivante (ai-01, 12/11, G: gelé en profondeur) : **929 s** dont **68 timeouts
`read_archive` de 10 s séquentiels** — la passe n'était pas bornée et l'organe
devenait muet pendant 15 minutes. `--archive-time-budget` (défaut **900 s** —
couvre la passe saine mesurée à **669 s**, #4643 ; l'ancien 120 s épuisait le
budget au bout de 3 min d'une passe **saine** et l'organe ne rendait jamais
0/2/3 ; `0` = illimité) borne l'ensemble listing + lectures d'archives, toutes
clés confondues ; les lectures **vivantes** ne consomment pas le budget et
continuent après épuisement. Au-delà : archives restantes **sautées**,
erreur d'instrument « fenêtre d'archives PARTIELLEMENT AVEUGLE », sortie **1**
par le fail-closed existant (la sonnerie reste annulée sur mesure partielle,
W3 #4655) — une mesure partielle rendue en temps borné plutôt qu'un organe
muet.

**#4643 — coques vides et timeouts clients (dispatch ai-01 12/11 ; reprise
c.6823202164).** Une lecture d'archive **muette** (le transport rend `None`)
est relancée **une fois** à timeout étendu (45 s) — un timeout client
sporadique frappe aussi des archives **saines** (5 relevés sur des fichiers
de 32-39 Ko). Un **rejet serveur `isError` ne se relance pas** : il est
déterministe (7 ms mesurés post-gel — les ~35 s venaient du gel de G:, pas
du rejet), et le transport rend son **texte** à l'organe via l'opt-in
`return_rejected_text` (les autres appelants gardent le `None` fail-closed).
Le texte est alors **classifié** : la signature « frontmatter manquant » sur
une archive **hors fenêtre** (seconde passe) désigne une **coque vide** (0
octet, writer interrompu d'avant le correctif temp+rename) → **WARN non
bloquant** ; sur une archive **de la fenêtre lue**, le même rejet vaut
**lecture partielle** depuis #4796 (erreur d'instrument, sortie 1) — le vide
ne prouve pas la coque depuis un siège : un placeholder DriveFS encore vide
se rejette pareil (mesure po-2024 16/11 : archive de 18 messages,
`[REPAIRED]` invisible, exit 2 fantôme sur deux runs propres, la même archive
lisible depuis ai-01) ; tout **autre rejet** → erreur d'instrument. Les
entrées vivantes restent intactes dans tous les cas ; seul le WARN hors
fenêtre garde un verdict 0/2/3. En source store, le dénominateur du rapport d'erreurs (« N
illisible(s) sur M ») est le nombre de **dashboards lus** (clés du listing) —
il disait « sur 0 ».

**Sans bearer, l'organe dit qu'il ne sait pas (#4650).** Une lecture **par
défaut** (ni `--dashboard-dir` ni `--dashboard-file`) sans **aucun** bearer
(ni `--ring-bearer`, ni `MCP_PROXY_BEARER`, ni fichier `--env-file`) sort **1**
avec le message « instrument incomplet : store PG non lu », quelles
que soient les données du miroir : depuis #4131 le miroir n'est plus écrit, un
verdict `0/2/3` y porterait sur une source morte. Le rapport du miroir reste
affiché (act-then-degrade). Un `--dashboard-dir` ou `--dashboard-file`
**explicite** garde son verdict — c'est le rejeu forensic, et c'est ce que les
tests exercent. Conséquence de mandat : une lane non équipée du bearer ne voit
plus de `2`, donc n'a plus à réveiller le user sur une mesure qu'elle n'a pas
les moyens de faire.

**Le store est lu en JSON, pas en markdown** (review ai-01 04/11, MUST) : le
`read` markdown passe par `buildMarkdownOutput`, qui émet l'en-tête et le corps
mais **aucune ligne `[tags: …]`**. Une lane qui déclarait par l'API canonique —
`append(tags=["DEGRADED"])`, corps en prose — restait donc invisible : `tags=[]`,
exit `0`, silence. Or c'est la forme que le harnais documente. L'organe demande
maintenant `format: json` et lit `data.intercom.messages[].tags` (déjà tronqué à
`intercomLimit` côté serveur), c'est-à-dire **la source, pas son rendu**. Les tags
du **corps** sont unis à ceux du champ : `append` ne dérive pas les tags du
contenu, donc la déclaration « par la ligne `[tags: … DEGRADED …]` » documentée
dans `scripts/diagnostic/README.md` n'a aucun tag dans son champ et se taisait sur
ce chemin (review ai-01 04/11, SHOULD-2). Le repli markdown est réservé au
**non-JSON** (hôte ancien, `format` ignoré) : une enveloppe JSON qui n'est pas une
réponse exploitable — `success: false` (store inaccessible, dashboard absent,
section invalide) ou structure inattendue — est une **erreur d'instrument**
(exit `1`), jamais un dashboard propre lu comme du markdown (SHOULD-1). Cas
symétrique côté miroir : la sérialisation place `[msg: id]` **avant** le corps,
donc une déclaration en premier token n'était jamais vue non plus — les lignes de
métadonnées de tête sont désormais neutralisées avant le test du premier token.

`--ring` poste un `[ASK-USER][DEGRADED-ESCALATION]` sur le dashboard `global`,
avec une clé d'idempotence **quotidienne et commune à tous les sièges** : le
même lot sonne **une fois par jour**, jamais une fois par tick ni une fois par
siège, et re-sonne chaque jour tant que rien n'est réparé. Le texte de la sonnerie ne porte **aucun token de declaration**
(`[DEGRADED]`/`[REPAIRED]` remplacés par leur mot) et son entrée porte le tag
`DEGRADED-ESCALATION` : la sonnerie ne peut ni fermer sa propre alarme ni en
ouvrir une nouvelle. Le transport est celui de `detect-approval-stalls.py`
(`call_dashboard_tool`, importé, pas recopié — le même pour LIRE le store et
POSTER la sonnerie). Un `--ring` qui échoue sort **1** : une sonnerie qui n'est
pas partie ne se présente jamais comme un succès. Elle est de plus **annulée
sur mesure partielle** (W3, review #4655) : dashboard(s) illisible(s) ⇒ pas de
sonnerie — la fenêtre aveugle peut cacher le `[REPAIRED]` qui ferait taire
l'escalade mesurée, et un faux réveil coûte une intervention humaine ; le
cycle suivant re-sonne sur une lecture complète.

### Défaut connu de l'hôte — rangé à part (décision user 14/11/2026, RX160 (a), #4730)

Verbatim user : « RX160 OK pour a ».

Un défaut **connu de l'hôte** — le harnais Claude Code lui-même, pas un MCP d'une
lane, aujourd'hui le worktree d'isolation des sous-agents refusé (**#3345**) — ne
se répare par aucune lane. L'organe le **range à part** : section séparée dans la
sonnerie (`KNOWN_HOST_DEFECTS`), marque `A-PART` dans le rapport texte,
`overdue_known_defect` en JSON. Il reste **ouvert** et **dû** : rien n'est déclaré
réparé, le code de sortie est inchangé (`2`), seul un `[REPAIRED]` de la lane le
ferme. L'empreinte de la sonnerie ne porte que le lot réparable, donc une nouvelle
escalade de défaut connu ne re-sonne pas le même jour. **Ajouter une entrée à
`KNOWN_HOST_DEFECTS` exige une PR citant l'issue du défaut de l'hôte.**

### Panne du lecteur de l'organe — rangée à part (GO coordinateur 20/11/2026, #4729)

Une escalade peut être la panne de **l'instrument lui-même** : l'organe du siège a
rendu `exit 1` (lecteur PG non configuré, `MCP_PROXY_BEARER` absent du processus,
miroir non autoritatif) et la lane a escaladé **ce fait**. Un `[REPAIRED]` de lane
ne ferme pas cette escalade tant que le lecteur manque — et le compteur
« délai dépassé » gonflait d'entrées qu'aucune lane ne pouvait fermer, surestimant
la dette de service (constat 20/11 00:21Z : 8 escalades sur 30, ≥ 6 sièges).

L'organe range ces escalades **à part**, comme les défauts d'hôte #4730 : section
nommée dans la sonnerie (avec le remède), marque `A-PART`, `overdue_reader_defect`
en JSON, exclusion de l'empreinte quotidienne. Elles restent **ouvertes**,
**visibles** et **dues** (exit `2` inchangé) — mais le compteur principal ne
compte plus que la dette de service. Contrairement au défaut d'hôte, cette famille
**se répare** :

**Remède du siège (`--env-file`).** L'organe lit lui-même son fichier
d'environnement (`MCP_PROXY_BEARER` / `MCP_PROXY_URL` / `MCP_PROXY_BASE_URL`,
défaut `%USERPROFILE%\.roo-state-manager\stall-detector.env` — celui que dépose
le lanceur compagnon ; sur un siège sans lanceur, tout fichier `CLE=valeur` portant
déjà le bearer convient, rien n'est copié ni imprimé) :

```bash
python scripts/diagnostic/check-degraded-escalations.py --env-file <fichier-du-siège>
```

**Forme durable (#4901) : le pointeur de siège.** Sur un siège sans lanceur
compagnon, chaque lane interactive devait passer `--env-file` à chaque appel —
et celle qui l'oubliait sortait en `1`. La variable d'environnement
`ORGAN_ENV_FILE` (portée User) porte le **chemin** du fichier du siège, et l'organe
la lit avant son fichier par défaut : `--env-file` > `ORGAN_ENV_FILE` >
`stall-detector.env`. **Une session ouverte avant le `setx` ne voit pas la
variable dans son processus : l'organe relit alors le pointeur, en lecture
seule, dans `HKCU\Environment`** (Windows, `KEY_READ` sur cette seule valeur,
rien d'écrit — PR #4920) ; l'ordre complet est donc `--env-file` > variable du
processus > registre > défaut. Rejoué sur ai-01 le 24/11 dans une session
antérieure au `setx` : store lu, 94 dashboards sur 95 (review de la PR #4920).
Aucune valeur n'est copiée ni imprimée — le warning de
sortie `1` nomme la variable à poser. Un pointeur vers un fichier absent avertit
(en nommant le chemin) et laisse la mesure fail-closed ; `--env-file ""` coupe
aussi le pointeur.

Mesuré sur ai-01 le 20/11 : exit 2 réel, 446 lectures. Si l'organe rend ensuite
`0`, `2` ou `3`, la lane poste son `[REPAIRED]` avec sa ligne de portée
(`scope:`). Si le fichier n'existe pas sur le siège — ou s'il existe et que
l'organe rend **encore** `1` pour une cause aval (ex. mesuré po-2027 20/11 : le
RSM derrière le proxy répond `store-absent` sur SON propre montage `G:`) — la lane
le **dit sur #4729** : c'est une panne différente de « bearer absent », elle se
répare côté proxy/hôte, jamais par un contournement de siège.

**Le motif se lit sur le code, pas sur la prose** (GO c.7032224803 ; durci par
la review ai-01 du 20/11) : la classification (`classify_reader_defect`)
exige la conjonction littérale de l'un de DEUX chemins, jamais une
interprétation sémantique du récit —

- **chemin A** : vocabulaire de l'instrument (`lecteur de l'organe`, `bearer`,
  `mcp_proxy`, nom de l'organe, `roosync_dashboard`) **ET** code de sortie
  (`rc=1`, `exit 1`, `retourne 1`…) ;
- **chemin B** : nom de l'organe **ET** marqueur store (`pg`, `store`,
  `miroir`) **ET** échec de lecture (code de sortie, ou `ne lit pas`,
  `pas lu`, `non lu`, `lecture`, `store-absent`).

Le nom de l'organe seul ne suffit **jamais** : « check-degraded-escalations a
sonné 30 échéances » est un instrument sain, et « l'organe a détecté : PG
down, export en échec » est une panne de **service** rapportée par un lecteur
sain — ni l'un ni l'autre ne sort du compteur principal (les deux repros de
la review du 20/11, tésés en négatif). Le marqueur `lecteur` nu est retiré :
« le lecteur de vidéos rend exit 1 » n'est pas notre panne. Frontières de mot
partout (`pg` dans « pgadmin » ne compte pas, `rc=1` dans « rc=15 » non
plus). Un post qui relève des deux familles reste compté une seule fois, en
défaut d'hôte. Un mutant sans classification fait rougir le témoin du
selftest, le test unitaire (`ReaderDefectSetAside`) et un `--selftest`
lancé en subprocess — sans ce dernier, la régression #4834 pouvait revenir
sans que rien ne la voie. Vérifié sur le corpus réel du 20/11 (miroir G:) :
les cinq posts de panne de lecteur restent rangés à part, la dette de
service repasse à 5.

---

## Lecture du store sous charge (#4729)

L'organe perdait sa mesure précisément pendant les pics de charge flotte
(ai-01 14/11 : exit 1 « store PG injoignable — The read operation timed out »,
puis exit 124 au feu suivant, alors que les appends MCP de la même fenêtre
passaient) — c'est-à-dire quand les escalades s'accumulent et que la sonnerie
compte. Trois protections :

1. **Relance généralisée.** Toute lecture muette du transport (None = timeout
   client sporadique) — listing initial, lectures vivantes, listings
   d'archives, fichiers d'archives, seconde passe — se relance UNE fois à
   timeout étendu (`STORE_READ_RETRY_TIMEOUT_S`, 45 s). Un rejet serveur
   `isError` ne se relance jamais (déterministe, contrat #4643) : une coque
   vide **hors fenêtre** reste un WARN non bloquant, une coque **dans la
   fenêtre** vaut lecture partielle (#4796), tout autre rejet une erreur
   d'instrument.
2. **Télémétrie de lecture.** Chaque lecture est mesurée ; le verdict porte
   les chiffres (`read_telemetry` en sortie `--json`, une ligne stderr
   sinon) : appels, ok/lents/muets (seuil `SLOW_READ_S`), relances posées et
   récupérées, p50/p95/max en ms. « Store lent » et « store mort » se
   distinguent en lisant la sortie, sans rejouer la passe.
3. **Attribution par phase (récidive 18/11).** Une lecture muette dit
   désormais **quelle phase MCP** est morte : le transport
   (`call_dashboard_tool`) mesure `initialize` / `initialized` /
   `tools-call` / `lecture` (durées, octets lus sur `lecture`) et, sur
   échec, rend `failure = {phase, exception, elapsed_ms}` — type d'exception
   et chiffres uniquement, jamais de secret ni de contenu. L'organe agrège
   (`muted_by_phase`, `muted_exceptions`, `muted_phase_max_ms` dans
   `read_telemetry`, plus « muets par phase » en stderr). Le témoin
   fondateur : deux archives muettes **à travers premier essai et relance**,
   la même archive servie en 154 ms juste après — sans attribution de phase,
   un timeout d'establishment et un timeout de lecture de corps se
   ressemblent exactement (« sans contenu »). Fail-closed, retry unique et
   un-seul-transport inchangés.
4. **Procédure exit 1 × 3 feux consécutifs.** Un organe qui rend exit 1 sur
   trois feux consécutifs du même siège est lui-même en panne d'instrument :
   la lane poste le constat sur le dashboard `global` (tag `ASK`, les trois
   `read_telemetry` — le différenciel p50/p95/max tranche lent vs mort, les
   phases muettes tranchent establishment vs lecture) et
   demande au coordinateur l'ouverture d'une issue `[CLAUDE-MACHINE]`
   (l'ouverture d'issue reste gated). Le silence n'est pas une option :
   l'alarme muette pendant l'incendie est précisément le défaut que #4729
   répare.

---

## Plafond dit explicitement

- **L'organe ne voit que les escalades postées.** Une lane qui n'escalade pas
  reste invisible — c'est pourquoi le point 1 n'est pas négociable, et pourquoi
  la sonde de siège (`check-mcp-seats.py`, PR #4518) existe : elle rend la
  dégradation visible sans attendre la bonne volonté de la lane.
- **La sonnerie ne dépend d'aucune horloge partagée** ; elle dépend de la lane
  qui exécute l'organe pendant son cycle. Câbler l'organe dans le pré-vol
  (`/continue`, `/coordinate`) est une décision du coordinateur, hors du
  périmètre de #4517.
- **« 2 cycles » est une convention**, pas une mesure de la difficulté de
  réparation : elle borne le silence, elle ne juge pas le travail.

---

**Voir aussi :** [`escalation-protocol.md`](escalation-protocol.md) (escalade de
**capacité**, 5 niveaux — axe différent) · [`deny-fallback-probe.md`](deny-fallback-probe.md)
(le repli deny qui n'existe pas) · [`tool-availability.md`](../../../.claude/rules/tool-availability.md)
(STOP & REPAIR).
