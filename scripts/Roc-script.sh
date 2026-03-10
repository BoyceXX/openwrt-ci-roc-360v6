# 建议加在脚本开头（如果你脚本最上面还没有）
set -euo pipefail
export GIT_TERMINAL_PROMPT=0
git config --global --unset-all http.https://github.com/.extraheader 2>/dev/null || true

# 移除要替换的包（只删除你确定要替换/不用的）
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-wechatpush
rm -rf feeds/luci/applications/luci-app-appfilter
rm -rf feeds/luci/applications/luci-app-frpc
rm -rf feeds/luci/applications/luci-app-frps
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang

# -----------------------------
# 加固版 Git 稀疏克隆：只取指定目录到 openwrt/package/
# 用法：git_sparse_clone <branch> <repo_url> <path1> [path2...]
# -----------------------------
git_sparse_clone() {
  local branch="$1"
  local repourl="$2"
  shift 2

  local repodir
  repodir="$(basename "$repourl")"
  repodir="${repodir%.git}"

  rm -rf "$repodir"
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$repodir"

  pushd "$repodir" >/dev/null
  git sparse-checkout set "$@"
  popd >/dev/null

  mkdir -p package
  for p in "$@"; do
    if [ -e "$repodir/$p" ]; then
      mv -f "$repodir/$p" package/
    else
      echo "WARN: sparse path not found in repo: $repourl -> $p"
    fi
  done

  rm -rf "$repodir"
}

# 可选：如果你确实不需要 ariang，就不要再拉它；否则保留这行
# git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang

# Golang：固定 25.x（给 dae 编译用）
rm -rf feeds/packages/lang/golang
git clone --depth 1 -b 25.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# -----------------------------
# 重要：不再删除 feeds/packages/net 的“核心库”
# 否则会导致 DAE 依赖（v2ray-geoip/geosite 或 geodata）缺失，出现 warning/编译失败
# -----------------------------
# （这里不需要 PassWall/OpenClash 相关操作，全部删掉）

# -----------------------------
# Nikki（MiHoMo）: 拉包 + 预下载 Geo 数据到 OpenWrt 的 files/（随固件打包）
# -----------------------------
rm -rf package/nikki
git clone --depth=1 -b main https://github.com/nikkinikki-org/OpenWrt-nikki.git package/nikki

FILES_DIR="$PWD/files/etc/nikki/run"
mkdir -p "$FILES_DIR"

wget -qO "$FILES_DIR/geoip.metadb" \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb" \
  || { echo "ERROR: geoip.metadb download failed"; exit 1; }

wget -qO "$FILES_DIR/geosite.dat" \
  "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" \
  || { echo "ERROR: geosite.dat download failed"; exit 1; }

echo "=== Nikki geo files ==="
ls -la "$FILES_DIR"

# -----------------------------
# DAE：一般来自 feeds/packages，不需要额外 clone
# 你可以加一个检查，方便确认确实存在
# -----------------------------
if [ -d "package/feeds/packages/dae" ] || [ -d "feeds/packages/net/dae" ]; then
  echo "DAE: found in feeds."
else
  echo "WARN: DAE not found in feeds yet. Check: ./scripts/feeds search dae"
fi
