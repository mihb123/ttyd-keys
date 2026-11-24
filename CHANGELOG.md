# Changelog

Định dạng: [AGENTS.md](AGENTS.md#changelog).

## 2026-11-25

- Build: push `main` chỉ build iOS; Android chỉ build khi chạy `make android-apk` / `make install-android` (tự gọi `build-android.yml` rồi tải về).
- Khoá app: mở app bằng mật khẩu đã nhớ phải mở khoá bằng Face ID (máy không có thì mã PIN 4 số, sai 10 lần tự đăng xuất); rời app từ 10 phút trở lên thì khoá lại; màn đen che terminal trong trình chuyển app ([khoa-app](docs/feature/khoa-app.md)).
- Cử chỉ: chạm terminal để bật/tắt bàn phím, thanh phím chỉ hiện cùng bàn phím ảo; nhấn giữ để sao chép/dán; hai ngón tay để đổi cỡ chữ ([cu-chi-terminal](docs/feature/cu-chi-terminal.md)).
- Sửa: chữ tiếng Việt có dấu bị tách dấu, lệch dòng và icon tmux hiện ô `?` (nhúng font JetBrains Mono Nerd Font).
- Build: `make install-ios` / `make install-android` tải bản build đúng commit hiện tại về `build-ios/`, `build-android/` rồi cài lên máy cắm USB; file build CI gắn sha commit.
- Build: chuyển `.gitignore` sang dạng whitelist để file build thêm vào gốc repo không bị git track.
- Mặc định mới: "Nhớ mật khẩu" tắt, lệnh tự chạy `tmux new -A -s mobile`.
- Build chuyển từ Codemagic sang GitHub Actions (`.github/workflows/build.yml`); `make ios-ipa` / `make android-apk` tải artifact bằng `gh`.
- Tài liệu: thêm `docs/` (kiến trúc, giao thức, build, kiểm thử, 4 tính năng, mẫu feature), `AGENTS.md`, `CHANGELOG.md`, lệnh `make docs-check`.

## 2026-11-24

- Phát hành đầu: terminal Flutter cho ttyd sau ttyd-auth, thanh phím Esc/Tab/Ctrl/Alt/Shift/mũi tên, nhớ mật khẩu, lệnh tự chạy, build Codemagic.
