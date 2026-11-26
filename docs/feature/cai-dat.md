# Cài đặt và lưu trữ

## Mục tiêu

Nhớ danh sách server (host, tài khoản, mật khẩu an toàn, lệnh tự chạy), cỡ chữ và thanh phím giữa các lần mở app.

## Phạm vi hiện tại

- Form server (thêm/sửa): tên hiển thị, host, username, mật khẩu (luôn lưu Keychain), "Lệnh tự chạy khi kết nối" ([nhieu-server.md](nhieu-server.md)).
- Menu ⋮ → Cài đặt (bottom sheet), dùng chung mọi server: cỡ chữ 1–24 (bước 0.5, `divisions: 46`), bật/tắt hàng phím thứ hai (`Hiện hàng phím thứ hai`) và chọn từng phím hiển thị (`Tuỳ chỉnh phím hiển thị`, [thanh-phim.md](thanh-phim.md)).
- Hai ngón tay chụm/mở trên terminal cũng đổi và lưu cỡ chữ ([cu-chi-terminal.md](cu-chi-terminal.md)).
- Xoá server (menu ⋮ hoặc nhấn giữ trong sidebar): đóng WS, xoá profile + mật khẩu; xoá server cuối cùng thì xoá luôn mã PIN, về màn đăng nhập.
- Chưa có: theme sáng.

## Code map

- `lib/settings.dart` — `ServerProfile`; `Settings`: `load` (+ `_migrateSingleHost`), `save`, `removeServer`, `forgetPassword`, `forgetAllPasswords`.
- `lib/terminal_screen.dart` — `_SettingsSheet`, `_openSettings`, `_deleteServer`, `_logout`.
- `lib/key_bar.dart` — `KeyBarCustomizationSheet`, `keyBarCatalog`.
- `lib/main.dart` — `main` (`Settings.load`), `_LoginScreenState._submit`.

## Luồng xử lý

1. `main` gọi `Settings.load()` trước `runApp`: đọc `servers`, rồi mật khẩu `password.<id>` của từng server. Chưa có key `servers` → `_migrateSingleHost` chuyển `host`/`username`/`startupCommand`/`password` cũ thành server đầu tiên (nếu có username), `save()`, xoá key cũ.
2. Đăng nhập/sửa server thành công (`_LoginScreenState._submit`) → cập nhật `servers`, `activeServerId` → `save()`.
3. Bottom sheet Cài đặt bấm Lưu → gán `fontSize`, `showSecondKeyRow`, `hiddenKeyBarKeys` → `save()` → `TerminalScreen` `setState` để vẽ lại.
4. Chuyển server → `activeServerId` → `save()`.
5. Đăng xuất từ màn khoá → `forgetAllPasswords()` → `save()` → `AppLock.clear()` (xoá `pinHash`, `pinFails`) → màn đăng nhập điền sẵn server gần nhất.
6. Tự đăng nhập lại thất bại vì sai mật khẩu → `forgetPassword(server)` của riêng server đó ([ket-noi-ttyd.md](ket-noi-ttyd.md)).

## Dữ liệu & giao thức

| Key | Nơi lưu | Mặc định | Ý nghĩa |
|---|---|---|---|
| `servers` | SharedPreferences | `[]` | JSON list `{id, name, host, username, startupCommand}`; host không scheme, không path; form thêm server đầu tiên điền sẵn `defaultHost` = `remote-ocl.mihb.site` |
| `activeServerId` | SharedPreferences | — | Server dùng gần nhất, mở app thì nối server này |
| `fontSize` | SharedPreferences | `14` | Cỡ chữ terminal (1–24 pt) |
| `showSecondKeyRow` | SharedPreferences | `true` | Hiện hàng 2 của thanh phím; chưa có key này thì đọc key cũ `showKeyBar` (`save()` xoá key cũ) |
| `hiddenKeyBarKeys` | SharedPreferences | `[]` | Danh sách id phím bị ẩn trên thanh phím (`keyBarCatalog`) |
| `password.<id>` | `flutter_secure_storage` (Keychain iOS / Keystore Android) | — | Mật khẩu của server `<id>`; luôn lưu khi đăng nhập thành công |
| `pinHash` | `flutter_secure_storage` | — | `salt:sha256(salt:pin)` của mã PIN 4 số ([khoa-app.md](khoa-app.md)); xoá khi đăng xuất |
| `pinFails` | `flutter_secure_storage` | — | Số lần nhập PIN sai liên tiếp; tới 10 thì đăng xuất |

## Quy tắc & lưu ý

- Lệnh tự chạy (`startupCommand` trong JSON server, mặc định `defaultStartupCommand` = `tmux new -A -s mobile`) gửi kèm `\r` sau output đầu tiên (chờ tối đa 3 s).
- `save()` ghi `password.<id>` khi mật khẩu khác rỗng, ngược lại xoá key đó. Key cũ `host`, `username`, `rememberPassword`, `startupCommand`, `password` chỉ còn được đọc lúc chuyển dữ liệu.
- Lỗi đọc/ghi secure storage bị nuốt (coi như không có mật khẩu), app vẫn chạy.
- Mỗi lần mất kết nối ttyd mở shell mới; lệnh tự chạy mặc định `tmux new -A -s mobile` đưa về lại đúng phiên tmux. Xoá trống nếu không muốn.
- Đổi cỡ chữ làm `TerminalView` đổi số cột/dòng → `onResize` gửi khung resize cho ttyd.
- Font terminal cố định `terminalFontFamily` = `JetBrainsMonoNF` (`lib/terminal_screen.dart`, khai báo trong `pubspec.yaml`, file ở `assets/fonts/`). Không dùng font hệ thống vì xterm vẽ từng ô một ký tự: Menlo trên iOS thiếu chữ tiếng Việt dựng sẵn (vd `ấ` U+1EA5) nên dấu bị tách và lệch dòng, và không có icon Nerd Font (thanh trạng thái tmux hiện ô `?`). Emoji/CJK vẫn rơi về danh sách font dự phòng mặc định của xterm.

## Còn để lại

- Cỡ chữ 1–2 pt trên màn lớn cho hàng trăm cột/dòng: buffer `maxLines: 10000` phình bộ nhớ, đổi cỡ chữ reflow chậm, vuốt trong tmux/vim bắn nhiều sự kiện cuộn.
- Chữ có dấu dạng tách (NFD, vd tên file từ macOS) vẫn lệch: xterm 4.0.0 `Buffer.writeChar` cho dấu kết hợp (độ rộng 0) chiếm riêng một ô.
