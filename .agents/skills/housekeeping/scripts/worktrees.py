"""Find Git worktrees whose removal loses nothing, and remove them through ADW or wt.

Removable: clean, no running process inside, no ignored user data, and either merged into the default
branch or idle for IDLE_DAYS with every commit on origin. Any unknown keeps the worktree.
"""
import hashlib
import json
import os
import re
import time
from datetime import datetime
from pathlib import Path

from measure import newest_mtime, run

# Ignored names that tools regenerate. Anything else ignored is checked for user data.
GENERATED = {
    'node_modules', '.venv', 'venv', '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache', '.tox',
    'dist', 'build', 'out', '.next', '.nuxt', '.svelte-kit', '.turbo', '.parcel-cache', '.cache', '.expo',
    'coverage', '.nyc_output', 'target', '.build', 'DerivedData', '.gradle', 'Pods', '.dart_tool',
    '_build', '_hooks', 'deps', '.elixir_ls', '.lexical', '.yarn', '.pnpm-store', '.nx', 'test-results', 'playwright-report',
    'blob-report', 'tmp', 'log', 'logs', '.DS_Store', '.ports.env', '.eslintcache', 'tsconfig.tsbuildinfo',
}
GENERATED_SUFFIXES = ('.pyc', '.log', '.tsbuildinfo', '.egg-info', '.map', '.css', '.js')
# Ignored files that are likely irreplaceable: secrets, databases, media, models.
USER_DATA = re.compile(r'(^|/)(\.env[^/]*|[^/]*\.env)$|\.(db|sqlite3?|sqlite-wal|sqlite-shm|duckdb|dump|pem|key|p12|'
                       r'mp4|mov|m4a|wav|mp3|gguf|safetensors|onnx|pt|ckpt)$', re.I)
MAX_WALK = 3000
MAX_REMOVALS = 25
IDLE_DAYS = 14


def git(path, *args, timeout=20):
    return run(['git', '-c', 'core.fsmonitor=false', '-C', str(path), *args], timeout=timeout)


def adw_state(home):
    """Return ({worktree_path: run}, {registered project roots}). Empty when ADW is absent."""
    config = home / '.adw' / 'config.yaml'
    if not config.is_file():
        return {}, set()
    roots = {m[1].strip().strip('\'"') for m in re.finditer(r'^\s*-?\s*path:\s*(.+)$', config.read_text(), re.M)}
    r = run(['adw', 'workflow', 'list', '--all', '--json'], timeout=120, limit=64 * 1024 ** 2)
    try:
        runs = json.loads(r['out']) if r['code'] == 0 else []
    except ValueError:
        runs = []
    by_path = {}
    for x in runs if isinstance(runs, list) else []:
        if isinstance(x, dict) and x.get('worktree_path') and not x.get('workspace_gone'):
            by_path.setdefault(x['worktree_path'], []).append(x)
    return by_path, roots


def main_checkout(path):
    r = git(path, 'worktree', 'list', '--porcelain')
    first = r['out'].split('\n', 1)[0] if r['code'] == 0 else ''
    return first[len('worktree '):] if first.startswith('worktree ') else None


def linked_worktrees(main):
    """Linked (non-main) worktrees of a repository as dicts with path, head, branch, locked."""
    r = git(main, 'worktree', 'list', '--porcelain')
    if r['code'] != 0:
        return []
    out = []
    for block in r['out'].strip().split('\n\n')[1:]:
        w = {'main': main, 'locked': False, 'prunable': False, 'branch': None, 'head': None}
        for line in block.splitlines():
            key, _, value = line.partition(' ')
            if key == 'worktree':
                w['path'] = value
            elif key == 'HEAD':
                w['head'] = value
            elif key == 'branch':
                w['branch'] = value.removeprefix('refs/heads/')
            elif key in ('locked', 'prunable'):
                w[key] = True
        if 'path' in w:
            out.append(w)
    return out


def digest(path):
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def env_is_copy(file, main_file, overlay):
    """An env file is a copy when each line is in the main checkout's copy or ADW's .ports.env overlay."""
    try:
        known = set(main_file.read_text().splitlines()) | set(overlay)
        lines = file.read_text().splitlines()
    except (OSError, UnicodeDecodeError):
        return False
    return all(not line.strip() or line.lstrip().startswith('#') or line in known for line in lines)


def is_generated(rel):
    parts = rel.rstrip('/').split('/')
    return any(p in GENERATED for p in parts) or parts[-1].endswith(GENERATED_SUFFIXES)


def ignored_risk(path, main):
    """Return a short list of ignored paths that may hold user data, or None when all are disposable.

    An unreadable or oversized ignored directory counts as risky.
    """
    r = git(path, 'status', '--porcelain=v1', '-z', '--ignored=traditional', '--untracked-files=normal', timeout=60)
    if r['code'] != 0:
        return ['git status failed']
    entries = [e[3:] for e in r['out'].split('\0') if e.startswith('!! ')]
    try:
        overlay = (Path(path) / '.ports.env').read_text().splitlines()
    except (OSError, UnicodeDecodeError):
        overlay = []
    risky = []
    for rel in entries:
        if is_generated(rel):
            continue
        target = Path(path) / rel
        if target.is_dir() and not target.is_symlink():
            risky += walk_risk(target, Path(main) / rel, rel, overlay)
        elif USER_DATA.search(rel) and not same_file(target, Path(main) / rel, overlay):
            risky.append(rel)
        if len(risky) >= 3:
            break
    return risky[:3] or None


def same_file(file, main_file, overlay):
    return digest(file) is not None and (digest(file) == digest(main_file) or env_is_copy(file, main_file, overlay))


def walk_risk(directory, main_directory, rel, overlay):
    """Every file under an ignored directory is inspected; user-data names must be copies of the main checkout's."""
    risky, count = [], 0
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if d not in GENERATED]
        for name in files:
            count += 1
            if count > MAX_WALK:
                return [rel + ' (too large to inspect)']
            sub = Path(root, name).relative_to(directory)
            if USER_DATA.search(name) and not same_file(Path(root, name), main_directory / sub, overlay):
                risky.append(f'{rel.rstrip("/")}/{sub}')
    # Unknown ignored directories (review notes, audit output) may be the only copy, so they keep the worktree.
    return risky or ([rel] if count else [])


def default_ref(main):
    r = git(main, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD')
    if r['code'] == 0:
        return r['out'].strip()
    for ref in ('origin/main', 'origin/master'):
        if git(main, 'rev-parse', '--verify', '--quiet', ref)['code'] == 0:
            return ref
    return None


def merged(w, ref):
    """Return how HEAD reached the default branch, or None when unproven."""
    if git(w['path'], 'merge-base', '--is-ancestor', w['head'], ref)['code'] == 0:
        return 'merged into ' + ref
    remote = git(w['main'], 'remote', 'get-url', 'origin')['out']
    if 'github.com' not in remote:
        return None
    base = ref.split('/', 1)[1]
    r = run(['gh', 'pr', 'list', '--state', 'merged', '--search', w['head'], '--limit', '5',
             '--json', 'number,headRefOid,baseRefName,mergeCommit'], cwd=w['main'], timeout=30)
    try:
        prs = json.loads(r['out']) if r['code'] == 0 else []
    except ValueError:
        return None
    for pr in prs:
        landing = (pr.get('mergeCommit') or {}).get('oid')
        if (pr.get('headRefOid') == w['head'] and pr.get('baseRefName') == base and landing
                and git(w['main'], 'merge-base', '--is-ancestor', landing, ref)['code'] == 0):
            return f'PR #{pr["number"]} merged'
    return None


def pushed(w):
    """True when HEAD is contained in a branch on origin, so removing the worktree loses no commits."""
    r = git(w['path'], 'branch', '-r', '--contains', w['head'], timeout=30)
    return r['code'] == 0 and any(b.strip() and '->' not in b for b in r['out'].splitlines())


def idle_days(w):
    """Days since anything touched the worktree: its files, index, HEAD, or its ADW run."""
    times = [newest_mtime(Path(w['path']))]
    gitdir = git(w['path'], 'rev-parse', '--absolute-git-dir')['out'].strip()
    for name in ('index', 'HEAD', 'logs/HEAD'):
        try:
            times.append((Path(gitdir) / name).stat().st_mtime)
        except OSError:
            pass
    stamp = (w['run'] or {}).get('updated_at')
    if stamp:
        try:
            times.append(datetime.fromisoformat(stamp.replace('Z', '+00:00')).timestamp())
        except ValueError:
            pass
    return (time.time() - max(times)) / 86400


def inside(path, others):
    p = path.rstrip('/') + '/'
    return any((c.rstrip('/') + '/').startswith(p) for c in others)


def plan(home, extra_repositories, cwds):
    """Classify every linked worktree. Returns list of dicts with decision 'remove' or 'keep' and a reason."""
    runs, roots = adw_state(home)
    mains = {m for m in (main_checkout(p) for p in sorted(roots | set(extra_repositories)) if Path(p).is_dir()) if m}
    t3_root = str(home / '.t3') + '/'
    fetched, out = set(), []
    for main in sorted(mains):
        for w in linked_worktrees(main):
            path = w['path']
            adw = [x for x in runs.get(path, []) if path not in roots]
            w['manager'] = 'adw' if adw else 'wt'
            w['run'] = adw[0] if adw else None
            w['decision'], w['reason'] = 'keep', None
            if path.startswith(t3_root):
                w['reason'] = 'T3 Code worktree (T3 manages it)'
            elif path in roots:
                w['reason'] = 'registered ADW project'
            elif w['locked'] or w['prunable'] or not Path(path).is_dir():
                w['reason'] = 'locked or missing on disk'
            elif any(x.get('status') in ('pending', 'running') for x in adw):
                w['reason'] = 'workflow still running'
            elif cwds is None:
                w['reason'] = 'could not check running processes'
            elif inside(path, cwds):
                w['reason'] = 'a running process is inside it'
            else:
                w['reason'] = gates(w, main, fetched)
            if w['reason'] is None:
                w['decision'] = 'remove'
            out.append(w)
    return out


def gates(w, main, fetched):
    status = git(w['path'], 'status', '--porcelain', timeout=60)
    if status['code'] != 0:
        return 'git status failed'
    if status['out'].strip():
        return 'uncommitted changes'
    ref = default_ref(main)
    if not ref:
        return 'no default branch to compare with'
    if main not in fetched:
        fetched.add(main)
        git(main, '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', 'fetch', '--quiet', '--prune', '--no-tags',
            'origin', timeout=120)
    how = merged(w, ref)
    if not how:
        if not pushed(w):
            return 'has commits that are not on the remote'
        days = idle_days(w)
        if days < IDLE_DAYS:
            return f'not merged and used in the last {IDLE_DAYS} days'
        how = f'all commits on the remote, idle {days:.0f} days'
    risky = ignored_risk(w['path'], main)
    if risky:
        return 'ignored files that may be yours: ' + ', '.join(risky)
    w['merged'] = how
    return None


def remove(w):
    """Remove one planned worktree with its manager. Returns an error string or None."""
    if w['manager'] == 'adw':
        r = run(['adw', 'purge', '--project', w['run']['project'], '--yes', w['run']['adw_id']], timeout=300)
    else:
        r = run(['wt', '-C', w['main'], 'remove', '--yes', '--foreground', w['path']], timeout=300)
    if r['code'] != 0:
        return (r.get('error') or r['out'].strip().splitlines()[-1:] or ['failed'])[0][:160]
    if Path(w['path']).exists():
        return 'still on disk after removal'
    if git(w['main'], 'rev-parse', '--verify', 'HEAD')['code'] != 0:
        return 'main checkout failed its check after removal'
    return None
