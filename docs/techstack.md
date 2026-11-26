# Công nghệ

Phiên bản lấy từ `pubspec.lock`, `.github/workflows/build.yml` (2026-11-25).

## App

| Công nghệ | Phiên bản | Dùng để |
|---|---|---|
| Flutter | 3.50.1 (GitHub Actions + máy dev) | UI iOS/Android |
| Dart SDK | `^3.14.0` | |
| `xterm` | 4.0.0 | Giả lập terminal (`Terminal`, `TerminalView`, `TerminalKey`, handler phím) |
| `material_ui` | 1.11.1 | Widget Material (thay import `package:flutter/material.dart`) |
| `shared_preferences` | 2.5.6 | Lưu host, username, `rememberPassword`, cỡ chữ, lệnh tự chạy |
| `flutter_secure_storage` | 11.2.0 | Lưu mật khẩu, hash mã PIN, bộ đếm sai trong Keychain/Keystore |
| `local_auth` | 3.0.2 | Face ID/Touch ID/vân tay ([khoa-app.md](feature/khoa-app.md)) |
| `crypto` | 3.0.8 | SHA-256 cho mã PIN |
| JetBrains Mono Nerd Font Mono | v3.5.1 (`assets/fonts/`, OFL) | Font terminal: đủ dấu tiếng Việt dựng sẵn + icon Nerd Font |
| `dart:io` `HttpClient`, `WebSocket` | SDK | Đăng nhập HTTP, kết nối ttyd |

## Server (ngoài repo)

| Thành phần | Vai trò |
|---|---|
| ttyd-auth | Reverse proxy có `/login`, cookie `ttyd_*`, cấp khóa tab |
| ttyd 1.7.4 | Terminal qua WebSocket, subprotocol `tty` |

## Build / CI

| Công nghệ | Dùng để |
|---|---|
| GitHub Actions (`.github/workflows/build.yml`, `build-android.yml`) | Build `.ipa` chưa ký (`macos-latest`) khi push `main`; `.apk` (`ubuntu-latest`) khi chạy `make android-apk` |
| `scripts/pull-build.sh` (`gh`) | Tải artifact của run mới nhất |
| Impactor | Ký `.ipa` bằng Apple ID và cài qua USB |
| `flutter_launcher_icons` 0.14.4 (khối `flutter_launcher_icons:` trong `pubspec.yaml`) | Sinh icon iOS/Android từ `assets/icon/icon.png`, `icon-foreground.png` |

## Kiểm tra

| Công nghệ | Dùng để |
|---|---|
| `flutter_lints` 6.0.0 (`analysis_options.yaml`) | `make analyze` |
| `flutter_test` | Khai báo sẵn, chưa có test |
