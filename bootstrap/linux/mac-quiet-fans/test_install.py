"""Run a relocated installer with stub services/ownership; never touch live sysfs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PACKAGE = Path(__file__).resolve().parent


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = self.root / 'package'
        self.package.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.state = self.root / 'services.json'
        self.state.write_text(json.dumps({'active': False, 'enabled': False, 'conflict': False}))
        for p in ('run/mac-quiet-fans', 'sys/class/dmi/id', 'sys/module/macsmc_hwmon/parameters',
                  'usr/lib/systemd/system-sleep', 'etc/systemd/system'):
            (self.root / p).mkdir(parents=True, exist_ok=True)
        self.param = self.root / 'sys/module/macsmc_hwmon/parameters/fan_control'
        self.param.write_text('N')
        self.model = self.root / 'sys/class/dmi/id/product_name'
        self.model.write_text('MacBookPro16,1')
        (self.root / 'run/mac-quiet-fans/status.json').write_text('{}')
        text = (PACKAGE / 'install-quiet-fans.sh').read_text()
        self.assertIn('[[ $EUID -eq 0 ]]', text)
        text = text.replace('[[ $EUID -eq 0 ]]', '[[ 1 -eq 1 ]]')
        for prefix in ('/usr/local/lib', '/usr/lib/systemd', '/etc/systemd', '/var/backups', '/run/', '/sys/'):
            text = text.replace(prefix, str(self.root) + prefix)
        self.script = self.package / 'install-quiet-fans.sh'
        self.script.write_text(text)
        # Only the separate curve tests run the actual controller (in fake sysfs).
        (self.package / 'mac-quiet-fans.py').write_text('import sys\nassert sys.argv[1:] == ["--check"]\n')
        for name in ('mac-quiet-fans.service', 'mac-quiet-fans-sleep'):
            shutil.copyfile(PACKAGE / name, self.package / name)
        self.stub('systemctl', f'''#!/usr/bin/python3
import json, sys
from pathlib import Path
state=Path({str(self.state)!r}); s=json.loads(state.read_text()); a=sys.argv[1:]
if a[0]=='is-enabled': sys.exit(0 if s['enabled'] else 1)
if a[0]=='is-active':
    sys.exit(0 if (s['active'] if a[-1]=='mac-quiet-fans.service' else s['conflict']) else 1)
if a[0] in ('stop','disable'):
    s['active']=False
    Path({str(self.param)!r}).write_text('N')
if a[0]=='disable': s['enabled']=False
if a[0]=='enable': s['enabled']=True
if a[0]=='start' or (a[0]=='enable' and '--now' in a): s['active']=True
state.write_text(json.dumps(s))
''')
        self.stub('install', '''#!/usr/bin/python3
import subprocess, sys
args=[]; it=iter(sys.argv[1:])
for arg in it:
    if arg in ('-o','-g'): next(it)
    else: args.append(arg)
subprocess.run(['/usr/bin/install',*args],check=True)
''')
        self.stub('sleep', '#!/bin/sh\nexit 0\n')
        self.stub('systemd-analyze', '#!/bin/sh\nexit 0\n')
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.backup = self.root / 'var/backups/mac-quiet-fans-original'
        self.targets = [self.root / p for p in ('usr/local/lib/mac-quiet-fans/controller.py',
                        'etc/systemd/system/mac-quiet-fans.service',
                        'usr/lib/systemd/system-sleep/mac-quiet-fans')]

    def stub(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def install(self, *args, success=True):
        result = subprocess.run(['bash', str(self.script), *args], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_fresh_install_and_rollback(self):
        self.install()
        for p, mode in zip(self.targets, (0o755, 0o644, 0o755)):
            self.assertEqual(p.stat().st_mode & 0o777, mode)
        self.assertEqual(json.loads(self.state.read_text())['enabled'], True)
        self.install('--rollback')
        self.assertTrue(all(not p.exists() for p in self.targets))
        self.assertFalse(json.loads(self.state.read_text())['active'])
        self.assertTrue((self.backup / 'complete').exists())

    def test_repeat_preserves_original_files_and_active_state(self):
        for p in self.targets:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('original file')
            p.chmod(0o640)
        self.state.write_text(json.dumps({'active': True, 'enabled': True, 'conflict': False}))
        self.install()
        snapshot = {p.relative_to(self.backup): p.read_bytes() for p in self.backup.rglob('*') if p.is_file()}
        self.install()
        self.assertEqual(snapshot, {p.relative_to(self.backup): p.read_bytes() for p in self.backup.rglob('*') if p.is_file()})
        self.install('--rollback')
        for p in self.targets:
            self.assertEqual(p.read_text(), 'original file')
            self.assertEqual(p.stat().st_mode & 0o777, 0o640)
        state = json.loads(self.state.read_text())
        self.assertTrue(state['active'] and state['enabled'])

    def test_refuses_other_model_controller_and_unowned_override(self):
        self.model.write_text('Other model')
        self.install(success=False)
        self.assertFalse(self.backup.exists())
        self.model.write_text('MacBookPro16,1')
        self.state.write_text(json.dumps({'active': False, 'enabled': False, 'conflict': True}))
        self.install(success=False)
        self.assertFalse(self.backup.exists())
        self.state.write_text(json.dumps({'active': False, 'enabled': False, 'conflict': False}))
        self.param.write_text('Y')
        self.install(success=False)
        self.assertTrue(all(not p.exists() for p in self.targets))
        self.assertEqual(self.param.read_text(), 'Y')

    def test_bootstrap_opt_in_skip_disabled_and_invalid(self):
        script = (PACKAGE / 'bootstrap.sh').read_text().replace('/etc/systemd', str(self.root) + '/etc/systemd')
        wrapper = self.package / 'bootstrap.sh'
        wrapper.write_text(script)
        calls = self.root / 'sudo-calls'
        self.stub('sudo', '#!/bin/sh\nprintf "%s\\n" "$*" >> ' + str(calls) + '\n')
        for option, expected, code in [('auto', False, 0), ('0', False, 0), ('1', True, 0), ('invalid', False, 1)]:
            calls.unlink(missing_ok=True)
            result = subprocess.run(['bash', str(wrapper)], env=dict(self.env, DOTFILES_MAC_QUIET_FANS=option), capture_output=True)
            self.assertEqual(result.returncode, code)
            self.assertEqual(calls.exists(), expected)
        self.targets[1].write_text('installed unit')
        for enabled in (False, True):
            calls.unlink(missing_ok=True)
            self.state.write_text(json.dumps({'active': False, 'enabled': enabled, 'conflict': False}))
            subprocess.run(['bash', str(wrapper)], env=dict(self.env, DOTFILES_MAC_QUIET_FANS='auto'), check=True)
            self.assertEqual(calls.exists(), enabled)

    def test_sleep_hook_resumes_only_previously_active_enabled_service(self):
        hook = self.package / 'mac-quiet-fans-sleep'
        hook.write_text((PACKAGE / hook.name).read_text().replace('/run/', str(self.root) + '/run/'))
        marker = self.root / 'run/mac-quiet-fans/resume-after-sleep'
        for enabled_after in (True, False):
            self.state.write_text(json.dumps({'active': True, 'enabled': True, 'conflict': False}))
            subprocess.run(['sh', str(hook), 'pre'], env=self.env, check=True)
            self.assertTrue(marker.exists())
            self.assertFalse(json.loads(self.state.read_text())['active'])
            self.state.write_text(json.dumps({'active': False, 'enabled': enabled_after, 'conflict': False}))
            subprocess.run(['sh', str(hook), 'post'], env=self.env, check=True)
            self.assertEqual(json.loads(self.state.read_text())['active'], enabled_after)
            self.assertFalse(marker.exists())

    def test_sleep_hook_leaves_inactive_service_stopped(self):
        hook = self.package / 'mac-quiet-fans-sleep'
        hook.write_text((PACKAGE / hook.name).read_text().replace('/run/', str(self.root) + '/run/'))
        for phase in ('pre', 'post'):
            subprocess.run(['sh', str(hook), phase], env=self.env, check=True)
        self.assertFalse(json.loads(self.state.read_text())['active'])


if __name__ == '__main__':
    unittest.main()
