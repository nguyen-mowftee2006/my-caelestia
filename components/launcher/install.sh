#!/usr/bin/env bash
#
# components/launcher/install.sh — Cài đặt Quick Launcher
# (Bản fix cho Arch Linux + Hyprland, thay cho apt/gsettings gốc)
#
# Biến COMPONENT_DIR được install.sh (script tổng) truyền vào, trỏ tới
# thư mục components/launcher — nếu chạy lẻ script này thì tự suy ra.
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

echo "== 4. Gán phím tắt trong Hyprland =="
if ! command -v hyprctl >/dev/null 2>&1; then
    echo "Không phát hiện Hyprland (thiếu hyprctl) — bỏ qua bước gán phím tắt."
    echo "Bạn có thể tự gọi lệnh 'launcher' trong terminal bất kỳ."
else
    # Tìm terminal emulator có sẵn trên máy
    TERMINALS=(kitty alacritty foot wezterm konsole)
    TERM_BIN=""
    for t in "${TERMINALS[@]}"; do
        if command -v "$t" >/dev/null 2>&1; then
            TERM_BIN="$t"
            break
        fi
    done

    if [ -z "$TERM_BIN" ]; then
        read -rp "Không tự nhận diện được terminal, nhập tên lệnh terminal bạn dùng: " TERM_BIN
    fi

    read -rp "Nhập tổ hợp phím muốn gán (mặc định 'SUPER, W'): " KEY_COMBO
    KEY_COMBO="${KEY_COMBO:-SUPER, W}"

    HYPR_DIR="$HOME/.config/hypr/conf"
    KEYBIND_FILE="$HYPR_DIR/launcher_keybind.conf"
    mkdir -p "$HYPR_DIR"

    case "$TERM_BIN" in
        kitty)      EXEC_CMD="kitty --class launcher -e $HOME/.local/bin/launcher" ;;
        alacritty)  EXEC_CMD="alacritty --class launcher -e $HOME/.local/bin/launcher" ;;
        foot)       EXEC_CMD="foot -a launcher $HOME/.local/bin/launcher" ;;
        wezterm)    EXEC_CMD="wezterm start -- $HOME/.local/bin/launcher" ;;
        konsole)    EXEC_CMD="konsole -e $HOME/.local/bin/launcher" ;;
        *)          EXEC_CMD="$TERM_BIN -e $HOME/.local/bin/launcher" ;;
    esac

    if {
        echo "# File này do My-caelestia (component launcher) tự sinh ra"
        echo "bind = $KEY_COMBO, exec, $EXEC_CMD"
    } > "$KEYBIND_FILE"; then
        echo "Đã ghi keybind vào: $KEYBIND_FILE"
    else
        echo "Lỗi: không ghi được file keybind $KEYBIND_FILE — bỏ qua bước gán phím tắt."
        KEYBIND_FILE=""
    fi

    HYPR_MAIN="$HOME/.config/hypr/hyprland.conf"
    if [ -n "$KEYBIND_FILE" ] && [ -f "$HYPR_MAIN" ] && ! grep -q "launcher_keybind.conf" "$HYPR_MAIN"; then
        echo "Lưu ý: cần thêm dòng sau vào $HYPR_MAIN (1 lần duy nhất):"
        echo "  source = $KEYBIND_FILE"
        read -rp "Tự động thêm dòng này vào hyprland.conf luôn không? (co/khong): " ans
        if [[ "$ans" =~ ^([Cc][Oo]|[Yy])$ ]]; then
            if echo "source = $KEYBIND_FILE" >> "$HYPR_MAIN"; then
                echo "Đã thêm."
            else
                echo "Lỗi: không ghi được vào $HYPR_MAIN. Bạn cần tự thêm dòng trên."
            fi
        fi
    fi

    hyprctl reload >/dev/null 2>&1 || true
fi

echo
echo "============================================"
echo " Cài Quick Launcher xong."
echo " Gọi trực tiếp bằng lệnh: launcher"
if command -v hyprctl >/dev/null 2>&1; then
    echo " Hoặc dùng phím tắt: ${KEY_COMBO:-SUPER, W}"
fi
echo "============================================"
