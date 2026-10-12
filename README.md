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

After installing or removing software, regenerate the lists that `setup`
installs from. Run these from the repo root:

```bash
./update-packages-leaves     # packages-leaves.txt: apt packages you chose to install
./update-flatpaks-list       # flatpaks.txt
./update-vscode-extensions   # vscode-extensions.txt
./update-alternatives-list   # alternatives.txt: alternatives you set by hand
```

## Tests

`tests/packages-leaves-docker-test` checks `update-packages-leaves` and
`setup.d/050-install-packages-leaves` in fresh Docker containers. It needs
Docker access (the `docker` group) and takes about 15 minutes.
