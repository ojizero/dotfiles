import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'collect.py'
spec = importlib.util.spec_from_file_location('collector', SCRIPT)
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)


class HousekeepingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.config = self.root / 'config.json'
        self.c = {'host': socket.gethostname(), 'disk_root': str(self.root),
                  'roots': [], 'repositories': []}
        self.write_config()

    def write_config(self):
        self.config.write_text(json.dumps(self.c))
        self.config.chmod(0o600)

    def fake_command(self, args, deadline, limit=None):
        if args[-1] == 'kern.memorystatus_vm_pressure_level':
            return {'text': '1'}
        if args[-1] == 'vm.swapusage':
            return {'text': 'total = 1024.00M used = 12.00M free = 1012.00M'}
        if args[0] == '/bin/ps':
            return {'text': '42 1 Fri Oct 16 12:00:00 2026 500 /bin/test'}
        return {'text': 'worktree /example\nHEAD abc\nbranch refs/heads/main\n'}

    def run_fake(self, review=False):
        disk = SimpleNamespace(f_blocks=100*h.GIB, f_frsize=1, f_bavail=80*h.GIB)
        with patch.object(h.platform, 'system', return_value='Darwin'), patch.object(h, 'command', side_effect=self.fake_command), patch.object(h.os, 'statvfs', return_value=disk):
            return h.run(str(self.config), review)

    def test_platform_and_missing_config(self):
        with patch.object(h.platform, 'system', return_value='Linux'):
            self.assertEqual(h.run(str(self.config))['status'], 'unsupported')
        with patch.object(h.platform, 'system', return_value='Darwin'):
            self.assertEqual(h.run(str(self.root / 'missing'))['status'], 'unconfigured')

    def test_runs_write_nothing_and_ignore_state_dir(self):
        self.c['state_dir'] = str(self.root / 'absent')
        self.write_config()
        before = sorted(self.root.rglob('*'))
        self.assertEqual(self.run_fake()['status'], 'healthy')
        self.assertEqual(self.run_fake(True)['status'], 'healthy')
        self.assertEqual(sorted(self.root.rglob('*')), before)

    def test_reject_bad_host_roots_and_permissions(self):
        for change in [{'host': 'wrong'}, {'roots': [str(Path.home())]},
                       {'warning_percent': float('nan')}]:
            with self.subTest(change=change):
                original = self.c.copy()
                self.c.update(change)
                self.write_config()
                with self.assertRaises((ValueError, KeyError)):
                    h.load_config(str(self.config))
                self.c = original
        self.write_config()
        self.config.chmod(0o666)
        with self.assertRaises(ValueError):
            h.load_config(str(self.config))

    def test_threshold_boundaries(self):
        config = {'urgent_gib': 25, 'warning_percent': 15}
        self.assertEqual(h.status(30*h.GIB, 200*h.GIB, 1, config), 'healthy')
        self.assertEqual(h.status(29*h.GIB, 200*h.GIB, 1, config), 'warning')
        self.assertEqual(h.status(25*h.GIB-1, 100*h.GIB, 1, config), 'urgent')
        self.assertEqual(h.status(80*h.GIB, 100*h.GIB, 4, config), 'urgent')
        self.assertEqual(h.status(80*h.GIB, 100*h.GIB, 2, config), 'warning')

    def test_quick_check_reports_current_state(self):
        report = self.run_fake()
        self.assertEqual(report['status'], 'healthy')
        self.assertEqual(report['mode'], 'quick')
        self.assertEqual(report['pressure_level'], 1)
        self.assertEqual(report['swap_bytes'], 12*1024**2)
        self.assertEqual(report['notices'], [])
        self.assertNotIn('roots', report)

    def test_allocated_deduplicates_and_bounds(self):
        cache = self.root / 'cache'
        cache.mkdir()
        data = cache / 'data'
        data.write_bytes(b'x'*8192)
        os.link(data, cache / 'hardlink')
        (cache / 'alias').symlink_to(cache, target_is_directory=True)
        result = h.allocated(cache, time.monotonic()+1, set())
        self.assertEqual(result['allocated_bytes'], cache.stat().st_blocks*512 + data.stat().st_blocks*512)
        with patch.object(h, 'MAX_ENTRIES', 1):
            self.assertIn('unknown', h.allocated(cache, time.monotonic()+1, set()))
        self.assertIn('unknown', h.allocated(cache, 0, set()))

    def test_review_is_inventory_only_and_docker_is_opt_in(self):
        cache = self.root / 'cache'
        cache.mkdir()
        (cache / 'protected.sqlite-wal').write_bytes(b'preserve')
        self.c['roots'] = [str(cache)]
        self.write_config()
        report = self.run_fake(True)
        self.assertIn('needs-user-decision', report['roots'][str(cache)]['decision'])
        self.assertEqual(report['processes'][0]['name'], 'test')
        self.assertIn('unconfigured', report['docker_logical']['unknown'])
        self.assertEqual((cache / 'protected.sqlite-wal').read_bytes(), b'preserve')

    def test_command_timeout_output_limit_and_failure(self):
        for code in ['import time; time.sleep(5)', 'print("x"*100000)', 'raise SystemExit(3)']:
            result = h.command([sys.executable, '-c', code], time.monotonic()+0.2)
            self.assertIn('unknown', result)
        self.assertIn('unknown', h.command(['/missing/tool'], time.monotonic()+1))
        self.assertEqual(h.command([sys.executable, '-c', 'print(42)'], time.monotonic()+1), {'text': '42\n'})

    def test_pressure_unknown_does_not_claim_healthy(self):
        original = self.fake_command
        with patch.object(self, 'fake_command', side_effect=lambda args, deadline, limit=None:
                          {'unknown': 'timeout'} if args[-1] == 'kern.memorystatus_vm_pressure_level'
                          else original(args, deadline)):
            report = self.run_fake()
        self.assertEqual(report['status'], 'unknown')
        self.assertIsNone(report['pressure_level'])

    def test_symlink_root_rejected(self):
        cache = self.root / 'cache'
        cache.mkdir()
        alias = self.root / 'alias'
        alias.symlink_to(cache, target_is_directory=True)
        self.c['roots'] = [str(alias)]
        self.write_config()
        with self.assertRaises(ValueError):
            h.load_config(str(self.config))

    def test_apply_rejected(self):
        proc = subprocess.run([sys.executable, str(SCRIPT), '--config', str(self.config), '--apply'], capture_output=True)
        self.assertEqual(proc.returncode, 2)


if __name__ == '__main__':
    unittest.main()
