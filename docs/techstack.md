# Công nghệ

Phiên bản lấy từ `pubspec.lock`, `codemagic.yaml` (2026-11-25).

## App

| Công nghệ | Phiên bản | Dùng để |
|---|---|---|
| Flutter | 3.50.1 (Codemagic + máy dev) | UI iOS/Android |
| Dart SDK | `^3.14.0` | |
| `xterm` | 4.0.0 | Giả lập terminal (`Terminal`, `TerminalView`, `TerminalKey`, handler phím) |
| `material_ui` | 1.11.1 | Widget Material (thay import `package:flutter/material.dart`) |
| `shared_preferences` | 2.5.6 | Lưu host, username, `rememberPassword`, cỡ chữ, lệnh tự chạy |
| `flutter_secure_storage` | 11.2.0 | Lưu mật khẩu trong Keychain/Keystore |
| `dart:io` `HttpClient`, `WebSocket` | SDK | Đăng nhập HTTP, kết nối ttyd |

## Server (ngoài repo)

| Thành phần | Vai trò |
|---|---|
| ttyd-auth | Reverse proxy có `/login`, cookie `ttyd_*`, cấp khóa tab |
| ttyd 1.7.4 | Terminal qua WebSocket, subprotocol `tty` |

## Build / CI

| Công nghệ | Dùng để |
|---|---|
| Codemagic (`codemagic.yaml`) | Build `.ipa` chưa ký (`mac_mini_m2`) và `.apk` (`linux_x2`) khi push `main` |
| `scripts/pull-build.sh` (`curl` + `jq`) | Tải artifact mới nhất qua Codemagic API |
| Impactor | Ký `.ipa` bằng Apple ID và cài qua USB |

## Kiểm tra

| Công nghệ | Dùng để |
|---|---|
| `flutter_lints` 6.0.0 (`analysis_options.yaml`) | `make analyze` |
| `flutter_test` | Khai báo sẵn, chưa có test |
