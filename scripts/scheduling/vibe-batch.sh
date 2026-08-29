#!/usr/bin/env bash
# Lance un lot d'audits Vibe en parallele, un pack de prompt par run.
#
# Usage :   [CAP=6] [WS=D:/dev/CoursIA] vibe-batch.sh <repertoire-logs> <repertoire-packs|pack.txt...>
#
# Trois pieges rencontres en production, corriges ici une fois pour toutes :
#  - le sous-shell fait `cd "$WS"` AVANT que la redirection ne soit posee : tout
#    chemin relatif (logs comme packs) n'existe plus a ce moment-la -> absolus ;
#  - un glob passe sur la ligne de commande peut ne pas atteindre le script selon
#    le lanceur -> accepter un REPERTOIRE et l'etendre ici ;
#  - fs_resolve du driver compare des realpath : --cwd doit etre en forme Windows
#    (D:/dev/X), jamais MSYS (/d/dev/X), sinon la garde de chemin refuse tout.
#
# Ne JAMAIS filtrer la sortie de ce script par `| head` : le SIGPIPE tue la boucle
# de lancement et seuls les premiers packs partent, avec un code de sortie 0.
set -u
CAP=${CAP:-6}
WS=${WS:-D:/dev/CoursIA}

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DRV="$ROOT/scripts/scheduling/vibe-acp-driver.py"
[ -f "$DRV" ] || { echo "driver introuvable: $DRV" >&2; exit 2; }
# python sous Windows ne comprend pas un chemin MSYS
command -v cygpath >/dev/null 2>&1 && DRV=$(cygpath -m "$DRV")

LOGS="$1"; shift
mkdir -p "$LOGS"; LOGS=$(cd "$LOGS" && pwd)

if [ $# -eq 1 ] && [ -d "$1" ]; then set -- "$1"/*.txt; fi
[ $# -gt 0 ] || { echo "aucun pack — STOP" >&2; exit 2; }

args=(); for a in "$@"; do args+=("$(cd "$(dirname "$a")" && pwd)/$(basename "$a")"); done
set -- "${args[@]}"
echo "packs a traiter: $#  (CAP=$CAP, WS=$WS)"

WSSH="$WS"; command -v cygpath >/dev/null 2>&1 && WSSH=$(cygpath -u "$WS")
for p in "$@"; do
  while [ "$(jobs -rp | wc -l)" -ge "$CAP" ]; do sleep 3; done
  slug=$(basename "$p" .txt)
  ( cd "$WSSH" && python "$DRV" --cwd "$WS" \
      --prompt-file "$p" --timeout "${TIMEOUT:-1800}" >"$LOGS/$slug.log" 2>&1
    echo "$slug EXIT=$?" >>"$LOGS/_exits.txt" ) &
  echo "launched $slug"
done
wait

echo "=== LOT TERMINE ==="
for f in "$LOGS"/i*.log; do
  [ -e "$f" ] || continue
  printf '%-52s %s\n' "$(basename "$f" .log)" "$(grep -E '^PROMPT_' "$f" | head -1)"
done
echo "--- fs servis : $(grep -ahc 'fs served' "$LOGS"/i*.log 2>/dev/null | awk '{s+=$1} END{print s+0}')"
grep -ho 'cost=[0-9.]*' "$LOGS"/i*.log 2>/dev/null | cut -d= -f2 \
  | awk '{s+=$1;n++} END{printf "%d runs avec cout  total=%.3f USD\n",n,s}'
