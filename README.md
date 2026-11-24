# ttyd keys

App Flutter (iOS + Android) làm terminal native cho ttyd sau ttyd-auth (`remote-ocl.mihb.site`), kèm thanh phím mà bàn phím điện thoại thiếu.

## Tính năng chính

- **Kết nối**: đăng nhập ttyd-auth, tự đăng nhập lại khi phiên hết hạn, tự nối lại khi rớt mạng. Xem [ket-noi-ttyd.md](docs/feature/ket-noi-ttyd.md).
- **Thanh phím**: Esc, Tab, Ctrl/Alt/Shift dính, mũi tên giữ để lặp, Home/End/PgUp/PgDn, `^C ^D ^Z ^R ^L ^B ^A ^E ^U ^W`, ký tự khó gõ, dán. Xem [thanh-phim.md](docs/feature/thanh-phim.md).
- **Bàn phím ảo**: gõ tiếng Việt, xoá, Enter từ IME. Xem [nhap-ban-phim-ao.md](docs/feature/nhap-ban-phim-ao.md).
- **Cử chỉ**: chạm terminal để bật/tắt bàn phím (thanh phím đi cùng bàn phím), nhấn giữ để sao chép/dán, hai ngón tay để phóng to/thu nhỏ chữ. Xem [cu-chi-terminal.md](docs/feature/cu-chi-terminal.md).
- **Khoá app**: tự đăng nhập bằng mật khẩu đã nhớ rồi mở khoá bằng Face ID (máy không có thì mã PIN 4 số, sai 10 lần tự đăng xuất); rời app dưới 10 phút không bị hỏi lại. Xem [khoa-app.md](docs/feature/khoa-app.md).
- **Cài đặt**: nhớ mật khẩu trong Keychain/Keystore, cỡ chữ, lệnh tự chạy (mặc định `tmux new -A -s mobile` để giữ phiên); "Nhớ mật khẩu" mặc định tắt. Xem [cai-dat.md](docs/feature/cai-dat.md).

## Stack

Flutter 3.50.1, `xterm` 4, `flutter_secure_storage`, `shared_preferences`, `local_auth`, font JetBrains Mono Nerd Font; build trên GitHub Actions. Chi tiết: [docs/techstack.md](docs/techstack.md).

## Cấu trúc

```text
lib/              toàn bộ code Dart (11 file, xem docs/architecture.md)
assets/fonts/     font terminal JetBrains Mono Nerd Font Mono (OFL)
scripts/          pull-build.sh: tải artifact theo commit; install-build.sh: cài lên máy qua USB
ios/, android/    project native (Flutter sinh)
.github/          workflows/build.yml (iOS, khi push), build-android.yml (Android, khi gọi)
docs/             tài liệu
```

## Chạy nhanh

```bash
make get            # flutter pub get
make analyze        # lint
git push            # GitHub Actions build iOS khi push main
make install-ios    # tải .ipa của commit hiện tại, ký Apple ID, cài lên iPhone cắm USB
make install-android # build .apk trên GitHub (nếu chưa có), tải về, cài qua adb
make ios-ipa        # chỉ tải .ipa về build-ios/ (cần gh đã đăng nhập)
```

Chi tiết cài lên iPhone: [docs/deployment_guide.md](docs/deployment_guide.md#4-cài-lên-iphone).

## Tài liệu

- **Mục lục**: [docs/index.md](docs/index.md)
- [AGENTS.md](AGENTS.md) · [Kiến trúc](docs/architecture.md) · [Giao thức](docs/api_specifications.md) · [Build](docs/deployment_guide.md) · [Kiểm thử](docs/testing.md) · [CHANGELOG](CHANGELOG.md)
