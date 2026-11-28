#!/usr/bin/env python3
"""vibe-refresh-basesha.py publishes the queue like the refresher (#4946).

It is the second writer of feeder-queue.json. The loaded queue must rotate
into .bak, and the new content must replace the file only once complete: a
torn write would lock refresh-vibe-queue.py at every tick (load_queue fails
closed on an invalid queue).
"""

import importlib.util
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

_SPEC = importlib.util.spec_from_file_location(
    "vibe_refresh_basesha",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "..", "scheduling", "vibe-refresh-basesha.py"))
basesha = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(basesha)

BASE = "a" * 40
WALL = ("x" * 2100).encode("utf-8")  # one prose wall: the grain stays queued
ORIGINAL = ('{\r\n  "_comment": "réservé",\r\n  "grains": [\r\n'
            '    {"id": "g1", "targetPath": "nb.ipynb", "baseSha": "old"}\r\n'
            '  ]\r\n}\r\n').encode("utf-8")


def fake_git(*args, text=True):
    if args[0] == "fetch":
        return mock.Mock(returncode=0, stdout="", stderr="")
    if args[0] == "rev-parse":
        return mock.Mock(returncode=0, stdout=BASE + "\n", stderr="")
    if args[0] == "show":
        return mock.Mock(returncode=0, stdout=WALL, stderr="")
    raise AssertionError("unexpected git call: %r" % (args,))


class TestBaseshaPublication(unittest.TestCase):

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.path = os.path.join(self.dir, "feeder-queue.json")
        with open(self.path, "wb") as fh:
            fh.write(ORIGINAL)

    def tearDown(self):
        for name in os.listdir(self.dir):
            os.unlink(os.path.join(self.dir, name))
        os.rmdir(self.dir)

    def _main(self):
        with mock.patch.object(basesha, "QUEUE_PATH", self.path), \
             mock.patch.object(basesha, "git", side_effect=fake_git), \
             redirect_stdout(io.StringIO()):
            return basesha.main()

    def test_publication_rotates_the_loaded_queue_into_backup_bytes(self):
        self.assertEqual(self._main(), 0)
        with open(self.path + ".bak", "rb") as fh:
            self.assertEqual(fh.read(), ORIGINAL)
        with io.open(self.path, encoding="utf-8") as fh:
            grains = json.load(fh)["grains"]
        self.assertEqual([(g["id"], g["baseSha"]) for g in grains], [("g1", BASE)])
        self.assertEqual(sorted(os.listdir(self.dir)),
                         ["feeder-queue.json", "feeder-queue.json.bak"])

    def test_interrupted_publication_leaves_the_queue_intact(self):
        real_publish = basesha.QUEUE_ORGAN.publish_text

        def crash_on_queue(path, text):
            if path == self.path:
                raise OSError("disk full")
            return real_publish(path, text)

        with mock.patch.object(basesha.QUEUE_ORGAN, "publish_text",
                               side_effect=crash_on_queue):
            with self.assertRaises(OSError):
                self._main()
        with open(self.path, "rb") as fh:
            self.assertEqual(fh.read(), ORIGINAL)
        with open(self.path + ".bak", "rb") as fh:
            self.assertEqual(fh.read(), ORIGINAL)
        self.assertEqual(sorted(os.listdir(self.dir)),
                         ["feeder-queue.json", "feeder-queue.json.bak"])


if __name__ == "__main__":
    unittest.main()
