import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import clean  # noqa: E402
import housekeeping  # noqa: E402
import measure  # noqa: E402
import report  # noqa: E402
import status  # noqa: E402
import worktrees  # noqa: E402

GIB = 1024 ** 3
FIXTURES = HERE / 'fixtures'


def fixture():
    run = json.loads((FIXTURES / 'run.json').read_text())
    history = [json.loads(line) for line in (FIXTURES / 'history.jsonl').read_text().splitlines()]
    return run, history


class Measure(unittest.TestCase):
    def test_status_thresholds(self):
        self.assertEqual(measure.status(20 * GIB, 400 * GIB, 15, 25), 'urgent')
        self.assertEqual(measure.status(50 * GIB, 400 * GIB, 15, 25), 'warning')
        self.assertEqual(measure.status(80 * GIB, 400 * GIB, 15, 25), 'healthy')

    def test_run_bounds_time_and_reports_missing_tools(self):
        started = time.monotonic()
        r = measure.run([sys.executable, '-c', 'import time; time.sleep(5)'], timeout=0.5)
        self.assertIsNone(r['code'])
        self.assertLess(time.monotonic() - started, 3)
        self.assertIn('unavailable', measure.run(['/nonexistent/tool'])['error'])

    def test_run_keeps_only_the_tail_of_long_output(self):
        r = measure.run([sys.executable, '-c', 'print("x" * 5000 + "END")'], limit=100)
        self.assertEqual(r['code'], 0)
        self.assertLessEqual(len(r['out']), 100)
        self.assertIn('END', r['out'])

    def test_run_stops_when_a_tool_announces_it_will_wait(self):
        started = time.monotonic()
        waits = 'import sys, time; print("Cache is currently in-use, waiting", flush=True); time.sleep(10)'
        r = measure.run([sys.executable, '-c', waits], timeout=8, stop='in-use')
        self.assertTrue(r['stopped'])
        self.assertLess(time.monotonic() - started, 3)


class Clean(unittest.TestCase):
    def test_reclaimed_sums_docker_totals(self):
        text = 'Deleted Images:\nx\n\nTotal reclaimed space: 1.5GB\nID\nTotal:\t500MB\n'
        self.assertEqual(clean.reclaimed(text), 2_000_000_000)
        self.assertEqual(clean.docker_size('6.093GB'), 6_093_000_000)
        self.assertIsNone(clean.docker_size(None))

    def test_tool_action_outcomes(self):
        spec = ('t', 'caches', 'Tool', [sys.executable, '-c', 'pass'], None, 10)
        self.assertEqual(clean.tool_action(spec, '/', True)['outcome'], 'planned')
        done = clean.tool_action(spec, '/', False)
        self.assertEqual(done['outcome'], 'done')
        self.assertGreaterEqual(done['bytes'], 0)
        failing = ('t', 'caches', 'Tool', [sys.executable, '-c', 'raise SystemExit("boom")'], None, 10)
        self.assertEqual(clean.tool_action(failing, '/', False)['reason'], 'boom')
        missing = ('t', 'caches', 'Tool', ['no-such-tool-xyz'], None, 10)
        self.assertEqual(clean.tool_action(missing, '/', False)['outcome'], 'skipped')

    def test_tool_action_skips_uv_when_its_cache_is_in_use(self):
        spec = ('uv', 'caches', 'uv', ['uv', 'cache', 'prune'], None, 10)
        stopped = {'code': None, 'out': '', 'error': 'stopped', 'stopped': True}
        with mock.patch.object(clean, 'available', return_value=True), \
                mock.patch.object(clean, 'run', return_value=stopped) as run:
            r = clean.tool_action(spec, '/', False)
        self.assertEqual((r['outcome'], r['reason']), ('skipped', 'another uv process is using its cache'))
        self.assertEqual(run.call_args.kwargs['stop'], clean.IN_USE['uv'])

    def test_tool_action_waits_for_busy_tools(self):
        spec = ('t', 'caches', 'Tool', [sys.executable, '-c', 'pass'], 'pattern', 10)
        with mock.patch.object(clean, 'busy', return_value=True):
            self.assertIn('right now', clean.tool_action(spec, '/', False)['reason'])

    def test_disposable_folders_need_age_idleness_and_home(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp).resolve()
            old, new, busy_dir = home / 'old', home / 'new', home / 'busy'
            for d in (old, new, busy_dir):
                (d / 'sub').mkdir(parents=True)
            stamp = time.time() - 30 * clean.DAY
            for d in (old, busy_dir):
                os.utime(d / 'sub', (stamp, stamp))
                os.utime(d, (stamp, stamp))
            out = clean.disposable(home, [str(old), str(new), str(busy_dir), '/tmp'], {str(busy_dir / 'sub')}, '/', False)
            by_label = {r['label']: r for r in out}
            self.assertEqual(by_label['~/old']['outcome'], 'done')
            self.assertFalse(old.exists())
            self.assertIn('14 days', by_label['~/new']['reason'])
            self.assertIn('running process', by_label['~/busy']['reason'])
            self.assertIn('under your home', by_label['/tmp']['reason'])

    def test_disposable_never_deletes_git_checkouts(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp).resolve()
            build = home / 'repo' / 'build'
            build.mkdir(parents=True)
            (home / 'repo' / '.git').write_text('gitdir: elsewhere')
            stamp = time.time() - 30 * clean.DAY
            os.utime(build, (stamp, stamp))
            out = clean.disposable(home, [str(build), str(home / 'repo')], set(), '/', False)
            self.assertTrue(all('ADW or wt' in r['reason'] for r in out))
            self.assertTrue(build.exists())


def git(cwd, *args):
    subprocess.run(['git', '-C', str(cwd), *args], check=True, capture_output=True)


class Worktrees(unittest.TestCase):
    """Real repositories exercise every gate. ADW is absent because the fake home has no ADW config."""

    @classmethod
    def setUpClass(cls):
        cls.env = mock.patch.dict(os.environ, {
            'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_AUTHOR_NAME': 't',
            'GIT_AUTHOR_EMAIL': 't@t', 'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t'})
        cls.env.start()
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name).resolve()
        cls.home = root / 'home'
        origin, main = root / 'origin.git', root / 'main'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(origin)], check=True)
        subprocess.run(['git', 'clone', '-q', str(origin), str(main)], check=True, capture_output=True)
        (main / '.gitignore').write_text('.env\nnode_modules/\nnotes/\n')
        (main / '.env').write_text('SECRET=1\n')
        git(main, 'add', '.gitignore')
        git(main, 'commit', '-qm', 'init')
        git(main, 'push', '-q', 'origin', 'main')
        cls.main = main

        def worktree(name, base=root):
            path = base / name
            path.parent.mkdir(parents=True, exist_ok=True)
            git(main, 'worktree', 'add', '-q', '-b', name, str(path))
            (path / f'{name}.txt').write_text(name)
            git(path, 'add', '.')
            git(path, 'commit', '-qm', name)
            return path

        cls.paths = {}
        for name in ('merged', 'env-copy', 'env-differs', 'notes'):
            cls.paths[name] = worktree(name)
            git(main, 'merge', '-q', name)
        (cls.paths['merged'] / 'node_modules').mkdir()
        (cls.paths['merged'] / 'node_modules' / 'x.js').write_text('x')
        (cls.paths['env-copy'] / '.env').write_text('SECRET=1\n')
        (cls.paths['env-differs'] / '.env').write_text('SECRET=2\n')
        (cls.paths['notes'] / 'notes').mkdir()
        (cls.paths['notes'] / 'notes' / 'review.md').write_text('only copy')
        git(main, 'push', '-q', 'origin', 'main')
        cls.paths['dirty'] = worktree('dirty')
        (cls.paths['dirty'] / 'wip.txt').write_text('wip')
        cls.paths['unpushed'] = worktree('unpushed')
        cls.paths['recent'] = worktree('recent')
        git(main, 'push', '-q', 'origin', 'recent')
        cls.paths['busy'] = worktree('busy')
        git(main, 'merge', '-q', 'busy')
        git(main, 'push', '-q', 'origin', 'main')
        cls.paths['t3'] = worktree('t3', cls.home / '.t3' / 'worktrees')
        cls.paths['orphan'] = worktree('orphan', cls.home / '.adw' / 'projects' / 'p' / 'trees')
        git(main, 'merge', '-q', 'orphan')
        # Squash merge: the worktree sits one commit behind the PR's final head, which landed as one commit.
        cls.paths['squashed'] = worktree('squashed')
        git(cls.paths['squashed'], 'commit', '-q', '--allow-empty', '-m', 'after review')
        cls.pr_head = subprocess.run(['git', '-C', str(cls.paths['squashed']), 'rev-parse', 'HEAD'],
                                     capture_output=True, text=True, check=True).stdout.strip()
        git(cls.paths['squashed'], 'push', '-q', 'origin', f'{cls.pr_head}:refs/pull/7/head')
        git(cls.paths['squashed'], 'reset', '-q', '--hard', 'HEAD~1')
        git(main, 'merge', '-q', '--squash', cls.pr_head)
        git(main, 'commit', '-qm', 'squashed (#7)')
        cls.landing = subprocess.run(['git', '-C', str(main), 'rev-parse', 'HEAD'],
                                     capture_output=True, text=True, check=True).stdout.strip()
        git(main, 'push', '-q', 'origin', 'main')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()
        cls.env.stop()

    def plan(self, prs=()):
        """Plan with ADW absent and GitHub answering `gh pr list` with prs."""
        real = worktrees.run

        def fake(args, **kw):
            if args[0] == 'gh':
                return {'code': 0, 'out': json.dumps(list(prs))}
            return real(args, **kw)
        cwds = {str(self.paths['busy'] / 'sub')}
        with mock.patch.object(worktrees, 'on_github', return_value=True), mock.patch.object(worktrees, 'run', fake):
            return {Path(w['path']).name: w for w in worktrees.plan(self.home, [str(self.main)], cwds)}

    def test_every_gate(self):
        plan = self.plan()
        self.assertEqual(plan['merged']['decision'], 'remove')
        self.assertEqual(plan['merged']['merged'], 'merged into origin/main')
        self.assertEqual(plan['env-copy']['decision'], 'remove')
        expected = {
            'env-differs': 'ignored files that may be yours: .env',
            'notes': 'ignored files that may be yours: notes/',
            'dirty': 'uncommitted changes',
            'unpushed': 'not merged into origin/main',
            'recent': 'not merged into origin/main',
            'busy': 'a running process is inside it',
            't3': 'T3 Code worktree (T3 manages it)',
            'orphan': 'ADW worktree without a run record',
            'squashed': 'not merged into origin/main',
        }
        for name, reason in expected.items():
            self.assertEqual((plan[name]['decision'], plan[name]['reason']), ('keep', reason), name)

    def pr(self, **overrides):
        return {'number': 7, 'headRefOid': self.pr_head, 'baseRefName': 'main',
                'mergeCommit': {'oid': self.landing}, **overrides}

    def test_squash_merged_pr_containing_head_is_removable(self):
        plan = self.plan([self.pr()])
        self.assertEqual((plan['squashed']['decision'], plan['squashed']['merged']), ('remove', 'PR #7 merged'))
        self.assertEqual(plan['unpushed']['decision'], 'keep')

    def test_squash_proof_rejects_other_bases_and_missing_landing(self):
        for pr in (self.pr(baseRefName='feature'), self.pr(mergeCommit=None), self.pr(headRefOid='0' * 40)):
            self.assertEqual(self.plan([pr])['squashed']['decision'], 'keep', pr)

    def test_unknown_process_list_keeps_everything(self):
        plan = worktrees.plan(self.home, [str(self.main)], None)
        self.assertTrue(all(w['decision'] == 'keep' for w in plan))

    @unittest.skipUnless(shutil.which('wt'), 'wt not installed')
    def test_wt_removal_keeps_the_branch(self):
        w = self.plan()['merged']
        self.assertIsNone(worktrees.remove(w))
        self.assertFalse(Path(w['path']).exists())
        git(self.main, 'rev-parse', '--verify', 'refs/heads/merged')

    def test_adw_removal_stops_when_dry_run_refuses(self):
        w = {'manager': 'adw', 'runs': [{'project': 'p', 'adw_id': 'a1'}], 'path': '/x', 'main': '/y'}
        calls = []

        def fake(args, **kw):
            calls.append(args)
            return {'code': 1, 'out': 'no such run'}
        with mock.patch.object(worktrees, 'run', fake):
            self.assertIn('refused', worktrees.remove(w))
        self.assertEqual(calls, [['adw', 'purge', '--project', 'p', '--dry-run', 'a1']])

    def test_env_overlay_counts_as_copy(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp, 'a'), Path(tmp, 'b')
            a.write_text('KEY=1\nPORT=4000\n')
            b.write_text('KEY=1\nOTHER=2\n')
            self.assertTrue(worktrees.env_is_copy(a, b, ['PORT=4000']))
            self.assertFalse(worktrees.env_is_copy(a, b, []))


class Housekeeping(unittest.TestCase):
    def test_config_defaults_and_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, 'c.json')
            self.assertEqual(housekeeping.load_config(path)['warning_percent'], 15)
            for bad in ({'nope': 1}, {'urgent_gib': 0}, {'skip': ['everything']}, {'repositories': 'x'}):
                path.write_text(json.dumps(bad))
                path.chmod(0o600)
                with self.assertRaises(ValueError):
                    housekeeping.load_config(path)
            path.write_text(json.dumps({'skip': ['docker'], 'warning_percent': 20}))
            path.chmod(0o666)
            with self.assertRaises(ValueError):
                housekeeping.load_config(path)
            path.chmod(0o600)
            self.assertEqual(housekeeping.load_config(path)['skip'], ['docker'])

    def test_state_lives_in_xdg_state_unless_configured(self):
        with mock.patch.dict(os.environ, {'XDG_STATE_HOME': '/x/state'}):
            self.assertEqual(housekeeping.state_dir(housekeeping.OPTIONS), Path('/x/state/housekeeping'))
            self.assertEqual(housekeeping.state_dir({**housekeeping.OPTIONS, 'state_dir': '/y'}), Path('/y'))

    def test_status_reports_progress_and_unfinished_runs(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            self.assertEqual(status.in_progress(state), 'Now: idle.')
            with mock.patch.object(housekeeping, 'PROGRESS', (state / 'progress.json', '2026-10-17T10:00:00+00:00')):
                housekeeping.progress('Docker')
            self.assertIn('on "Docker"', status.in_progress(state))
            info = json.loads((state / 'progress.json').read_text())
            (state / 'progress.json').write_text(json.dumps({**info, 'pid': 2 ** 22 + 7}))
            self.assertIn('did not finish; it stopped during "Docker"', status.in_progress(state))

    def test_status_summarises_the_last_run(self):
        run, _ = fixture()
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, 'last-run.json').write_text(json.dumps(run))
            text = status.last_run(Path(tmp), 'last-run', 2)
        self.assertIn('Freed 92.6 GiB', text)
        self.assertIn('FAILED:', text)
        self.assertEqual(text.count('\n  '), 2)

    def test_history_is_capped_and_skips_bad_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, 'h.jsonl')
            path.write_text(''.join(json.dumps({'n': i}) + '\n' for i in range(600)) + 'not json\n')
            history = housekeeping.read_history(path)
            self.assertEqual(len(history), housekeeping.HISTORY_LINES - 1)
            housekeeping.append_history(path, {'n': 'new'}, history)
            lines = path.read_text().splitlines()
            self.assertEqual(len(lines), housekeeping.HISTORY_LINES)
            self.assertEqual(json.loads(lines[-1]), {'n': 'new'})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_summary_lists_failures_and_report_path(self):
        run, _ = fixture()
        text = housekeeping.summary(run, Path('/x/report.html'))
        self.assertIn('Freed 92.6 GiB', text)
        self.assertIn('FAILED: Worktree ~/.adw/projects/pace_api-507dfa9b/trees/9a6a0d97', text)
        self.assertTrue(text.endswith('Report: /x/report.html'))

    def test_skipped_and_out_of_budget_steps_are_reported(self):
        config = {**housekeeping.OPTIONS, 'skip': ['docker']}
        with mock.patch.object(clean, 'DEADLINE', time.monotonic() - 1), \
                mock.patch.object(measure, 'process_cwds', return_value=set()), \
                mock.patch.object(clean, 'playwright_kept', return_value=[]):
            results, low = housekeeping.cleanup(Path('/nonexistent'), config, '/', True, (1, 1))
        reasons = {r['label']: r['reason'] for r in results}
        self.assertEqual(reasons['Docker'], 'turned off in config')
        self.assertIn('budget', reasons['Homebrew old versions and downloads'])
        self.assertFalse(low)


class Report(unittest.TestCase):
    def test_renders_every_section_offline(self):
        run, history = fixture()
        page = report.render(run, history)
        for text in ('92.6 GiB', 'Freed by category', 'Free space over time', 'What it did', 'What it left alone',
                     'locked by another process', 'Memory right now', 'hist-data'):
            self.assertIn(text, page)
        self.assertIsNone(re.search(r'(src|href)="https?:', page))
        self.assertNotIn('url(http', page)

    def test_escapes_tool_text(self):
        run, history = fixture()
        run['results'][0]['label'] = '<script>alert(1)</script>'
        run['results'][0]['reason'] = '"><img src=x onerror=alert(1)>'
        page = report.render(run, history + [{'date': '</script><script>alert(2)//', 'capacity': 1}])
        self.assertNotIn('<script>alert', page)
        self.assertNotIn('<img src=x', page)

    def test_dry_run_and_first_run_states(self):
        run, _ = fixture()
        run.update(dry_run=True, freed={}, freed_bytes=0)
        for r in run['results']:
            if r['outcome'] == 'done':
                r['outcome'] = 'planned'
        run['counts']['planned'], run['counts']['done'] = run['counts']['done'], 0
        page = report.render(run, [])
        self.assertIn('actions planned', page)
        self.assertIn('Dry run: nothing was removed.', page)
        self.assertIn('What it would do', page)
        self.assertIn('History starts with the first real run.', page)


if __name__ == '__main__':
    unittest.main()
