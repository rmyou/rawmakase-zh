#!/bin/sh
# Build a signed pacman repository from the package makepkg produced, for hosts
# that publish it themselves (a GitHub Pages branch, a web server, a NAS …).
#
#   tools/make-repo.sh            # sign with the default secret key
#   tools/make-repo.sh --no-sign  # unsigned, for a quick local test
#   REPO_URL=https://… tools/make-repo.sh
#
# Writes repo/ with the package, its databases (repo-add), the detached package
# signature, the public key, a pacman.conf snippet and an index page.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${REPO_DIR:-$root/repo}
say() { printf '\033[1m%s\033[0m\n' "$*"; }

sign=1
[ "${1:-}" = --no-sign ] && sign=0

pkg=$(ls -1t "$root"/aur/*.pkg.tar.zst 2>/dev/null | head -1)
[ -n "$pkg" ] || { echo "no package in aur/: run makepkg there first" >&2; exit 1; }
name=$(basename "$pkg")

key=${REPO_GPG_KEY:-$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/{print $5; exit}')}
if [ "$sign" = 1 ] && [ -z "$key" ]; then
	echo "no secret key found; create one with:" >&2
	echo "  gpg --batch --pinentry-mode loopback --passphrase '' \\" >&2
	echo "      --quick-generate-key 'rawmakase-zh pacman repo <you@example.com>' ed25519 sign never" >&2
	exit 1
fi

mkdir -p "$out"
cp -f "$pkg" "$out/"
cp -f "$root/aur/PKGBUILD" "$out/PKGBUILD"

if [ "$sign" = 1 ]; then
	say "signing $name with $key"
	(gpg --batch --yes --local-user "$key" --detach-sign --no-armor \
		--output "$out/$name.sig" "$out/$name")
	(cd "$out" && repo-add --sign --key "$key" rawmakase-zh.db.tar.zst "$name")
	gpg --export "$key" >"$out/rawmakase-zh.gpg"
	gpg --armor --export "$key" >"$out/rawmakase-zh.asc"
	siglevel="Required"
	keyblock="<h2>导入签名公钥（只需一次）</h2>
<pre>sudo pacman-key --add - &lt;(curl -fsSL ${REPO_URL:-https://OWNER.github.io/rawmakase-zh}/rawmakase-zh.asc)
sudo pacman-key --lsign-key $key</pre>"
else
	say "indexing $name (unsigned)"
	(cd "$out" && repo-add rawmakase-zh.db.tar.zst "$name")
	rm -f "$out/$name.sig" "$out/rawmakase-zh.gpg" "$out/rawmakase-zh.asc"
	siglevel="Optional"
	keyblock=""
fi

version=$(sed -n 's/^pkgver=//p' "$root/aur/PKGBUILD")
cat >"$out/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>rawmakase-zh pacman repository</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:3rem auto;padding:0 1rem}
code{background:#f2f2f2;padding:.1rem .3rem;border-radius:3px}pre{background:#f6f6f6;padding:1rem;overflow:auto}</style>
<h1>rawmakase-zh · pacman 仓库</h1>
<p>RAWmakase 中文版 $version 的二进制包，供 Arch Linux 的 pacman 直接安装。签名密钥：<code>$key</code></p>
$keyblock
<h2>添加仓库</h2>
<pre>[rawmakase-zh]
SigLevel = $siglevel
Server = ${REPO_URL:-https://OWNER.github.io/rawmakase-zh}</pre>
<p>写进 <code>/etc/pacman.conf</code> 末尾，然后 <code>sudo pacman -Syu rawmakase-zh</code>。</p>
<p>包文件：<a href="$name">$name</a></p>
EOF

cat >"$out/rawmakase-zh.conf" <<EOF
[rawmakase-zh]
SigLevel = $siglevel
Server = ${REPO_URL:-https://OWNER.github.io/rawmakase-zh}
EOF

say "repository in $out"
ls -la "$out"
say "publish it (examples)"
cat <<EOF
  GitHub Pages:  tools/publish-repo.sh
  任意静态站点:  rsync -av repo/ user@host:/srv/http/pacman/
EOF
