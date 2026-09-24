"""Quota mapping, stale display and alert deduplication regressions."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('usage', Path(__file__).resolve().parents[1] /
                                             'config/waybar/codex-usage.py')
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)


class UsageTests(unittest.TestCase):
    def test_weekly_only_omits_missing_five_hour_allowance(self):
        state = {'windows': {'10080': {'remaining': 95, 'reset': 1000}}, 'updated': 100}
        result = usage.render(state, 200)
        self.assertEqual(result['text'], '95%')
        self.assertNotIn('5-hour', result['tooltip'])
        self.assertEqual(result['class'], 'normal')

    def test_both_windows_and_severity(self):
        state = {'windows': {'10080': {'remaining': 80, 'reset': 2000},
                             '300': {'remaining': 9, 'reset': 1000}}}
        result = usage.render(state, 200)
        self.assertEqual(result['text'], '5h: 9% · W: 80%')
        self.assertEqual(result['class'], 'critical')

    def test_failure_keeps_last_value_visibly_stale(self):
        state = {'windows': {'10080': {'remaining': 20, 'reset': 1000}}, 'updated': 100}
        result = usage.render(state, 200, 'Offline')
        self.assertIn('20%', result['text'])
        self.assertIn('STALE — Offline', result['tooltip'])
        self.assertEqual(result['class'], 'error')
        self.assertTrue(usage.render({}, 200, 'Offline')['text'].endswith('⟳'))

    def test_expired_window_never_assumes_reset_to_full(self):
        state = {'windows': {'300': {'remaining': 0, 'reset': 100}}}
        result = usage.render(state, 200)
        self.assertEqual(result['class'], 'error')
        self.assertIn('0%', result['text'])
        self.assertEqual(usage.alerts(state['windows'], {}, 200)[1], [])

    def test_alert_once_per_threshold_and_reset(self):
        windows = {'300': {'remaining': 24, 'reset': 1000}}
        recorded, pending = usage.alerts(windows, {}, 200)
        self.assertEqual(len(pending), 1)
        self.assertEqual(usage.alerts(windows, recorded, 210)[1], [])
        windows['300']['remaining'] = 9
        recorded, pending = usage.alerts(windows, recorded, 220)
        self.assertEqual(pending[0][0], 2)
        windows['300']['remaining'] = 20
        recorded, pending = usage.alerts(windows, recorded, 230)
        self.assertEqual(pending, [])
        windows['300']['remaining'] = 9
        self.assertEqual(usage.alerts(windows, recorded, 240)[1], [])
        windows['300']['reset'] = 2000
        self.assertEqual(len(usage.alerts(windows, recorded, 250)[1]), 1)

    def test_threshold_boundaries(self):
        self.assertEqual([usage.level(n) for n in (25, 24, 10, 9)], [0, 1, 1, 2])


if __name__ == '__main__':
    unittest.main()
