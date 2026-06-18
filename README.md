# claude-waker

Keep a **fresh Claude 5-hour usage window always open** so you never sit down to a
mid-window reset. A tiny systemd timer fires one cheap headless prompt
(`claude -p`, Haiku) at each window boundary. Supports **multiple accounts**,
each staggered by a configurable offset — e.g. 2 accounts at +2h30 = a fresh
window every 2h30, alternating.

> Claude subscription usage runs in **5h rolling windows** that start on your
> first message. This just guarantees a window is open by each boundary. It can't
> reset a window early — only useful if you haven't already used Claude in the
> current window.

## Requirements

A small always-on Debian/Ubuntu box: an LXC, a VM, or a cheap VPS. ~512MB RAM.
That's it. (Proxmox users: optional `proxmox/create-lxc.sh` spins up the LXC.)

## Install

```bash
git clone <this-repo> claude-waker && cd claude-waker
cp config.env.example config.env
nano config.env                 # set ACCOUNTS + OFFSET_MINUTES
sudo ./install.sh               # installs node + claude CLI + timers
```

Then authenticate **each** account (one of):

```bash
# token (works headless) — run on a machine logged into that account:
claude setup-token
sudo sed -i 's|PASTE_ME|<TOKEN>|' /etc/claude-waker/env.a   # repeat per account

# test it:
sudo -u claude /usr/local/sbin/claude-waker.sh a
```

## Config

| Key | Meaning |
|-----|---------|
| `ACCOUNTS` | space-separated labels, one timer each (`"a b"`) |
| `OFFSET_MINUTES` | stagger between accounts (`150` = 2h30). Even spread: `300 / N` |
| `PERIOD_MINUTES` | window length, leave `300` |
| `TIMEZONE` | `Europe/Paris` etc. |

Each account is isolated in its own Claude config dir (`/home/claude/.claude-<acct>`)
so credentials never collide.

## Verify

```bash
systemctl list-timers 'claude-waker-*'      # next fire times
tail -f /var/log/claude-waker.log           # acct=a rc=0 out=ok
```

## How offsets map to timers

`install.sh` generates one `OnCalendar` line per fire. Account index `i` starts at
`i * OFFSET_MINUTES` then repeats every `PERIOD_MINUTES`. With `ACCOUNTS="a b"` and
`OFFSET_MINUTES=150`:

```
a -> 00:00 05:00 10:00 15:00 20:00
b -> 02:30 07:30 12:30 17:30 22:30
```

## Files

| File | Role |
|------|------|
| `install.sh` | run as root on the target host; installs everything |
| `config.env.example` | copy to `config.env`, edit |
| `claude-waker.sh` | the trigger (`/usr/local/sbin/`) |
| `claude-waker@.service` | templated oneshot unit (`%i` = account) |
| `proxmox/create-lxc.sh` | optional PVE helper to create the LXC |

## License

MIT
