# 发布清单（需要本人操作的部分）

代码、补丁、词典、打包文件都已就绪，下面这些需要账号和操作，只能由本人完成。
把 `OWNER` / `你的用户名` 换成你的 GitHub 用户名。

## ⚠️ 现状：AUR 暂停收件

2026-06 起 AUR 关闭了新账号注册，2026-08 起连推送都冻结（aur.archlinux.org 直接返回
HTTP 503，页面写着“对自动化建号的一波攻击采取的措施”），所以 **AUR 暂时上不了架**。
两条路：

- **方案 A（现在就能用）**：自建 pacman 仓库，托管在 GitHub Pages，`pacman -S` 直接装。
- **方案 B（等 AUR 恢复）**：`aur/` 已按 AUR 规范备好，恢复后照第 3 节推送即可。

---

## 1. GitHub：建仓库并推送（两个方案都要）

```sh
cd ~/rawmakseHANHUA
sed -i 's/OWNER/你的用户名/g' README.md aur/PKGBUILD
git config user.name  "你的名字"
git config user.email "你的邮箱"
git add -A && git commit -m "Point the URL at my account"

gh auth login                       # 已登录可跳过
gh repo create rawmakase-zh --public --source . --push
```

推送后 Actions 会跑 `.github/workflows/checks.yml`（词典同步、补丁可套用、.SRCINFO
是否最新）；打 tag 还会触发 `package.yml` 在 Arch 容器里 `makepkg` 出包。

## 2. 方案 A：自建 pacman 仓库（GitHub Pages）

```sh
cd ~/rawmakseHANHUA
tools/make-aur.sh --srcinfo                 # 已做过可跳过
(cd aur && makepkg -f)                      # 出 .pkg.tar.zst，已有可跳过
tools/make-repo.sh                          # 生成 repo/（repo-add 数据库 + index.html）
tools/publish-repo.sh                       # 把 repo/ 推到 gh-pages 分支

# 只需打开一次 Pages：
gh api -X POST repos/你的用户名/rawmakase-zh/pages \
        -f 'source[branch]=gh-pages' -f 'source[path]=/'
```

几分钟后 `https://你的用户名.github.io/rawmakase-zh/` 就是仓库地址。用户那边：

```ini
# /etc/pacman.conf 末尾
[rawmakase-zh]
SigLevel = Optional
Server = https://你的用户名.github.io/rawmakase-zh
```

```sh
sudo pacman -Syu rawmakase-zh
```

> 这是二进制仓库，装的时候不编译。`make-repo.sh` 默认用本机 GPG 私钥给**数据库和包**
> 都签名，并把公钥导出成 `repo/rawmakase-zh.asc` / `.gpg`，所以配置里用
> `SigLevel = Required`。用户首次安装要导入公钥：
>
> ```sh
> sudo pacman-key --add - <(curl -fsSL https://你的用户名.github.io/rawmakase-zh/rawmakase-zh.asc)
> sudo pacman-key --lsign-key F2EBB07B9579715A     # 你的密钥 ID
> ```
>
> 本机密钥：`rawmakase-zh pacman repo <rmyou@users.noreply.github.com>`，
> 指纹 `208D 1B49 5828 C60E 1296  27A8 F2EB B07B 9579 715A`（无口令，仅用于签名仓库）。
> 想给密钥加口令：`gpg --edit-key F2EBB07B9579715A passwd`，之后签名时 gpg-agent 会问一次。

## 3. 方案 B：AUR（等恢复后）

1. 在 https://aur.archlinux.org 注册账号（用 GitHub 登录），确认页面不再 503。
2. 把 SSH 公钥加到 *My Account → SSH Public Key*（`ssh-keygen -t ed25519` 生成）。
3. 发布：

```sh
cd ~/rawmakseHANHUA
tools/make-aur.sh --srcinfo

git clone ssh://aur@aur.archlinux.org/rawmakase-zh.git /tmp/aur-rawmakase-zh
cp aur/PKGBUILD aur/.SRCINFO aur/zh.tsv aur/zh.rs aur/patch_epaint.py \
   aur/patch_cargo.py aur/rawmakase-zh aur/rawmakase-zh.desktop \
   aur/rawmakase-zh.svg aur/check-update.sh aur/LICENSE \
   aur/rawmakase-zh-update-check.service aur/rawmakase-zh-update-check.timer \
   /tmp/aur-rawmakase-zh/
cd /tmp/aur-rawmakase-zh
makepkg --printsrcinfo > .SRCINFO
git add -A && git commit -m "rawmakase-zh 0.4.1-1"
git push
```

> AUR 只收源码构建的 PKGBUILD，用户装的时候会在本地编译 15–25 分钟。

## 4. 本机收尾（可选）

```sh
systemctl --user daemon-reload
systemctl --user enable --now rawmakase-zh-update-check.timer   # 每天查新版本
```

## 5. 以后跟随上游

```sh
cd ~/rawmakseHANHUA
tools/rebuild-zh.sh latest            # 或指定 tag
python3 tools/extract_missing.py      # 有新字符串时：翻译 → build_dict.py
(cd aur && makepkg -f)                # 重新出包
tools/make-repo.sh && tools/publish-repo.sh    # 方案 A：刷新仓库
tools/make-aur.sh --srcinfo           # 方案 B：改 pkgver 后再推 AUR
```
