#!/bin/bash

./InstallDeps.sh

set -e
set -x

#load dep exports
#need to switch to game dir for Dockerfile weirdness
original_dir=$PWD
cd "$1"
. dependencies.sh
cd "$original_dir"

# Build rust-g from the fork vendored in-repo at tools/rust/rust-g (adds the
# xeno_pathfind feature - see code/__DEFINES/__xeno_pathfind.dm) instead of
# cloning vanilla tgstation/rust-g fresh every compile. Vanilla upstream has
# no xeno_pathfind support at all, so rebuilding from it would silently
# replace a working library with one missing that feature. Building the
# exact version checked into this commit also means the native source and
# the DM code that calls it can never drift out of sync with each other.
echo "Building rust-g..."
cd "$1/tools/rust/rust-g"
~/.cargo/bin/rustup target add i686-unknown-linux-gnu
env PKG_CONFIG_ALLOW_CROSS=1 ~/.cargo/bin/cargo build --release --target=i686-unknown-linux-gnu --features redis_pubsub
cp target/i686-unknown-linux-gnu/release/librust_g.so "$1/librust_g.so"
cd "$original_dir"

# compile tgui
echo "Compiling tgui..."
cd "$1"
chmod +x tools/bootstrap/node  # Workaround for https://github.com/tgstation/tgstation-server/issues/1167
env TG_BOOTSTRAP_CACHE="$original_dir" TG_BOOTSTRAP_NODE_LINUX=1 CBT_BUILD_MODE="TGS" tools/bootstrap/node tools/build/build.js

echo "Running changelog script..."
python3 .github/ss13_genchangelog.py html/changelogs
