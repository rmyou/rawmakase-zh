#!/bin/sh
# Build a pacman repository from the package makepkg produced, for hosts that
# publish it themselves (a GitHub Pages branch, a web server, a NAS …).
#
#   tools/make-repo.sh [--sign KEYID]
#
# Writes repo/ with the package, its databases (repo-add), a pacman.conf snippet
# and an index page. Publish the directory wherever HTTP serves it, then users
# add one entry to /etc/pacman.conf.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${REPO_DIR:-$root/repo}
sign=

[ "${1:-}" = --sign ] && { sign="--sign"; shift; }

pkg=$(ls -1t "$root"/aur/*.pkg.tar.zst 2>/dev/null | head -1)
[ -n "$pkg" ] || { echo "no package in aur/: run makepkg there first" >&2; exit 1; }

mkdir -p "$out"
cp -f "$pkg" "$out/"
name=$(basename "$pkg")
say() { printf '\033[1m%s\033[0m\n' "$*"; }

say "indexing $name"
(cd "$out" && repo-add $sign rawmakase-zh.db.tar.zst "$name")

# repo-add leaves the versioned names as symlinks; keep both, Dropbox-free hosts
# follow them fine.
version=$(sed -n 's/^pkgver=//p' "$root/aur/PKGBUILD")
cat >"$out/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>rawmakase-zh pacman repository</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:3rem auto;padding:0 1rem}
code{background:#f2f2f2;padding:.1rem .3rem;border-radius:3px}pre{background:#f6f6f6;padding:1rem;overflow:auto}</style>
<h1>rawmakase-zh · pacman 仓库</h1>
<p>RAWmakase 中文版 $version 的二进制包，供 Arch Linux 的 pacman 直接安装。</p>
<h2>添加仓库</h2>
<pre>[rawmakase-zh]
SigLevel = Optional
Server = ${REPO_URL:-https://OWNER.github.io/rawmakase-zh}</pre>
<p>把这段写进 <code>/etc/pacman.conf</code> 末尾，然后 <code>sudo pacman -Sy rawmakase-zh</code>。</p>
<p>包文件：<a href="$name">$name</a></p>
EOF

cat >"$out/rawmakase-zh.conf" <<EOF
[rawmakase-zh]
SigLevel = Optional
Server = ${REPO_URL:-https://OWNER.github.io/rawmakase-zh}
EOF

say "repository in $out"
ls -la "$out"
say "publish it (examples)"
cat <<EOF
  GitHub Pages:  git subtree push --prefix repo origin gh-pages
  任意静态站点:  rsync -av repo/ user@host:/srv/http/pacman/
EOF
