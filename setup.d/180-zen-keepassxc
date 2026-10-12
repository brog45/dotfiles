#!/usr/bin/env bash

set -xeu

# set up Zen browser to use KeePassXC as password manager

if [ ! -x ~/.var/app/app.zen_browser.zen/.zen/native-messaging-hosts/keepassxc-proxy ]; then
    if [ ! -d ~/tmp/keepassxc-proxy-rust ]; then
        git clone https://github.com/varjolintu/keepassxc-proxy-rust ~/tmp/keepassxc-proxy-rust
    fi
    rustup target add x86_64-unknown-linux-musl
    cd ~/tmp/keepassxc-proxy-rust

    RUSTFLAGS='-C link-arg=-s -Clink-self-contained=y -Clinker=rust-lld' cargo build --release --target x86_64-unknown-linux-musl

    mkdir -p ~/.var/app/app.zen_browser.zen/.zen/native-messaging-hosts

    cp ~/tmp/keepassxc-proxy-rust/target/x86_64-unknown-linux-musl/release/keepassxc-proxy \
        ~/.var/app/app.zen_browser.zen/.zen/native-messaging-hosts/keepassxc-proxy
fi

cat > ~/.var/app/app.zen_browser.zen/.zen/native-messaging-hosts/org.keepassxc.keepassxc_browser.json <<'EOF'
{
  "name": "org.keepassxc.keepassxc_browser",
  "description": "KeePassXC integration with native messaging support",
  "path": "/home/brogers/.zen/native-messaging-hosts/keepassxc-proxy",
  "type": "stdio",
  "allowed_extensions": ["keepassxc-browser@keepassxc.org"]
}
EOF

cd ~/.var/app/app.zen_browser.zen
rm -rf .mozilla
mkdir -p .mozilla/native-messaging-hosts
cd .mozilla/native-messaging-hosts
ln -s ../../.zen/native-messaging-hosts/keepassxc-proxy .
ln -s ../../.zen/native-messaging-hosts/org.keepassxc.keepassxc_browser.json .

flatpak override --user --persist=.mozilla app.zen_browser.zen
flatpak override --user --filesystem=xdg-run/app/org.keepassxc.KeePassXC:ro app.zen_browser.zen