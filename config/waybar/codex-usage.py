#!/usr/bin/env -S uv run --offline --no-project --script
"""Waybar allowance meter using Codex's authenticated app-server protocol."""
import fcntl
import json
import math
import os
from pathlib import Path
import queue
import shutil
import subprocess
import threading
import time
from datetime import datetime

STATE_DIR = Path.home() / 'REPOS/machine-thinkpad-p16s/state'
STATE_FILE = STATE_DIR / 'codex-usage.json'
DAILY_TARGET = 14


def codex_binary():
    binary = shutil.which('codex')
    if binary:
        return binary
    # The IDE extension bundles Codex but does not add it to Waybar's PATH.
    candidates = [p for root in ('.vscode-insiders', '.vscode')
                  for p in (Path.home() / root / 'extensions').glob(
                      'openai.chatgpt-*/bin/linux-*/codex') if os.access(p, os.X_OK)]
    if not candidates:
        raise RuntimeError('Codex CLI missing; install/sign in to the Codex IDE extension')
    return str(max(candidates, key=lambda p: p.stat().st_mtime))


def fetch_limits():
    process = subprocess.Popen([codex_binary(), 'app-server'], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    messages = queue.Queue()

    def reader():
        try:
            for line in process.stdout:
                messages.put(json.loads(line))
        finally:
            messages.put(None)

    threading.Thread(target=reader, daemon=True).start()
    deadline = time.monotonic() + 20

    def send(message):
        process.stdin.write(json.dumps(message) + '\n')
        process.stdin.flush()

    def receive(request_id):
        while True:
            try:
                message = messages.get(timeout=max(0, deadline - time.monotonic()))
            except queue.Empty:
                raise RuntimeError('Codex usage request timed out') from None
            if message is None:
                raise RuntimeError('Codex app server closed unexpectedly')
            if message.get('id') == request_id:
                if 'error' in message:
                    # Do not expose raw server errors or authentication data.
                    raise RuntimeError('Codex usage unavailable; check Codex sign-in')
                return message['result']

    try:
        send({'id': 1, 'method': 'initialize', 'params': {
            'clientInfo': {'name': 'waybar_codex_usage', 'version': '1.0'}}})
        receive(1)
        send({'method': 'initialized'})
        send({'id': 2, 'method': 'account/rateLimits/read'})
        result = receive(2)
        bucket = (result.get('rateLimitsByLimitId') or {}).get('codex') or result.get('rateLimits')
        if not bucket:
            raise RuntimeError('Codex allowance was not returned')
        windows = {}
        for key in ('primary', 'secondary'):
            window = bucket.get(key)
            if not window:
                continue
            duration = int(window['windowDurationMins'])
            used = float(window['usedPercent'])
            reset = int(window['resetsAt'])
            if not math.isfinite(used) or not 0 <= used <= 100 or reset <= 0:
                raise ValueError('Invalid quota data')
            windows[str(duration)] = {'remaining': 100 - used, 'reset': reset}
        if not windows:
            raise RuntimeError('Codex returned no allowance windows')
        return windows
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdin.close()
        process.stdout.close()


def level(remaining):
    return 2 if remaining < 10 else 1 if remaining < 25 else 0


def alerts(windows, previous, now):
    """Remember each threshold per reset window, including across bar restarts."""
    notified = {}
    pending = []
    for duration, window in windows.items():
        old = previous.get(duration, {})
        before = old.get('level', 0) if old.get('reset') == window['reset'] else 0
        current = level(window['remaining']) if window['reset'] > now else 0
        notified[duration] = {'reset': window['reset'], 'level': max(before, current)}
        if current > before:
            label = {'300': '5-hour', '10080': 'Weekly'}.get(duration, f'{duration}-minute')
            pending.append((current, f"{label} allowance: {window['remaining']:g}% remaining"))
    return notified, pending


def daily_usage(windows, previous, now):
    """Measure weekly allowance consumed since today's first successful refresh."""
    weekly = windows.get('10080')
    if not weekly or weekly['reset'] <= now:
        return previous
    today = datetime.fromtimestamp(now).astimezone().date().isoformat()
    previous = previous or {}
    used = 0
    started = now
    if previous.get('date') == today:
        started = previous['started']
        used = previous['used']
        if previous['reset'] == weekly['reset']:
            used = max(0, used + previous['remaining'] - weekly['remaining'])
        elif previous['reset'] <= now:
            # Keep today's observed usage before the weekly reset, then add
            # the new window's usage. Unobserved use before reset is unknown.
            used += 100 - weekly['remaining']
    return {'date': today, 'started': started, 'used': used,
            'remaining': weekly['remaining'], 'reset': weekly['reset']}


def render(state, now, error=None):
    windows = state.get('windows', {})
    expired = any(w['reset'] <= now for w in windows.values())
    stale = bool(error) or expired
    pieces = []
    lines = []
    for duration in sorted(windows, key=int):
        label = {'300': '5h', '10080': 'W'}.get(duration, f'{duration}m')
        prefix = f'{label}: ' if len(windows) > 1 else ''
        pieces.append(f"{prefix}{windows[duration]['remaining']:g}%")
    if not pieces:
        pieces.append('—')
    for duration, window in windows.items():
        label = {'300': '5-hour', '10080': 'Weekly'}.get(duration, f'{duration}-minute')
        minutes = max(0, math.ceil((window['reset'] - now) / 60))
        days, minutes = divmod(minutes, 1440)
        hours, minutes = divmod(minutes, 60)
        countdown = f'{days}d {hours}h {minutes}m' if days else f'{hours}h {minutes}m'
        reset = datetime.fromtimestamp(window['reset']).astimezone().strftime('%a %b %d %H:%M')
        lines.append(f"{label}: {window['remaining']:g}% remaining\nResets: {countdown} ({reset})")
    daily = state.get('daily') or {}
    today = datetime.fromtimestamp(now).astimezone().date().isoformat()
    if daily.get('date') == today:
        line = f"Today's percent used: {daily['used']:g}% (target {DAILY_TARGET}%)"
        if daily['used'] > DAILY_TARGET:
            line = f'<span foreground="#BF616A">{line}</span>'
        lines.append(line)
        started = datetime.fromtimestamp(daily['started']).astimezone().strftime('%H:%M')
        lines.append(f'Estimated from refreshes since {started}')
    else:
        lines.append(f"Today's percent used: — (target {DAILY_TARGET}%)")
    if state.get('updated'):
        lines.append('Updated: ' + datetime.fromtimestamp(
            state['updated']).astimezone().strftime('%a %H:%M'))
    if stale:
        lines.append('STALE — ' + (error or 'reset time passed; awaiting updated allowance'))
    severity = max((level(w['remaining']) for w in windows.values()), default=0)
    return {'text': ' · '.join(pieces) + (' ⟳' if stale else ''),
            'tooltip': '\n'.join(lines),
            'class': 'error' if stale else ['normal', 'warning', 'critical'][severity]}


def main():
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE_DIR / 'codex-usage.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            state = json.loads(STATE_FILE.read_text())
        except (OSError, ValueError):
            state = {}
        error = None
        now = time.time()
        try:
            windows = fetch_limits()
            now = time.time()
            notified, pending = alerts(windows, state.get('notified', {}), now)
            daily = daily_usage(windows, state.get('daily'), now)
            state = {'windows': windows, 'updated': now, 'notified': notified,
                     'daily': daily}
            temporary = STATE_FILE.with_suffix('.tmp')
            temporary.write_text(json.dumps(state))
            temporary.chmod(0o600)
            temporary.replace(STATE_FILE)
            for severity, message in pending:
                try:
                    subprocess.run(['notify-send', '-a', 'Codex usage', '-u',
                                    'critical' if severity == 2 else 'normal',
                                    'Codex allowance running low', message],
                                   timeout=5, check=False, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL)
                except (OSError, subprocess.TimeoutExpired):
                    pass
        except RuntimeError as exc:
            error = str(exc)
        except (OSError, ValueError, KeyError, TypeError):
            error = 'Unable to read Codex usage; check Codex sign-in and local state'
        print(json.dumps(render(state, now, error)))


if __name__ == '__main__':
    main()
