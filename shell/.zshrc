
. "$HOME/.local/bin/env"
if [ -f "$HOME/REPOS/symlinked-env/.env" ]; then
  set -a
  . "$HOME/REPOS/symlinked-env/.env"
  set +a
fi
export PATH="/opt/Antigravity:$PATH"
