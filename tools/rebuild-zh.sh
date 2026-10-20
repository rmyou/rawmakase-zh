#!/bin/sh
# Rebuild the Chinese RAWmakase from any upstream tag.
#
#   tools/rebuild-zh.sh                 # latest GitHub release
#   tools/rebuild-zh.sh v0.4.1          # a specific tag
#   tools/rebuild-zh.sh v0.4.1 --prepare-only   # only set the tree up (fast check)
#   tools/rebuild-zh.sh v0.4.1 --no-install     # build, leave it in target/
#
# What it does, per tag:
#   1. checkout the tag in ./src (the local clone) and fetch its dependencies;
#   2. copy the epaint version that tag pins into ./patched/ and insert the
#      dictionary hook (tools/patch_epaint.py, idempotent);
#   3. point [patch.crates-io] at that copy, build with --release;
#   4. verify the binary really carries the dictionary, install it, and report
#      which new UI strings the dictionary does not cover yet.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ROOT
TAG=latest
PREPARE_ONLY=0
INSTALL=1

for arg in "$@"; do
	case $arg in
	--prepare-only) PREPARE_ONLY=1 ;;
	--no-install) INSTALL=0 ;;
	-*) echo "unknown option: $arg" >&2; exit 2 ;;
	*) TAG=$arg ;;
	esac
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [ "$TAG" = latest ]; then
	# github.com/releases/latest redirects to the tag; the JSON API is rate limited.
	TAG=$(curl -fsI -o /dev/null -w '%{redirect_url}' https://github.com/pch/rawmakase/releases/latest |
		sed 's#.*/tag/##')
	say "latest release is $TAG"
fi

say "checking out $TAG"
if [ ! -d "$ROOT/src/.git" ]; then
	echo "cloning pch/rawmakase into $ROOT/src (first run)"
	git clone --depth 1 https://github.com/pch/rawmakase.git "$ROOT/src" >/dev/null
fi
git -C "$ROOT/src" fetch --tags --depth 1 origin >/dev/null 2>&1 || true
git -C "$ROOT/src" checkout -q -- Cargo.toml Cargo.lock 2>/dev/null || true
git -C "$ROOT/src" checkout -q "$TAG"

say "fetching dependencies"
(cd "$ROOT/src" && cargo fetch >/dev/null)

EP=$(python3 - "$ROOT/src/Cargo.lock" <<-'PY'
	import re, sys
	text = open(sys.argv[1], encoding="utf-8").read()
	m = re.search(r'name = "epaint"\nversion = "([^"]+)"', text)
	print(m.group(1) if m else "unknown")
PY
)
[ "$EP" != unknown ] || { echo "epaint is not in Cargo.lock" >&2; exit 1; }
say "epaint $EP"

DIR=$ROOT/patched/epaint
if [ -f "$DIR/Cargo.toml" ] && ! grep -qx "version = \"$EP\"" "$DIR/Cargo.toml"; then
	DIR=$ROOT/patched/epaint-$EP
fi
if [ ! -f "$DIR/Cargo.toml" ]; then
	SRC=$(ls -d "$HOME"/.cargo/registry/src/*/epaint-"$EP" 2>/dev/null | head -1)
	[ -n "$SRC" ] || { echo "epaint-$EP is not unpacked in the cargo registry" >&2; exit 1; }
	mkdir -p "$ROOT/patched"
	cp -r "$SRC" "$DIR"
	say "copied epaint-$EP to $DIR"
fi

python3 "$ROOT/tools/patch_epaint.py" "$DIR" "$ROOT/patches/zh.rs"

REL=$(python3 - "$DIR" <<-'PY'
	import os, sys
	print(os.path.relpath(sys.argv[1], os.path.join(os.environ["ROOT"], "src")))
PY
)
python3 "$ROOT/tools/patch_cargo.py" "$ROOT/src/Cargo.toml" "$REL"
say "Cargo.toml now patches epaint from $REL"

if [ "$PREPARE_ONLY" = 1 ]; then
	say "prepare only: checking that the patched epaint compiles"
	(cd "$ROOT/src" && cargo check -p epaint)
	say "ready to build: tools/rebuild-zh.sh $TAG"
	exit 0
fi

say "building (release, LTO; several minutes)"
(cd "$ROOT/src" && cargo build --release)

if ! strings "$ROOT/src/target/release/rawmakase" | grep -q "RAWMAKASE_ZH_DICT"; then
	echo "built binary has no dictionary hook" >&2
	exit 1
fi

if [ "$INSTALL" = 1 ]; then
	say "installing"
	"$ROOT/packaging/install.sh"
	printf '%s\n' "$TAG" | sudo tee /usr/local/share/rawmakase-zh/version >/dev/null
	say "installed $TAG"
fi

say "dictionary coverage for $TAG"
python3 "$ROOT/tools/extract_missing.py" || true
