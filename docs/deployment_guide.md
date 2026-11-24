# Build và cài đặt

## Yêu cầu

- Flutter 3.50.1 (máy dev: `~/flutter`, Makefile tự tìm `flutter` trong `PATH` trước).
- `curl`, `jq` cho `make ios-ipa` / `make android-apk`.
- Token Codemagic trong `~/.config/ttyd-keys/codemagic.env`.
- Cài iOS: Impactor + cáp USB + Apple ID.

## 1. Lệnh hằng ngày

| Lệnh | Việc |
|---|---|
| `make help` | Liệt kê lệnh |
| `make get` | `flutter pub get` |
| `make analyze` | `flutter analyze` (lint) |
| `make ios-ipa` | Tải `.ipa` chưa ký mới nhất của `main` về `~/Downloads/ttyd-keys-ios`, chờ nếu đang build |
| `make android-apk` | Tải `.apk` mới nhất về `~/Downloads/ttyd-keys-android` |
| `make docs-check` | Kiểm link tương đối, khung mục `docs/feature/*.md`, cú pháp mermaid (`scripts/check-docs.py` + mermaid-check) |

Chạy trên thiết bị khi có máy dev nối điện thoại/emulator: `flutter run`.

## 2. Biến môi trường

Chỉ `scripts/pull-build.sh` và `Makefile` đọc; app không đọc biến môi trường.

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `CODEMAGIC_API_TOKEN` | — (bắt buộc) | Token API Codemagic |
| `CODEMAGIC_APP_ID` | — (bắt buộc) | ID app trên Codemagic |
| `TTYD_KEYS_CODEMAGIC_ENV` | `~/.config/ttyd-keys/codemagic.env` | File chứa 2 biến trên |
| `WORKFLOW` | `ios-unsigned` | `ios-unsigned` hoặc `android-apk` (Makefile tự đặt) |
| `BRANCH` | `main` | Nhánh lấy build |
| `WAIT` | `1` | `1` = chờ build đang chạy (kiểm mỗi 30 s), `0` = báo lỗi ngay |
| `OUT_DIR` | `~/Downloads/ttyd-keys-ios` / `-android` | Thư mục lưu file |
| `FLUTTER` (Makefile) | `flutter` trong `PATH`, không có thì `~/flutter/bin/flutter` | Binary Flutter |
| `NODE` (Makefile) | `node` trong `PATH`, không có thì bản mới nhất trong `~/.nvm` | Chạy kiểm mermaid |
| `MERMAID_CHECK` (Makefile) | `~/.claude/tools/mermaid-check/check-mermaid.mjs` | Thiếu thì `docs-check` bỏ qua mermaid kèm cảnh báo |

Tên file tải về: tên artifact + `-<7 ký tự commit>` (vd `TtydKeys-12-unsigned-25e9d64.ipa`).

## 3. CI/CD (Codemagic)

```mermaid
flowchart LR
    Push["push main"] --> CM{"Có đổi lib/, ios/, android/, pubspec.*, codemagic.yaml?"}
    CM -->|"không"| Skip["Không build"]
    CM -->|"có"| IOS["ios-unsigned: flutter build ios --no-codesign, zip Payload thành .ipa"]
    CM -->|"có"| AND["android-apk: flutter build apk --release"]
    IOS --> Pull["make ios-ipa"]
    AND --> PullA["make android-apk"]
    Pull --> Imp["Impactor ký + cài qua USB"]
    PullA --> Phone["Cài .apk lên Android"]
```

- Build mới huỷ build cũ đang chạy (`cancel_previous_builds`); số build = `$BUILD_NUMBER` của Codemagic.
- Giới hạn: iOS 45 phút (`mac_mini_m2`), Android 30 phút (`linux_x2`).
- Sửa chỉ tài liệu (`**/*.md`), `Makefile`, `scripts/`, `analysis_options.yaml` không kích hoạt build.

## 4. Cài lên iPhone

Hướng dẫn chung dùng Impactor (Ubuntu + Apple ID miễn phí): `~/thu-chi/docs/ios-codemagic.md`, phần "Phần cho người dùng". Lưu ý (theo tài liệu đó): bản ký bằng Apple ID miễn phí hết hạn sau 7 ngày; cài đè lại bằng Impactor (cùng Apple ID, không gỡ app) thì dữ liệu vẫn giữ.
