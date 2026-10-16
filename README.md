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
the new group. It then runs each executable script in `setup.d/` in order.

Each script can also be run on its own, and is meant to be safe to rerun.
Log out and back in afterwards to pick up the `docker` group.

To add a step, drop an executable script into `setup.d/` with a number that
puts it in the right place.

## Stowing packages

`setup` stows the `base` package. Additional packages (e.g. machine-specific
configs) can be stowed the same way:

```
stow -vv --no-folding -t ~ <package-name>
```

`--no-folding` creates real directories in `$HOME` and links only the files.

## Updating the lists

Each list `setup` installs from comes in two parts:

- a shared file at the repo root, such as `packages-leaves.txt`, installed on
  every machine and edited by hand;
- an optional file of the same name in `hosts/<hostname>/`, installed only on
  that machine.

`setup` installs both. After installing or removing software, regenerate this
machine's host files:

```bash
./update-packages-leaves     # apt packages you chose to install
./update-flatpaks-list       # flatpaks
./update-vscode-extensions   # VS Code extensions
./update-alternatives-list   # alternatives you set by hand
```

Each writes only `hosts/<hostname>/`: what this machine has beyond the shared
file. To give every machine something, move its line into the shared file. The
scripts point out entries another host lists too, and shared entries this
machine is missing. `packages-leaves-exclude.txt` works the same way: the
shared file applies everywhere, `hosts/<hostname>/packages-leaves-exclude.txt`
only there. Set `DOTFILES_HOST` to use another name than `hostname -s`.

## Tests

`tests/packages-leaves-docker-test` checks `update-packages-leaves` and
`setup.d/050-install-packages-leaves` in fresh Docker containers. It needs
Docker access (the `docker` group) and takes about 15 minutes.
