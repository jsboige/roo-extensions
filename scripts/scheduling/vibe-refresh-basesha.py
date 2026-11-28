# -*- coding: utf-8 -*-
"""Refresh queued Vibe grains against the current CoursIA origin/main."""

import importlib.util
import io
import json
import os
import re
import subprocess
import sys

QUEUE_PATH = r"D:\dev\roo-extensions\outputs\vibe\feeder-queue.json"
COURSIA_REPO = r"D:\dev\CoursIA"


def _load_queue_organ():
    """The refresher owns the queue publication (publish_text, preserve_previous)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "refresh-vibe-queue.py")
    spec = importlib.util.spec_from_file_location("refresh_vibe_queue", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


QUEUE_ORGAN = _load_queue_organ()


def git(*args: str, text: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", COURSIA_REPO, *args], capture_output=True, text=text
    )


def target_of(grain: dict) -> str | None:
    explicit = grain.get("targetPath")
    if explicit:
        return explicit.strip()

    payload = grain.get("payload", "")
    patterns = (
        r"aerer le mur de texte de (.+?) \(paragraphe",
        r"aération mécanique de ([^\n]+?) uniquement",
        r"aérer le mur de texte de ([^\n]+?) uniquement",
    )
    for pattern in patterns:
        match = re.search(pattern, payload, re.IGNORECASE)
        if match:
            return match.group(1).strip().strip("`")
    return None


def prose_walls(text: str) -> list[int]:
    return [
        len(block)
        for block in text.replace("\r", "").split("\n\n")
        if len(block) > 2000
        and block.strip()
        and not any(line.strip().startswith("|") for line in block.split("\n"))
    ]


def main() -> int:
    fetch = git("fetch", "origin", "main", "-q")
    if fetch.returncode != 0:
        print("ERREUR fetch:", fetch.stderr.strip())
        return 1

    rev = git("rev-parse", "origin/main")
    base = rev.stdout.strip()
    if rev.returncode != 0 or len(base) != 40:
        print("ERREUR rev-parse:", rev.stderr.strip())
        return 1

    with io.open(QUEUE_PATH, encoding="utf-8-sig", newline="") as handle:
        previous = handle.read()
    queue = json.loads(previous)

    grains = queue.get("grains", [])
    if not grains:
        print("file VIDE")
        return 0

    keep: list[dict] = []
    dropped: list[str] = []
    warnings: list[str] = []
    for grain in grains:
        target = target_of(grain)
        if not target:
            keep.append(grain)
            warnings.append(f"{grain.get('id', '?')}: cible inconnue conservee")
            continue

        show = git("show", f"{base}:{target}", text=False)
        if show.returncode != 0:
            dropped.append(grain["id"])
            continue

        try:
            text = show.stdout.decode("utf-8")
        except UnicodeDecodeError:
            keep.append(grain)
            warnings.append(f"{grain.get('id', '?')}: UTF-8 invalide conserve")
            continue

        if prose_walls(text):
            grain["baseSha"] = base
            grain["targetPath"] = target
            keep.append(grain)
        else:
            dropped.append(grain["id"])

    queue["grains"] = keep
    # Second writer of the queue (#4946): same publication as the refresher.
    # The loaded queue rotates into .bak, then the file is replaced only once
    # the new content is complete -- a torn write here would lock the
    # refresher at every tick (load_queue fails closed).
    if not QUEUE_ORGAN.preserve_previous(QUEUE_PATH, previous):
        print("ERREUR: file invalide, publication refusee (.bak intact)")
        return 1
    QUEUE_ORGAN.publish_text(QUEUE_PATH, json.dumps(queue, indent=4, ensure_ascii=False))

    rebased: list[str] = []
    for grain in keep:
        worktree = grain.get("worktree")
        if not worktree:
            continue
        ahead = subprocess.run(
            ["git", "-C", worktree, "rev-list", "--count", f"{base}..HEAD"],
            capture_output=True,
            text=True,
        )
        status = subprocess.run(
            ["git", "-C", worktree, "status", "--porcelain"],
            capture_output=True,
            text=True,
        )
        if ahead.returncode == 0 and ahead.stdout.strip() == "0" and not status.stdout.strip():
            reset = subprocess.run(
                ["git", "-C", worktree, "reset", "--hard", base],
                capture_output=True,
                text=True,
            )
            if reset.returncode == 0:
                rebased.append(grain["id"].replace("15457-aerate-", ""))

    suffix = ""
    if dropped:
        suffix += ", retires: " + ", ".join(dropped)
    if rebased:
        suffix += " | worktrees recales: " + ", ".join(rebased)
    if warnings:
        suffix += " | WARN: " + "; ".join(warnings)
    print(f"REFRESH {base[:9]} : {len(keep)} grains a jour{suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
