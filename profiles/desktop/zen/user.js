// Zen preferences for hosts with the desktop profile that Zen sets on every
// start, so they hold even if Zen's default changes (see lib/zen). A change
// in Zen's settings lasts until it restarts. update-zen-settings leaves
// these alone.

// Tell websites not to sell or share my data (Global Privacy Control)
user_pref("privacy.globalprivacycontrol.enabled", true);
