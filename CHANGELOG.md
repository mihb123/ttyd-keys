# Changelog

Định dạng: [AGENTS.md](AGENTS.md#changelog).

## 2026-11-25

- Build: `make install-ios` / `make install-android` tải bản build đúng commit hiện tại về `build-ios/`, `build-android/` rồi cài lên máy cắm USB; file build CI gắn sha commit.
- Build: chuyển `.gitignore` sang dạng whitelist để file build thêm vào gốc repo không bị git track.
- Mặc định mới: "Nhớ mật khẩu" tắt, lệnh tự chạy `tmux new -A -s mobile`.
- Build chuyển từ Codemagic sang GitHub Actions (`.github/workflows/build.yml`); `make ios-ipa` / `make android-apk` tải artifact bằng `gh`.
- Tài liệu: thêm `docs/` (kiến trúc, giao thức, build, kiểm thử, 4 tính năng, mẫu feature), `AGENTS.md`, `CHANGELOG.md`, lệnh `make docs-check`.

## 2026-11-24

- Phát hành đầu: terminal Flutter cho ttyd sau ttyd-auth, thanh phím Esc/Tab/Ctrl/Alt/Shift/mũi tên, nhớ mật khẩu, lệnh tự chạy, build Codemagic.
