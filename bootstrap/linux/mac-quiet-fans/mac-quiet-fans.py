#!/usr/bin/python3
"""neofand Quiet curve adapted to macsmc_hwmon's fan_target interface.

Curve provenance: akhilv1/neofand commit
9da402c87a6a3941047ec08bf71d2120076eec82, src/config.rs and
src/fan_controller.rs. This is a local adapter, not an installed neofand build.
"""
from collections import deque
import fcntl
import json
import os
from pathlib import Path
import signal
import socket
import sys
import time

ROOT = Path('/sys/class/hwmon')
PARAM = Path('/sys/module/macsmc_hwmon/parameters/fan_control')
RUNTIME = Path('/run/mac-quiet-fans')
PROFILE = {'name': 'neofand-quiet', 'cpu_C': [70, 92], 'gpu_junction_C': [80, 96],
           'curve': 'cubic', 'poll_seconds': 1, 'fall_samples': 20,
           'upstream_commit': '9da402c87a6a3941047ec08bf71d2120076eec82',
           'implementation': 'local macsmc_hwmon adapter'}


def read(path):
    return int(path.read_text().strip())


def write(path, value):
    path.write_text(str(value) + '\n')


def discover():
    found = {}
    for path in ROOT.glob('hwmon*'):
        name = (path / 'name').read_text().strip()
        if name in found and name in ('macsmc_hwmon', 'coretemp', 'amdgpu'):
            raise RuntimeError('Ambiguous device: ' + name)
        found[name] = path
    smc, cpu, gpu = (found[n] for n in ('macsmc_hwmon', 'coretemp', 'amdgpu'))
    cpu_paths = [p.with_name(p.name.replace('_label', '_input'))
                 for p in cpu.glob('temp*_label') if p.read_text().strip().startswith('Package id')]
    gpu_paths = [p.with_name(p.name.replace('_label', '_input'))
                 for p in gpu.glob('temp*_label') if p.read_text().strip() == 'junction']
    if not cpu_paths or len(gpu_paths) != 1:
        raise RuntimeError('CPU package or GPU junction sensor unavailable')
    limits = [(read(smc / f'fan{i}_min'), read(smc / f'fan{i}_max')) for i in (1, 2)]
    if any(not 0 < lo < hi < 10000 for lo, hi in limits):
        raise RuntimeError('Implausible fan limits')
    return smc, cpu_paths, gpu_paths, limits


def temperatures(cpu_paths, gpu_paths):
    values = [max(read(p) for p in paths) / 1000 for paths in (cpu_paths, gpu_paths)]
    if any(not 1 <= v <= 125 for v in values):
        raise RuntimeError('Implausible temperature reading')
    return values


def targets(cpu, gpu, limits):
    demand = max(min(1., max(0., (cpu - 70) / 22)),
                 min(1., max(0., (gpu - 80) / 16))) ** 3
    return [lo + int(demand * (hi - lo)) for lo, hi in limits]


class Response:
    def __init__(self):
        self.history = [deque(maxlen=20), deque(maxlen=20)]

    def effective(self, values):
        out = []
        for history, value in zip(self.history, values):
            # Upstream reads whole Celsius and uses an integer trailing mean.
            value = int(value)
            history.append(value)
            out.append(max(value, sum(history) // len(history)))
        return out


def status(mode, **fields):
    RUNTIME.mkdir(mode=0o755, exist_ok=True)
    data = {'timestamp': time.time(), 'mode': mode, 'profile': PROFILE, **fields}
    temp = RUNTIME / 'status.tmp'
    temp.write_text(json.dumps(data) + '\n')
    temp.replace(RUNTIME / 'status.json')
    return data


def notify(message):
    address = os.environ.get('NOTIFY_SOCKET')
    if address:
        if address.startswith('@'):
            address = '\0' + address[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.connect(address)
            sock.sendall(message.encode())


def restore():
    # Only release a manual override owned by this service, not someone else's.
    owner = RUNTIME / 'owned'
    if not owner.exists():
        return
    smc = next(p for p in ROOT.glob('hwmon*')
               if (p / 'name').read_text().strip() == 'macsmc_hwmon')
    errors = []
    for i in (1, 2):
        try:
            write(smc / f'fan{i}_target', 0)
        except Exception as exc:
            errors.append(str(exc))
            try:
                write(smc / f'fan{i}_target', read(smc / f'fan{i}_max'))
            except Exception as fallback:
                errors.append(str(fallback))
    if errors:
        status('RESTORE_FAILED', errors=errors)
        raise RuntimeError('; '.join(errors))
    write(PARAM, 'N')
    owner.unlink()
    print(json.dumps(status('firmware', reason='Manual targets released')), flush=True)


def stopped(signum, frame):
    raise SystemExit(0)


def run():
    RUNTIME.mkdir(mode=0o755, exist_ok=True)
    with (RUNTIME / 'controller.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        restore()  # Recover our own override if an earlier process was killed.
        smc, cpu_paths, gpu_paths, limits = discover()
        initial = temperatures(cpu_paths, gpu_paths)
        if PARAM.read_text().strip() != 'N':
            raise RuntimeError('Another manual fan override is active')
        (RUNTIME / 'owned').write_text(str(os.getpid()) + '\n')
        response = Response()
        expected = None
        stable_since = time.monotonic()
        last_record = -float('inf')
        try:
            write(PARAM, 'Y')
            while True:
                now = time.monotonic()
                raw = temperatures(cpu_paths, gpu_paths)
                effective = response.effective(raw)
                rpm = targets(*effective, limits)
                if PARAM.read_text().strip() != 'Y':
                    raise RuntimeError('Manual override changed externally')
                if expected is not None:
                    actual_targets = [read(smc / f'fan{i}_target') for i in (1, 2)]
                    if any(abs(a-b) > 2 for a,b in zip(actual_targets, expected)):
                        raise RuntimeError('Fan target changed externally')
                actual = [read(smc / f'fan{i}_input') for i in (1, 2)]
                if expected is not None and now - stable_since > 30:
                    if any(abs(a-b) > max(300, b * .25) for a,b in zip(actual, expected)):
                        raise RuntimeError('Fan RPM did not follow target')
                if rpm != expected:
                    for i, value in enumerate(rpm, 1):
                        write(smc / f'fan{i}_target', value)
                    expected, stable_since = rpm, now
                if now - last_record >= 5:
                    data = status('quiet-automatic', raw_C={'cpu_package':raw[0], 'gpu_junction':raw[1]},
                                  effective_C=effective, targets=rpm, actual_RPM=actual, limits=limits)
                    if last_record == -float('inf'):
                        print(json.dumps(data), flush=True)
                    last_record = now
                notify('READY=1\nWATCHDOG=1')
                time.sleep(1)
        finally:
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            signal.signal(signal.SIGINT, signal.SIG_IGN)
            restore()


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stopped)
    signal.signal(signal.SIGINT, stopped)
    if sys.argv[1:] == ['--check']:
        smc, cpu_paths, gpu_paths, limits = discover()
        raw = temperatures(cpu_paths, gpu_paths)
        print(json.dumps({'profile':PROFILE, 'raw_C':raw, 'limits':limits,
                          'computed_targets':targets(*(int(v) for v in raw), limits)}))
    elif sys.argv[1:] == ['restore']:
        restore()
    elif not sys.argv[1:]:
        run()
    else:
        raise SystemExit('Usage: mac-quiet-fans.py [--check|restore]')
