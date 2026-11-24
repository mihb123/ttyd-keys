# Cử chỉ trên terminal

## Mục tiêu

Dùng terminal bằng tay trên điện thoại: chạm để bật/tắt bàn phím ảo, nhấn giữ để sao chép/dán với clipboard hệ thống, hai ngón tay để phóng to/thu nhỏ chữ.

## Phạm vi hiện tại

- Chạm một lần vào terminal: bàn phím ảo đang mở thì đóng, đang đóng thì mở. Thanh phím chỉ hiện khi bàn phím ảo đang mở; đóng bàn phím thì terminal chiếm hết chiều cao.
- Nhấn giữ (hoặc chạm đúp) lên chữ: chọn từ, kéo để mở rộng; nhả tay hiện menu "Sao chép", "Dán", "Chọn tất cả" (chọn các dòng đang thấy). Nhấn giữ chỗ trống: menu chỉ có "Dán". Sao chép xong hiện "Đã sao chép".
- Đang có vùng chọn/menu: chạm lần đầu chỉ bỏ chọn, đóng menu (không bật/tắt bàn phím). Gõ phím cũng đóng menu.
- Hai ngón tay chụm/mở: đổi cỡ chữ 9–24, bước 0.5, nhãn "N pt" giữa màn hình khi đang kéo; nhả tay thì lưu cỡ chữ.
- Chưa có: kéo hai đầu vùng chọn sau khi nhả tay, chọn khối.

## Code map

- `lib/terminal_screen.dart` — `_TerminalScreenState`: `_onPointerDown/Move/Up/Cancel` (phân biệt chạm, nhấn giữ, nhiều ngón bằng `Listener`), `_toggleKeyboard`, `_hideKeyboard`, `_isKeyboardOpen`, `_showContextMenu`, `_copySelection`, `_selectAll`, `_dismissSelectionAndMenu`, `_onPinchStart/Update/End`; `_terminalScaffold` chỉ dựng `KeyBar` khi `viewInsets.bottom > 0`.
- `lib/terminal_gestures.dart` — `PinchGestureRecognizer` (chỉ nhận khi ≥ 2 ngón), `snapFontSize`, `formatFontSize`, `minTerminalFontSize`/`maxTerminalFontSize`.
- `lib/terminal_input.dart` — `TerminalInputState.show`, `hide`, `isAttached`.

## Luồng xử lý

1. `TerminalView` bọc trong `Listener` (không vào gesture arena, nên chuột cho tmux/vim của xterm vẫn chạy) và `RawGestureDetector` có `PinchGestureRecognizer`.
2. Chạm xuống một ngón → ghi vị trí, bàn phím đang mở hay không, có vùng chọn/menu không; hẹn `kLongPressTimeout` để đánh dấu nhấn giữ (kèm rung nhẹ).
3. Nhả tay:
   - Đã nhấn giữ → `_showContextMenu` (`ContextMenuController` + `AdaptiveTextSelectionToolbar.buttonItems`).
   - Kéo quá `touchSlop` hoặc dùng nhiều ngón → bỏ qua (cuộn/pinch).
   - Trước đó có vùng chọn/menu → `_dismissSelectionAndMenu`.
   - Có vùng chọn mới (chạm đúp) → hiện menu.
   - Còn lại → bàn phím đang mở thì `_hideKeyboard` (đóng `TextInputConnection` + `unfocus`), không thì `TerminalInput.show`.
4. Sao chép: `Terminal.buffer.getText(selection)` → `Clipboard.setData`. Dán: `_paste` (`Terminal.paste`, bracketed paste).
5. Ngón thứ hai chạm → `PinchGestureRecognizer` thắng arena, loại cuộn/chạm/nhấn giữ của xterm; `_onPinchStart` tạm `setSuspendPointerInput(true)`, `_onPinchUpdate` đặt `fontSize = snapFontSize(gốc × scale)`, `_onPinchEnd` mở lại input chuột và `Settings.save()`.
6. Bàn phím bị hệ điều hành đóng (vuốt xuống) → `viewInsets.bottom` về 0 → frame sau gọi `_hideKeyboard` để lần chạm sau mở lại được ngay.

## Dữ liệu & giao thức

- Cỡ chữ lưu ở key `fontSize` (chi tiết: [cai-dat.md](cai-dat.md)); đổi cỡ chữ làm terminal đổi cột/dòng và gửi khung resize ([api_specifications.md](../api_specifications.md)).

## Quy tắc & lưu ý

- `TerminalView` của xterm 4.0.0 không gọi `onTapUp` truyền vào (chỉ `onSingleTapUp` nội bộ) và luôn `requestFocus` khi chạm xuống, nên chạm được bắt bằng `Listener`, và `TerminalInput` không còn tự mở bàn phím khi có focus (`_onFocus` chỉ đóng kết nối khi mất focus).
- Không bọc thêm `GestureDetector(onLongPress…)`: `LongPressGestureRecognizer` của xterm sẽ thắng và recognizer ngoài bị loại; nhấn giữ được nhận bằng hẹn giờ trong `Listener`.
- Menu nằm trên `Overlay`: khoá app (`_lockNow`) và lúc app ra nền phải gọi `_dismissSelectionAndMenu`, nếu không menu nổi trên màn khoá.
- Bàn phím cứng (không có `viewInsets`) thì thanh phím bị ẩn.

## Còn để lại

- Chạm 2 ngón lệch nhau > 100 ms khi chương trình bật chuột (tmux mouse): xterm có thể đã gửi "nhấn chuột" trước khi pinch thắng, không gửi "nhả".
- Đang cuộn một ngón rồi mới đặt ngón thứ hai: không pinch được, phải nhả tay làm lại.
- Chạm đúp nhanh để mở rồi đóng bàn phím: lần chạm 2 thành chọn từ và hiện menu.
- Mỗi bước 0.5 khi pinch gửi một khung resize lên server (chưa gộp).
- Chưa thử trên máy thật.
