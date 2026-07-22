#!/usr/bin/env bash
# Quick Launcher — chọn app/web từ terminal, hỗ trợ thêm mới
# (phần lõi giữ nguyên logic gốc, chỉ dọn lại cho Wayland/Hyprland)
set -uo pipefail

CONFIG_DIR="$HOME/.config/quicklauncher"
CONFIG_FILE="$CONFIG_DIR/items.tsv"   # format: Ten<TAB>can_root(0/1)<TAB>Lenh
LOG_FILE="$CONFIG_DIR/launch.log"
mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

ADD_NEW="+ Thêm mục mới..."
DELETE_ENTRY="- Xóa mục..."

# ------------------------------------------------------------------
# Chế độ ẩn: được chính fzf gọi lại để lấy nội dung preview cho 1 mục.
# Tách riêng thành 1 nhánh gọi lại chính script (thay vì nhúng awk thẳng
# vào chuỗi --preview) để KHÔNG có rủi ro command injection nếu tên mục
# chứa ký tự đặc biệt (`, $(), "...) — {} trong --preview chỉ được truyền
# vào đây như 1 tham số dòng lệnh bình thường ($2), không phải đoạn shell
# được thực thi trực tiếp.
# ------------------------------------------------------------------
if [ "${1:-}" = "--preview-entry" ]; then
    name="${2:-}"
    case "$name" in
        "$ADD_NEW")
            echo "Thêm 1 shortcut mới (app hoặc website)."
            ;;
        "$DELETE_ENTRY")
            echo "Chọn 1 mục có sẵn để xóa khỏi danh sách."
            ;;
        *)
            awk -F'\t' -v n="$name" '
                $1 == n {
                    root = ($2 == 1) ? "Co (chay bang sudo)" : "Khong"
                    printf "Lenh:\n  %s\n\nCan quyen root: %s\n", $3, root
                    found = 1
                }
                END { if (!found) print "(khong tim thay du lieu cho muc nay)" }
            ' "$CONFIG_FILE"
            ;;
    esac
    exit 0
fi

# --- Đảm bảo terminal con (mở từ phím tắt) có đủ biến môi trường session ---
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
# WAYLAND_DISPLAY và DISPLAY thường đã có sẵn trong session Hyprland,
# chỉ đặt giá trị dự phòng nếu vì lý do gì đó bị thiếu.
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

if ! command -v fzf >/dev/null 2>&1; then
    echo "Cần cài fzf trước: sudo pacman -S fzf"
    read -rp "Nhấn Enter để thoát..." _
    exit 1
fi

# Xóa 1 dòng có tên (cột 1) TRÙNG CHÍNH XÁC với $1 khỏi CONFIG_FILE.
# Dùng awk so khớp field 1 theo giá trị chuỗi thuần (không phải regex),
# KHÔNG dùng grep -P (bug cũ: tên chứa ký tự regex như ( ) . * + ? có thể
# làm grep lỗi cú pháp, output rỗng, ghi đè mất sạch dữ liệu) và cũng
# KHÔNG dùng grep -F thô (bug khác: grep -F so khớp substring bất kỳ đâu
# trong dòng, không neo đầu dòng — vd tên "0" có thể vô tình khớp vào cột
# root_flag của các dòng khác và xóa nhầm). awk -F'\t' -v so sánh đúng
# TOÀN BỘ nội dung cột 1, không phải regex, không phải substring — an
# toàn tuyệt đối với mọi ký tự người dùng gõ.
remove_entry_by_name() {
    local name="$1"
    local tmp
    tmp="$(mktemp "${CONFIG_FILE}.XXXXXX")" || return 1

    if awk -F'\t' -v n="$name" '$1 != n' "$CONFIG_FILE" > "$tmp"; then
        mv "$tmp" "$CONFIG_FILE"
    else
        echo "Lỗi khi xử lý file dữ liệu, hủy thao tác để tránh mất dữ liệu."
        rm -f "$tmp"
        return 1
    fi
    return 0
}

while true; do
    choice=$(
        {
            cut -f1 "$CONFIG_FILE"
            echo "$ADD_NEW"
            # Chỉ hiện lựa chọn xóa khi đã có ít nhất 1 mục trong danh sách,
            # tránh hiện "Xóa mục..." khi chưa có gì để xóa.
            if [ -s "$CONFIG_FILE" ]; then
                echo "$DELETE_ENTRY"
            fi
        } | fzf --prompt="Chọn app/web > " --height=100% --border \
                --header="Enter: mở | Esc: thoát" \
                --preview="\"$0\" --preview-entry {}" \
                --preview-window="right:50%:wrap"
    ) || exit 0

    [ -z "${choice:-}" ] && exit 0

    if [ "$choice" = "$ADD_NEW" ]; then
        read -rp "Tên hiển thị: " name
        [ -z "$name" ] && { echo "Tên không được để trống."; sleep 1; continue; }

        read -rp "Loại (a = app, w = website): " kind_raw
        kind=$(echo "$kind_raw" | tr '[:upper:]' '[:lower:]' | xargs)
        kind="${kind:0:1}"

        if [ "$kind" = "w" ]; then
            read -rp "URL (vd: https://mail.google.com): " target
            [ -z "$target" ] && { echo "URL không được để trống."; sleep 1; continue; }
            if [[ "$target" != http://* && "$target" != https://* ]]; then
                target="https://$target"
            fi
            cmd="xdg-open '$target'"
            root_flag=0
        else
            read -rp "Lệnh chạy app (vd: gimp, code, gnome-calculator): " target
            [ -z "$target" ] && { echo "Lệnh không được để trống."; sleep 1; continue; }

            # Chỉ CẢNH BÁO, không chặn lưu — lệnh có thể là alias/function
            # riêng của shell người dùng nên "command -v" không phát hiện
            # được hết mọi trường hợp hợp lệ.
            first_word=$(awk '{print $1}' <<< "$target")
            if ! command -v "$first_word" >/dev/null 2>&1; then
                echo "Cảnh báo: không tìm thấy lệnh '$first_word' trong PATH hiện tại."
                echo "Vẫn có thể lưu — nhưng lệnh có thể lỗi lúc chạy nếu app chưa cài."
            fi

            cmd="$target"
            read -rp "Lệnh này có cần sudo/quyền root không? (y/n): " needroot
            if [ "$needroot" = "y" ]; then
                root_flag=1
            else
                root_flag=0
            fi
        fi

        if ! remove_entry_by_name "$name"; then
            sleep 1.5
            continue
        fi
        printf '%s\t%s\t%s\n' "$name" "$root_flag" "$cmd" >> "$CONFIG_FILE"
        echo "Đã thêm: $name (loại: $([ "$kind" = "w" ] && echo web || echo app))"
        sleep 1
        continue
    fi

    if [ "$choice" = "$DELETE_ENTRY" ]; then
        target_name=$(cut -f1 "$CONFIG_FILE" | fzf --prompt="Chọn mục cần xóa > " \
            --height=100% --border --header="Enter: chọn | Esc: hủy" \
            --preview="\"$0\" --preview-entry {}" \
            --preview-window="right:50%:wrap")
        [ -z "${target_name:-}" ] && continue

        read -rp "Xóa '$target_name' khỏi danh sách? (co/khong): " confirm_ans
        if [[ "$confirm_ans" =~ ^([Cc][Oo]|[Yy])$ ]]; then
            if remove_entry_by_name "$target_name"; then
                echo "Đã xóa: $target_name"
            fi
            sleep 1
        else
            echo "Đã hủy, không xóa gì."
            sleep 1
        fi
        continue
    fi

    root_flag=$(awk -F'\t' -v n="$choice" '$1==n{print $2; exit}' "$CONFIG_FILE")
    cmd=$(awk -F'\t' -v n="$choice" '$1==n{print $3; exit}' "$CONFIG_FILE")
    [ -z "$cmd" ] && exit 0

    if [ "$root_flag" = "1" ]; then
        echo "Cần quyền root, nhập password:"
        if [[ "$cmd" != sudo* ]]; then
            sudo bash -c "$cmd"
        else
            bash -c "$cmd"
        fi
        status=$?
        if [ "$status" -ne 0 ]; then
            echo "Lệnh kết thúc với lỗi (mã $status)."
            read -rp "Nhấn Enter để đóng..." _
        fi
    else
        log_size_before=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
        nohup setsid bash -c "$cmd" >>"$LOG_FILE" 2>&1 &
        disown
        sleep 1.5
        # Nếu ngay sau khi chạy đã có dòng log mới trông giống lỗi
        # (lệnh sai / app chưa cài), báo cho người dùng biết trước khi
        # cửa sổ đóng lại, thay vì im lặng thoát và chỉ ghi vào launch.log.
        new_lines=$(tail -n +"$((log_size_before + 1))" "$LOG_FILE" 2>/dev/null)
        if [ -n "$new_lines" ] && echo "$new_lines" | grep -qiE "not found|no such file|command not found|permission denied"; then
            echo "Có thể lệnh vừa chạy đã lỗi, xem chi tiết tại: $LOG_FILE"
            echo "$new_lines"
            read -rp "Nhấn Enter để đóng..." _
        fi
    fi
    exit 0
done
