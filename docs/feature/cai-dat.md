# Cài đặt và lưu trữ

## Mục tiêu

Nhớ host, tài khoản, mật khẩu (an toàn), cỡ chữ và lệnh tự chạy giữa các lần mở app.

## Phạm vi hiện tại

- Màn đăng nhập: host, username, mật khẩu, "Nhớ mật khẩu (Keychain), tự đăng nhập lại".
- Menu ⋮ → Cài đặt (bottom sheet): cỡ chữ 9–24 (15 nấc), "Lệnh tự chạy khi kết nối".
- Menu ⋮ → "Đăng xuất, quên mật khẩu": đóng WS, xoá mật khẩu, về màn đăng nhập.
- Chưa có: nhiều hồ sơ host, theme sáng.

## Code map

- `lib/settings.dart` — `Settings`: `load`, `save`, `forgetPassword`.
- `lib/terminal_screen.dart` — `_SettingsSheet`, `_openSettings`, `_logout`.
- `lib/main.dart` — `main` (`Settings.load`), `_LoginScreenState._submit`.

## Luồng xử lý

1. `main` gọi `Settings.load()` trước `runApp`; đọc mật khẩu từ secure storage chỉ khi `rememberPassword`.
2. Đăng nhập thành công (`_LoginScreenState._submit`) → `save()`; không nhớ mật khẩu thì xoá mật khẩu khỏi bộ nhớ sau khi lưu.
3. Bottom sheet Cài đặt bấm Lưu → gán `fontSize`, `startupCommand` → `save()` → `TerminalScreen` `setState` để vẽ lại.
4. Đăng xuất → `forgetPassword()` (xoá key `password`) → `save()` → màn đăng nhập.
5. Tự đăng nhập lại thất bại vì sai mật khẩu → `forgetPassword()` ([ket-noi-ttyd.md](ket-noi-ttyd.md)).

## Dữ liệu & giao thức

| Key | Nơi lưu | Mặc định | Ý nghĩa |
|---|---|---|---|
| `host` | SharedPreferences | `remote-ocl.mihb.site` | Host ttyd-auth (không scheme, không path) |
| `username` | SharedPreferences | rỗng | Tài khoản ttyd-auth |
| `rememberPassword` | SharedPreferences | `false` | Nhớ mật khẩu, tự đăng nhập lại |
| `fontSize` | SharedPreferences | `14` | Cỡ chữ terminal |
| `startupCommand` | SharedPreferences | `tmux new -A -s mobile` | Gửi kèm `\r` sau output đầu tiên (chờ tối đa 3s) |
| `password` | `flutter_secure_storage` (Keychain iOS / Keystore Android) | — | Chỉ có khi `rememberPassword` |

## Quy tắc & lưu ý

- `save()` ghi mật khẩu vào secure storage chỉ khi `rememberPassword` và mật khẩu khác rỗng; ngược lại xoá key `password`.
- Lỗi đọc/ghi secure storage bị nuốt (coi như không có mật khẩu), app vẫn chạy.
- Mỗi lần mất kết nối ttyd mở shell mới; lệnh tự chạy mặc định `tmux new -A -s mobile` đưa về lại đúng phiên tmux. Xoá trống nếu không muốn.
- Đổi cỡ chữ làm `TerminalView` đổi số cột/dòng → `onResize` gửi khung resize cho ttyd.

## Còn để lại

- Không có nút sửa host khi đang ở terminal: phải đăng xuất để đổi host/tài khoản.
