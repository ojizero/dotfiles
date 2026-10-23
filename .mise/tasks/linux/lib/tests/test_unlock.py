"""Exercise SSH transitions without connecting, unlocking, or restarting GDM."""
import json
import os
from pathlib import Path
import subprocess
import sys
import shlex
import tempfile
import unittest

TASK = Path(__file__).resolve().parents[2] / 'unlock'
REMOTE = TASK.parent / 'lib/gnome-login.sh'

SSH = '''#!/usr/bin/env python3
import json, os, pathlib, sys, time
p = pathlib.Path(os.environ['MOCK_STATE'])
s = json.loads(p.read_text())
a = sys.argv[1:]
s['calls'].append(a)
if a[-1] == 'true':
    s['probes'] += 1
    result = 0 if s['probes'] >= s['ready_at'] else 255
    if os.environ.get('SLOW_PROBE'):
        time.sleep(1.05)
elif 'test-device-unlock' in a:
    result = s['unlock_status']
elif 'cat >' in a[-1]:
    s['payload'] = sys.stdin.read()
    result = s['upload_status']
else:
    result = 0
p.write_text(json.dumps(s))
sys.exit(result)
'''


class UnlockTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.state = self.root / 'state.json'
        self.command('ssh', SSH)
        self.command('sleep', '#!/bin/sh\nexit 0\n')
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}',
                        MOCK_STATE=str(self.state), usage_device='test-device', usage_timeout='10')

    def command(self, name, source):
        p = self.bin / name
        p.write_text(source)
        p.chmod(0o755)

    def invoke(self, ready_at=1, unlock_status=255, upload_status=0):
        self.state.write_text(json.dumps(dict(calls=[], probes=0, ready_at=ready_at,
                                              unlock_status=unlock_status, upload_status=upload_status)))
        result = subprocess.run(['bash', str(TASK)], env=self.env, capture_output=True, text=True, timeout=10)
        return result, json.loads(self.state.read_text())

    def test_already_unlocked_skips_unlock_and_uploads_versioned_helper(self):
        result, state = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any('test-device-unlock' in call for call in state['calls']))
        self.assertEqual(state['payload'], REMOTE.read_text())
        self.assertIn('gnome-login.sh', state['calls'][-1][-1])
        self.assertIn('-t', state['calls'][-1])

    def test_waits_for_early_ssh_and_tolerates_boot_disconnect(self):
        result, state = self.invoke(ready_at=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum('test-device-unlock' in call for call in state['calls']), 3)
        self.assertEqual(state['probes'], 5)
        self.assertIn('payload', state)

    def test_unlock_elsewhere_during_boot_skips_early_ssh(self):
        result, state = self.invoke(ready_at=2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any('test-device-unlock' in call for call in state['calls']))

    def test_zero_unlock_exit_is_not_success_without_normal_ssh(self):
        self.env.update(usage_timeout='1')
        self.command('sleep', '#!/bin/sh\n/bin/sleep 1.1\n')
        result, state = self.invoke(ready_at=999, unlock_status=0)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('payload', state)
        self.assertEqual(sum('test-device-unlock' in call for call in state['calls']), 1)

    def test_cancel_does_not_retry_or_start_desktop(self):
        result, state = self.invoke(ready_at=999, unlock_status=130)
        self.assertEqual(result.returncode, 130)
        self.assertEqual(sum('test-device-unlock' in call for call in state['calls']), 1)
        self.assertNotIn('payload', state)

    def test_failed_upload_does_not_run_remote_helper(self):
        result, state = self.invoke(upload_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cat >', state['calls'][-1][-1])

    def test_rejects_device_that_could_be_an_ssh_option(self):
        self.env['usage_device'] = '-oProxyCommand=bad'
        result, state = self.invoke()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(state['calls'], [])

    def test_reuses_existing_gnome_without_sudo_or_gdm_restart(self):
        home = self.root / 'home'
        runtime = self.root / 'run'
        home.mkdir()
        runtime.mkdir()
        self.command('uname', '#!/bin/sh\necho Linux\n')
        for cmd in ['ghostty', 'gnome-session-inhibit', 'flock', 'pgrep']:
            self.command(cmd, '#!/bin/sh\nexit 0\n')
        for cmd in ['sudo', 'systemctl', 'systemd-run']:
            self.command(cmd, '#!/bin/sh\necho "unexpected desktop restart" >&2\nexit 99\n')
        self.command('gdbus', '#!/bin/sh\necho "(true,)"\n')
        self.command('python3', '#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' "$@"\n')
        env = dict(self.env, HOME=str(home), XDG_RUNTIME_DIR=str(runtime))
        result = subprocess.run(['bash', str(REMOTE)], env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('screen locked', result.stdout)
        self.assertIn('OnlyShowIn=GNOME;', (home / '.config/autostart/gnome-inhibit-and-lock.desktop').read_text())
        self.assertTrue((home / '.local/bin/gnome-inhibit-and-lock').stat().st_mode & 0o100)


if __name__ == '__main__':
    unittest.main()
