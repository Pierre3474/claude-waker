#!/usr/bin/env bash
# Fire one minimal Claude message to open the 5h usage window for ONE account.
# Usage: claude-waker.sh <acct>   where <acct> matches /etc/claude-waker/env.<acct>
set -euo pipefail

ACCT="${1:?usage: claude-waker.sh <acct>}"
LOG=/var/log/claude-waker.log
ENV_FILE="/etc/claude-waker/env.${ACCT}"

ts() { date -Is; }

# Per-account env: may set CLAUDE_CONFIG_DIR (creds isolation) and/or
# CLAUDE_CODE_OAUTH_TOKEN. With no real token it falls back to whatever
# `claude login` stored in that account's config dir.
if [[ -r "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
  export CLAUDE_CONFIG_DIR
fi

if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" && "$CLAUDE_CODE_OAUTH_TOKEN" != "PASTE_ME" ]]; then
  export CLAUDE_CODE_OAUTH_TOKEN
else
  unset CLAUDE_CODE_OAUTH_TOKEN
fi

# Cheapest model, single turn, hard timeout. The window opens regardless of model.
if out=$(timeout 120 claude -p "Reply with exactly: ok" \
          --model claude-haiku-4-5-20251001 \
          --output-format text 2>&1); then
  rc=0
else
  rc=$?
fi

echo "$(ts) acct=${ACCT} rc=$rc out=${out:0:300}" >> "$LOG"
exit "$rc"
