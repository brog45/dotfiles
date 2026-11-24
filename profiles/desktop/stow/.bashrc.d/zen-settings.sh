# Set the Zen settings that setup left pending because Zen was running or had
# no profile yet, once Zen is closed (see ~/.local/bin/zen-settings). The check for
# the file keeps this free while nothing is pending.
if [ -e "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/zen-settings-pending" ]; then
    "$HOME/.local/bin/zen-settings" --pending
fi
