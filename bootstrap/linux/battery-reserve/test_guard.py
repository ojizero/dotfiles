"""Exercise the guard without live lid reads, inhibitors or sleep requests."""
import importlib.machinery
import importlib.util
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

loader = importlib.machinery.SourceFileLoader('guard', str(Path(__file__).with_name('closed-lid-suspend-guard')))
spec = importlib.util.spec_from_loader(loader.name, loader)
g = importlib.util.module_from_spec(spec)
loader.exec_module(g)


class GuardTests(unittest.TestCase):
    def test_parser(self):
        with tempfile.TemporaryDirectory() as directory:
            lid = Path(directory) / 'state'
            for value, expected in [('state:      closed\n', True), ('state:      open\n', False)]:
                lid.write_text(value)
                self.assertEqual(g.lid_closed(lid), expected)
            lid.write_text('state: unknown\n')
            with self.assertRaises(ValueError):
                g.lid_closed(lid)
            lid.unlink()
            with self.assertRaises(FileNotFoundError):
                g.lid_closed(lid)

    def run_loop(self, states, child, fail=False):
        handlers = {}
        def sleep(_):
            if len(states) == 1:
                handlers[signal.SIGTERM](signal.SIGTERM, None)
            else:
                states.pop(0)
        with patch.object(g.signal, 'signal', side_effect=lambda sig, fn: handlers.update({sig: fn})), \
             patch.object(g, 'lid_closed', side_effect=lambda: states[0]), \
             patch.object(g.time, 'sleep', side_effect=sleep), \
             patch.object(g.subprocess, 'Popen', return_value=child) as spawn:
            if fail:
                with self.assertRaises(RuntimeError):
                    g.main()
            else:
                g.main()
            return spawn

    def test_open_close_open_releases_inhibitor(self):
        child = Mock()
        child.poll.return_value = None
        spawn = self.run_loop([False, True, True, False], child)
        spawn.assert_called_once_with(g.INHIBIT)
        child.terminate.assert_called_once()
        child.wait.assert_called_once_with(timeout=3)
        self.assertIn('--what=sleep:idle:handle-suspend-key:handle-hibernate-key', g.INHIBIT)

    def test_stop_while_closed_releases_inhibitor(self):
        child = Mock()
        child.poll.return_value = None
        self.run_loop([True], child)
        child.terminate.assert_called_once()

    def test_child_failure_exits_for_service_restart(self):
        child = Mock(returncode=1)
        child.poll.return_value = 1
        self.run_loop([True, True], child, fail=True)
        child.terminate.assert_not_called()

    def test_release_kills_unresponsive_child(self):
        child = Mock()
        child.poll.return_value = None
        child.wait.side_effect = [subprocess.TimeoutExpired('inhibitor', 3), None]
        g.release(child)
        child.kill.assert_called_once()
        self.assertEqual(child.wait.call_count, 2)


if __name__ == '__main__':
    unittest.main()
