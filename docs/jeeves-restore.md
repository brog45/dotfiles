# Moving jeeves into a VM: backup and restore

Status: implemented (`backup-host`, `lib/backup` and the setup steps below)
and tested (`tests/backup-test`, `tests/syncthing-restore-test`); not yet
used for the move.

jeeves's hardware becomes a Proxmox host named moxie. jeeves itself becomes a
Debian trixie VM on moxie, rebuilt by this repo's `setup` and restored from
backups on the Seagate USB drive, so every other machine reconnects to it as
if it had only rebooted: same SSH host keys, same Tailscale nodes, same
Syncthing device, same mail.

## The move

1. On the old jeeves, install `age` and `zstd` (`sudo apt install age zstd`),
   and run `./backup-host` once ahead of time: the first run makes the key
   pair, asking for its passphrase.
2. Run the final backup (`./backup-host --final`), which checks every
   archive, and power off.
3. Install Proxmox on the hardware, named moxie, as `docs/moxie.md`
   describes. Installing it destroys the old jeeves.
4. On moxie, create the jeeves VM and install Debian trixie, with the first
   user `brogers`. That user gets UID 1000, as now; the archives keep numeric
   owners, so this matters. Pass the Seagate's USB device through to the VM.
   `docs/moxie.md` has the VM's settings.
5. Check that `jeeves.lan` reaches the VM. Its NIC has a new MAC address, so
   it likely gets a new LAN address, but nothing uses the address itself,
   only the name, and the router likely names DHCP clients by the hostname
   they send. If the name does not follow, either:
   - give the VM jeeves's old MAC address, and moxie's bridge another one
     (a `hwaddress` line in moxie's `/etc/network/interfaces`; unverified
     on Proxmox), so the router sees the old jeeves; or
   - move the router's reservation or name for jeeves to the VM's MAC.

   Until then little breaks: over the tailnet `jeeves` resolves anyway, and
   only dinky, which is not on Tailscale, uses `jeeves.lan`, and only in its
   `jeeves-ssh-key` setup step.
6. In the VM, clone this repo and run `./setup`. It mounts the drive at
   `/mnt/backups` (the `install-etc` step installs `mnt-backups.mount`, as
   now), asks once for the backup passphrase, and restores each item below
   as it gets to the step that sets that thing up.
7. Check from another machine that jeeves is back as itself:
   - `ssh jeeves` connects with no warning of a changed host key (the
     fingerprints are in `docs/moxie.md`).
   - `tailscale status` lists `jeeves` and `immich`, with no `jeeves-1`.
   - Syncthing on larry or felixblue shows jeeves connected, and jeeves's
     folders fill without anything being deleted elsewhere.
8. By hand, once Syncthing has fetched `~/Pictures`: `./setup immich`, which
   starts Immich, and then check `https://immich.<tailnet>.ts.net`.
9. By hand, as described below: set up ssh-fetch-mail for each remote host,
   reinstall job-boards-tracker's crontab lines, and set the Claude Code
   environments to start automatically (still on the to-do list).

## What is backed up

One archive per item, so each step restores only its own. The items are
listed in `hosts/jeeves/backup.txt` and defined in `lib/backup`.

| Item | Paths | Restored by | Restored when |
|---|---|---|---|
| `ssh-host-keys` | `/etc/ssh/ssh_host_*` | new `ssh-host-keys` step | the backup's keys differ from the installed ones (asks first) |
| `ssh` | `~/.ssh` (keys, `authorized_keys`, `config`, `known_hosts`) | `ssh-key` | there is no `~/.ssh/id_ed25519` |
| `tailscale` | `/var/lib/tailscale` (the jeeves node and its `tailscale serve` config) | `tailscale` | tailscaled is not logged in |
| `syncthing` | `cert.pem`, `key.pem`, `https-cert.pem`, `https-key.pem`, `config.xml` from `~/.local/state/syncthing` | `syncthing` | there is no Syncthing config yet |
| `immich` | `/srv/immich` (uploads, database, `.env`, the immich node's Tailscale login, `image-digests.txt`) | `immich` | `/srv/immich` has no database yet |
| `maildir` | `~/Maildir` | new `restore-home` step | `~/Maildir` is missing or empty |
| `src` | the whole of `~/src` | `restore-home` | `~/src` is missing or empty |
| `config` | `~/.config` (1.4 GB, nearly all of it VS Code's leftovers in `Code/`) | new `restore-config` | file by file: each one only if it does not exist yet |
| `claude` | `~/.claude`, `~/.claude.json` | `restore-home` | `~/.claude` has no `projects/` |
| `todo` | this repo's `todo.md`, which git ignores, so a clone lacks it | `restore-home` | the repo has no `todo.md` |

Not backed up, on purpose:

- **The Syncthing folders** (`~/Documents`, `~/Dropbox`, `~/Music`,
  `~/Pictures`). Each is complete on another machine, so jeeves pulls them
  back. Its index database is not restored either (see Safety).
- **What setup rebuilds anyway:** packages, flatpaks, dotfiles, Docker images
  other than Immich's.

`~/Maildir` is backed up because it costs nothing (42 MB): ssh-fetch-mail
deletes each message from the remote host once it is delivered, so jeeves
holds the only copy, though none of that mail matters now. Without the
archive, the restore starts it empty.

job-boards-tracker is restored with `~/src` and `~/.config` (its
`job-boards/config.toml`) and reinstalled by hand: its data is in
`~/Documents`, `install-watch.sh` installs its `watch.sh` crontab line, and
its README gives the line for `fx_rates.py`.

ssh-fetch-mail is also restored with `~/src` and set up by hand afterwards:
run its `setup-home-server` once per remote host (now the SSH aliases
`dinky-mail` and `thoughtsandprayers-mail`, whose keys and aliases come back
with `~/.ssh`). That sets up Postfix, Dovecot and the fetch timers. Until
then mail waits on the remote hosts; the `tailscale serve` ports come back
with the Tailscale state, but nothing answers behind them.

## Encryption

The archives hold secrets (host keys, Tailscale node keys, Syncthing's key,
Immich's database password, Claude Code's login), so all of them are
encrypted with `age`, to one key pair:

- The public key (the recipient) is on the drive, at
  `/mnt/backups/jeeves/recipient.txt`, so the backup script needs no
  passphrase and can run unattended. It is not secret, and can be
  recomputed from the private key (`age-keygen -y`). Someone able to write
  to the drive could swap in their own, so that later backups are readable
  by them and not by you, with no warning; for a drive kept at home, that
  is accepted.
- The private key (the identity) is on the drive, at
  `/mnt/backups/jeeves/identity.age`, itself encrypted with a passphrase
  (`age -p`). Keep the passphrase in KeePassXC. Without it the backups
  cannot be read.

During `setup`, the first step that restores something asks for the
passphrase and decrypts the identity to `$XDG_RUNTIME_DIR` (a tmpfs, readable
only by you). Later steps reuse it, and `setup` deletes it when it exits. A
step run on its own deletes it when that step exits.

`age` and `zstd` go in jeeves's package list. The restoring steps all run
after `install-packages-leaves`, so both are there in time.

## The backup script

`./backup-host [--final]`, at the repo root like the `update-*` scripts. The
items are defined once, in `lib/backup`, which both the script and the
restoring steps source, so the two cannot drift apart.

- Writes `/mnt/backups/<host>/<item>.tar.zst.age`. Each archive is written
  next to the old one and renamed over it only once it is complete; the
  previous one is kept as `<item>.prev.tar.zst.age`.
- Uses `sudo` for the root-owned items, and `tar --numeric-owner`, so the
  container users in `/srv/immich` keep their IDs.
- Stops the Immich stack while it archives `/srv/immich`, and starts it
  again unless `--final`. Just before archiving, it writes the digests of
  the running images to `/srv/immich/image-digests.txt`, so they are in the
  archive, always matching its data, and are restored to where the
  `immich` step looks for them.
- Checks each new archive by decrypting and listing it, which asks for the
  passphrase once (`--no-verify` skips that).
- `--final` also stops the ssh-fetch-mail timers before archiving
  `~/Maildir`, so that no mail is delivered to the old jeeves after it is
  archived. Undelivered mail waits on the remote hosts. It leaves Immich and
  the timers stopped, and says to power off.

The archives come to about 57 GB before compression (`~/src` 25 GB,
`/srv/immich` 29 GB, `~/.config` 1.4 GB); the
drive has 615 GB free.

## Restoring in setup

The rule: a step restores only when the thing it sets up is not set up yet,
and never overwrites live state. Each item is restored at most once on a
machine: `~/.local/state/dotfiles/restored/<item>` records it, and
`backup-host` writes the same record on the machine it backs up, which has
nothing to restore. So rerunning `setup` on the new jeeves brings back
nothing deleted since, and running it on the old jeeves or any other machine
restores nothing. `DOTFILES_NO_RESTORE=1` turns restoring off.

If an archive is missing because the drive is not mounted, the steps whose
item gives the machine its identity (`ssh`, `tailscale`, `syncthing`,
`immich`) stop and say to mount it, rather than make a new SSH key, Tailscale
node, Syncthing device or empty Immich. The others (`ssh-host-keys`,
`config`, `maildir`, `src`, `claude`) warn and go on, and a later run with the
drive restores them.

Changes, in setup order:

- **New `restore-config`,** right after `install-packages-leaves` (which
  installs `age`), so the later steps see the restored config: restores
  `~/.config` with `tar --skip-old-files`, so the links `install-stow` made
  and anything else already there are kept.
- **`immich`:** restores `/srv/immich` before `docker compose up`, then pulls
  the recorded image digests and tags them as the compose file's tags
  (`immich-server:v3` and so on), so compose starts the versions the
  database was last used with instead of pulling newer ones.
- **`ssh-key`:** restores `~/.ssh` before deciding whether to create a key.
- **New `ssh-host-keys`,** next to `ssh-key`: restores the host keys and
  restarts sshd.
- **`syncthing`:** restores the identity and config before starting the
  service.
- **`tailscale`:** with tailscaled stopped, restores its state directory,
  then starts it, before checking whether it is logged in.
- **New `restore-home`,** after `tailscale` and before `install-claude-cli`:
  restores `~/Maildir`, `~/src`, `~/.claude` with `~/.claude.json`, and the
  repo's `todo.md`, keeping files already there.

## Safety

- **Syncthing:** restoring its index database with the folders still empty
  makes Syncthing take every file as deleted and send those deletions to
  the other machines. Tried with Syncthing 1.27: the other machine deleted
  every file. Only the identity and config are restored: the same device
  ID, folder IDs and devices, with no record of having had any files. When
  it connects, the other machines see a fresh index from it and send their
  full ones, and it downloads everything, having nothing of its own to
  delete. The step makes each missing or empty folder with the `.stfolder`
  marker Syncthing wants before it uses a folder (`st_make_folders` in
  `lib/syncthing`). `tests/syncthing-restore-test` checks this with two
  real Syncthing instances: the folder fills again and nothing is deleted.
- **Immich and `~/Pictures`:** Immich reads `~/Pictures` as an external
  library. If it scans that library before Syncthing has pulled it back,
  it may mark every photo there as offline. Whether that leads to them
  being trashed is unverified. So on a restore, the `immich` step leaves
  Immich stopped until Syncthing reports `~/Pictures` up to date, and says
  to rerun `./setup immich` then.
- **One jeeves at a time:** after the final backup the old jeeves must not
  start again with its Tailscale state or host keys. Proxmox's install
  wipes it anyway.

## Testing

- `tests/backup-test` backs up and restores each item in throwaway
  directories, behind a fake `sudo`, `docker`, `systemctl` and `tailscale`,
  with a test age key. It checks that every item comes back, that a restore
  keeps what is there already and never happens twice, that the machine
  backed up restores nothing, and what happens with no drive.
- `tests/syncthing-restore-test`, as above.
- The final backup's own check, decrypting and listing every archive,
  before jeeves is powered off.
