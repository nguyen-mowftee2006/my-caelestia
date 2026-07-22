# UPDATE.md — Việc đang làm dở: vá `launcher`

> File này là **kế hoạch chỉnh sửa (đang ở giai đoạn test)**, viết để bất kỳ
> ai (hoặc Claude ở phiên chat sau) đọc vào là hiểu ngay đang làm gì, còn
> thiếu gì. Gửi kèm file này + `RULE.md` khi mở phiên chat mới để tiếp tục.
>
> Quy ước code áp dụng khi sửa nằm ở [`RULE.md`](./RULE.md) — file này chỉ
> nói *đang thiếu gì* và *cách vá cụ thể*, không lặp lại quy ước chung.

---

## 1. Bối cảnh

Kế hoạch refactor lớn trước đó (dựng `lib/common.sh` dùng chung, dispatch
tổng quát theo action, thêm `uninstall`...) **đã bị hủy** — quyết định
chuyển sang hướng đơn giản: sửa trực tiếp từng component, chấp nhận trùng
lặp code, ưu tiên không phát sinh bug hơn là code gọn. Chi tiết quy ước
mới nằm ở `RULE.md`.

Việc cần làm hiện tại **chỉ giới hạn trong component `launcher`**.
`quickedit` tạm gác lại, chưa cần sửa gì.

`manifest.json` (script tổng) đã được tạo, hiện chỉ khai báo `launcher` —
đủ để test toàn bộ luồng cài đặt thật qua `install.sh` tổng, chưa cần chờ
`quickedit`.

## 2. Vấn đề đã xác nhận — đã vá xong trong code

### 2.1 `launcher` thiếu chức năng xóa mục — ✅ đã vá

Trước đây `launcher.sh` chỉ có 2 lựa chọn: chọn 1 mục có sẵn để chạy, hoặc
`+ Thêm mục mới...`. Đã thêm lựa chọn `- Xóa mục...` vào vòng lặp chính:

1. Hiện danh sách tên hiện có qua `fzf` để người dùng chọn mục cần xóa
2. Hỏi xác nhận (theo mẫu ở `RULE.md` mục 5) trước khi xóa thật
3. Dùng hàm `remove_entry_by_name` có sẵn (khớp chính xác cột 1 bằng
   `awk`, theo `RULE.md` mục 3) — không viết logic xóa mới

### 2.2 Lỗi PATH khi shell là `fish` — ✅ đã vá

`components/launcher/install.sh` trước đây chỉ gợi ý thêm dòng
`export PATH="$HOME/.local/bin:$PATH"` vào `~/.bashrc`/`~/.zshrc`, không
có tác dụng với `fish`. Đã thêm phát hiện shell:

```bash
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
        echo "Luu y: ~/.local/bin chua nam trong PATH."
        if [ -n "${FISH_VERSION:-}" ] || [[ "$SHELL" == *fish ]]; then
            echo "Ban dang dung fish shell. Chay lenh sau de sua ngay:"
            echo "  fish_add_path \$HOME/.local/bin"
        else
            echo "Them dong sau vao ~/.bashrc hoac ~/.zshrc:"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        ;;
esac
```

Lưu ý: `$SHELL` là shell **đăng nhập mặc định** của user, không phải shell
đang chạy script này (script luôn chạy bằng `bash` vì có shebang
`#!/usr/bin/env bash`) — nên phải check `$SHELL`, không check
`$0`/`$BASH_VERSION`.

## 3. Thứ tự thực hiện

- [x] **Bước 1** — Sửa `components/launcher/launcher.sh`: thêm lựa chọn
      xóa mục + xác nhận trước khi xóa (mục 2.1)
- [x] **Bước 2** — Sửa `components/launcher/install.sh`: phát hiện fish,
      gợi ý đúng lệnh sửa PATH (mục 2.2)
- [ ] **Bước 3** — Test thủ công qua `install.sh` tổng (giờ đã có
      `manifest.json`): cài `launcher` bằng cả 3 cách gọi
      (`bash install.sh`, `bash install.sh launcher`, `bash install.sh --all`),
      cài lại trên máy có sẵn dữ liệu `items.tsv`, thử xóa 1 mục (xác nhận
      có/không đều phải đúng hành vi), thử cài trên `fish` shell xem gợi ý
      PATH có đúng không
- [ ] **Bước 4** — Cập nhật `CHANGELOG.md` — thêm mục `Fixed`/`Added` phù
      hợp (tùy đây tính là bugfix hay tính năng mới — xem `RULE.md` mục 6
      để quyết định bump `PATCH` hay `MINOR`). **Lưu ý: `CHANGELOG.md`
      chưa tồn tại trong repo, cần tạo mới ở bước này.**

## 4. Không nằm trong phạm vi đợt này

- `quickedit` — chưa triển khai, kể cả lỗi PATH tương tự (nếu có) cũng tạm
  chưa sửa, đợi yêu cầu riêng
- Component `check` (ý tưởng cũ) — chưa có kế hoạch
- Mọi ý tưởng thuộc kế hoạch refactor lớn cũ (uninstall, sửa tại chỗ,
  `lib/common.sh`...) — đã hủy, không nằm trong định hướng hiện tại

---

## 5. Trạng thái hiện tại

🟡 **Code xong, đang chờ test** — mục 2.1 và 2.2 đã code xong hoàn chỉnh.
`manifest.json` đã có để test qua `install.sh` tổng. Việc còn lại là
**Bước 3** (test thủ công) rồi **Bước 4** (changelog).
