# ttyd keys

App Flutter (iOS + Android) làm terminal native cho ttyd sau ttyd-auth (`remote-ocl.mihb.site`), kèm thanh phím Esc, Tab, Ctrl, Alt, Shift, mũi tên, Home/End/PgUp/PgDn, `^C ^D ^Z ^R ^L ^B ^A ^E ^U ^W`, ký tự khó gõ (`| ~ / - \` \ * $ &`), dán, ẩn bàn phím.

- Ctrl/Alt/Shift là phím dính: chạm 1 lần = áp cho phím kế tiếp (xanh), chạm lần 2 = khóa (viền trắng), lần 3 = tắt.
- Mũi tên giữ để lặp.
- Mỗi lần mất kết nối ttyd mở shell mới; muốn giữ phiên thì đặt "Lệnh tự chạy khi kết nối" = `tmux new -A -s main` (menu ⋮ → Cài đặt).
- Mật khẩu lưu trong Keychain/Keystore khi bật "Nhớ mật khẩu", dùng để tự đăng nhập lại khi phiên hết hạn.

## Luồng kết nối

`POST /login` → cookie `ttyd_<id>` → `GET /` lấy khóa tab `var k="..."` trong HTML → `wss://host/ws?k=<khóa>` (Cookie, subprotocol `tty`) → giao thức ttyd 1.7.4 (`0`=input/output, `1`=resize/title). Code: `lib/ttyd_client.dart`.

## Build

```bash
make analyze        # cần Flutter SDK (~/flutter)
make ios-ipa        # tải .ipa chưa ký mới nhất từ Codemagic
make android-apk    # tải .apk
```

Cấu hình `~/.config/ttyd-keys/codemagic.env`:

```bash
CODEMAGIC_API_TOKEN=...
CODEMAGIC_APP_ID=...
```

Push `main` → Codemagic build (`codemagic.yaml`: `ios-unsigned`, `android-apk`). Ký và cài lên iPhone bằng Impactor: xem `~/thu-chi/docs/ios-codemagic.md` phần "cho người dùng".
