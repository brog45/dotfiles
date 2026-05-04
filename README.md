# My dotfiles

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system

### Git

```
sudo apt install git
```

### Stow

```
sudo apt install stow
```

## Installation

First, check out the `dotfiles` repo in your `$HOME` directory using `git`

```
cd $HOME
mkdir .cargo
mkdir .config
mkdir bin
git clone https://github.com/brog45/dotfiles.git
cd dotfiles
```

then use GNU `stow` to create symlinks for the base package (in the `base` subdirectory).

```
stow -vv base
```

Additional packages (e.g. machine-specific configs) can be stowed the same way:

```
stow -vv <package-name>
```

## Installing VS Code extensions

`vscode-extensions.txt` contains a list of VS Code extensions generated using this command:
```bash
code --list-extensions > vscode-extensions.txt
```

Use this command to restore extensions:
```bash
cat vscode-extensions.txt | xargs -L1 code --install-extension
```
