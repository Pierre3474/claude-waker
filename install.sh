#!/usr/bin/env bash
# claude-waker installer — run as root on any Debian/Ubuntu host (LXC / VM / VPS).
# Installs Node + Claude Code CLI, a dedicated user, and one systemd timer per
# account so a fresh 5h usage window is always open, staggered by OFFSET_MINUTES.
set -euo pipefail

cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }

# --- config ----------------------------------------------------------------
CONF="${1:-config.env}"
[[ -f "$CONF" ]] || { echo "missing $CONF (copy config.env.example)"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"
ACCOUNTS="${ACCOUNTS:-a}"
OFFSET_MINUTES="${OFFSET_MINUTES:-150}"
PERIOD_MINUTES="${PERIOD_MINUTES:-300}"
TIMEZONE="${TIMEZONE:-Europe/Paris}"

# --- deps ------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates

if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
npm install -g @anthropic-ai/claude-code

timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true

# --- user + dirs -----------------------------------------------------------
id claude >/dev/null 2>&1 || useradd -r -m -d /home/claude -s /usr/sbin/nologin claude
install -d -m 700 /etc/claude-waker
touch /var/log/claude-waker.log && chown claude:claude /var/log/claude-waker.log

install -m 755 claude-waker.sh /usr/local/sbin/claude-waker.sh
install -m 644 'claude-waker@.service' /etc/systemd/system/claude-waker@.service

# --- per-account env + timer ----------------------------------------------
# OnCalendar lines: account index i fires at i*OFFSET, then +PERIOD, < 24h.
i=0
for acct in $ACCOUNTS; do
  cfgdir="/home/claude/.claude-${acct}"
  install -d -o claude -g claude -m 700 "$cfgdir"

  env_file="/etc/claude-waker/env.${acct}"
  if [[ ! -f "$env_file" ]]; then
    cat > "$env_file" <<EOF
# Account ${acct}. Auth EITHER via 'claude login' into ${cfgdir},
# OR paste a token from 'claude setup-token' below (replace PASTE_ME).
CLAUDE_CONFIG_DIR=${cfgdir}
CLAUDE_CODE_OAUTH_TOKEN=PASTE_ME
EOF
    chmod 600 "$env_file"
    chown claude:claude "$env_file"
  fi

  timer="/etc/systemd/system/claude-waker-${acct}.timer"
  {
    echo "[Unit]"
    echo "Description=Claude waker account ${acct} (offset $((i*OFFSET_MINUTES))min)"
    echo
    echo "[Timer]"
    echo "Unit=claude-waker@${acct}.service"
    t=$(( i * OFFSET_MINUTES ))
    while [[ $t -lt 1440 ]]; do
      printf 'OnCalendar=*-*-* %02d:%02d:00\n' $(( t / 60 )) $(( t % 60 ))
      t=$(( t + PERIOD_MINUTES ))
    done
    echo "Persistent=true"
    echo "AccuracySec=1s"
    echo
    echo "[Install]"
    echo "WantedBy=timers.target"
  } > "$timer"

  i=$(( i + 1 ))
done

systemctl daemon-reload
for acct in $ACCOUNTS; do
  systemctl enable --now "claude-waker-${acct}.timer"
done

echo
echo "DONE. Per account, authenticate ONE of these ways:"
for acct in $ACCOUNTS; do
  echo "  [$acct] token:  claude setup-token  (on a logged-in machine) ->"
  echo "        sed -i 's|PASTE_ME|<TOKEN>|' /etc/claude-waker/env.${acct}"
  echo "        test:  sudo -u claude /usr/local/sbin/claude-waker.sh ${acct}"
done
echo
echo "Schedule:  systemctl list-timers 'claude-waker-*'"
echo "Logs:      tail -f /var/log/claude-waker.log"
