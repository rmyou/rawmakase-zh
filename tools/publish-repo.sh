#!/bin/sh
# Publish ./repo as a standalone branch (GitHub Pages serves it over HTTPS).
#
#   tools/publish-repo.sh [branch]        # default gh-pages
#
# Needs `origin` configured and push access. After the first push, enable Pages
# once:  gh api -X POST repos/OWNER/rawmakase-zh/pages \
#             -f 'source[branch]=gh-pages' -f 'source[path]=/'
# Users then add the repository shown in repo/index.html to /etc/pacman.conf.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
branch=${1:-gh-pages}
remote=$(git -C "$root" remote get-url origin)

[ -f "$root/repo/rawmakase-zh.db.tar.zst" ] || {
	echo "no repository in repo/: run tools/make-repo.sh first" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R "$root/repo/." "$work/"
cd "$work"
git init -q -b "$branch"
git add -A
git -c user.name="$(git -C "$root" config user.name)" \
    -c user.email="$(git -C "$root" config user.email)" \
    commit -q -m "Publish rawmakase-zh pacman repository"
git remote add origin "$remote"
git push -f origin "$branch"
echo "pushed $branch to $remote"
