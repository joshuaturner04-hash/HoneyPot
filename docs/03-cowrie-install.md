# 3. Cowrie install

## Dependencies

```bash
apt update && apt install -y git python3-venv python3-pip libssl-dev libffi-dev build-essential authbind
```

## Dedicated low-privilege user

Never run Cowrie as root:

```bash
useradd -m -d /home/cowrie -s /bin/bash cowrie
su - cowrie
```

## Clone and install

```bash
git clone https://github.com/cowrie/cowrie.git
cd cowrie
python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install -e .
```

> **Version note:** in current Cowrie releases (tested on 3.0.13), the project installs as a pip package with a `cowrie` console-script entry point — there's no `bin/cowrie` shell wrapper anymore. `pip install -e .` is what creates the `cowrie` command inside the venv.

## Config

The config template moved to `src/cowrie/data/etc/` in current releases (the root-level `etc/` is just where your live copy goes, and is `.gitignore`'d upstream):

```bash
cp src/cowrie/data/etc/cowrie.cfg.dist etc/cowrie.cfg
cp src/cowrie/data/etc/userdb.example etc/userdb.txt
```

Edit `etc/cowrie.cfg`:
- `[honeypot] hostname` — set something believable, not "honeypot"
- `[ssh] listen_endpoints` — confirm `tcp:2222:interface=0.0.0.0`
- `[output_jsonlog] enabled` — confirm `true`

`etc/userdb.txt` ships with sensible defaults (accepts most username/password combos except a few trivially-bot-only cases) — fine to leave as-is for a general SSH honeypot.

## Run it manually first

```bash
cowrie start
cowrie status
ss -tlnp | grep 2222
```

Test it:

```bash
ssh -p 2222 root@localhost
# any password works
```

Check the log:

```bash
tail -f var/log/cowrie/cowrie.json
```

## Systemd service

See [`configs/systemd/cowrie.service`](../configs/systemd/cowrie.service) — copy it to `/etc/systemd/system/cowrie.service`, adjusting paths if your username/install location differs.

```bash
systemctl daemon-reload
systemctl enable --now cowrie
systemctl status cowrie
```

> **Gotcha:** if you get a `FileNotFoundError` for `twistd` when starting via systemd, it's a `PATH` issue — the unit file needs `Environment="PATH=.../cowrie-env/bin:/usr/bin:/bin"` so it can find `twistd` outside of an activated shell. See the provided service file for the fix already applied.

Next: [4. Port redirect →](04-port-redirect.md)
