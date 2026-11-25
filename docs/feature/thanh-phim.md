# Thanh phím và phím bổ trợ

## Mục tiêu

Bàn phím điện thoại thiếu Esc, Tab, Ctrl, Alt, mũi tên… Thanh phím dưới terminal bù các phím đó và sinh đúng chuỗi escape mà shell/vim/tmux mong đợi.

## Phạm vi hiện tại

- Hàng 1 (giãn đều): `Esc`, `Tab`, `Ctrl`, `Alt`, `Shift`, `←`, `↓`, `↑`, `→`.
- Hàng 2 (cuộn ngang, cao 38): `^C ^D ^Z ^R ^L ^B ^A ^E ^U ^W`, `Home`, `End`, `PgUp`, `PgDn`, 9 ký tự khó gõ (pipe, `~`, `/`, `-`, backtick, backslash, `*`, `$`, `&`), dán, ẩn/hiện bàn phím.
- Tuỳ chỉnh trong Cài đặt: bật/tắt hàng 2 (`showSecondKeyRow`, hàng 1 luôn hiện) hoặc ẩn/hiện từng phím, từng nhóm (`KeyBarCustomizationSheet`, lưu ở `hiddenKeyBarKeys`); ẩn hết phím của một hàng thì hàng đó không chiếm chỗ.
- Phản hồi rung (haptic): chạm phím rung `lightImpact`, khóa modifier (`locked`) rung `mediumImpact`, lặp phím mũi tên rung `selectionClick` mỗi nhịp.
- Ctrl/Alt/Shift là phím dính 3 trạng thái: chạm 1 = áp cho phím kế tiếp (nền xanh), chạm 2 = khóa (viền trắng), chạm 3 = tắt.
- Mũi tên giữ để lặp.
- Thanh phím chỉ hiện khi bàn phím ảo đang mở (`MediaQuery.viewInsetsOf(context).bottom > 0`) và thu/mở cùng lúc với bàn phím (không còn cảnh bàn phím đóng xong thanh phím mới biến mất làm terminal giật); chạm vào terminal để bật/tắt ([cu-chi-terminal.md](cu-chi-terminal.md)).
- Chưa có: đổi thứ tự phím, F1–F12.

## Code map

- `lib/key_bar.dart` — `KeyBarItem`, `KeyBarGroup`, `keyBarCatalog` (34 phím), `KeyBar` (lọc theo `hiddenKeys`, `showSecondRow`, bố cục 1–2 hàng), `_ModKey`, `_Key` (màu, lặp phím, haptic), `KeyBarCustomizationSheet` (tắt hàng 2 thì chỉ liệt kê phím hàng 1).
- `lib/modifiers.dart` — `Modifiers` (`ChangeNotifier`, `tap`/`consume`/`reset`), `applyModifiers`, `_ctrlChar`.
- `lib/key_handler.dart` — `FixedKeyHandler`: đổi `TerminalKey` + modifier thành chuỗi escape, rơi về `KeytabInputHandler` + `CtrlInputHandler` của xterm.
- `lib/terminal_screen.dart` — `_terminalScaffold` (thu/mở thanh phím cùng bàn phím), `_onInputAttachChanged`, `_onBarKey`, `_onBarText`, `_onBarRaw`, `_paste`, `_toggleKeyboard`, `_SettingsSheet`.

## Luồng xử lý

| Nút | Callback | Đi qua | Áp modifier |
|---|---|---|---|
| Esc, Tab, mũi tên, Home/End/PgUp/PgDn | `onKey` → `_onBarKey` | `Terminal.keyInput` → `FixedKeyHandler` | Có, rồi `consume` |
| 9 ký tự khó gõ | `onText` → `_onBarText` → `_onTyped` | `applyModifiers` → `Terminal.textInput` | Có, rồi `consume` |
| `^C` … `^W` | `onRaw` → `_onBarRaw` | gửi thẳng byte `chữ - 0x40` qua WS | Không |
| Dán | `_paste` | `Terminal.paste` (bracketed paste nếu chương trình bật) | Không |
| Ẩn bàn phím | `_toggleKeyboard` | `_hideKeyboard` / `TerminalInput.show` | — |
| Ctrl/Alt/Shift | `Modifiers.tap` | chỉ đổi trạng thái | — |

Các nút gửi input (phím, ký tự, `^X`, dán khi clipboard có chữ) gọi `TerminalInput.reset()` để xoá bộ đệm IME; Ctrl/Alt/Shift và ẩn bàn phím thì không.

## Dữ liệu & giao thức

- Trạng thái ẩn/hiện hàng 2 (`showSecondKeyRow`) và danh sách id phím ẩn (`hiddenKeyBarKeys`) lưu ở `SharedPreferences`: [cai-dat.md](cai-dat.md).
- Trạng thái modifier chỉ nằm trong bộ nhớ (`Modifiers`).
- Mọi phím ra WS dưới dạng khung input `0`: [api_specifications.md](../api_specifications.md#khung-tin-nhắn-ttyd-174).

## Quy tắc & lưu ý

- Chuỗi escape (`FixedKeyHandler`):
  - Mũi tên/Home/End: không modifier → `ESC [ X` (hoặc `ESC O X` khi chương trình bật cursor keys mode); có modifier → `ESC [1;<m>X`.
  - Insert/Delete/PgUp/PgDn: `ESC [n~`, có modifier → `ESC [n;<m>~`.
  - `<m>` = 1 + Shift(1) + Alt(2) + Ctrl(4) (chuẩn xterm).
  - Shift+Tab → `ESC [Z` (bỏ qua Alt).
  - Alt thêm tiền tố `ESC` cho Tab, Esc, Enter, Backspace và chữ A–Z; phím khác rơi về handler của xterm (không có `AltInputHandler`).
  - Ctrl+Backspace → `0x08`.
- `applyModifiers` chỉ áp khi chuỗi dài đúng 1 code unit: Shift → chữ hoa; Ctrl → mã điều khiển (`a-z`, `@`–`_`, space/`2` → NUL, `3` → ESC, `4`–`6` → 0x1c–0x1e, `7`/`-`/`/` → 0x1f, `8`/`?` → DEL, DEL → 0x08); Alt → tiền tố `ESC`.
- Lặp phím: chờ 400 ms rồi lặp mỗi 60 ms (`_KeyState._start`). Phím lặp dùng `Listener` (nhận ngay khi chạm), phím thường dùng `GestureDetector.onTap`.
- Màu: thường `0xFF3A3D43`, đang nhấn `0xFF52565E`, modifier bật `0xFF3B82F6`, khóa `0xFF2563EB` + viền trắng.
- Thu/mở cùng bàn phím (`_terminalScaffold`): `KeyBar` luôn nằm trong `ClipRect(AnimatedAlign(heightFactor))`, `heightFactor` = 1 khi `viewInsets.bottom > 0` và `TerminalInput.isAttached`, ngược lại 0, chạy 180 ms `easeOutCubic`. Chạm terminal để ẩn → `_hideKeyboard` đóng kết nối IME ngay → thanh phím thu lại song song lúc bàn phím trượt xuống. `TerminalInput.onAttachChanged` → `_onInputAttachChanged` `setState`. Không dùng focus vì `TerminalView._onTapDown` (xterm) tự `requestFocus` khi chạm. `KeyBar` bỏ padding đáy (`MediaQuery.removePadding`) để chiều cao không đổi giữa chừng. Giữ `resizeToAvoidBottomInset: true` để SnackBar vẫn nổi trên bàn phím.
- Thêm phím mới: thêm `_Key` vào `KeyBar`; phím cần modifier đi `onKey` (có `TerminalKey`) hoặc `onText`; mã điều khiển cố định đi `onRaw`.

## Còn để lại

- Bàn phím bị hệ điều hành đóng (nút Back Android, vuốt ẩn) thì IME chỉ tách khi inset về 0, nên thanh phím thu lại sau bàn phím (180 ms, mượt chứ không nhảy).
- Tắt hàng 2 thì sheet tuỳ chỉnh và bộ đếm chỉ tính phím hàng 1; mất nút Dán và Ẩn bàn phím trên thanh (vẫn chạm terminal để ẩn bàn phím, nhấn giữ để dán).
- Các nút `^X` bỏ qua trạng thái Ctrl/Alt đang bật và không `consume` chúng.
- Lỗi chưa sửa: `_onTyped` kiểm 1 rune nhưng `applyModifiers` kiểm 1 code unit, nên ký tự ngoài BMP (emoji) tiêu thụ modifier mà không áp (`lib/terminal_screen.dart` `_onTyped`, `lib/modifiers.dart` `applyModifiers`).
