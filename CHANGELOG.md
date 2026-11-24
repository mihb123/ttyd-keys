# Changelog

Định dạng: [AGENTS.md](AGENTS.md#changelog).

## 2026-11-25

- Mặc định mới: "Nhớ mật khẩu" tắt, lệnh tự chạy `tmux new -A -s mobile`.
- Build chuyển từ Codemagic sang GitHub Actions (`.github/workflows/build.yml`); `make ios-ipa` / `make android-apk` tải artifact bằng `gh`.
- Tài liệu: thêm `docs/` (kiến trúc, giao thức, build, kiểm thử, 4 tính năng, mẫu feature), `AGENTS.md`, `CHANGELOG.md`, lệnh `make docs-check`.

## 2026-11-24

- Phát hành đầu: terminal Flutter cho ttyd sau ttyd-auth, thanh phím Esc/Tab/Ctrl/Alt/Shift/mũi tên, nhớ mật khẩu, lệnh tự chạy, build Codemagic.
