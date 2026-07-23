# My-caelestia

> Bộ công cụ terminal cá nhân cho **Arch Linux + Hyprland (Calestia)**.
> Một script tổng (`install.sh`) đóng vai trò như "package manager" riêng,
> cài đặt các script con (gọi là **component**) được lưu trong repo này.

---

## 🎯 Mục đích dự án

Thay vì rải rác nhiều script lẻ trên máy, My-caelestia gom tất cả vào **một
repo GitHub duy nhất**, có cấu trúc rõ ràng để:

- Cài đặt nhanh trên máy mới chỉ bằng `git clone` + `bash install.sh`
- Thêm tính năng mới (component mới) mà **không phải sửa code cũ**
- Mỗi component tự quản lý dữ liệu, phím tắt, dependency của riêng nó

Đây là dự án đang phát triển dần — mỗi lần thêm component là một buổi làm
việc riêng. README này + `RULE.md` + `UPDATE.md` dùng để bất kỳ ai (hoặc
Claude ở phiên chat sau) đọc vào là hiểu ngay hiện trạng và mục tiêu.

---

## 📁 Cấu trúc thư mục

```
my-caelestia/
├── install.sh                 # Script tổng — chạy đầu tiên khi setup máy mới
├── manifest.json               # Danh sách component đang có (hiện tại: launcher)
├── README.md                   # File này
├── RULE.md                     # Quy ước code khi sửa/thêm component
├── UPDATE.md                   # Việc đang làm dở, kế hoạch vá cụ thể
└── components/
    └── launcher/
        ├── install.sh           # Cài đặt riêng cho launcher
        ├── launcher.sh          # Script chạy thực tế (TUI chọn app/web)
        └── KEYBIND.md           # Hướng dẫn tự gán phím tắt Hyprland
```

**Nguyên tắc cố định:**

- Mỗi component là **1 thư mục con trong `components/`**
- Bắt buộc phải có file `install.sh` bên trong — đây là điểm mà script tổng
  gọi vào để cài đặt component đó
- Các file khác trong component (tên, số lượng) do component đó tự quyết
  định, script tổng không quan tâm
- Quy ước chi tiết hơn khi sửa/thêm component: xem `RULE.md`

---

## 🚀 Cài đặt trên máy mới

```
git clone <url-repo-cua-ban> my-caelestia
cd my-caelestia
bash install.sh
```

Script tổng sẽ:

1. Kiểm tra máy có phải Arch Linux không (cảnh báo nếu không phải)
2. Tự cài `jq` và `fzf` nếu thiếu (cần cho việc đọc `manifest.json` và hiện menu)
3. Hiện menu chọn component muốn cài (chọn nhiều bằng phím `TAB`)

**Các cách gọi khác:**

| Lệnh                       | Ý nghĩa                                              |
| -------------------------- | ----------------------------------------------------- |
| `bash install.sh`          | Hiện menu chọn component cần cài                      |
| `bash install.sh launcher` | Cài thẳng **1** component cụ thể (`launcher`), bỏ qua menu |
| `bash install.sh --all`    | Cài **tất cả** component có trong `manifest.json`      |

---

## 🧩 Danh sách component hiện có

### 1. `launcher` — Chọn nhanh app/website

TUI dùng `fzf`, cho thêm/xóa shortcut tới ứng dụng hoặc trang web, chọn là
chạy ngay. Có phân biệt lệnh cần quyền `sudo` hay không.

- Cài lệnh `launcher` vào `~/.local/bin/`
- **Không** tự động gán phím tắt Hyprland nữa — sau khi cài, tự bind phím
  theo hướng dẫn ở [`components/launcher/KEYBIND.md`](./components/launcher/KEYBIND.md)
- Dữ liệu lưu tại `~/.config/quicklauncher/items.tsv` (định dạng TSV:
  `Tên<TAB>cần_root(0/1)<TAB>Lệnh`)
- Trạng thái: ✅ đã code xong phần thêm/xóa/chạy shortcut + fix PATH cho
  shell `fish`. Đang chờ test thủ công thực tế qua `install.sh` tổng
  (xem `UPDATE.md`).

### 2. `quickedit` — Mở nhanh file để sửa

**Chưa triển khai.** Ý tưởng: TUI dùng `fzf`, lưu danh sách **tiêu đề →
đường dẫn file**, chọn là mở thẳng file đó bằng trình soạn thảo. Sẽ làm sau
khi `launcher` test xong qua script tổng.

---

## ➕ Cách thêm component mới

Chỉ cần đụng vào **2 chỗ**, không sửa `install.sh` tổng:

**Bước 1 — Tạo thư mục component:**

```
components/ten-component-moi/
├── install.sh     # bắt buộc
└── ...            # các file khác tùy component
```

**Bước 2 — Thêm 1 phần tử vào `manifest.json`:**

```json
{
  "name": "ten-component-moi",
  "description": "Mo ta ngan gon component nay lam gi",
  "path": "components/ten-component-moi"
}
```

Script tổng chỉ làm 1 việc với mọi component: ghép `SCRIPT_DIR/<path>/install.sh`
rồi chạy. Component nào cần dependency gì, tự lo trong `install.sh` của
chính nó (theo mẫu `pacman -S --needed <gói>`).

Quy ước chi tiết (đặt tên, xử lý TSV, xử lý shell fish, thao tác xóa...):
xem `RULE.md`.

---

## 🖥️ Ghi chú môi trường

- Distro mục tiêu: **Arch Linux**
- Window Manager: **Hyprland** (theo theme **Calestia**)
- Các script dùng `bash`, `fzf`, `jq` — không dùng `apt`/`gsettings`/GNOME
- Phím tắt hệ thống được các component tự ghi vào
  `~/.config/hypr/conf/*.conf` rồi `source` vào `hyprland.conf`, sau đó gọi
  `hyprctl reload` — **không** dùng `gsettings` (đó là của GNOME, không áp
  dụng cho Hyprland)

---

## 📝 Trạng thái / việc dở dang

- ✅ `install.sh` (script tổng) — đã code xong, đọc `manifest.json` qua `jq`,
  hỗ trợ menu / cài theo tên / `--all`
- ✅ `manifest.json` — đã tạo, hiện chỉ khai báo `launcher` để test trước
- 🟡 `launcher` — code đã xong (kể cả 2 việc từng ghi ở `UPDATE.md`: xóa mục
  + fix PATH cho fish), đang chờ **test thủ công qua `install.sh` tổng**
- ⛔ `quickedit` — chưa làm, tạm gác lại
- 💡 Từng có ý tưởng component `check` (so sánh thư mục với checklist file
  cần có, báo thiếu/thừa) — chưa có kế hoạch cụ thể

Khi trò chuyện với Claude ở phiên sau, có thể gửi kèm README này + `RULE.md`
+ `UPDATE.md` để Claude nắm ngay cấu trúc dự án, quy ước đặt tên, và việc
đang làm dở, tránh phải giải thích lại từ đầu.
