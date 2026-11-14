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
KEYRING = TASK.parent / 'lib/unlock-login-keyring.py'

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
    s.setdefault('payloads', {})[a[-1].rsplit('/', 1)[-1]] = sys.stdin.read()
    result = s['upload_status']
else:
    result = 0
p.write_text(json.dumps(s))
sys.exit(result)
'''

# Stands in for PyGObject. It answers the Secret Service calls that
# unlock-login-keyring.py makes and records them in FAKE_KEYRING.
FAKE_GI = '''
import json, os, pathlib, types

STATE = pathlib.Path(os.environ['FAKE_KEYRING'])


class Error(Exception):
    def __init__(self, message):
        super().__init__(message)
        self.message = message


class Variant:
    def __init__(self, signature, value):
        self.value = value

    def unpack(self):
        return self.value


class Bus:
    def call_sync(self, name, path, interface, method, args, reply, flags, timeout, cancellable):
        s = json.loads(STATE.read_text())
        s['calls'].append(method)
        try:
            if method == 'Get':
                return Variant('(v)', (s['locked'],))
            if method == 'OpenSession':
                return Variant('(vo)', ('', '/session/1'))
            if method == 'UnlockWithMasterPassword':
                collection, (session, _, password, _) = args.value
                s['unlocks'].append([collection, session, password.decode()])
                if password.decode() != s['password']:
                    raise Error('The password was invalid')
                s['locked'] = False
            return None
        finally:
            STATE.write_text(json.dumps(s))


GLib = types.SimpleNamespace(Error=Error, Variant=Variant, VariantType=lambda signature: signature)
Gio = types.SimpleNamespace(bus_get_sync=lambda bus_type: Bus(),
                            BusType=types.SimpleNamespace(SESSION=1),
                            DBusCallFlags=types.SimpleNamespace(NONE=0))
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
        self.assertEqual(state['payloads'], {'gnome-login.sh': REMOTE.read_text(),
                                             'unlock-login-keyring.py': KEYRING.read_text()})
        self.assertIn('gnome-login.sh', state['calls'][-1][-1])
        self.assertIn('-t', state['calls'][-1])

    def test_waits_for_early_ssh_and_tolerates_boot_disconnect(self):
        result, state = self.invoke(ready_at=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum('test-device-unlock' in call for call in state['calls']), 3)
        self.assertEqual(state['probes'], 5)
        self.assertIn('payloads', state)

    def test_unlock_elsewhere_during_boot_skips_early_ssh(self):
        result, state = self.invoke(ready_at=2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any('test-device-unlock' in call for call in state['calls']))

    def test_zero_unlock_exit_is_not_success_without_normal_ssh(self):
        self.env.update(usage_timeout='1')
        self.command('sleep', '#!/bin/sh\n/bin/sleep 1.1\n')
        result, state = self.invoke(ready_at=999, unlock_status=0)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('payloads', state)
        self.assertEqual(sum('test-device-unlock' in call for call in state['calls']), 1)

    def test_cancel_does_not_retry_or_start_desktop(self):
        result, state = self.invoke(ready_at=999, unlock_status=130)
        self.assertEqual(result.returncode, 130)
        self.assertEqual(sum('test-device-unlock' in call for call in state['calls']), 1)
        self.assertNotIn('payloads', state)

    def test_failed_upload_does_not_run_remote_helper(self):
        result, state = self.invoke(upload_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cat >', state['calls'][-1][-1])

    def test_rejects_device_that_could_be_an_ssh_option(self):
        self.env['usage_device'] = '-oProxyCommand=bad'
        result, state = self.invoke()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(state['calls'], [])

    def prepare_running_gnome(self):
        home = self.root / 'home'
        runtime = self.root / 'run'
        home.mkdir()
        runtime.mkdir()
        self.command('uname', '#!/bin/sh\necho Linux\n')
        for cmd in ['ghostty', 'gnome-session-inhibit', 'flock', 'pgrep']:
            self.command(cmd, '#!/bin/sh\nexit 0\n')
        for cmd in ['sudo', 'systemctl', 'systemd-run']:
            self.command(cmd, '#!/bin/sh\necho "unexpected desktop restart" >&2\nexit 99\n')
        self.command('gdbus', '''#!/bin/sh
printf '%s\\n' "$*" >> "$DBUS_LOG"
case "$*" in
  *org.gnome.ScreenSaver.GetActive*)
    if test -f "$SCREEN_STATE"; then echo '(true,)'; else echo '(false,)'; fi ;;
  *org.gnome.ScreenSaver.Lock*)
    touch "$SCREEN_STATE"
    echo 'Error: Timeout was reached' >&2
    exit 1 ;;
  *) echo '(true,)' ;;
esac
''')
        self.command('python3', '#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' "$@"\n')
        gi = self.root / 'pythonpath/gi'
        (gi / 'repository').mkdir(parents=True)
        (gi / '__init__.py').write_text('')
        (gi / 'repository/__init__.py').write_text(FAKE_GI)
        env = dict(self.env, HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
                   DBUS_LOG=str(self.root / 'dbus.log'), SCREEN_STATE=str(self.root / 'locked'),
                   PYTHONPATH=str(gi.parent), FAKE_KEYRING=str(self.root / 'keyring.json'))
        self.keyring_state(env)
        return env, home

    def keyring_state(self, env, locked=False):
        Path(env['FAKE_KEYRING']).write_text(json.dumps(
            dict(locked=locked, password='luks passphrase', calls=[], unlocks=[])))

    def run_remote(self, env, passphrases=''):
        # A new session has no controlling terminal, so getpass reads stdin.
        return subprocess.run(['bash', str(REMOTE)], env=env, input=passphrases, start_new_session=True,
                              capture_output=True, text=True, timeout=10)

    def test_reuses_existing_locked_gnome_without_redundant_lock_or_restart(self):
        env, home = self.prepare_running_gnome()
        Path(env['SCREEN_STATE']).touch()
        result = self.run_remote(env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('screen locked', result.stdout)
        self.assertIn('OnlyShowIn=GNOME;', (home / '.config/autostart/gnome-inhibit-and-lock.desktop').read_text())
        self.assertTrue((home / '.local/bin/gnome-inhibit-and-lock').stat().st_mode & 0o100)
        self.assertNotIn('org.gnome.ScreenSaver.Lock\n', Path(env['DBUS_LOG']).read_text())

    def test_unlocked_keyring_is_reported_without_a_prompt(self):
        env, home = self.prepare_running_gnome()
        result = self.run_remote(env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('The login keyring is unlocked.', result.stdout)
        self.assertNotIn('passphrase', result.stdout + result.stderr)
        self.assertEqual(json.loads(Path(env['FAKE_KEYRING']).read_text())['calls'], ['Get'])

    def test_locked_keyring_is_unlocked_with_the_luks_passphrase(self):
        env, home = self.prepare_running_gnome()
        self.keyring_state(env, locked=True)
        result = self.run_remote(env, 'wrong\nluks passphrase\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('LUKS disk passphrase', result.stdout + result.stderr)
        self.assertIn('did not unlock', result.stderr)
        self.assertIn('The login keyring is unlocked.', result.stdout)
        keyring = json.loads(Path(env['FAKE_KEYRING']).read_text())
        self.assertFalse(keyring['locked'])
        login = '/org/freedesktop/secrets/collection/login'
        self.assertEqual(keyring['unlocks'], [[login, '/session/1', 'wrong'],
                                              [login, '/session/1', 'luks passphrase']])
        # Each attempt closes the session it opened.
        self.assertEqual(keyring['calls'].count('OpenSession'), 2)
        self.assertEqual(keyring['calls'].count('Close'), 2)

    def test_still_locked_keyring_fails_after_the_screen_is_locked(self):
        env, home = self.prepare_running_gnome()
        self.keyring_state(env, locked=True)
        result = self.run_remote(env, 'one\ntwo\nthree\nfour\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('login keyring is still locked', result.stderr)
        self.assertNotIn('The login keyring is unlocked.', result.stdout)
        self.assertIn('screen locked', result.stdout)
        self.assertTrue(Path(env['SCREEN_STATE']).exists())
        self.assertEqual(len(json.loads(Path(env['FAKE_KEYRING']).read_text())['unlocks']), 3)

    def test_lock_timeout_is_success_only_when_locked_state_is_verified(self):
        env, home = self.prepare_running_gnome()
        result = self.run_remote(env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('screen locked', result.stdout)
        self.assertIn('org.gnome.ScreenSaver.Lock\n', Path(env['DBUS_LOG']).read_text())

        # The autostart terminal must also retain its inhibitor after this same
        # timeout, rather than terminating its command and releasing inhibition.
        self.command('gnome-session-inhibit', '#!/bin/sh\nwhile [ "$1" != bash ]; do shift; done\nexec "$@"\n')
        Path(env['SCREEN_STATE']).unlink()
        result = subprocess.run(['bash', str(home / '.local/bin/gnome-inhibit-and-lock')],
                                env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(Path(env['SCREEN_STATE']).exists())


if __name__ == '__main__':
    unittest.main()
