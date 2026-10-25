# My dotfiles

This directory contains the dotfiles for my system

## Requirements

A Debian-based system, and `git` to check out the repo. On a fresh install your
user may not be in the `sudo` group yet, so install `git` as root:

```
su -c 'apt install -y git'
```

## Installation

Check out the `dotfiles` repo in your `$HOME` directory and run `setup`.

```
git clone https://github.com/brog45/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup
```

`setup` first makes sure you are in the `sudo` group. If you are not, it asks
for the root password to add you, then for your own password to continue with
the new group. It then runs the scripts in `setup.d/` in the order
`setup.d/_order.txt` lists them.

`setup` first names the host and the profiles it is using. The terminal then
shows one line per step and whether it succeeded; the steps' own output goes
to `~/dotfiles-setup.log`, after that of earlier runs. When a step fails,
`setup` stops and points to the log. Steps still ask on the terminal
when they need you: a GitHub or Tailscale login, a password for jeeves,
whether to merge a folder that has files into Syncthing.
Packages are installed without asking; to review the list first, run
`setup.d/install-packages-leaves -i`. Before the first `sudo` that needs your password, `setup`
says which step wants it, and then keeps sudo from asking again for the rest
of the run.

To run only some steps, name them, and they run in the order given:

```
./setup ssh-key github-ssh-key
```

Each script can also be run on its own, and is meant to be safe to rerun.
Log out and back in afterwards to pick up the `docker` group.

To add a step, drop an executable script into `setup.d/` and add its name to
`setup.d/_order.txt` where it should run. The list takes `#` comments, so it
can say why a step goes where it does. `setup` refuses to run anything if a
script is missing from the list or a listed name has no executable script.
A step that may need the user sources `lib/terminal` and sends its prompts to
fd 3, which is the terminal under `setup` and stdout when run on its own.

## Dotfiles in your home directory

The `install-stow` setup script links files into your home directory with GNU
Stow, from `stow/` at the repo root (every machine), from `stow/` in each of
the machine's profiles, and from `hosts/<hostname>/stow/`. For example,
`profiles/desktop/stow/bin/rdp-tunnel` becomes `~/bin/rdp-tunnel`. A file may
be in only one of these trees.

Stow links only the files (`--no-folding`), creating real directories for
them. To move a file to another tree, `git mv` it and rerun `install-stow`:
it first removes the broken links into the repo that the move left behind.
Links to a file deleted from every tree stay behind, broken, until you remove
them.

## Profiles

A profile is a set of lists and config that several machines share, such as
`desktop`. Each lives in `profiles/<profile>/` and may hold any of
`packages-leaves.txt`, `packages-leaves-exclude.txt`, `flatpaks.txt`,
`alternatives.txt`, `vscode-extensions.txt`, `syncthing-folders.txt`, an
`etc/` tree, a `stow/` tree and an `avatar.txt`.

A machine builds on the profiles named in `hosts/<hostname>/profiles.txt`, one
per line. A name with no `profiles/` directory is an error, not skipped.

## System config

Files under `etc/` in a host's profiles and in `hosts/<hostname>/` are copied
into `/etc` at the same paths by the `install-etc` setup script. Where both
have the same file, the host's wins. Use drop-in directories such as
`/etc/systemd/logind.conf.d/` rather than replacing a package's own config
file.

## Syncthing

The `syncthing` setup script adds Syncthing to your startup applications,
starts it, and syncs the folders listed in `syncthing-folders.txt`, from the
machine's profiles and `hosts/<hostname>/`, with jeeves, the hub. Each folder
joins jeeves's folder whose label is the directory's name, wherever jeeves
keeps it. The script adds the machine to jeeves over SSH (with the key from
`jeeves-ssh-key`) and makes jeeves an introducer, so the other machines that
share those folders with jeeves are added too. A folder that is not synced
yet but already has files (on a fresh install it is empty) is listed, and you
are asked whether to merge it into jeeves's; if not, it is skipped until a
rerun. A merge keeps a file that differs on both sides as a `.sync-conflict`
copy. Nothing is ever deleted. Each listed folder ignores `.git` and
`node_modules` directories, so they stay on each machine: the script adds
`(?d).git` and `(?d)node_modules` to the folder's ignore patterns when
missing, after any patterns it has, which are kept. Ignore patterns are per
machine, so this is done on every machine, jeeves included, on every run. On
jeeves itself it only does that and starts Syncthing; away from the home
network it also does it for the folders synced already. The `desktop` profile
lists `~/Documents`, `~/Dropbox`, `~/Music` and `~/Pictures`.

When the web UI says another machine is out of sync, `./syncthing-need
DEVICE` (a device's name or the start of its ID) shows what this machine
thinks it still needs: each shared folder's completion, and the items grouped
by their first two directory levels, largest first. `-n GROUPS` shows more
groups (default 15); `-a` lists every item.

## User picture

The `user-avatar` setup script sets your picture on the login and lock
screens (GNOME and COSMIC) to the image that `avatar.txt` names, from the
machine's profiles or `hosts/<hostname>/`, the host's winning. A leading `~`
means your home directory. The picture stays out of the repo, so the step
skips with a warning until it exists. The `desktop` profile has one.

## Updating the lists

Each list `setup` installs from comes in up to three parts:

- a shared file at the repo root, such as `packages-leaves.txt`, installed on
  every machine and edited by hand;
- a file of the same name in each of the machine's profiles, also edited by
  hand;
- an optional file of the same name in `hosts/<hostname>/`, installed only on
  that machine.

`setup` installs all of them. For `alternatives.txt` the order matters: a
profile's choices override the shared file's, and the host's override both.

After installing or removing software, regenerate this machine's host files:

```bash
./update-packages-leaves     # apt packages you chose to install
./update-flatpaks-list       # flatpaks
./update-vscode-extensions   # VS Code extensions
./update-alternatives-list   # alternatives you set by hand
```

Each writes only `hosts/<hostname>/`: what this machine has beyond the shared
file and its profiles. To give several machines something, move its line into
a profile they share, or into the shared file for every machine. The scripts
point out entries another host lists too, and shared or profile entries this
machine is missing. `packages-leaves-exclude.txt` works the same way. Set
`DOTFILES_HOST` to use another name than `hostname -s`.

## Tests

`tests/setup-test` checks `setup` itself with fake steps in a throwaway copy
of the repo: the step list checks, progress lines and run times, the log, and
stopping at a failed step. It needs no root and takes a few seconds.

`tests/install-stow-test` checks the `install-stow` setup script in a throwaway
home directory: stowing from the root, profile and host trees, and upgrading
links left by the old `base/` package or by moving a file between trees. It
needs GNU Stow and takes about a second.

`tests/syncthing-test` checks the `syncthing` setup script with two throwaway
Syncthing instances, one standing in for jeeves behind a fake `ssh`: pairing
the devices, joining jeeves's folders by label, asking before merging a folder
that has files, rerunning, refusing a folder already synced under another
ID, and adding the ignore patterns, keeping any others, on both machines and
away from home. It needs Syncthing, `jq` and `curl`, and takes about 8
seconds.

`tests/packages-leaves-docker-test` checks `update-packages-leaves` and
the `install-packages-leaves` setup script in fresh Docker containers. It needs
Docker access (the `docker` group) and takes about 15 minutes.
