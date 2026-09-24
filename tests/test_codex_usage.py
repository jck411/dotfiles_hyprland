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

    def test_per_day_allowance_uses_fractional_days(self):
        for remaining, seconds_left, expected in ((70, 5 * 86400, '14.0'),
                                                   (35, 2.5 * 86400, '14.0'),
                                                   (10, 0.5 * 86400, '20.0')):
            with self.subTest(remaining=remaining, seconds_left=seconds_left):
                state = {'windows': {'10080': {'remaining': remaining,
                                               'reset': 200 + seconds_left}}}
                result = usage.render(state, 200)
                self.assertIn(f'Available: {expected}%/day', result['tooltip'])
                self.assertEqual(result['text'], f'{remaining}%')

    def test_per_day_line_red_only_below_fourteen(self):
        for remaining, red in ((0, True), (65, True), (70, False), (75, False)):
            with self.subTest(remaining=remaining):
                state = {'windows': {'10080': {'remaining': remaining,
                                               'reset': 200 + 5 * 86400}}}
                result = usage.render(state, 200)
                self.assertEqual('foreground="#BF616A"' in result['tooltip'], red)

    def test_per_day_line_omitted_without_valid_weekly_allowance(self):
        for windows, error in (({}, None),
                               ({'300': {'remaining': 50, 'reset': 1000}}, None),
                               ({'10080': {'remaining': 50, 'reset': 200}}, None),
                               ({'10080': {'remaining': 50, 'reset': 100}}, None),
                               ({'10080': {'remaining': 50, 'reset': 1000}}, 'Offline')):
            with self.subTest(windows=windows, error=error):
                result = usage.render({'windows': windows}, 200, error)
                self.assertNotIn('%/day', result['tooltip'])


if __name__ == '__main__':
    unittest.main()
