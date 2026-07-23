#!/usr/bin/env bash
#
# install.sh — Script tổng của My-caelestia
#
# Đọc manifest.json để biết repo có những component nào, cho người dùng
# chọn (qua fzf) muốn cài gì, rồi gọi install.sh riêng của từng component.
#
# Cách dùng:
#   bash install.sh              -> hiện menu chọn component cần cài
#   bash install.sh launcher     -> cài thẳng component "launcher"
#   bash install.sh --all        -> cài tất cả component có trong manifest
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"

# ============================ MÀU SẮC ============================

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_CYAN=$'\033[38;5;80m'
C_GREEN=$'\033[38;5;114m'
C_YELLOW=$'\033[38;5;221m'
C_RED=$'\033[38;5;203m'
C_BLUE=$'\033[38;5;111m'
C_GRAY=$'\033[38;5;245m'

FZF_THEME="fg:#d0d0d0,bg:-1,hl:#5fff87,fg+:#ffffff,bg+:#3a3a3a,hl+:#5fff87,\
info:#af87ff,prompt:#5fafff,pointer:#ff5faf,marker:#ffaf00,spinner:#af87ff,\
header:#87afff,border:#5f5f87,label:#d7af5f"

# ============================ LOG / UI HELPERS ============================

log_info()    { printf "  %s[INFO]%s %s\n" "$C_BLUE" "$C_RESET" "$1"; }
log_warn()    { printf "  %s[WARN]%s %s\n" "$C_YELLOW" "$C_RESET" "$1"; }
log_error()   { printf "  %s[ERROR]%s %s\n" "$C_RED" "$C_RESET" "$1"; }
log_success() { printf "  %s[SUCCESS]%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }

# nhãn luôn là chuỗi ASCII thuần khi đưa vào %-8s để chiều rộng cột luôn
# đúng — màu bọc bên NGOÀI qua %s riêng, không nhét vào chuỗi được canh lề
info_row() {
    local label="$1" value="$2"
    printf "  %s%-8s%s : %s\n" "$C_BOLD$C_BLUE" "$label" "$C_RESET" "$value"
}

hr() {
    printf "  %s" "$C_GRAY"
    printf -- '─%.0s' $(seq 1 42)
    printf "%s\n" "$C_RESET"
}

format_elapsed() {
    local secs="$1"
    if [ "$secs" -ge 60 ]; then
        printf "%dm%02ds" "$((secs / 60))" "$((secs % 60))"
    else
        printf "%ds" "$secs"
    fi
}

# ============================ BANNER ============================
# Chỉ giữ OS / Kernel / Shell / WM — đây là installer, không phải
# fastfetch, nên bỏ Packages/Components: không phục vụ việc cài.

print_banner() {
    local os_name kernel shell_name wm

    os_name=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null || true)
    os_name="${os_name:-Khong ro}"
    kernel=$(uname -r 2>/dev/null || echo "khong ro")
    shell_name=$(basename "${SHELL:-bash}")
    if command -v hyprctl >/dev/null 2>&1; then
        wm="Hyprland"
    else
        wm="Khong phat hien"
    fi

    echo
    printf "  %s✦ My-caelestia%s  %sinstaller%s\n" "$C_BOLD$C_CYAN" "$C_RESET" "$C_GRAY" "$C_RESET"
    hr
    info_row "OS" "$os_name"
    info_row "Kernel" "$kernel"
    info_row "Shell" "$shell_name"
    info_row "WM" "$wm"
    hr
    echo
}

# Environment check — chỉ những gì thực sự liên quan tới việc cài đặt
# (khác Packages/Components ở banner cũ, cái này có tác dụng thật: biết
# ngay thiếu gì trước khi bấm cài).
print_environment() {
    echo "  Environment"
    env_check pacman "Arch-based Linux"
    env_check hyprctl "Hyprland"
    env_check jq "jq"
    env_check fzf "fzf"
    echo
}

env_check() {
    local bin="$1" label="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        printf "    %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$label"
    else
        printf "    %s✗%s %s\n" "$C_RED" "$C_RESET" "$label"
    fi
}

print_manifest_preview() {
    local total
    total=$(jq 'length' "$MANIFEST" 2>/dev/null || echo 0)
    echo "  Components available"
    jq -r '.[] | "    • \(.name) - \(.description)"' "$MANIFEST" 2>/dev/null || true
    printf "  Total: %s\n\n" "$total"
}

# ============================ KIỂM TRA MÔI TRƯỜNG ============================

check_arch() {
    if ! command -v pacman >/dev/null 2>&1; then
        log_warn "Khong tim thay 'pacman'. My-caelestia duoc viet cho Arch-based Linux (Arch, EndeavourOS, CachyOS, Garuda...)."
        read -rp "  Van muon tiep tuc? (co/khong): " ans
        [[ "$ans" =~ ^([Cc][Oo]|[Yy])$ ]] || exit 1
    fi
}

# Xin quyền sudo 1 LẦN DUY NHẤT ở đầu script, cache lại (mặc định ~15
# phút theo cấu hình sudoers) — tránh bug hỏi mật khẩu 2 lần: 1 lần khi
# cài jq/fzf ở đây, 1 lần nữa khi component con tự gọi sudo pacman.
prefetch_sudo() {
    if command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        log_info "Kiem tra quyen sudo (chi hoi mat khau 1 lan cho ca qua trinh cai)..."
        if ! sudo -v; then
            log_error "Khong lay duoc quyen sudo."
            exit 1
        fi
    fi
}

# Cài 1 package qua pacman nếu máy chưa có — dùng chung cho jq, fzf, và
# bất kỳ dependency nào installer cần sau này (thay vì lặp ensure_jq(),
# ensure_fzf() riêng từng cái).
ensure_package() {
    local pkg="$1" reason="$2"
    if command -v "$pkg" >/dev/null 2>&1; then
        return 0
    fi
    log_warn "Can '$pkg' ($reason), dang cai..."
    if ! sudo pacman -S --needed "$pkg"; then
        log_error "Khong the cai $pkg."
        exit 1
    fi
}

# ============================ CÀI 1 COMPONENT ============================

INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()

install_component() {
    local name="$1"
    local comp_path
    comp_path=$(jq -r --arg n "$name" '.[] | select(.name==$n) | .path' "$MANIFEST" 2>/dev/null) || comp_path=""

    if [ -z "$comp_path" ]; then
        log_error "Khong tim thay component '$name' trong manifest.json"
        FAILED_COMPONENTS+=("$name")
        return 1
    fi

    local install_script="$SCRIPT_DIR/$comp_path/install.sh"
    if [ ! -f "$install_script" ]; then
        log_error "Thieu file cai dat: $install_script"
        FAILED_COMPONENTS+=("$name")
        return 1
    fi

    # Truyền COMPONENT_DIR để script con biết mình đang ở đâu (lấy file kèm theo)
    if COMPONENT_DIR="$SCRIPT_DIR/$comp_path" bash "$install_script"; then
        log_success "$name da cai xong"
        INSTALLED_COMPONENTS+=("$name")
    else
        local status=$?
        log_error "$name that bai (ma loi $status)"
        FAILED_COMPONENTS+=("$name")
        return 1
    fi
}

# ============================ MENU CHỌN COMPONENT ============================

select_components_interactive() {
    jq -r '.[] | "\(.name)  -  \(.description)"' "$MANIFEST" | \
        fzf --multi --height=100% --border=rounded --layout=reverse \
            --border-label=" My-caelestia " \
            --color="$FZF_THEME" --pointer="▶" --marker="✓" \
            --prompt="❯ Chon component: " \
            --header="TAB chon nhieu    ↵ xac nhan    Esc huy" | \
        awk -F'  -  ' '{print $1}'
}

# ============================ CHẠY CHƯƠNG TRÌNH ============================

main() {
    print_banner
    print_environment
    check_arch
    prefetch_sudo
    ensure_package jq "doc manifest.json"

    if [ ! -f "$MANIFEST" ]; then
        log_error "Khong tim thay manifest.json tai: $MANIFEST"
        exit 1
    fi

    print_manifest_preview

    local targets=()

    if [ "${1:-}" = "--all" ]; then
        mapfile -t targets < <(jq -r '.[].name' "$MANIFEST")
    elif [ -n "${1:-}" ]; then
        targets=("$1")
    else
        ensure_package fzf "hien thi menu chon"
        mapfile -t targets < <(select_components_interactive)
    fi

    if [ "${#targets[@]}" -eq 0 ]; then
        log_info "Khong co component nao duoc chon. Thoat."
        exit 0
    fi

    local start_time idx=0 total="${#targets[@]}"
    start_time=$(date +%s)

    for name in "${targets[@]}"; do
        [ -z "$name" ] && continue
        idx=$((idx + 1))
        echo
        printf "  %s[%d/%d] %s%s\n" "$C_BOLD$C_CYAN" "$idx" "$total" "$name" "$C_RESET"
        hr
        install_component "$name" || true
    done

    local elapsed
    elapsed=$(( $(date +%s) - start_time ))

    echo
    hr
    echo "  Installation Summary"
    for name in "${INSTALLED_COMPONENTS[@]:-}"; do
        [ -z "$name" ] && continue
        printf "    %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$name"
    done
    for name in "${FAILED_COMPONENTS[@]:-}"; do
        [ -z "$name" ] && continue
        printf "    %s✗%s %s\n" "$C_RED" "$C_RESET" "$name"
    done
    hr
    printf "  Installed: %s\n" "${#INSTALLED_COMPONENTS[@]}"
    printf "  Failed:    %s\n" "${#FAILED_COMPONENTS[@]}"
    printf "  Time:      %s\n" "$(format_elapsed "$elapsed")"
    echo

    if [ "${#FAILED_COMPONENTS[@]}" -eq 0 ]; then
        echo "  My-caelestia installed successfully."
        echo "  Mo terminal moi (hoac source lai file cau hinh shell) de PATH cap nhat."
    else
        echo "  Cai dat hoan tat mot phan — kiem tra log o tren de biet nguyen nhan."
    fi
    hr

    [ "${#FAILED_COMPONENTS[@]}" -eq 0 ]
}

main "$@"
