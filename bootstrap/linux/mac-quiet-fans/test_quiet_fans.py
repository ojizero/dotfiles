import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('quiet', Path(__file__).with_name('mac-quiet-fans.py'))
quiet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quiet)


class QuietTests(unittest.TestCase):
    limits = [(1836,5616),(1700,5200)]

    def test_curve_boundaries_and_combination(self):
        self.assertEqual(quiet.targets(70,80,self.limits),[1836,1700])
        self.assertEqual(quiet.targets(92,40,self.limits),[5616,5200])
        self.assertEqual(quiet.targets(40,96,self.limits),[5616,5200])
        self.assertEqual(quiet.targets(81,88,self.limits),[2308,2137])
        self.assertEqual(quiet.targets(90,90,self.limits),quiet.targets(90,0,self.limits))
        for gpu in range(30,110):
            last=[0,0]
            for cpu in range(30,110):
                rpm=quiet.targets(cpu,gpu,self.limits)
                self.assertTrue(all(lo<=r<=hi for r,(lo,hi) in zip(rpm,self.limits)))
                self.assertTrue(all(a<=b for a,b in zip(last,rpm)))
                last=rpm

    def test_upstream_immediate_rise_and_trailing_integer_mean(self):
        response=quiet.Response()
        for _ in range(20): self.assertEqual(response.effective([50.9,45.1]),[50,45])
        self.assertEqual(response.effective([90.9,89.1]),[90,89])
        self.assertEqual(response.effective([50,45]),[52,47])
        for _ in range(19): end=response.effective([50,45])
        self.assertEqual(end,[50,45])

    def test_real_loop_in_fake_sysfs_restores_after_exit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);hw=root/'hw';hw.mkdir();runtime=root/'run';param=root/'fan_control';param.write_text('N')
            definitions={'hwmon0':{'name':'macsmc_hwmon','fan1_min':'1836','fan1_max':'5616','fan2_min':'1700','fan2_max':'5200','fan1_target':'1836','fan2_target':'1700','fan1_input':'1836','fan2_input':'1700'},
                         'hwmon1':{'name':'coretemp','temp1_label':'Package id 0','temp1_input':'81000'},
                         'hwmon2':{'name':'amdgpu','temp2_label':'junction','temp2_input':'88000'}}
            for name,files in definitions.items():
                d=hw/name;d.mkdir()
                for key,value in files.items(): (d/key).write_text(value)
            with patch.object(quiet,'ROOT',hw),patch.object(quiet,'PARAM',param),patch.object(quiet,'RUNTIME',runtime),patch.object(quiet,'notify'),patch.object(quiet.signal,'signal'),patch.object(quiet.time,'sleep',side_effect=SystemExit):
                with self.assertRaises(SystemExit): quiet.run()
                self.assertEqual(param.read_text().strip(),'N')
                self.assertEqual((hw/'hwmon0/fan1_target').read_text().strip(),'0')
                self.assertEqual((hw/'hwmon0/fan2_target').read_text().strip(),'0')
                self.assertFalse((runtime/'owned').exists())

    def test_restore_failure_keeps_owned_marker_and_uses_full_cooling(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);hw=root/'hwmon0';hw.mkdir();runtime=root/'run';runtime.mkdir()
            (runtime/'owned').touch();(hw/'name').write_text('macsmc_hwmon')
            for i in (1,2): (hw/f'fan{i}_max').write_text('5200')
            writes=[]
            def writer(path,value):
                writes.append((path.name,value))
                if path.name=='fan1_target' and value==0: raise OSError('release failed')
            with patch.object(quiet,'ROOT',root),patch.object(quiet,'RUNTIME',runtime),patch.object(quiet,'write',side_effect=writer):
                with self.assertRaises(RuntimeError): quiet.restore()
            self.assertTrue((runtime/'owned').exists())
            self.assertIn(('fan1_target',5200),writes)
            self.assertIn(('fan2_target',0),writes)
            self.assertNotIn(('fan_control','N'),writes)


if __name__=='__main__': unittest.main()
