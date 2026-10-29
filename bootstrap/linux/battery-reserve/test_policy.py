#!/usr/bin/python3
"""No root, live sysfs writes, or real sleep calls. Exercise action boundaries."""
import importlib.machinery
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

loader = importlib.machinery.SourceFileLoader('reserve', str(Path(__file__).with_name('battery-reserve')))
spec = importlib.util.spec_from_loader(loader.name, loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.p = dict(armed=True, threshold=20, debounce=30, rearm=120)
        self.s = {}
        self.calls = []

    def tick(self, ac=0, cap=20, now=0, last_ac=0, reader=None, code=0):
        return m.tick(self.s, self.p, now, reader=reader or (lambda: (ac, cap)),
                      ac_reader=lambda: last_ac, persist=lambda s: None,
                      run=lambda command, **kw: (self.calls.append(command) or SimpleNamespace(returncode=code)))

    def test_ac_and_above(self):
        self.assertIn('decision=ac', self.tick(ac=1, cap=5))
        self.assertIn('above-reserve', self.tick(cap=21))
        self.assertFalse(self.calls)

    def test_debounce_threshold_and_resume_latch(self):
        self.assertIn('debouncing', self.tick(cap=20))
        self.assertIn('debouncing', self.tick(cap=19, now=29))
        self.tick(cap=19, now=30)
        self.assertEqual(self.calls, [m.COMMAND])
        self.assertTrue(self.s['latched'])
        self.assertIn('latched', self.tick(cap=18, now=900))
        self.assertEqual(len(self.calls), 1)

    def test_unknown_resets_debounce(self):
        self.tick()
        def bad():
            raise FileNotFoundError('missing battery')
        self.assertIn('unknown-data', self.tick(now=30, reader=bad))
        self.assertIn('debouncing', self.tick(now=60))
        self.assertFalse(self.calls)

    def test_ac_last_moment(self):
        self.tick()
        self.assertIn('cancelled', self.tick(now=30, last_ac=1))
        self.assertFalse(self.calls)
        self.assertNotIn('latched', self.s)

    def test_ac_recheck_error(self):
        self.s['low_since'] = 0
        def bad():
            raise OSError('read error')
        result = m.tick(self.s, self.p, 30, reader=lambda: (0, 20), ac_reader=bad,
                        persist=lambda s: None, run=lambda *a, **k: self.fail('must not suspend'))
        self.assertIn('cancelled', result)

    def test_ac_stable_rearm_and_bounce(self):
        self.s['latched'] = True
        self.tick(ac=1, now=0)
        self.tick(ac=0, now=60)
        self.tick(ac=1, now=90)
        self.tick(ac=1, now=209)
        self.assertTrue(self.s['latched'])
        self.tick(ac=1, now=210)
        self.assertNotIn('latched', self.s)
        self.assertIn('debouncing', self.tick(ac=0, now=240))

    def test_failure_stays_latched(self):
        self.tick()
        self.tick(now=30, code=1)
        self.assertIn('latched', self.tick(now=60))
        self.assertEqual(len(self.calls), 1)

    def test_disarmed(self):
        self.p['armed'] = False
        self.tick()
        self.assertIn('disarmed-would-suspend', self.tick(now=30))
        self.assertFalse(self.calls)

    def test_real_reader_validation(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            ac, battery = Path(d) / 'ac', Path(d) / 'battery'
            old_ac, old_battery = m.AC, m.BATTERY
            m.AC, m.BATTERY = ac, battery
            try:
                ac.write_text('0\n')
                battery.write_text('20\n')
                self.assertEqual(m.sample(), (0, 20))
                for value in ('', '-1', '101', 'unknown'):
                    battery.write_text(value)
                    with self.assertRaises(ValueError):
                        m.sample()
                battery.unlink()
                with self.assertRaises(FileNotFoundError):
                    m.sample()
                ac.write_text('unknown')
                with self.assertRaises(ValueError):
                    m.read_ac()
            finally:
                m.AC, m.BATTERY = old_ac, old_battery


if __name__ == '__main__':
    unittest.main()
