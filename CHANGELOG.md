# Changelog

Định dạng dựa theo [Keep a Changelog](https://keepachangelog.com/),
version theo [SemVer](https://semver.org/) (xem `RULE.md` mục 6).

## [Unreleased]

### Changed

- `launcher`: bỏ toàn bộ phần tự động gán phím tắt Hyprland trong
  `install.sh` (không còn hỏi tổ hợp phím, không tự ghi
  `launcher_keybind.conf`, không tự gọi `hyprctl reload`). Lý do: giảm
  rủi ro ghi đè/sai cú pháp config Hyprland của người dùng, tách rõ trách
  nhiệm cài đặt và cấu hình cá nhân.

### Added

- `components/launcher/KEYBIND.md` — hướng dẫn người dùng tự gán phím tắt
  Hyprland cho `launcher` sau khi cài.

> Repo chưa có bản release chính thức nào (`v1.0.0` trở lên) tính tới thời
> điểm này — các thay đổi trên gộp chung vào `[Unreleased]` cho tới khi
> đóng bản release đầu tiên.
