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
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"

# ============================ KIỂM TRA MÔI TRƯỜNG ============================

check_arch() {
    if ! command -v pacman >/dev/null 2>&1; then
        echo "Cảnh báo: không tìm thấy 'pacman'. My-caelestia được viết cho Arch Linux."
        read -rp "Vẫn muốn tiếp tục? (co/khong): " ans
        [[ "$ans" =~ ^([Cc][Oo]|[Yy])$ ]] || exit 1
    fi
}

# jq cần thiết để đọc manifest.json -> tự cài nếu thiếu
ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Cần 'jq' để đọc manifest, đang cài..."
        if ! sudo pacman -S --needed jq; then
            echo "Lỗi: cài jq thất bại. Không thể đọc manifest.json, dừng lại."
            exit 1
        fi
    fi
}

# fzf dùng cho menu chọn component -> tự cài nếu thiếu
ensure_fzf() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Cần 'fzf' để hiện menu chọn, đang cài..."
        if ! sudo pacman -S --needed fzf; then
            echo "Lỗi: cài fzf thất bại. Không thể hiện menu chọn, dừng lại."
            exit 1
        fi
    fi
}

# ============================ CÀI 1 COMPONENT ============================

# Danh sách component thất bại, dùng để tổng kết cuối script
FAILED_COMPONENTS=()

install_component() {
    local name="$1"
    local comp_path
    comp_path=$(jq -r --arg n "$name" '.[] | select(.name==$n) | .path' "$MANIFEST")

    if [ -z "$comp_path" ]; then
        echo "Không tìm thấy component '$name' trong manifest.json"
        FAILED_COMPONENTS+=("$name (không có trong manifest)")
        return 1
    fi

    local install_script="$SCRIPT_DIR/$comp_path/install.sh"
    if [ ! -f "$install_script" ]; then
        echo "Thiếu file cài đặt: $install_script"
        FAILED_COMPONENTS+=("$name (thiếu install.sh)")
        return 1
    fi

    echo
    echo "===== Đang cài: $name ====="
    # Truyền COMPONENT_DIR để script con biết mình đang ở đâu (lấy file kèm theo)
    if COMPONENT_DIR="$SCRIPT_DIR/$comp_path" bash "$install_script"; then
        echo "===== Xong: $name ====="
    else
        echo "===== THẤT BẠI: $name (mã lỗi $?) ====="
        FAILED_COMPONENTS+=("$name")
        return 1
    fi
}

# ============================ MENU CHỌN COMPONENT ============================

select_components_interactive() {
    jq -r '.[] | "\(.name)  -  \(.description)"' "$MANIFEST" | \
        fzf --multi --height=100% --border=rounded --layout=reverse \
            --prompt="My-caelestia install > " \
            --header="TAB: chon nhieu | Enter: xac nhan | ESC: huy" | \
        awk -F'  -  ' '{print $1}'
}

# ============================ CHẠY CHƯƠNG TRÌNH ============================

main() {
    check_arch
    ensure_jq

    if [ ! -f "$MANIFEST" ]; then
        echo "Không tìm thấy manifest.json tại: $MANIFEST"
        exit 1
    fi

    local targets=()

    if [ "${1:-}" = "--all" ]; then
        mapfile -t targets < <(jq -r '.[].name' "$MANIFEST")
    elif [ -n "${1:-}" ]; then
        targets=("$1")
    else
        ensure_fzf
        mapfile -t targets < <(select_components_interactive)
    fi

    if [ "${#targets[@]}" -eq 0 ]; then
        echo "Không có component nào được chọn. Thoát."
        exit 0
    fi

    for name in "${targets[@]}"; do
        [ -z "$name" ] && continue
        install_component "$name"
    done

    echo
    echo "============================================"
    if [ "${#FAILED_COMPONENTS[@]}" -eq 0 ]; then
        echo " Hoàn tất cài đặt My-caelestia."
        echo " Mở terminal mới (hoặc 'source ~/.bashrc') để PATH cập nhật."
    else
        echo " Cài đặt HOÀN TẤT MỘT PHẦN — có component bị lỗi:"
        for f in "${FAILED_COMPONENTS[@]}"; do
            echo "   - $f"
        done
        echo " Kiểm tra lại log ở trên để biết nguyên nhân."
    fi
    echo "============================================"

    [ "${#FAILED_COMPONENTS[@]}" -eq 0 ]
}

main "$@"
