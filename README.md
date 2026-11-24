# ttyd keys

App Flutter (iOS + Android) làm terminal native cho ttyd sau ttyd-auth (`remote-ocl.mihb.site`), kèm thanh phím mà bàn phím điện thoại thiếu.

## Tính năng chính

- **Kết nối**: đăng nhập ttyd-auth, tự đăng nhập lại khi phiên hết hạn, tự nối lại khi rớt mạng. Xem [ket-noi-ttyd.md](docs/feature/ket-noi-ttyd.md).
- **Thanh phím**: Esc, Tab, Ctrl/Alt/Shift dính, mũi tên giữ để lặp, Home/End/PgUp/PgDn, `^C ^D ^Z ^R ^L ^B ^A ^E ^U ^W`, ký tự khó gõ, dán. Xem [thanh-phim.md](docs/feature/thanh-phim.md).
- **Bàn phím ảo**: gõ tiếng Việt, xoá, Enter từ IME. Xem [nhap-ban-phim-ao.md](docs/feature/nhap-ban-phim-ao.md).
- **Cài đặt**: nhớ mật khẩu trong Keychain/Keystore, cỡ chữ, lệnh tự chạy (mặc định `tmux new -A -s mobile` để giữ phiên); "Nhớ mật khẩu" mặc định tắt. Xem [cai-dat.md](docs/feature/cai-dat.md).

## Stack

Flutter 3.50.1, `xterm` 4, `flutter_secure_storage`, `shared_preferences`; build trên Codemagic. Chi tiết: [docs/techstack.md](docs/techstack.md).

## Cấu trúc

```text
lib/              toàn bộ code Dart (8 file, xem docs/architecture.md)
scripts/          pull-build.sh: tải artifact Codemagic
ios/, android/    project native (Flutter sinh)
codemagic.yaml    workflow ios-unsigned, android-apk
docs/             tài liệu
```

## Chạy nhanh

```bash
make get            # flutter pub get
make analyze        # lint
git push            # Codemagic build khi push main
make ios-ipa        # tải .ipa chưa ký mới nhất (cần ~/.config/ttyd-keys/codemagic.env)
make android-apk    # tải .apk
```

Ký và cài lên iPhone: [docs/deployment_guide.md](docs/deployment_guide.md#4-cài-lên-iphone).

## Tài liệu

- **Mục lục**: [docs/index.md](docs/index.md)
- [AGENTS.md](AGENTS.md) · [Kiến trúc](docs/architecture.md) · [Giao thức](docs/api_specifications.md) · [Build](docs/deployment_guide.md) · [Kiểm thử](docs/testing.md) · [CHANGELOG](CHANGELOG.md)
