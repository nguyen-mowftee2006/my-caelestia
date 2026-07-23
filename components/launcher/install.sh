#!/usr/bin/env bash
#
# components/launcher/install.sh — Cài đặt Quick Launcher
# (Bản fix cho Arch Linux + Hyprland, thay cho apt/gsettings gốc)
#
# Biến COMPONENT_DIR được install.sh (script tổng) truyền vào, trỏ tới
# thư mục components/launcher — nếu chạy lẻ script này thì tự suy ra.
#
# LƯU Ý: bản này KHÔNG tự gán phím tắt Hyprland nữa. Tự bind phím theo
# hướng dẫn ở components/launcher/KEYBIND.md sau khi cài xong.
#
set -uo pipefail

COMPONENT_DIR="${COMPONENT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

echo "== 1. Cài fzf (nếu chưa có) =="
if ! command -v fzf >/dev/null 2>&1; then
    if ! sudo pacman -S --needed fzf; then
        echo "Lỗi: cài fzf thất bại. Dừng cài đặt launcher."
        exit 1
    fi
else
    echo "fzf đã có sẵn, bỏ qua."
fi

echo "== 2. Tạo thư mục cần thiết =="
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config/quicklauncher"
touch "$HOME/.config/quicklauncher/items.tsv"

echo "== 3. Cài file launcher.sh vào ~/.local/bin =="
if [ ! -f "$COMPONENT_DIR/launcher.sh" ]; then
    echo "Lỗi: không tìm thấy $COMPONENT_DIR/launcher.sh"
    exit 1
fi
if ! cp "$COMPONENT_DIR/launcher.sh" "$HOME/.local/bin/launcher"; then
    echo "Lỗi: copy launcher.sh vào ~/.local/bin thất bại. Dừng cài đặt."
    exit 1
fi
if ! chmod +x "$HOME/.local/bin/launcher"; then
    echo "Lỗi: không gán được quyền thực thi cho ~/.local/bin/launcher."
    exit 1
fi
echo "Đã tạo: $HOME/.local/bin/launcher"

# Nhắc thêm ~/.local/bin vào PATH nếu chưa có.
# Kiểm tra riêng cho shell fish vì cú pháp/file cấu hình khác hẳn
# bash/zsh — "export PATH=..." không có tác dụng gì với fish, và fish
# không đọc ~/.bashrc/~/.zshrc.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
        echo "Lưu ý: ~/.local/bin chưa nằm trong PATH."
        if [ -n "${FISH_VERSION:-}" ] || [[ "${SHELL:-}" == *fish ]]; then
            echo "Bạn đang dùng fish shell. Chạy lệnh sau để sửa ngay (tự lưu vĩnh viễn):"
            echo "  fish_add_path \$HOME/.local/bin"
        else
            echo "Thêm dòng sau vào ~/.bashrc hoặc ~/.zshrc:"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        ;;
esac

echo
echo "============================================"
echo " Cài Quick Launcher xong."
echo " Gọi trực tiếp bằng lệnh: launcher"
echo " Muốn gán phím tắt trong Hyprland: xem"
echo " components/launcher/KEYBIND.md"
echo "============================================"
