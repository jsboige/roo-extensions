#!/usr/bin/env python3
"""check_lane_signature.py — lane-signature guard for commits (#harness, ask CoursIA-2 2026-11-18).

Origine : demande user (verbatim 17/11, relayee par myia-ai-01:CoursIA-2) —
« il faudrait demander a roo-extension de rajouter au harnais global que toutes
les lanes doivent signer leurs contributions sur git a base de
machine:workspace pour qu'on comprenne qui fait quoi ». L'attribution reposait
sur des tags declaratifs (dashboard, claims) : rien dans git ne disait quelle
lane a produit un commit.

Design (arbitrage a/b, recommandation livre) : TRAILER de commit `Lane:
<machine:workspace>`, pas un changement de `git user.name` par lane — le
trailer est lisible par `git log --format=%(trailers:key=Lane)`, ne touche pas
l'identite d'auteur que le tooling flotte interroge (--author=jsboige), et suit
la meme mecanique que Co-Authored-By. Les merges (squash-merge GitHub compris)
sont EXCLUS : le squash artifact est cree par le merger, reference la PR dont
le corps porte la lane ; le garde s'applique aux commits de CONTRIBUTION.

Surfaces (meme forme que gitleaks, #3685) :
  1. CI       -> .github/workflows/lane-signature.yml (chaque PR, delta de commits)
  2. local    -> pre-commit hook commit-msg (opt-in par machine)
  3. manuel   -> ce script, avant push, depuis n'importe quel checkout/depot

Usage :
    python scripts/git/check_lane_signature.py                  # origin/main..HEAD
    python scripts/git/check_lane_signature.py HEAD~3..HEAD     # plage explicite
    python scripts/git/check_lane_signature.py --commit-msg .git/COMMIT_EDITMSG
                                                                 # hook commit-msg :
                                                                 # verifie le FICHIER
                                                                 # message (le commit
                                                                 # n'existe pas encore)

Validation d'un lane-id `myia-po-204:roo-extensions` :
  - format     : ^myia-[a-z0-9-]+(:[A-Za-z0-9._-]+)?$ (machine, workspace optionnel)
  - machine    : croisee avec .claude/configs/fleet-manifest.json QUAND le fichier
                 existe dans le depot (roo-extensions) ; format seul sinon (le garde
                 doit rester portable aux depots fils qui adoptent la gate).
  - sans ':'   : accepte (une lane par machine signe machine-seul) — le manifeste
                 des lanes n'existe pas, on ne peut pas l'exiger.

Exit codes (famille check_gitlinks_pushed) :
    0  = OK (tous les commits non-merge de la plage portent la signature)
    1  = UNSIGNED — au moins un commit sans trailer Lane: valide : NE PAS pousser
    2  = instrument (git indisponible, plage inconnue, manifeste illible) —
         un garde muet ne valide rien, il arrete
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

LANE_RE = re.compile(r"^myia-[a-z0-9-]+(?::[A-Za-z0-9._-]+)?$")
TRAILER_RE = re.compile(r"^Lane:[ \t]*(myia-[a-z0-9-]+(?::[A-Za-z0-9._-]+)?)[ \t]*$", re.IGNORECASE)

# Separateur improbable entre champs (%x00 = NUL) — un sujet de commit ne peut
# pas en contenir, le parsing par ligne reste deterministe.
LOG_FORMAT = "%H%x00%P%x00%s%x00%(trailers:key=Lane,valueonly,separator=%x01)"


def run_git(args):
    proc = subprocess.run(["git", *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout, proc.stderr


def load_manifest_machines():
    """Machines connues du fleet-manifest, ou None si absent (depot tiers)."""
    # Le script vit dans <root>/scripts/git/ — la racine est parents[2].
    manifest = Path(__file__).resolve().parents[2] / ".claude" / "configs" / "fleet-manifest.json"
    if not manifest.exists():
        return None
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
        machines = data.get("machines")
        return set(machines.keys()) if isinstance(machines, dict) else None
    except (OSError, ValueError):
        print(f"[ERROR] manifeste illisible : {manifest}", file=sys.stderr)
        sys.exit(2)


def lane_trailers_from_message(message):
    """Lane-ids declares dans un message de commit (paragraph-trailer uniquement).

    Un `Lane:` au milieu du corps n'est pas un trailer git — on ne lit que la
    description complete et les trailers terminaux, comme git (%trailers).
    Pour rester simple et robuste sur les deux modes (objet git ET fichier
    message), on scanne les lignes du bloc final apres la derniere ligne vide.
    """
    lines = message.splitlines()
    # retire les lignes de commentaire du gabarit commit-msg (git les strip)
    lines = [ln for ln in lines if not ln.startswith("#")]
    # bloc de trailers = dernier paragraphe
    while lines and not lines[-1].strip():
        lines.pop()
    last_para = []
    for ln in reversed(lines):
        if not ln.strip():
            break
        last_para.append(ln)
    lanes = []
    for ln in last_para:
        m = TRAILER_RE.match(ln.strip())
        if m:
            lanes.append(m.group(1))
    return lanes


def validate_lane(lane_id, machines):
    """(ok, raison) pour un lane-id. `machines` = set connu ou None (format seul)."""
    if not LANE_RE.match(lane_id):
        return False, f"format invalide (attendu myia-<machine>[:<workspace>]) : {lane_id}"
    machine = lane_id.split(":", 1)[0]
    if machines is not None and machine not in machines:
        return False, f"machine inconnue du fleet-manifest : {machine}"
    return True, ""


def check_range(rev_range, machines, since=None):
    """Verifie chaque commit non-merge de la plage. Rend (nb_ok, unsigned[]).

    `since` (ISO 8601) exempte les commits anTERIEURS a la regle : au rollout,
    les PR ouvertes d'avant la garde ne rougissent pas sur leur historique.
    Le filtre porte sur la date de COMMITTER (celle que git reecrit au rebase —
    un commit ancient rebase pour entrer dans une PR reste ancient pour l'auteur
    mais jeune pour le committer ; on veut verifier ce qui entre FRAICHEMENT).
    """
    args = ["log", "--no-color", f"--format={LOG_FORMAT}"]
    if since:
        args.append(f"--since={since}")
    args.append(rev_range)
    rc, out, err = run_git(args)
    if rc != 0:
        print(f"[ERROR] git log {rev_range} : {err.strip()}", file=sys.stderr)
        sys.exit(2)
    unsigned = []
    nb_ok = 0
    for line in out.splitlines():
        if not line.strip():
            continue
        parts = line.split("\x00")
        if len(parts) != 4:
            continue
        sha, parents, subject, declared = parts
        if len(parents.split()) > 1:
            continue  # merge commit : hors perimetre (artifact du merger)
        # %trailers:key=Lane est l'extraction AUTORITAIRE cote git (meme source
        # que le mode commit-msg, qui parse le bloc final du fichier message).
        lanes = [t for t in declared.split("\x01") if t.strip()]
        reasons = [reason for ok, reason in (validate_lane(ln, machines) for ln in lanes) if not ok]
        if lanes and not reasons:
            nb_ok += 1
        else:
            unsigned.append((sha[:12], subject, reasons))
    return nb_ok, unsigned


def check_message_file(path):
    """Mode hook commit-msg : le fichier message passe par pre-commit ($1)."""
    try:
        message = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"[ERROR] lecture {path} : {e}", file=sys.stderr)
        sys.exit(2)
    machines = load_manifest_machines()
    lanes = lane_trailers_from_message(message)
    for lane_id in lanes:
        ok, reason = validate_lane(lane_id, machines)
        if not ok:
            print(f"[UNSIGNED] trailer Lane: invalide — {reason}", file=sys.stderr)
            return 1
    if lanes:
        return 0
    print("[UNSIGNED] le message de commit ne porte pas de trailer `Lane: <machine[:workspace]>`",
          file=sys.stderr)
    print("            ex: Lane: myia-po-204:roo-extensions", file=sys.stderr)
    return 1


def main():
    ap = argparse.ArgumentParser(description="Garde signature de lane (trailer Lane: machine:workspace)")
    ap.add_argument("range", nargs="?", default=None,
                    help="plage git a verifier (defaut : origin/main..HEAD)")
    ap.add_argument("--commit-msg", metavar="FILE", default=None,
                    help="mode hook commit-msg : verifier le FICHIER message plutot qu'une plage")
    ap.add_argument("--since", metavar="ISO8601", default=None,
                    help="exempter les commits anTERIEURS a cette date (committer date, rollout)")
    args = ap.parse_args()

    if args.commit_msg:
        sys.exit(check_message_file(args.commit_msg))

    machines = load_manifest_machines()
    if args.range:
        rev_range = args.range
    else:
        rc, _, err = run_git(["rev-parse", "--verify", "--quiet", "origin/main"])
        if rc != 0:
            print("[ERROR] origin/main introuvable et aucune plage fournie", file=sys.stderr)
            sys.exit(2)
        rev_range = "origin/main..HEAD"

    nb_ok, unsigned = check_range(rev_range, machines, since=args.since)
    if unsigned:
        print(f"[UNSIGNED] {len(unsigned)} commit(s) sans trailer Lane: valide :", file=sys.stderr)
        for sha, subject, reasons in unsigned:
            detail = f" — {' ; '.join(reasons)}" if reasons else ""
            print(f"  {sha} {subject}{detail}", file=sys.stderr)
        print("Ajouter le trailer au message : Lane: <machine[:workspace]>", file=sys.stderr)
        print("  (rebase -i / commit --amend, ou relire la regle Git du harnais global)",
              file=sys.stderr)
        sys.exit(1)
    mode = "manifeste+format" if machines is not None else "format seul (pas de fleet-manifest)"
    print(f"OK — {nb_ok} commit(s) signes ({mode})")
    sys.exit(0)


if __name__ == "__main__":
    main()
