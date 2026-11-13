"""Purge chirurgicale du cache MSAL mort — issue #1422 (Q15, GO user 04/11/2026).

Une seule cible : les cles `secret://` de l'extension microsoft-authentication au
format PCA (le refresh token mort, jamais evince par MSAL — MSAL#8849). Aucune autre
cle n'est touchee. N'imprime JAMAIS de valeur de secret : seulement des comptes et
des compteurs.

Le jeton fautif est identifie dans les journaux par `AADSTS700082: The refresh token
has expired due to inactivity` (compte `jsboige@hotmail.com`, portee
`499b84ac-1321-427f-aa17-267ca6975798`, emis le 2026-05-21). Il ne se renouvelle pas
tout seul : seule une purge suivie d'une reconnexion le remplace.

Usage :
    python purge-msal-cache.py <state.vscdb>                 # dry-run (lecture seule)
    python purge-msal-cache.py <state.vscdb> --apply         # backup + suppression
    python purge-msal-cache.py <state.vscdb> --apply --busy-timeout 2000

Code de sortie : 0 = succes (y compris « deja fait »), 1 = echec/incoherence,
2 = usage invalide.
"""
import os
import shutil
import sqlite3
import sys
import time

PATTERN = 'secret://{"extensionId":"vscode.microsoft-authentication","key":"pca:%'

DEFAULT_BUSY_TIMEOUT_MS = 5000


def _arg_value(argv, name, default):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


def main() -> int:
    argv = sys.argv
    positional = [a for a in argv[1:] if not a.startswith("--")]
    if not positional:
        print("usage: purge-msal-cache.py <state.vscdb> [--apply] [--busy-timeout MS]")
        return 2
    db = positional[0]
    apply = "--apply" in argv

    try:
        busy_ms = int(_arg_value(argv, "--busy-timeout", DEFAULT_BUSY_TIMEOUT_MS))
    except ValueError:
        print("[ERREUR] --busy-timeout attend un entier (millisecondes)")
        return 2

    if not os.path.isfile(db):
        print(f"[ERREUR] base introuvable : {db}")
        return 1

    con = sqlite3.connect(db, timeout=max(busy_ms, 0) / 1000.0)
    try:
        n = con.execute(
            "SELECT COUNT(*) FROM ItemTable WHERE key LIKE ?", (PATTERN,)
        ).fetchone()[0]
        others = con.execute(
            "SELECT COUNT(*) FROM ItemTable WHERE key LIKE 'secret://%' AND key NOT LIKE ?",
            (PATTERN,),
        ).fetchone()[0]
        print(f"[PROBE]   cles cible pca:*        = {n}")
        print(f"[PROBE]   autres cles secret://    = {others} (intouchables)")

        if not apply:
            print("[DRY-RUN] rien ecrit. Relancer avec --apply pour purger.")
            return 0

        if n == 0:
            print("[DEJA-FAIT] aucune cle cible : rien a purger.")
            return 0

        backup = f"{db}.bak-msalpurge-{time.strftime('%Y%m%d-%H%M%S')}"
        shutil.copy2(db, backup)
        print(f"[BACKUP]  {backup}")

        try:
            con.execute("DELETE FROM ItemTable WHERE key LIKE ?", (PATTERN,))
            con.commit()
        except sqlite3.OperationalError as exc:
            # Contention : VS Code a repris la base entre la sonde et l'ecriture.
            # Fail-closed et bruyant — surtout ne pas retenter a l'aveugle.
            print(f"[ECHEC]   ecriture impossible ({exc}) : base reprise par VS Code ?")
            print(f"          backup intact : {backup}")
            return 1

        purged = con.total_changes
        after = con.execute(
            "SELECT COUNT(*) FROM ItemTable WHERE key LIKE ?", (PATTERN,)
        ).fetchone()[0]
        others_after = con.execute(
            "SELECT COUNT(*) FROM ItemTable WHERE key LIKE 'secret://%' AND key NOT LIKE ?",
            (PATTERN,),
        ).fetchone()[0]
        print(f"[PURGE]   {purged} entree(s) supprimee(s), reste cible = {after}")
        print(f"[VERIF]   autres cles secret://    = {others_after} (doit egaler {others})")
        if after != 0 or others_after != others:
            print("[ECHEC]  incoherence : restaurer le backup par-dessus la base.")
            return 1
        print("[OK] purge terminee. Rouvrir VS Code puis : Comptes > Microsoft > Sign in (2FA).")
        print("      Succes = plus aucun AADSTS700082 au demarrage suivant,")
        print("      et le message ne cite plus 'issued on 2026-05-21'.")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())