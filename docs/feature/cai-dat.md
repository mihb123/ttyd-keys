# Cài đặt và lưu trữ

## Mục tiêu

Nhớ host, tài khoản, mật khẩu (an toàn), cỡ chữ và lệnh tự chạy giữa các lần mở app.

## Phạm vi hiện tại

- Màn đăng nhập: host, username, mật khẩu, "Nhớ mật khẩu (Keychain), tự đăng nhập lại".
- Menu ⋮ → Cài đặt (bottom sheet): cỡ chữ 6–24 (bước 0.5, `divisions: 36`), "Lệnh tự chạy khi kết nối", bật/tắt thanh phím bên dưới (`Hiện thanh phím bên dưới`) và chọn từng phím hiển thị (`Tuỳ chỉnh phím hiển thị`, [thanh-phim.md](thanh-phim.md)).
- Hai ngón tay chụm/mở trên terminal cũng đổi và lưu cỡ chữ ([cu-chi-terminal.md](cu-chi-terminal.md)).
- Menu ⋮ → "Đăng xuất, quên mật khẩu": đóng WS, xoá mật khẩu và mã PIN, về màn đăng nhập.
- Chưa có: nhiều hồ sơ host, theme sáng.

## Code map

- `lib/settings.dart` — `Settings`: `load`, `save`, `forgetPassword`.
- `lib/terminal_screen.dart` — `_SettingsSheet`, `_openSettings`, `_logout`.
- `lib/key_bar.dart` — `KeyBarCustomizationSheet`, `keyBarCatalog`.
- `lib/main.dart` — `main` (`Settings.load`), `_LoginScreenState._submit`.

## Luồng xử lý

1. `main` gọi `Settings.load()` trước `runApp`; đọc mật khẩu từ secure storage chỉ khi `rememberPassword`.
2. Đăng nhập thành công (`_LoginScreenState._submit`) → `save()`; không nhớ mật khẩu thì xoá mật khẩu khỏi bộ nhớ sau khi lưu.
3. Bottom sheet Cài đặt bấm Lưu → gán `fontSize`, `startupCommand`, `showKeyBar`, `hiddenKeyBarKeys` → `save()` → `TerminalScreen` `setState` để vẽ lại.
4. Đăng xuất → `forgetPassword()` (xoá key `password`) → `save()` → `AppLock.clear()` (xoá `pinHash`, `pinFails`) → màn đăng nhập.
5. Tự đăng nhập lại thất bại vì sai mật khẩu → `forgetPassword()` ([ket-noi-ttyd.md](ket-noi-ttyd.md)).

## Dữ liệu & giao thức

| Key | Nơi lưu | Mặc định | Ý nghĩa |
|---|---|---|---|
| `host` | SharedPreferences | `remote-ocl.mihb.site` | Host ttyd-auth (không scheme, không path) |
| `username` | SharedPreferences | rỗng | Tài khoản ttyd-auth |
| `rememberPassword` | SharedPreferences | `false` | Nhớ mật khẩu, tự đăng nhập lại |
| `fontSize` | SharedPreferences | `14` | Cỡ chữ terminal (6–24 pt) |
| `startupCommand` | SharedPreferences | `tmux new -A -s mobile` | Gửi kèm `\r` sau output đầu tiên (chờ tối đa 3s) |
| `showKeyBar` | SharedPreferences | `true` | Hiện hay ẩn toàn bộ thanh phím bên dưới |
| `hiddenKeyBarKeys` | SharedPreferences | `[]` | Danh sách id phím bị ẩn trên thanh phím (`keyBarCatalog`) |
| `password` | `flutter_secure_storage` (Keychain iOS / Keystore Android) | — | Chỉ có khi `rememberPassword` |
| `pinHash` | `flutter_secure_storage` | — | `salt:sha256(salt:pin)` của mã PIN 4 số ([khoa-app.md](khoa-app.md)); xoá khi đăng xuất |
| `pinFails` | `flutter_secure_storage` | — | Số lần nhập PIN sai liên tiếp; tới 10 thì đăng xuất |

## Quy tắc & lưu ý

- `save()` ghi mật khẩu vào secure storage chỉ khi `rememberPassword` và mật khẩu khác rỗng; ngược lại xoá key `password`.
- Lỗi đọc/ghi secure storage bị nuốt (coi như không có mật khẩu), app vẫn chạy.
- Mỗi lần mất kết nối ttyd mở shell mới; lệnh tự chạy mặc định `tmux new -A -s mobile` đưa về lại đúng phiên tmux. Xoá trống nếu không muốn.
- Đổi cỡ chữ làm `TerminalView` đổi số cột/dòng → `onResize` gửi khung resize cho ttyd.
- Font terminal cố định `terminalFontFamily` = `JetBrainsMonoNF` (`lib/terminal_screen.dart`, khai báo trong `pubspec.yaml`, file ở `assets/fonts/`). Không dùng font hệ thống vì xterm vẽ từng ô một ký tự: Menlo trên iOS thiếu chữ tiếng Việt dựng sẵn (vd `ấ` U+1EA5) nên dấu bị tách và lệch dòng, và không có icon Nerd Font (thanh trạng thái tmux hiện ô `?`). Emoji/CJK vẫn rơi về danh sách font dự phòng mặc định của xterm.

## Còn để lại

- Không có nút sửa host khi đang ở terminal: phải đăng xuất để đổi host/tài khoản.
- Chữ có dấu dạng tách (NFD, vd tên file từ macOS) vẫn lệch: xterm 4.0.0 `Buffer.writeChar` cho dấu kết hợp (độ rộng 0) chiếm riêng một ô.
