# Maintainer: Your Name <you@example.com>
# Chinese (zh-CN) interface for RAWmakase: the unmodified upstream sources built
# with one patched dependency (epaint), plus an external TSV dictionary.
pkgname=rawmakase-zh
pkgver=0.4.1
pkgrel=1
pkgdesc='RAWmakase RAW photo editor with a Chinese (zh-CN) interface'
arch=('x86_64')
url="https://github.com/rmyou/rawmakase-zh"
license=('MIT')
depends=('hicolor-icon-theme')
optdepends=('noto-fonts-cjk: 中文字形'
            'onnxruntime-cpu: AI 主体与天空选择')
makedepends=('rust' 'cargo' 'clang' 'python')
options=(!debug !lto)
source=("rawmakase-$pkgver.tar.gz::https://github.com/pch/rawmakase/archive/refs/tags/v$pkgver.tar.gz"
        'zh.tsv'
        'zh.rs'
        'patch_epaint.py'
        'patch_cargo.py'
        'rawmakase-zh'
        'rawmakase-zh.desktop'
        'rawmakase-zh.svg'
        'rawmakase-zh-update-check.service'
        'rawmakase-zh-update-check.timer'
        'check-update.sh'
        'LICENSE')
sha256sums=('a94f5a1a9c9181e05ba56ca9dd0a709669bf6e21a23ae6393fa9eca49292d4aa'
            '5aa8c3867214b0b6cce8292b24664239f471be81f45b56164cc8e50983e34feb'
            'c7de42168c3ddacee972e19f4f864a4e87c17457b861e002a116a5c9c33e8aab'
            'ce3c98ee36d4a8ec4669ab810c57412f0048a20f1e279d82c64d99362dbafa45'
            '41e21b810c57829364045fd5bdbd815a0122fcb6a298e6ad04141d41f25d8050'
            '78417bede99ce90c02bb3112be3fa246597080a1a5445f7c943e5ed0a4f674f3'
            '0374feba17760d5d04adb8f90c5751880f678c4fed329644da8f15b786b41e67'
            '78faf3f9c4c0cdbb0b184ddbd4978e7461c14f6014d7c6de64d1c6c8e0430b84'
            'c0cf34548c96e218abf72b973763c99eb6d519f881acf24066629aac5217c574'
            '378017170462963c0a6f7aaf349092ffb9ab55735bcf2a6e054dbfd80e4e96f2'
            'd152370de821b1ea1ad7dd32c8e35db4e38d3712ef3e3b23394ce846cd91d44d'
            '11c3c58e683352d8f0f0b928d42c023938386c4bdb785ac62058ebf6d9b834b9')

prepare() {
	cd "rawmakase-$pkgver"
	export CARGO_HOME="$srcdir/cargo-home"
	cargo fetch --locked

	local epaint_version epaint_crate
	epaint_version=$(python - Cargo.lock <<-'PY'
		import re, sys
		text = open(sys.argv[1], encoding="utf-8").read()
		print(re.search(r'name = "epaint"\nversion = "([^"]+)"', text).group(1))
	PY
	)
	[ -n "$epaint_version" ] || { echo "epaint is not in Cargo.lock" >&2; return 1; }
	echo "    epaint $epaint_version"

	# Fetch the crate explicitly instead of hunting for cargo's unpacked copy:
	# an empty path here would turn a `cp` into a copy of the whole filesystem.
	epaint_crate="$srcdir/epaint-$epaint_version.crate"
	curl -fsSL "https://static.crates.io/crates/epaint/epaint-$epaint_version.crate" -o "$epaint_crate"
	rm -rf "$srcdir/epaint"
	mkdir -p "$srcdir/epaint"
	tar -xf "$epaint_crate" -C "$srcdir/epaint" --strip-components=1
	[ -f "$srcdir/epaint/src/text/fonts.rs" ] || { echo "epaint extraction failed" >&2; return 1; }

	python "$srcdir/patch_epaint.py" "$srcdir/epaint" "$srcdir/zh.rs"
	python "$srcdir/patch_cargo.py" Cargo.toml "$srcdir/epaint"
}

build() {
	cd "rawmakase-$pkgver"
	export CARGO_HOME="$srcdir/cargo-home"
	# makepkg's CFLAGS/LDFLAGS (notably -flto on the C side) break ring's
	# pregenerated assembly at link time; build Rust with the toolchain defaults.
	env -u CFLAGS -u CXXFLAGS -u LDFLAGS cargo build --release
}

package() {
	cd "rawmakase-$pkgver"
	install -Dm755 target/release/rawmakase "$pkgdir/usr/lib/rawmakase-zh/rawmakase"
	install -Dm644 "$srcdir/zh.tsv" "$pkgdir/usr/share/rawmakase-zh/zh.tsv"
	printf 'v%s\n' "$pkgver" >"$pkgdir/usr/share/rawmakase-zh/version"
	install -Dm755 "$srcdir/rawmakase-zh" "$pkgdir/usr/bin/rawmakase-zh"
	install -Dm644 "$srcdir/rawmakase-zh.desktop" "$pkgdir/usr/share/applications/rawmakase-zh.desktop"
	install -Dm644 "$srcdir/rawmakase-zh.svg" "$pkgdir/usr/share/icons/hicolor/scalable/apps/rawmakase-zh.svg"
	install -Dm644 "$srcdir/rawmakase-zh-update-check.service" \
		"$pkgdir/usr/lib/systemd/user/rawmakase-zh-update-check.service"
	install -Dm644 "$srcdir/rawmakase-zh-update-check.timer" \
		"$pkgdir/usr/lib/systemd/user/rawmakase-zh-update-check.timer"
	install -Dm755 "$srcdir/check-update.sh" "$pkgdir/usr/lib/rawmakase-zh/check-update.sh"
	install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/rawmakase-zh/LICENSE"
}
