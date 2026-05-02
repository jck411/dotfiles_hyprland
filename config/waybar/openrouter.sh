#!/bin/bash
# OpenRouter waybar module — shows balance, delta since last check, and activity breakdown in tooltip
# No polling — triggered by signal only (pkill -RTMIN+9 waybar)

ENV_FILE="$HOME/REPOS/machine-thinkpad-p16s/secrets/.env"
STATE_FILE="$HOME/REPOS/machine-thinkpad-p16s/state/openrouter-usage"

if [[ ! -f "$ENV_FILE" ]]; then
    echo '{"text": "??", "tooltip": "Missing .env", "class": "error"}'
    exit 0
fi

OPENROUTER_MGMT_KEY=$(grep '^OPENROUTER_MGMT_KEY=' "$ENV_FILE" | cut -d'=' -f2-)

if [[ -z "$OPENROUTER_MGMT_KEY" ]]; then
    echo '{"text": "??", "tooltip": "Missing OPENROUTER_MGMT_KEY", "class": "error"}'
    exit 0
fi

AUTH_HEADER="Authorization: Bearer $OPENROUTER_MGMT_KEY"

# Fetch credits
credits_json=$(curl -sf --connect-timeout 3 --max-time 8 \
    -H "$AUTH_HEADER" \
    "https://openrouter.ai/api/v1/credits" 2>/dev/null)

if [[ -z "$credits_json" ]]; then
    echo '{"text": "??", "tooltip": "API error", "class": "error"}'
    exit 0
fi

read -r total_credits total_usage < <(echo "$credits_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']
print(d['total_credits'], d['total_usage'])
" 2>/dev/null)

if [[ -z "$total_credits" || -z "$total_usage" ]]; then
    echo '{"text": "??", "tooltip": "Parse error", "class": "error"}'
    exit 0
fi

remaining=$(python3 -c "print(round($total_credits - $total_usage, 2))")

# Delta tracking
delta_text=""
if [[ -f "$STATE_FILE" ]]; then
    prev_usage=$(cat "$STATE_FILE")
    delta=$(python3 -c "d = round($total_usage - $prev_usage, 4); print(d if d > 0 else 0)")
    if [[ "$delta" != "0" ]]; then
        delta_text=" (-\$$delta)"
    fi
fi
echo "$total_usage" > "$STATE_FILE"

# Determine class based on remaining balance
class="normal"
if python3 -c "exit(0 if $remaining < 1 else 1)"; then
    class="critical"
elif python3 -c "exit(0 if $remaining < 5 else 1)"; then
    class="warning"
fi

# Fetch today's activity for tooltip breakdown
activity_json=$(curl -sf --connect-timeout 3 --max-time 10 \
    -H "$AUTH_HEADER" \
    "https://openrouter.ai/api/v1/activity" 2>/dev/null)

tooltip="Balance: \$${remaining}${delta_text}\nCredits: \$${total_credits} | Used: \$${total_usage}"

if [[ -n "$activity_json" ]]; then
    breakdown=$(echo "$activity_json" | python3 -c "
import sys, json
from datetime import datetime, timezone
data = json.load(sys.stdin).get('data', [])
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
entries = [e for e in data if e['date'].startswith(today)]
if not entries:
    print('No activity today')
else:
    entries.sort(key=lambda x: x['usage'], reverse=True)
    lines = []
    total = 0
    for e in entries:
        model = e['model'].split('/')[-1]
        cost = e['usage']
        reqs = e['requests']
        total += cost
        lines.append(f'  {model}: \${cost:.4f} ({reqs}req)')
    print(f'\nToday: \${total:.4f}')
    print('\n'.join(lines))
" 2>/dev/null)
    if [[ -n "$breakdown" ]]; then
        tooltip="${tooltip}\n${breakdown}"
    fi
fi

echo "{\"text\": \"\$${remaining}${delta_text}\", \"tooltip\": \"${tooltip}\", \"class\": \"${class}\"}"
