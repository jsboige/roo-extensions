#!/usr/bin/env python3
"""#4438 — Sonde de l'ingress PUBLIC du magasin vectoriel (Qdrant).

Ce que la panne du 30/10 00:33Z a montre : un ingress noir (HTTP 502 apres
~21 s, signature « paquet perdu » et non « service arrete ») etait invisible
de tous les sieges hors-hote — personne n'interrogeait le chemin PUBLIC depuis
un siege. Une sonde qui lit le conteneur en local (localhost:6333) ne voit
jamais la panne que vivent les sieges distants : elle est donc censee viser
l'ingress public, et elle le DIT quand la cible resolue est locale.

Contrat de sortie :
    0 = healthy   (HTTP 200)
    1 = degraded  (502 / timeout / 401 / autre statut)
    2 = erreur d'instrument (URL illisible, env illisible, cible absente)

Stdlib uniquement (urllib). Aucun secret n'est imprime : la cle d'API est lue
par son NOM dans le fichier d'env et envoyee en en-tete, jamais affichee.
"""
import argparse
import json
import os
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# #4438: source de vérité UNIQUE de l'ingress public. Le littéral n'apparait
# qu'ici : une regle dupliquee (le meme defaut ecrit deux fois) rend le garde
# aveugle — le mutant « cible locale » passait alors que le test etait vert.
DEFAULT_URL = "https://qdrant.myia.io/collections"
DEFAULT_BASE = DEFAULT_URL.rsplit("/", 1)[0]
DEFAULT_ENV_FILE = os.path.join(os.path.expanduser("~"), ".roo-state-manager", ".env")
DEFAULT_TIMEOUT = 10.0
LOOPBACK_HOSTS = {"localhost", "127.0.0.1", "::1", "0.0.0.0"}


def read_env_file(path):
    """Lit un fichier .env KEY=VALUE. Retourne {key: value} (valeurs brutes).
    Les secrets ne sont JAMAIS affiches : seule la presence d'une cle est
    rapportee."""
    values = {}
    if not path or not os.path.isfile(path):
        return values
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def resolve_target(url_arg, env_file):
    """Retourne (url, api_key, source) — la cle peut etre None."""
    env_values = read_env_file(env_file)
    api_key = env_values.get("QDRANT_API_KEY") or os.environ.get("QDRANT_API_KEY")
    if url_arg:
        return url_arg, api_key, "argument"
    base = env_values.get("QDRANT_URL") or os.environ.get("QDRANT_URL") or DEFAULT_BASE
    base = base.rstrip("/")
    path = urllib.parse.urlparse(base).path.strip("/")
    if not path:
        base = base + "/collections"
    return base, api_key, "env"


def classify_scope(url):
    """public-ingress (ce que vivent les sieges distants) ou local-container."""
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    if host in LOOPBACK_HOSTS:
        return "local-container"
    return "public-ingress"


def probe(url, api_key, timeout=DEFAULT_TIMEOUT, opener=None):
    """Interroge l'ingress et rend un dict de verdict. Ne leve pas."""
    if opener is None:
        opener = urllib.request.urlopen
    headers = {"Accept": "application/json"}
    if api_key:
        headers["api-key"] = api_key
    request = urllib.request.Request(url, headers=headers, method="GET")
    started = time.monotonic()
    result = {
        "url": url,
        "scope": classify_scope(url),
        "status": None,
        "latency_ms": None,
        "verdict": "degraded",
        "reason": "unknown",
        "api_key_present": bool(api_key),
    }
    try:
        with opener(request, timeout=timeout) as response:
            status = getattr(response, "status", None) or response.getcode()
            response.read(1)
    except urllib.error.HTTPError as exc:
        status = exc.code
        result["status"] = status
        result["latency_ms"] = int((time.monotonic() - started) * 1000)
        result["reason"] = _reason_for_status(status)
        return result
    except (socket.timeout, TimeoutError):
        result["latency_ms"] = int((time.monotonic() - started) * 1000)
        result["reason"] = "timeout"
        return result
    except urllib.error.URLError as exc:
        result["latency_ms"] = int((time.monotonic() - started) * 1000)
        reason = getattr(exc, "reason", None)
        if isinstance(reason, (socket.timeout, TimeoutError)):
            result["reason"] = "timeout"
        else:
            result["reason"] = "unreachable"
        return result
    except OSError:
        result["latency_ms"] = int((time.monotonic() - started) * 1000)
        result["reason"] = "unreachable"
        return result
    result["status"] = status
    result["latency_ms"] = int((time.monotonic() - started) * 1000)
    result["verdict"] = "healthy" if status == 200 else "degraded"
    result["reason"] = _reason_for_status(status)
    return result


def _reason_for_status(status):
    if status == 200:
        return "ok"
    if status in (401, 403):
        return "auth_rejected"
    if status == 502:
        # IIS/ARR : le backend ne repond plus et la facade rend 502 apres son
        # propre delai — la signature mesuree le 30/10 (21,6 s).
        return "ingress_blackholed"
    if status == 503:
        return "ingress_unavailable"
    if status == 404:
        return "not_found"
    return "http_%s" % status


def format_human(result):
    lines = [
        "qdrant ingress probe — %s" % result["verdict"].upper(),
        "  url        : %s" % result["url"],
        "  scope      : %s%s" % (
            result["scope"],
            "  (cible LOCALE : ce que vit le conteneur, pas le chemin que vivent les sieges distants)"
            if result["scope"] == "local-container" else "",
        ),
        "  status     : %s" % (result["status"] if result["status"] is not None else "no-response"),
        "  latency_ms : %s" % result["latency_ms"],
        "  reason     : %s" % result["reason"],
        "  api_key    : %s" % ("presente" if result["api_key_present"] else "ABSENTE (401 attendu)"),
    ]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Sonde l'ingress PUBLIC du magasin vectoriel (Qdrant) depuis ce siege.",
    )
    parser.add_argument("--url", default=None, help="cible (defaut: QDRANT_URL du .env, sinon %s)" % DEFAULT_URL)
    parser.add_argument("--env-file", default=DEFAULT_ENV_FILE, help="fichier d'env lu par NOM de cle")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help="delai max en secondes (defaut 10)")
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    args = parser.parse_args(argv)

    url, api_key, _source = resolve_target(args.url, args.env_file)
    try:
        urllib.parse.urlparse(url)
    except ValueError:
        sys.stderr.write("URL illisible: %r\n" % url)
        return 2
    if not url:
        sys.stderr.write("aucune cible resolue\n")
        return 2

    result = probe(url, api_key, timeout=args.timeout)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(format_human(result))
    return 0 if result["verdict"] == "healthy" else 1


if __name__ == "__main__":
    sys.exit(main())
