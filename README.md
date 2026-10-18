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
when they need you: a package list to confirm, a GitHub or Tailscale login, a
password for jeeves. Before the first `sudo` that needs your password, `setup`
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

## Stowing packages

`setup` stows the `base` package. Additional packages (e.g. machine-specific
configs) can be stowed the same way:

```
stow -vv --no-folding -t ~ <package-name>
```

`--no-folding` creates real directories in `$HOME` and links only the files.

## Profiles

A profile is a set of lists and config that several machines share, such as
`desktop`. Each lives in `profiles/<profile>/` and may hold any of
`packages-leaves.txt`, `packages-leaves-exclude.txt`, `flatpaks.txt`,
`alternatives.txt`, `vscode-extensions.txt` and an `etc/` tree.

A machine builds on the profiles named in `hosts/<hostname>/profiles.txt`, one
per line. A name with no `profiles/` directory is an error, not skipped.

## System config

Files under `etc/` in a host's profiles and in `hosts/<hostname>/` are copied
into `/etc` at the same paths by the `install-etc` setup script. Where both
have the same file, the host's wins. Use drop-in directories such as
`/etc/systemd/logind.conf.d/` rather than replacing a package's own config
file.

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

`tests/packages-leaves-docker-test` checks `update-packages-leaves` and
the `install-packages-leaves` setup script in fresh Docker containers. It needs
Docker access (the `docker` group) and takes about 15 minutes.
