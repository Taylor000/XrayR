#!/usr/bin/env bash

set -o pipefail

SERVICE="XrayR"
CONFIG="/etc/XrayR/config.yml"
BIN="/usr/local/XrayR/XrayR"
INSTALL_URL="https://raw.githubusercontent.com/Taylor000/XrayR/master/install.sh"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

info() { echo -e "${green}$*${plain}"; }
warn() { echo -e "${yellow}$*${plain}"; }
fail() { echo -e "${red}$*${plain}" >&2; exit 1; }
installed() { [[ -x $BIN && -f /etc/systemd/system/XrayR.service ]]; }
require_install() { installed || fail "XrayR 未安装。"; }

run_installer() {
    local file status
    file=$(mktemp /tmp/xrayr-installer.XXXXXX) || return 1
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 "$INSTALL_URL" -o "$file"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$file" "$INSTALL_URL"
    else
        rm -f "$file"
        fail "系统缺少 curl 或 wget。"
    fi
    status=$?
    if (( status == 0 )); then
        bash -n "$file" && bash "$file"
        status=$?
    fi
    rm -f "$file"
    return "$status"
}

start() { require_install; systemctl start "$SERVICE" && info "XrayR 已启动。"; }
stop() { require_install; systemctl stop "$SERVICE" && info "XrayR 已停止。"; }
restart() { require_install; systemctl restart "$SERVICE" && info "XrayR 已重启。"; }
status() { require_install; systemctl status "$SERVICE" --no-pager -l; }
log() { require_install; journalctl -u "${SERVICE}.service" -e --no-pager -f; }
enable() { require_install; systemctl enable "$SERVICE" && info "已设置开机自启。"; }
disable() { require_install; systemctl disable "$SERVICE" && info "已取消开机自启。"; }
version() { require_install; "$BIN" version; }
config() { require_install; "${EDITOR:-vi}" "$CONFIG"; }
install_xrayr() { run_installer || fail "安装失败。"; }
update_xrayr() { run_installer || fail "重新安装失败。"; }

uninstall_xrayr() {
    read -r -p "确认卸载 XrayR？(y/n): " answer
    [[ $answer == [yY] ]] || return 0
    systemctl stop "$SERVICE" 2>/dev/null || true
    systemctl disable "$SERVICE" 2>/dev/null || true
    rm -f /etc/systemd/system/XrayR.service /usr/bin/xrayr /usr/bin/XrayR
    rm -rf /usr/local/XrayR /etc/XrayR
    systemctl daemon-reload
    info "XrayR 已卸载。"
}

usage() {
    echo "xrayr start|stop|restart|status|log"
    echo "xrayr enable|disable|config|version"
    echo "xrayr install|update|uninstall"
}

menu() {
    while true; do
        echo
        echo "XrayR v0.9.4"
        echo "1. 修改配置"
        echo "2. 安装/重新安装"
        echo "3. 卸载"
        echo "4. 启动"
        echo "5. 停止"
        echo "6. 重启"
        echo "7. 状态"
        echo "8. 日志"
        echo "9. 开机自启"
        echo "10. 取消自启"
        echo "11. 版本"
        echo "0. 退出"
        read -r -p "请选择 [0-11]: " choice
        case "$choice" in
            1) config ;;
            2) install_xrayr ;;
            3) uninstall_xrayr ;;
            4) start ;;
            5) stop ;;
            6) restart ;;
            7) status ;;
            8) log ;;
            9) enable ;;
            10) disable ;;
            11) version ;;
            0) exit 0 ;;
            *) warn "请输入 0-11。" ;;
        esac
    done
}

[[ $EUID -eq 0 ]] || fail "请使用 root 权限运行。"
case "${1:-}" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    log) log ;;
    enable) enable ;;
    disable) disable ;;
    config) config ;;
    version) version ;;
    install) install_xrayr ;;
    update) update_xrayr ;;
    uninstall) uninstall_xrayr ;;
    -h|--help|help) usage ;;
    "") menu ;;
    *) usage; exit 1 ;;
esac
