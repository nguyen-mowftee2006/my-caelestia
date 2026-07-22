# RULE.md — Quy ước phát triển My-caelestia

> Nguồn chân lý duy nhất cho quy ước code trong repo. `README.md` chỉ tóm
> tắt/trỏ tới đây, không lặp lại nội dung.
>
> **Định hướng hiện tại (đã chốt):** ưu tiên đơn giản, sửa/thêm trực tiếp
> trong file của từng component, **chấp nhận code trùng lặp giữa các
> component** — không dựng thư viện dùng chung (`lib/common.sh`), không
> dispatch tổng quát, không trừu tượng hóa thêm tầng nào. Mục tiêu số 1 là
> **không phát sinh bug**, không phải code gọn/không trùng lặp.

---

## 1. Cấu trúc bắt buộc của 1 component

```
components/ten-component/
├── install.sh       # BẮT BUỘC — script tổng gọi khi cài
└── ten-component.sh # Script chạy thực tế (tên tùy component)
```

- Không có `install.sh` → component không cài được, script tổng báo lỗi
- Không cần `uninstall.sh` hay bất kỳ file chuẩn hóa nào khác — mỗi
  component tự quyết định cấu trúc bên trong thư mục của mình
- Script tổng (`install.sh` ở gốc repo) chỉ làm đúng 1 việc: tìm và chạy
  `components/<ten>/install.sh` — không có cơ chế action tổng quát
- Mọi component **phải** được khai báo trong `manifest.json` ở gốc repo
  (xem mục 7) thì script tổng mới thấy và cài được

## 2. Sửa/thêm tính năng — đụng đúng 1 component

- Sửa hoặc thêm tính năng cho component nào → chỉ sửa file của **chính
  component đó** (`install.sh` riêng + script chạy thực tế riêng)
- Không tạo hàm/file dùng chung giữa các component. Nếu 2 component cần
  logic giống nhau (vd xóa 1 dòng trong TSV) → **copy logic đó vào cả 2
  nơi**, chấp nhận trùng lặp, không gộp thành 1 hàm chung
- Lý do: tránh 1 thay đổi ảnh hưởng dây chuyền tới component khác — sửa
  `launcher` không bao giờ có nguy cơ làm hỏng component khác, và ngược lại

## 3. Xử lý dữ liệu dạng TSV (tên/tiêu đề + dữ liệu)

- Xóa/ghi đè 1 dòng theo tên → luôn dùng `awk` so khớp **chính xác toàn
  bộ** giá trị cột, không phải regex, không phải substring:
  ```bash
  awk -F'\t' -v n="$name" '$1 != n' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  ```
- **Không dùng `grep -P`** (tên chứa ký tự regex như `( ) . * + ?` có thể
  làm `grep` lỗi cú pháp, output rỗng, ghi đè mất sạch dữ liệu)
- **Không dùng `grep -F`** dù fixed-string (không neo đầu dòng, khớp nhầm
  chuỗi con ở cột khác — vd tên `"0"` khớp nhầm cột `root_flag` của dòng
  khác)
- Đây là bug thật đã xảy ra và fix trong component `launcher` — đã áp
  dụng đúng cách này trong `remove_entry_by_name` (xem `UPDATE.md`).
  Khi có `CHANGELOG.md` (chưa tạo — xem mục 6), ghi chi tiết bug này vào
  đó dưới mục version tương ứng
- Quy tắc này **bắt buộc dù có chấp nhận trùng lặp code** — an toàn dữ
  liệu quan trọng hơn việc tránh lặp

## 4. Tương thích shell của người dùng

- Không giả định người dùng dùng `bash`/`zsh` — máy Arch/Hyprland cá nhân
  có thể dùng `fish` làm shell mặc định
- Bất kỳ chỗ nào script hướng dẫn/tự sửa `PATH` (thường ở bước cài đặt),
  cần kiểm tra `$SHELL` hoặc phát hiện fish, rồi dùng đúng cú pháp:
  - `fish`: `fish_add_path ~/.local/bin`
  - `bash`/`zsh`: `export PATH="$HOME/.local/bin:$PATH"` ghi vào
    `~/.bashrc`/`~/.zshrc`
- Đây là bug thật đã gặp (script chỉ gợi ý sửa `.bashrc`, không hoạt động
  với `fish`) — đã vá trong `components/launcher/install.sh`, xem
  `UPDATE.md` để biết chi tiết bản vá

## 5. Thao tác nguy hiểm (xóa dữ liệu)

- Bất kỳ chức năng xóa nào (xóa mục khỏi danh sách, xóa file cấu hình...)
  → luôn hỏi xác nhận trước (`read -rp "... (co/khong): "`), không xóa
  ngay khi người dùng chọn
- Không cần hàm dùng chung cho việc này — viết trực tiếp trong từng
  component theo mẫu đơn giản:
  ```bash
  read -rp "Xoa '$name'? (co/khong): " ans
  if [[ "$ans" =~ ^([Cc][Oo]|[Yy])$ ]]; then
      # thực hiện xóa
  fi
  ```

## 6. Versioning & release

- Version repo theo [SemVer](https://semver.org/) (`MAJOR.MINOR.PATCH`),
  khớp 1-1 với tag/GitHub Release (`v1.0.0`, `v1.0.1`...)
- Thêm tính năng mới, không phá gì cũ → tăng `MINOR`
- Chỉ sửa lỗi → tăng `PATCH`
- Mọi thay đổi ảnh hưởng người dùng → ghi vào `CHANGELOG.md` (không ghi
  refactor nội bộ/commit vụn vặt)
- **Lưu ý hiện tại:** `CHANGELOG.md` **chưa được tạo** trong repo. Tạo file
  này khi đóng bản release đầu tiên (`v1.0.0`) hoặc khi hoàn tất bugfix ở
  `UPDATE.md` mục 3 Bước 4 — không tạo trước khi có nội dung thật để ghi

## 7. Checklist thêm component mới

1. Tạo `components/ten-moi/install.sh` — tự viết logic cài `fzf`/dependency
   khác nếu cần, tự `cp` file vào `~/.local/bin/` + `chmod +x`, tự xử lý
   cảnh báo/sửa `PATH` (có tính fish theo mục 4)
2. Tạo `components/ten-moi/ten-moi.sh` — script chạy thực tế, tự viết
   toàn bộ logic cần thiết (không cần tìm hàm dùng chung ở đâu khác)
3. Thêm 1 phần tử vào `manifest.json` (xem mẫu ở `README.md` phần "Cách
   thêm component mới") — thiếu bước này thì script tổng sẽ không thấy
   component, dù thư mục và `install.sh` đã có sẵn
4. Nếu có thao tác xóa/ghi đè dữ liệu → áp dụng mục 3 và 5 ở trên
