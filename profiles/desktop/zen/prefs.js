// Zen preferences for hosts with the desktop profile (see lib/zen).
// update-zen-settings saves a host's own to hosts/<host>/zen/prefs.js; move
// them here by hand to share them.

// Address bar: no search suggestions, from the search engine or for engines
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.engines", false);
// No prefetching of DNS or links, and no speculative connections
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
// KeePassXC saves passwords, not Zen (see setup.d/zen-keepassxc)
user_pref("signon.rememberSignons", false);
// Block autoplay of audio and video
user_pref("media.autoplay.default", 5);
// Clear form history on shutdown
user_pref("privacy.clearOnShutdown_v2.formdata", true);
// Ctrl+Tab goes to the tab used last
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
// Firefox's dark theme: Zen records the theme's ID here, and
// setup.d/zen-settings turns that theme on
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
// No compact mode at startup, and no single toolbar
user_pref("zen.view.compact.enable-at-startup", false);
user_pref("zen.view.use-single-toolbar", false);
// Developer tools docked on the right
user_pref("devtools.toolbox.host", "right");
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", true);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", true);
user_pref("browser.startup.page", 1);
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"containerise_kinte_sh-browser-action\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"share-tab-button\",\"unified-extensions-button\",\"_testpilot-containers-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"keepassxc-browser_keepassxc_org-browser-action\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\",\"zen-media-controls-toolbar\",\"customizableui-special-spring4\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"personal-bookmarks\"],\"zen-sidebar-top-buttons\":[\"zen-toggle-compact-mode\"],\"zen-sidebar-foot-buttons\":[\"zen-library-button\",\"zen-workspaces-button\",\"zen-create-new-button\"]},\"seen\":[\"smartwindow-group-tabs-button\",\"ai-window-toggle\",\"developer-button\",\"screenshot-button\",\"ublock0_raymondhill_net-browser-action\",\"keepassxc-browser_keepassxc_org-browser-action\",\"_testpilot-containers-browser-action\",\"containerise_kinte_sh-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"zen-sidebar-foot-buttons\",\"TabsToolbar\",\"PersonalToolbar\",\"unified-extensions-area\",\"toolbar-menubar\",\"zen-sidebar-top-buttons\"],\"currentVersion\":28,\"newElementCount\":4}");
user_pref("browser.uidensity", 0);
user_pref("dom.security.https_only_mode", true);
user_pref("nimbus.rollouts.enabled", false);
user_pref("services.sync.declinedEngines", "passwords,addresses,creditcards,forms,history");
user_pref("services.sync.engine.history", false);
user_pref("services.sync.engine.passwords", false);
user_pref("services.sync.engine.spaces", true);
