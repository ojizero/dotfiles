"""Test backup upgrades and rollback using temporary files and stub systemctl."""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('installer', Path(__file__).with_name('install.py'))
i = importlib.util.module_from_spec(spec)
spec.loader.exec_module(i)


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = self.root / 'original'
        self.original.write_text('before reserve')
        self.upower = self.root / 'upower'
        self.upower.write_text('original UPower')
        self.guard = self.root / 'guard'
        self.unit = self.root / 'guard.service'
        self.wake = self.root / 'wake'
        self.wake.write_text('disabled\n')
        self.backup = self.root / 'backup'
        self.files = {str(self.original): ('battery-reserve.conf', 0o644)}
        self.states = {}
        self.calls = []
        def status(command, **kwargs):
            return SimpleNamespace(stdout=self.states.get((command[1], command[2]), 'disabled'))
        patches = [patch.object(i, 'BACKUP', self.backup), patch.object(i, 'FILES', self.files),
                   patch.object(i, 'UPOWER', self.upower), patch.object(i, 'WAKE', [str(self.wake)]),
                   patch.object(i, 'UNITS', i.UNITS[:2]), patch.object(i.subprocess, 'run', side_effect=status),
                   patch.object(i, 'run', side_effect=lambda *args, **kwargs: self.calls.append(args))]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def manifest(self):
        return json.loads((self.backup / 'manifest.json').read_text())

    def add_guard(self):
        self.files.update({str(self.guard): ('closed-lid-suspend-guard', 0o755),
                           str(self.unit): ('closed-lid-suspend-guard.service', 0o644)})

    def test_upgrade_preserves_originals_and_removes_new_guard_on_rollback(self):
        i.backup()  # Original pre-guard manifest.
        original_manifest = self.manifest()
        self.original.write_text('installed reserve config')
        self.upower.write_text('installed UPower')
        self.wake.write_text('enabled\n')
        self.add_guard()
        with patch.object(i, 'UNITS', (*i.UNITS, i.GUARD)):
            i.backup()
            upgraded = self.manifest()
            self.guard.write_text('installed guard')
            self.unit.write_text('installed unit')
            i.backup()
            self.assertEqual(upgraded, self.manifest())
            self.assertEqual(original_manifest['units'], {k: upgraded['units'][k] for k in original_manifest['units']})
            i.rollback()
        self.assertEqual(self.original.read_text(), 'before reserve')
        self.assertEqual(self.upower.read_text(), 'original UPower')
        self.assertEqual(self.wake.read_text(), 'disabled\n')
        self.assertFalse(self.guard.exists())
        self.assertFalse(self.unit.exists())
        self.assertIn(i.GUARD, self.calls[0])

    def test_preexisting_migrated_guard_is_restored(self):
        i.backup()
        self.add_guard()
        self.guard.write_text('migrated guard')
        self.unit.write_text('migrated unit')
        self.states.update({('is-enabled', i.GUARD): 'enabled', ('is-active', i.GUARD): 'active'})
        with patch.object(i, 'UNITS', (*i.UNITS, i.GUARD)):
            i.backup()
            self.guard.write_text('updated guard')
            self.unit.write_text('updated unit')
            i.rollback()
        self.assertEqual(self.guard.read_text(), 'migrated guard')
        self.assertEqual(self.unit.read_text(), 'migrated unit')
        self.assertIn(('systemctl', 'enable', i.GUARD), self.calls)
        self.assertIn(('systemctl', 'start', i.GUARD), self.calls)

    def test_old_backup_does_not_retire_separate_guard(self):
        i.backup()
        self.guard.write_text('separate guard')
        i.rollback()
        self.assertEqual(self.guard.read_text(), 'separate guard')
        self.assertNotIn(i.GUARD, self.calls[0])


if __name__ == '__main__':
    unittest.main()
