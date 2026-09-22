#!/usr/bin/env python3
"""
test_check_clean_cycle_exit.py — tests unitaires et integration pour #3776.

Couvre chaque verdict de l'organe :
  - PASS             : clone propre, sur branche par defaut, a jour de l'upstream, sans untracked.
  - WRONG_BRANCH     : HEAD sur une branche secondaire.
  - DETACHED         : HEAD detache sur un commit isole.
  - UNBORN           : depot neuf sans commit.
  - NO_UPSTREAM      : branche locale sans remote.
  - BEHIND           : HEAD en arriere d'un commit sur origin/main.
  - AHEAD            : HEAD en avance d'un commit non pousse.
  - DIVERGED         : HEAD et upstream ont des commits distincts.
  - DIRTY_TRACKED    : fichier suivi modifie, staged ou unstaged.
  - UNTRACKED        : chemins non suivis ; couvrent espaces et Unicode.
  - SUBMODULE_DRIFT  : submodule au mauvais SHA alors qu'il est propre en interne.
  - SUBMODULE_DIRTY  : submodule au bon SHA mais avec modifs internes.
  - NOT_REPOSITORY   : chemin qui n'est pas un depot git.

Chaque test cree un depot temporaire, place les fixtures necessaires,
execute l'organe, puis verifie le verdict exact.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import List

# Permet l'import depuis scripts/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from check_clean_cycle_exit import (
    collect_state,
    main,
    parse_porcelain_z,
    render_human,
    VERDICTS_PASS,
    VERDICT_WRONG_BRANCH,
    VERDICT_DETACHED,
    VERDICT_UNBORN,
    VERDICT_NO_UPSTREAM,
    VERDICT_BEHIND,
    VERDICT_AHEAD,
    VERDICT_DIVERGED,
    VERDICT_DIRTY_TRACKED,
    VERDICT_UNTRACKED,
    VERDICT_SUBMODULE_DRIFT,
    VERDICT_SUBMODULE_DIRTY,
    VERDICT_NOT_REPOSITORY,
)


GIT_ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_AUTHOR_NAME": "tester",
           "GIT_AUTHOR_EMAIL": "tester@example.com", "GIT_COMMITTER_NAME": "tester",
           "GIT_COMMITTER_EMAIL": "tester@example.com"}


def git(args: List[str], cwd: Path, check: bool = True, env: dict = None) -> subprocess.CompletedProcess:
    proc = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        env=env or GIT_ENV,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and proc.returncode != 0:
        raise AssertionError(
            f"git {' '.join(args)} dans {cwd} a echoue : {proc.stderr or proc.stdout}"
        )
    return proc


def init_repo(path: Path, default_branch: str = "main") -> None:
    """Initialise un depot git avec une branche par defaut donnee, plus un origin fake.

    Le fake origin est essentiel pour tester BEHIND/AHEAD/DIVERGED sans reseau.
    """
    git(["init", "--initial-branch", default_branch], cwd=path)
    git(["config", "user.email", "tester@example.com"], cwd=path)
    git(["config", "user.name", "tester"], cwd=path)
    git(["config", "commit.gpgsign", "false"], cwd=path)
    # Un fichier + commit pour eviter UNBORN
    (path / "README.md").write_text("seed\n", encoding="utf-8")
    git(["add", "README.md"], cwd=path)
    git(["commit", "-m", "initial"], cwd=path)
    # Creer un bare remote comme upstream (path sibling, jamais un suffixe de path)
    remote = path.parent / (path.name + ".remote.git")
    remote.mkdir()
    git(["init", "--bare", "--initial-branch", default_branch], cwd=remote)
    git(["remote", "add", "origin", str(remote)], cwd=path)
    git(["push", "-u", "origin", default_branch], cwd=path)
    # Forcer origin/HEAD (necessaire pour symbolic-ref resolution sur certains git)
    git(["remote", "set-head", "origin", default_branch], cwd=path)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def sibling(path: Path, suffix: str) -> Path:
    """Retourne un chemin sibling (meme parent) avec le suffixe donne.

    `Path.with_suffix` mute l'extension et casse sur certains noms ;
    on utilise toujours le repertoire parent pour les fixtures.
    """
    return path.parent / (path.name + suffix)


class TestParsePorcelainZ(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(parse_porcelain_z(""), [])

    def test_modified(self):
        out = " M README.md\x00"
        entries = parse_porcelain_z(out)
        self.assertEqual(entries, [" M README.md"])

    def test_staged_only(self):
        out = "M  staged.txt\x00"
        self.assertEqual(parse_porcelain_z(out), ["M  staged.txt"])

    def test_rename(self):
        out = "R  old\x00new\x00"
        self.assertEqual(parse_porcelain_z(out), ["R  new"])


class TestNotRepository(unittest.TestCase):
    def test_non_git_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_NOT_REPOSITORY)
            self.assertFalse(state["ready_for_close"])


class TestUnborn(unittest.TestCase):
    def test_empty_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "fresh"
            p.mkdir()
            git(["init", "--initial-branch", "main"], cwd=p, check=False)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_UNBORN)


class TestPass(unittest.TestCase):
    def test_clean_synced(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "clean"
            p.mkdir()
            init_repo(p, default_branch="main")
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICTS_PASS, msg=json.dumps(state, indent=2))
            self.assertTrue(state["ready_for_close"])
            self.assertEqual(state["branch"], "main")
            self.assertEqual(state["ahead"], 0)
            self.assertEqual(state["behind"], 0)


class TestWrongBranch(unittest.TestCase):
    def test_on_feature_branch(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "rb"
            p.mkdir()
            init_repo(p, default_branch="main")
            git(["checkout", "-b", "feature/x"], cwd=p)
            git(["push", "-u", "origin", "feature/x"], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_WRONG_BRANCH)
            self.assertEqual(state["branch"], "feature/x")
            self.assertEqual(state["default_branch"], "main")


class TestDetached(unittest.TestCase):
    def test_detached_head(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "dh"
            p.mkdir()
            init_repo(p, default_branch="main")
            sha = git(["rev-parse", "HEAD"], cwd=p).stdout.strip()
            git(["checkout", "--detach", sha], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_DETACHED)


class TestNoUpstream(unittest.TestCase):
    def test_local_branch_no_upstream(self):
        """Une branche egale a la default branch mais sans upstream tracking.

        On cree une nouvelle branche locale portant le nom de la branche par
        defaut (par exemple 'main'), sans la pusher, pour obtenir le verdict
        NO_UPSTREAM sans declencher WRONG_BRANCH.
        """
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "local"
            p.mkdir()
            init_repo(p, default_branch="main")
            # Casser le tracking de main : detacher l'upstream
            git(["branch", "--unset-upstream", "main"], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_NO_UPSTREAM)
            self.assertEqual(state["branch"], "main")
            self.assertEqual(state["default_branch"], "main")


class TestBehind(unittest.TestCase):
    def test_remote_has_extra_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "behind"
            p.mkdir()
            init_repo(p, default_branch="main")
            remote = sibling(p, ".remote.git")
            # Ajouter un commit sur origin directement via le bare remote
            work = sibling(p, ".work")
            work.mkdir()
            git(["clone", str(remote), str(work)], cwd=work)
            write(work / "extra.md", "from upstream\n")
            git(["add", "extra.md"], cwd=work)
            git(["commit", "-m", "upstream commit"], cwd=work)
            git(["push", "origin", "main"], cwd=work)
            # Note : on laisse `work` etre nettoyee par le TemporaryDirectory,
            # shutil.rmtree echoue sur les .git/objects read-only sous Windows.
            # Le clone de test doit fetcher pour voir le commit distant
            git(["fetch", "origin"], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_BEHIND)
            self.assertEqual(state["behind"], 1)


class TestAhead(unittest.TestCase):
    def test_local_has_unpushed_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "ahead"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "local.md", "local work\n")
            git(["add", "local.md"], cwd=p)
            git(["commit", "-m", "local commit"], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_AHEAD)
            self.assertEqual(state["ahead"], 1)


class TestDiverged(unittest.TestCase):
    def test_diverged_branches(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "divg"
            p.mkdir()
            init_repo(p, default_branch="main")
            remote = sibling(p, ".remote.git")

            # Commit local avance
            write(p / "local.md", "local\n")
            git(["add", "local.md"], cwd=p)
            git(["commit", "-m", "local advance"], cwd=p)

            # Commit cote remote via clone
            work = sibling(p, ".work")
            work.mkdir()
            git(["clone", str(remote), str(work)], cwd=work)
            write(work / "remote.md", "remote\n")
            git(["add", "remote.md"], cwd=work)
            git(["commit", "-m", "remote advance"], cwd=work)
            git(["push", "origin", "main"], cwd=work)
            # Note : on laisse `work` etre nettoyee par le TemporaryDirectory,
            # shutil.rmtree echoue sur les .git/objects read-only sous Windows.

            # Fetch dans le clone de test, sans merge
            git(["fetch", "origin"], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_DIVERGED)


class TestDirtyTracked(unittest.TestCase):
    def test_modified_tracked_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "dirty"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "README.md", "modified\n")
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_DIRTY_TRACKED)

    def test_staged_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "staged"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "new.md", "new\n")
            git(["add", "new.md"], cwd=p)
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_DIRTY_TRACKED)


class TestUntracked(unittest.TestCase):
    def test_simple_untracked(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "untracked"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "scratch.txt", "junk")
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_UNTRACKED)
            self.assertEqual(state["signals"][0]["kind"], "untracked")
            self.assertIn("scratch.txt", state["signals"][0]["paths"])

    def test_untracked_with_spaces(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "untracked-space"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "mon fichier capture.txt", "playwright artifact")
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_UNTRACKED)
            self.assertIn("mon fichier capture.txt", state["signals"][0]["paths"])

    def test_untracked_unicode(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "untracked-unicode"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "synthese-épreuve-α.txt", "résumé")
            state = collect_state(p)
            self.assertEqual(state["verdict"], VERDICT_UNTRACKED)
            self.assertIn("synthese-épreuve-α.txt", state["signals"][0]["paths"])

    def test_untracked_paths_not_exposed_in_human(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "human"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "secret-content.bin", "binary data")
            text = render_human(collect_state(p))
            # Le verdict et le nombre sont visibles, le contenu ne l'est pas.
            self.assertIn("UNTRACKED", text)
            self.assertIn("1 chemin(s)", text)
            self.assertNotIn("binary data", text)


class TestSubmodule(unittest.TestCase):
    def _make_submodule(self, parent: Path) -> Path:
        sub = sibling(parent, ".submod")
        sub.mkdir()
        git(["init", "--initial-branch", "main"], cwd=sub)
        git(["config", "user.email", "tester@example.com"], cwd=sub)
        git(["config", "user.name", "tester"], cwd=sub)
        write(sub / "sub.md", "submodule seed\n")
        git(["add", "sub.md"], cwd=sub)
        git(["commit", "-m", "sub initial"], cwd=sub)
        return sub

    def test_submodule_drift_clean_internal(self):
        """Submodule propre en interne mais sur un SHA different du gitlink parent.

        On ajoute le submodule (ce qui pose un gitlink = SHA_A), puis on
        cree un commit directement dans le checkout du submodule (p/ext),
        ce qui avance le HEAD du submodule sans toucher au gitlink parent.
        """
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "sub-drift"
            p.mkdir()
            init_repo(p, default_branch="main")
            sub = self._make_submodule(p)
            git(["-c", "protocol.file.allow=always", "submodule", "add", str(sub), "ext"], cwd=p)
            git(["commit", "-m", "add submodule"], cwd=p)
            git(["push", "origin", "main"], cwd=p)
            # Avancer le submodule directement dans p/ext (sans toucher au
            # gitlink parent). Cela cree un commit orphelin du point de vue
            # du parent, mais valide du point de vue du submodule.
            ext = p / "ext"
            write(ext / "sub2.md", "submodule advance\n")
            git(["add", "sub2.md"], cwd=ext)
            git(["commit", "-m", "sub advance"], cwd=ext)
            new_sha = git(["rev-parse", "HEAD"], cwd=ext).stdout.strip()
            self.assertNotEqual(new_sha, "")
            state = collect_state(p)
            sub_states = [s for s in state["submodules"] if s["path"] == "ext"]
            self.assertEqual(len(sub_states), 1, msg=json.dumps(state, indent=2))
            self.assertTrue(sub_states[0]["drift"])
            self.assertFalse(sub_states[0]["dirty"])
            self.assertEqual(state["verdict"], VERDICT_SUBMODULE_DRIFT)

    def test_submodule_dirty_internal(self):
        """Submodule au bon gitlink, mais avec une modification non commitee a l'interieur."""
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "sub-dirty"
            p.mkdir()
            init_repo(p, default_branch="main")
            sub = self._make_submodule(p)
            git(["-c", "protocol.file.allow=always", "submodule", "add", str(sub), "ext"], cwd=p)
            git(["commit", "-m", "add submodule"], cwd=p)
            git(["push", "origin", "main"], cwd=p)
            # Modifier un fichier dans le CHECKOUT du submodule (p/ext),
            # pas dans la source (sub). Le submodule reste sur le bon SHA,
            # mais son worktree est maintenant dirty.
            ext = p / "ext"
            write(ext / "sub.md", "internal edit\n")
            state = collect_state(p)
            sub_states = [s for s in state["submodules"] if s["path"] == "ext"]
            self.assertEqual(len(sub_states), 1, msg=json.dumps(state, indent=2))
            self.assertFalse(sub_states[0]["drift"])
            self.assertTrue(sub_states[0]["dirty"])
            self.assertEqual(state["verdict"], VERDICT_SUBMODULE_DIRTY)


class TestEndToEnd(unittest.TestCase):
    def test_cli_pass_returns_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "cli-pass"
            p.mkdir()
            init_repo(p, default_branch="main")
            rc = main(["--path", str(p), "--json"])
            self.assertEqual(rc, 0)

    def test_cli_fail_returns_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "cli-fail"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "scratch.txt", "leftover")
            rc = main(["--path", str(p), "--json"])
            self.assertEqual(rc, 1)


class TestNoMutationGuarantee(unittest.TestCase):
    """L'organe ne doit JAMAIS muter le working tree.

    On verifie en placant plusieurs signaux et en verifiant que la liste des fichiers,
    le diff staged et le diff unstaged restent inchanges apres l'execution.
    """

    def test_no_mutation_on_dirty_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "no-mutate"
            p.mkdir()
            init_repo(p, default_branch="main")
            write(p / "scratch.txt", "junk")
            write(p / "mon fichier.bin", "playwright capture")
            write(p / "README.md", "modified body")

            before = subprocess.run(
                ["git", "status", "--porcelain=v1", "-z"],
                cwd=str(p), capture_output=True, text=True, env=GIT_ENV
            ).stdout

            _ = main(["--path", str(p), "--json"])

            after = subprocess.run(
                ["git", "status", "--porcelain=v1", "-z"],
                cwd=str(p), capture_output=True, text=True, env=GIT_ENV
            ).stdout

            self.assertEqual(before, after, msg="L'organe a mute le working tree (interdit).")


if __name__ == "__main__":
    unittest.main()
