#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="v0.9.4"
RAW_BASE_URL="https://raw.githubusercontent.com/Taylor000/XrayR/master"
RELEASE_URL="${RAW_BASE_URL}/release/${VERSION}"
INSTALL_DIR="/usr/local/XrayR"
CONFIG_DIR="/etc/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
MANAGER_FILE="/usr/bin/XrayR"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

info() { echo -e "${green}$*${plain}"; }
warn() { echo -e "${yellow}$*${plain}"; }
fail() { echo -e "${red}$*${plain}" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

download_file() {
    local url=$1 destination=$2
    if command_exists curl; then
        curl --fail --location --silent --show-error --retry 3 \
            --connect-timeout 15 --max-time 900 "$url" -o "$destination"
    elif command_exists wget; then
        wget --https-only --quiet --timeout=900 --tries=3 -O "$destination" "$url"
    else
        return 1
    fi
}

install_dependencies() {
    local packages=(curl unzip ca-certificates coreutils)
    if command_exists apt-get; then
        DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 update
        DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 install -y "${packages[@]}"
    elif command_exists dnf; then
        dnf install -y "${packages[@]}"
    elif command_exists yum; then
        yum install -y "${packages[@]}"
    else
        fail "请先安装 curl、unzip、ca-certificates 和 coreutils。"
    fi
}

backup_file() {
    local path=$1
    [[ ! -e $path || -d $path ]] || cp -p "$path" "${path}.backup"
}

[[ $EUID -eq 0 ]] || fail "请使用 root 权限运行。"
command_exists systemctl || fail "仅支持 systemd 系统。"

requested_version=${1:-$VERSION}
case "$requested_version" in
    -h|--help)
        echo "用法: install.sh [v0.9.4]"
        exit 0
        ;;
esac
[[ $requested_version == v* ]] || requested_version="v${requested_version}"
[[ $requested_version == "$VERSION" ]] || fail "仅提供 ${VERSION}。"

case $(uname -m) in
    x86_64|amd64) release_arch="64" ;;
    aarch64|arm64) release_arch="arm64-v8a" ;;
    s390x) release_arch="s390x" ;;
    *) fail "不支持的 CPU 架构：$(uname -m)" ;;
esac

if ! command_exists unzip || ! command_exists sha256sum ||
   { ! command_exists curl && ! command_exists wget; }; then
    install_dependencies || fail "依赖安装失败。"
fi

temp_dir=$(mktemp -d /tmp/xrayr-install.XXXXXX) || fail "无法创建临时目录。"
trap 'rm -rf "$temp_dir"' EXIT

archive_name="XrayR-linux-${release_arch}.zip"
archive_file="${temp_dir}/${archive_name}"
checksum_file="${temp_dir}/SHA256SUMS"
extract_dir="${temp_dir}/extract"

info "正在安装 XrayR ${VERSION} (${release_arch})..."
download_file "${RELEASE_URL}/${archive_name}" "$archive_file" || fail "安装包下载失败。"
download_file "${RELEASE_URL}/SHA256SUMS" "$checksum_file" || fail "校验文件下载失败。"

expected_sha256=$(awk -v name="$archive_name" '$2 == name { print $1; exit }' "$checksum_file")
actual_sha256=$(sha256sum "$archive_file" | awk '{print $1}')
[[ -n $expected_sha256 && ${actual_sha256,,} == ${expected_sha256,,} ]] || fail "SHA-256 校验失败。"
unzip -tq "$archive_file" >/dev/null || fail "安装包损坏。"

mkdir -p "$extract_dir"
unzip -q "$archive_file" -d "$extract_dir"
[[ -f "$extract_dir/XrayR" && -f "$extract_dir/config.yml" ]] || fail "安装包文件不完整。"

download_file "${RAW_BASE_URL}/scripts/XrayR.service" "$temp_dir/XrayR.service" || fail "服务文件下载失败。"
download_file "${RAW_BASE_URL}/scripts/xrayr.sh" "$temp_dir/xrayr.sh" || fail "管理脚本下载失败。"
grep -q '^ExecStart=/usr/local/XrayR/XrayR --config /etc/XrayR/config.yml$' "$temp_dir/XrayR.service" || fail "服务文件无效。"
bash -n "$temp_dir/xrayr.sh" || fail "管理脚本无效。"

had_config=0
[[ -f "$CONFIG_DIR/config.yml" ]] && had_config=1

install -d -m 755 "$INSTALL_DIR" "$CONFIG_DIR"
backup_file "$INSTALL_DIR/XrayR"
backup_file "$SERVICE_FILE"
backup_file "$MANAGER_FILE"
systemctl stop XrayR 2>/dev/null || true

install -m 755 "$extract_dir/XrayR" "$INSTALL_DIR/XrayR"
install -m 644 "$temp_dir/XrayR.service" "$SERVICE_FILE"
install -m 755 "$temp_dir/xrayr.sh" "$MANAGER_FILE"

for file in geoip.dat geosite.dat; do
    [[ ! -f "$extract_dir/$file" ]] || install -m 644 "$extract_dir/$file" "$CONFIG_DIR/$file"
done
if (( had_config == 0 )); then
    install -m 600 "$extract_dir/config.yml" "$CONFIG_DIR/config.yml"
fi
for file in dns.json route.json custom_outbound.json custom_inbound.json rulelist; do
    if [[ -f "$extract_dir/$file" && ! -e "$CONFIG_DIR/$file" ]]; then
        install -m 644 "$extract_dir/$file" "$CONFIG_DIR/$file"
    fi
done

if [[ -e /usr/bin/xrayr && ! -L /usr/bin/xrayr ]]; then
    backup_file /usr/bin/xrayr
    rm -f /usr/bin/xrayr
fi
ln -sfn "$MANAGER_FILE" /usr/bin/xrayr

systemctl daemon-reload
systemctl enable XrayR >/dev/null
if (( had_config == 1 )); then
    systemctl restart XrayR || warn "服务启动失败，请执行 xrayr status 检查。"
else
    warn "请编辑 ${CONFIG_DIR}/config.yml 后执行 xrayr start。"
fi

info "XrayR ${VERSION} 安装完成。管理命令：xrayr"
