#!/usr/bin/env bash
# Quick Launcher — chọn app/web từ terminal, hỗ trợ thêm mới
# (phần lõi giữ nguyên logic gốc, chỉ dọn lại cho Wayland/Hyprland)
#
# Bản này thêm trang trí giao diện fzf (icon, màu sắc, border/header đẹp
# hơn) — KHÔNG đổi định dạng dữ liệu (items.tsv vẫn 3 cột như cũ) và
# KHÔNG đổi logic xử lý an toàn (xóa dòng bằng awk khớp chính xác, quoting
# URL, xử lý root/log) so với bản trước.
set -uo pipefail

CONFIG_DIR="$HOME/.config/quicklauncher"
CONFIG_FILE="$CONFIG_DIR/items.tsv"   # format: Ten<TAB>can_root(0/1)<TAB>Lenh
LOG_FILE="$CONFIG_DIR/launch.log"
mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

ADD_NEW="+ Thêm mục mới..."
DELETE_ENTRY="- Xóa mục..."

# ------------------------------------------------------------------
# Màu sắc dùng chung cho cả list, preview và các thông báo tương tác.
# Icon: 🌐 website | 💻 app thường | 🔐 app cần quyền root
# ------------------------------------------------------------------
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

# Trả về icon có màu tương ứng với 1 mục, dựa vào lệnh + cờ root — không
# cần thêm cột mới vào items.tsv, suy ra trực tiếp từ dữ liệu hiện có.
badge_for() {
    local cmd="$1" root_flag="$2"
    case "$cmd" in
        "xdg-open "*) printf '%s🌐%s' "$C_CYAN" "$C_RESET" ;;
        *)
            if [ "$root_flag" = "1" ]; then
                printf '%s🔐%s' "$C_YELLOW" "$C_RESET"
            else
                printf '%s💻%s' "$C_GREEN" "$C_RESET"
            fi
            ;;
    esac
}

# In danh sách mục hiện có dưới dạng "hiển thị(có màu)<TAB>tên gốc".
# Cột 2 (tên gốc, không màu) dùng để fzf trả về qua {2} — mọi so khớp/
# tra cứu trong script vẫn làm việc trên chuỗi thuần, KHÔNG đụng vào
# chuỗi có mã màu ANSI.
build_item_rows() {
    while IFS=$'\t' read -r name root cmd; do
        [ -z "$name" ] && continue
        printf '%s %s\t%s\n' "$(badge_for "$cmd" "$root")" "$name" "$name"
    done < "$CONFIG_FILE"
}

# ------------------------------------------------------------------
# Chế độ ẩn: được chính fzf gọi lại để lấy nội dung preview cho 1 mục.
# Tách riêng thành 1 nhánh gọi lại chính script (thay vì nhúng awk thẳng
# vào chuỗi --preview) để KHÔNG có rủi ro command injection nếu tên mục
# chứa ký tự đặc biệt (`, $(), "...) — {2} trong --preview chỉ được
# truyền vào đây như 1 tham số dòng lệnh bình thường ($2), không phải
# đoạn shell được thực thi trực tiếp.
# ------------------------------------------------------------------
if [ "${1:-}" = "--preview-entry" ]; then
    name="${2:-}"
    case "$name" in
        "$ADD_NEW")
            printf '%s%s➕ Thêm 1 shortcut mới%s\n\n%sChọn loại app hoặc website, rồi nhập lệnh/URL.%s\n' \
                "$C_BOLD" "$C_GREEN" "$C_RESET" "$C_GRAY" "$C_RESET"
            ;;
        "$DELETE_ENTRY")
            printf '%s%s🗑️  Xóa 1 mục khỏi danh sách%s\n\n%sSẽ hỏi xác nhận trước khi xóa thật.%s\n' \
                "$C_BOLD" "$C_RED" "$C_RESET" "$C_GRAY" "$C_RESET"
            ;;
        *)
            awk -F'\t' -v n="$name" -v cbl="$C_BLUE" -v cb="$C_BOLD" -v cr="$C_RESET" \
                -v cg="$C_GREEN" -v cy="$C_YELLOW" '
                $1 == n {
                    root_txt = ($2 == 1) ? cy "Co (chay bang sudo)" cr : cg "Khong" cr
                    printf "%sLenh:%s\n  %s\n\n%sCan quyen root:%s %s\n", cbl, cr, $3, cb, cr, root_txt
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
    printf '%s❌ Cần cài fzf trước: sudo pacman -S fzf%s\n' "$C_RED" "$C_RESET"
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
        printf '%s❌ Lỗi khi xử lý file dữ liệu, hủy thao tác để tránh mất dữ liệu.%s\n' "$C_RED" "$C_RESET"
        rm -f "$tmp"
        return 1
    fi
    return 0
}

while true; do
    choice_line=$(
        {
            build_item_rows
            printf '%s%s➕%s %s\t%s\n' "$C_BOLD" "$C_GREEN" "$C_RESET" "$ADD_NEW" "$ADD_NEW"
            # Chỉ hiện lựa chọn xóa khi đã có ít nhất 1 mục trong danh sách,
            # tránh hiện "Xóa mục..." khi chưa có gì để xóa.
            if [ -s "$CONFIG_FILE" ]; then
                printf '%s%s🗑️ %s %s\t%s\n' "$C_BOLD" "$C_RED" "$C_RESET" "$DELETE_ENTRY" "$DELETE_ENTRY"
            fi
        } | fzf --ansi --delimiter=$'\t' --with-nth=1 \
                --prompt="❯ Chọn app/web: " --height=100% --border=rounded \
                --border-label=" 🚀 Quick Launcher " \
                --header="↵ Mở/Chọn    Esc Thoát" \
                --color="$FZF_THEME" --pointer="▶" --marker="✓" \
                --preview="\"$0\" --preview-entry {2}" \
                --preview-window="right:50%:wrap"
    ) || exit 0

    [ -z "${choice_line:-}" ] && exit 0
    choice=$(printf '%s' "$choice_line" | cut -f2)
    [ -z "${choice:-}" ] && exit 0

    if [ "$choice" = "$ADD_NEW" ]; then
        read -rp "$(printf '%s➕ Tên hiển thị:%s ' "$C_GREEN" "$C_RESET")" name
        [ -z "$name" ] && { printf '%s⚠️  Tên không được để trống.%s\n' "$C_YELLOW" "$C_RESET"; sleep 1; continue; }

        read -rp "$(printf '%sLoại (a = app, w = website):%s ' "$C_BLUE" "$C_RESET")" kind_raw
        kind=$(echo "$kind_raw" | tr '[:upper:]' '[:lower:]' | xargs)
        kind="${kind:0:1}"

        if [ "$kind" = "w" ]; then
            read -rp "$(printf '%sURL (vd: https://mail.google.com):%s ' "$C_BLUE" "$C_RESET")" target
            [ -z "$target" ] && { printf '%s⚠️  URL không được để trống.%s\n' "$C_YELLOW" "$C_RESET"; sleep 1; continue; }
            if [[ "$target" != http://* && "$target" != https://* ]]; then
                target="https://$target"
            fi
            cmd="xdg-open '$target'"
            root_flag=0
        else
            read -rp "$(printf '%sLệnh chạy app (vd: gimp, code, gnome-calculator):%s ' "$C_BLUE" "$C_RESET")" target
            [ -z "$target" ] && { printf '%s⚠️  Lệnh không được để trống.%s\n' "$C_YELLOW" "$C_RESET"; sleep 1; continue; }

            # Chỉ CẢNH BÁO, không chặn lưu — lệnh có thể là alias/function
            # riêng của shell người dùng nên "command -v" không phát hiện
            # được hết mọi trường hợp hợp lệ.
            first_word=$(awk '{print $1}' <<< "$target")
            if ! command -v "$first_word" >/dev/null 2>&1; then
                printf '%s⚠️  Cảnh báo: không tìm thấy lệnh "%s" trong PATH hiện tại.%s\n' "$C_YELLOW" "$first_word" "$C_RESET"
                echo "Vẫn có thể lưu — nhưng lệnh có thể lỗi lúc chạy nếu app chưa cài."
            fi

            cmd="$target"
            read -rp "$(printf '%sLệnh này có cần sudo/quyền root không? (y/n):%s ' "$C_BLUE" "$C_RESET")" needroot
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
        printf '%s✅ Đã thêm: %s (loại: %s)%s\n' "$C_GREEN" "$name" "$([ "$kind" = "w" ] && echo web || echo app)" "$C_RESET"
        sleep 1
        continue
    fi

    if [ "$choice" = "$DELETE_ENTRY" ]; then
        target_line=$(build_item_rows | fzf --ansi --delimiter=$'\t' --with-nth=1 \
            --prompt="🗑️  Chọn mục cần xóa: " --height=100% --border=rounded \
            --border-label=" Xóa mục " --header="↵ Chọn    Esc Hủy" \
            --color="$FZF_THEME" --pointer="▶" \
            --preview="\"$0\" --preview-entry {2}" \
            --preview-window="right:50%:wrap")
        target_name=$(printf '%s' "$target_line" | cut -f2)
        [ -z "${target_name:-}" ] && continue

        read -rp "$(printf '%s⚠️  Xóa "%s" khỏi danh sách? (co/khong):%s ' "$C_YELLOW" "$target_name" "$C_RESET")" confirm_ans
        if [[ "$confirm_ans" =~ ^([Cc][Oo]|[Yy])$ ]]; then
            if remove_entry_by_name "$target_name"; then
                printf '%s✅ Đã xóa: %s%s\n' "$C_GREEN" "$target_name" "$C_RESET"
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
        printf '%s🔐 Cần quyền root, nhập password:%s\n' "$C_YELLOW" "$C_RESET"
        if [[ "$cmd" != sudo* ]]; then
            sudo bash -c "$cmd"
        else
            bash -c "$cmd"
        fi
        status=$?
        if [ "$status" -ne 0 ]; then
            printf '%s❌ Lệnh kết thúc với lỗi (mã %s).%s\n' "$C_RED" "$status" "$C_RESET"
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
            printf '%s⚠️  Có thể lệnh vừa chạy đã lỗi, xem chi tiết tại: %s%s\n' "$C_YELLOW" "$LOG_FILE" "$C_RESET"
            echo "$new_lines"
            read -rp "Nhấn Enter để đóng..." _
        fi
    fi
    exit 0
done
