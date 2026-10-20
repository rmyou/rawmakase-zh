# 发布清单（需要本人操作的部分）

代码、补丁、词典、打包文件都已就绪，下面这些需要账号和密钥，只能由本人完成。
把 `OWNER` 换成你的 GitHub 用户名即可。

## 1. GitHub：建仓库并推送

```sh
cd ~/rawmakseHANHUA
# 把 README.md 两处、aur/PKGBUILD 的 url 与 Maintainer 改成你的
sed -i 's/OWNER/你的用户名/g' README.md aur/PKGBUILD
git config user.name  "你的名字"
git config user.email "你的邮箱"
git add -A && git commit -m "Point the URL at my account"
git remote add origin git@github.com:你的用户名/rawmakase-zh.git

gh auth login            # 或网页上先建好空仓库
git push -u origin main
git tag -a v0.4.1 -m "中文版 0.4.1" && git push origin v0.4.1   # 可选：触发打包 CI
```

推送后 GitHub Actions 会自动跑 `.github/workflows/checks.yml`（词典是否同步、
补丁能否套到对应 epaint、.SRCINFO 是否最新）；打 tag 会触发
`.github/workflows/package.yml` 在 Arch 容器里 `makepkg`，产物在 Actions 的
artifact 里，可直接用 `pacman -U` 安装。

## 2. AUR：上架 `rawmakase-zh`

1. 在 https://aur.archlinux.org 注册账号（用 GitHub 登录即可）。
2. 把 SSH 公钥加到 AUR 账户的 *My Account → SSH Public Key*。
   没有密钥就先 `ssh-keygen -t ed25519`，然后 `cat ~/.ssh/id_ed25519.pub`。
3. 发布：

```sh
cd ~/rawmakseHANHUA
tools/make-aur.sh --srcinfo          # 同步 aur/ 并生成 .SRCINFO

git clone ssh://aur@aur.archlinux.org/rawmakase-zh.git /tmp/aur-rawmakase-zh
cp aur/PKGBUILD aur/.SRCINFO aur/zh.tsv aur/zh.rs aur/patch_epaint.py \
   aur/patch_cargo.py aur/rawmakase-zh aur/rawmakase-zh.desktop \
   aur/rawmakase-zh.svg aur/rawmakase-zh-update-check.service \
   aur/rawmakase-zh-update-check.timer /tmp/aur-rawmakase-zh/
cd /tmp/aur-rawmakase-zh
makepkg --printsrcinfo > .SRCINFO     # 确认与仓库里的一致
git add -A && git commit -m "rawmakase-zh 0.4.1-1"
git push
```

之后 `yay -S rawmakase-zh` 或 `paru -S rawmakase-zh` 就能装。

> AUR 只接受「源码构建」的 PKGBUILD，所以装的时候会在本地编译一次（约 15–25 分钟，
> 取决于 CPU）。二进制包不适合放 AUR，走第 1 步的 GitHub Release 更合适。

## 3. 本机收尾（可选）

```sh
# 已按 AUR 方式安装后，手动安装的 /usr/local 版本可以删掉，避免两份
sudo rm -rf /usr/local/{bin/rawmakase-zh,lib/rawmakase-zh,share/rawmakase-zh,share/applications/rawmakase-zh.desktop}

# 每天检查新版本的用户定时器（AUR 包已自带单元，启用即可）
systemctl --user daemon-reload
systemctl --user enable --now rawmakase-zh-update-check.timer
```

## 4. 以后跟随上游

```sh
cd ~/rawmakseHANHUA
tools/rebuild-zh.sh latest           # 或指定 tag
# 有新字符串时：python3 tools/extract_missing.py → 翻译 → build_dict.py
tools/make-aur.sh --srcinfo          # 改 pkgver 后重新生成 .SRCINFO 并推送 AUR
```
