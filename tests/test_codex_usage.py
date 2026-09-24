"""Quota mapping, stale display and alert deduplication regressions."""
import importlib.util
from datetime import datetime, timedelta
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

    def test_daily_usage_survives_refreshes_and_restart(self):
        now = datetime(2026, 9, 23, 12).timestamp()
        windows = {'10080': {'remaining': 80, 'reset': now + 3600}}
        daily = usage.daily_usage(windows, None, now)
        self.assertEqual(daily['used'], 0)
        windows['10080']['remaining'] = 65
        daily = usage.daily_usage(windows, daily, now + 60)
        self.assertEqual(daily['used'], 15)
        # A restarted widget reads the same persisted state and quota.
        self.assertEqual(usage.daily_usage(windows, daily, now + 120), daily)
        self.assertEqual(daily['started'], now)

    def test_daily_usage_starts_over_on_local_calendar_day(self):
        start = datetime(2026, 9, 23, 23, 55)
        now = start.timestamp()
        windows = {'10080': {'remaining': 80, 'reset': now + 86400}}
        daily = usage.daily_usage(windows, None, now)
        windows['10080']['remaining'] = 60
        later = (start + timedelta(minutes=10)).timestamp()
        daily = usage.daily_usage(windows, daily, later)
        self.assertEqual(daily['used'], 0)
        self.assertEqual(daily['date'], '2026-09-24')
        self.assertEqual(daily['started'], later)

    def test_daily_usage_preserves_observed_use_across_weekly_reset(self):
        now = datetime(2026, 9, 23, 12).timestamp()
        windows = {'10080': {'remaining': 30, 'reset': now + 120}}
        daily = usage.daily_usage(windows, None, now)
        windows['10080']['remaining'] = 20
        daily = usage.daily_usage(windows, daily, now + 60)
        windows['10080'] = {'remaining': 97, 'reset': now + 604800}
        daily = usage.daily_usage(windows, daily, now + 180)
        self.assertEqual(daily['used'], 13)

    def test_missing_or_expired_weekly_data_does_not_change_daily_usage(self):
        now = datetime(2026, 9, 23, 12).timestamp()
        windows = {'10080': {'remaining': 80, 'reset': now + 60}}
        daily = usage.daily_usage(windows, None, now)
        self.assertEqual(usage.daily_usage({}, daily, now + 30), daily)
        self.assertEqual(usage.daily_usage(windows, daily, now + 120), daily)
        self.assertIsNone(usage.daily_usage({}, None, now))

    def test_daily_tooltip_red_only_above_target(self):
        now = datetime(2026, 9, 23, 12).timestamp()
        windows = {'10080': {'remaining': 80, 'reset': now + 3600}}
        daily = usage.daily_usage(windows, None, now)
        state = {'windows': windows, 'daily': daily}
        for used in (0, 14, 15):
            daily['used'] = used
            result = usage.render(state, now)
            self.assertIn(f"Today's percent used: {used}% (target 14%)", result['tooltip'])
            self.assertEqual('foreground="#BF616A"' in result['tooltip'], used > 14)
            self.assertEqual(result['class'], 'normal')
        self.assertIn("Today's percent used: 15%", usage.render(state, now, 'Offline')['tooltip'])
        self.assertIn("Today's percent used: —", usage.render(state, now + 86400, 'Offline')['tooltip'])

    def test_daily_usage_handles_quota_correction_without_double_counting(self):
        now = datetime(2026, 9, 23, 12).timestamp()
        windows = {'10080': {'remaining': 80, 'reset': now + 3600}}
        daily = usage.daily_usage(windows, None, now)
        for remaining, expected in ((70, 10), (75, 5), (70, 10)):
            windows['10080']['remaining'] = remaining
            daily = usage.daily_usage(windows, daily, now + 60)
            self.assertEqual(daily['used'], expected)


if __name__ == '__main__':
    unittest.main()
