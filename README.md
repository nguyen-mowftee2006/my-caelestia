# My-caelestia

> Bộ công cụ terminal cá nhân cho **Arch Linux + Hyprland (Calestia)**.
> Một script tổng (`install.sh`) đóng vai trò như "package manager" riêng,
> cài đặt các script con (gọi là **component**) được lưu trong repo này.

**📚 Tài liệu liên quan:** [`CHANGELOG.md`](./CHANGELOG.md) — lịch sử thay đổi theo version.

---

## 🎯 Mục đích dự án

- Gom mọi script cá nhân vào **một repo duy nhất**, cài nhanh trên máy mới
  chỉ bằng `git clone` + `bash install.sh`
- Mỗi component tự quản lý dữ liệu, phím tắt, dependency của riêng nó,
  sửa/thêm tính năng cho component nào thì đụng trực tiếp file của
  component đó
- Ưu tiên **đơn giản, ít rủi ro** hơn là gọn code — chấp nhận có phần
  logic lặp lại giữa các component, miễn không phát sinh bug

---

## 📁 Cấu trúc thư mục

```
my-caelestia/
├── install.sh            # Script tổng — hiện menu chọn component để cài
├── manifest.json          # Danh sách component đang có
├── README.md               # File này
├── CHANGELOG.md             # Lịch sử thay đổi, theo version
└── components/
    ├── launcher/
    │   ├── install.sh         # Cài đặt launcher
    │   └── launcher.sh        # TUI chọn app/web
    └── quickedit/
        ├── install.sh         # Cài đặt quickedit
        └── quickedit.sh       # TUI mở nhanh file để sửa
```

Trên máy sau khi cài:
```
~/.local/bin/launcher
~/.local/bin/quickedit
```

---

## 🚀 Cài đặt

```bash
git clone https://github.com/nguyen-mowftee2006/my-caelestia
cd my-caelestia
bash install.sh
```

Script tổng: kiểm tra Arch Linux → tự cài `jq`/`fzf` nếu thiếu → hiện menu
chọn component (`TAB` để chọn nhiều). Component nào lỗi khi cài sẽ được
báo rõ và liệt kê ở bảng tổng kết cuối, không làm dừng các component khác.

| Lệnh                        | Ý nghĩa                                    |
|------------------------------|---------------------------------------------|
| `bash install.sh`           | Hiện menu chọn component cần cài            |
| `bash install.sh launcher`  | Cài thẳng 1 component cụ thể, bỏ qua menu   |
| `bash install.sh --all`     | Cài tất cả component có trong manifest      |

**Lưu ý cho người dùng shell `fish`:** sau khi cài, nếu `~/.local/bin`
chưa có trong `PATH`, chạy thêm:
```bash
fish_add_path ~/.local/bin
```
(người dùng `bash`/`zsh` làm theo hướng dẫn script tự in ra lúc cài)

---

## 🧩 Danh sách component

### 1. `launcher` — Chọn nhanh app/website

TUI `fzf`, thêm/xóa shortcut app hoặc web, chọn là chạy ngay; phân biệt
lệnh cần `sudo` hay không.

- Cài lệnh `launcher` vào `~/.local/bin/`; lúc cài hỏi phím tắt, tự ghi
  vào `~/.config/hypr/conf/launcher_keybind.conf` rồi `hyprctl reload`
- Dữ liệu: `~/.config/quicklauncher/items.tsv`
  (`Tên<TAB>cần_root(0/1)<TAB>Lệnh`)
- Phím tắt mở **terminal mới** rồi chạy `launcher` bên trong; lệnh không
  cần root mà lỗi ngay sẽ báo lỗi tại chỗ, chi tiết ở
  `~/.config/quicklauncher/launch.log`
- Không autostart — chỉ chạy khi gọi chủ động

### 2. `quickedit` — Mở nhanh file để sửa

TUI `fzf`, lưu **tiêu đề → đường dẫn file**, chọn là mở thẳng bằng trình
soạn thảo (vd: đặt tiêu đề `configkey` trỏ tới
`~/.config/hypr/conf/keybinds.conf`, lần sau chọn `configkey` là vào sửa
ngay, không cần gõ đường dẫn).

- Cài lệnh `quickedit` vào `~/.local/bin/`; lúc cài hỏi trình soạn thảo
  mặc định (ưu tiên đã lưu → `$EDITOR` → `nano`)
- Dữ liệu: `~/.config/quickedit/files.tsv` (`Tiêu_đề<TAB>Đường_dẫn`)
- Chỉ chạy bằng gõ lệnh tay, chưa có bước gán phím tắt như `launcher`

---

## ➕ Thêm component mới

1. Tạo `components/ten-moi/install.sh` (bắt buộc — script tổng gọi vào
   khi cài) + script chạy thực tế (tên tùy component)
2. Thêm 1 phần tử vào `manifest.json`:
   ```json
   { "name": "ten-moi", "description": "Mo ta ngan gon", "path": "components/ten-moi" }
   ```
3. Nếu component cần xử lý danh sách kiểu TSV (xóa/ghi đè 1 dòng theo
   tên), luôn so khớp **chính xác toàn bộ cột** bằng `awk`, không dùng
   `grep -P`/`grep -F` — 2 lỗi này từng gây mất dữ liệu thật, xem
   `CHANGELOG.md` mục `[1.0.1]`:
   ```bash
   awk -F'\t' -v n="$name" '$1 != n' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
   ```
4. Không cần dùng lại hàm từ component khác — component mới có thể tự
   viết logic riêng, kể cả khi giống component cũ. Ưu tiên đơn giản, dễ
   sửa độc lập hơn là tránh trùng lặp.

---

## 🖥️ Môi trường

- Distro: **Arch Linux**, WM: **Hyprland** (theme **Calestia**)
- Dùng `bash`, `fzf`, `jq` — không dùng `apt`/`gsettings`/GNOME
- Phím tắt: component tự ghi vào `~/.config/hypr/conf/*.conf`, `source`
  vào `hyprland.conf`, rồi `hyprctl reload`
- Shell mặc định người dùng có thể là `fish` — các bước liên quan `PATH`
  cần tính tới trường hợp này (xem mục Cài đặt)

---

## 📝 Trạng thái

- ✅ `quickedit` — hoàn chỉnh (thêm/xóa/mở file, đổi trình soạn thảo)
- 🟡 `launcher` — đang bổ sung: chức năng xóa mục (hiện chỉ có thêm mới),
  xác nhận trước khi xóa, sửa PATH cho shell `fish`
- 💡 `check` (so sánh thư mục với checklist file cần có) — ý tưởng tạm
  dừng, có thể làm sau

⚠️ Chưa test trong môi trường Hyprland thật (fzf tương tác, `hyprctl
reload`, phím tắt). Không hỗ trợ cài qua `curl | bash`.
