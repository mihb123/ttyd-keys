# Cử chỉ trên terminal

## Mục tiêu

Dùng terminal bằng tay trên điện thoại: chạm để bật/tắt bàn phím ảo, nhấn giữ để sao chép/dán với clipboard hệ thống, hai ngón tay để phóng to/thu nhỏ chữ.

## Phạm vi hiện tại

- Chạm một lần vào terminal: bàn phím ảo đang mở thì đóng, đang đóng thì mở. Thanh phím chỉ hiện khi bàn phím ảo đang mở và thu/mở cùng lúc với bàn phím ([thanh-phim.md](thanh-phim.md)); đóng bàn phím thì terminal chiếm hết chiều cao.
- Vuốt dọc để xem nội dung cũ:
  - Buffer chính (shell thường): cuộn mượt tối đa 10.000 dòng kèm thanh cuộn (`Scrollbar`) và nút nổi `↓` để về cuối; gõ phím tự cuộn về cuối.
  - Alternate buffer (`tmux`, `vim`, `less`…): vuốt có quán tính (`FrictionSimulation`), đổi đúng toạ độ cục bộ của `RenderTerminal` để gửi sự kiện cuộn chuột (`wheelUp`/`wheelDown`, hoặc rơi về `↑`/`↓` nếu chương trình không bật mouse).
- Nhấn giữ (hoặc chạm đúp) để chọn chữ và sao chép:
  - Nhấn giữ lên từ (hoặc ký tự dấu) → rung nhẹ, chọn từ/ký tự đó; có thể kéo luôn khi đang giữ (qua được cả khoảng trắng và dấu) hoặc nhả tay rồi kéo hai đầu giọt nước (`TerminalSelectionHandles`, tự cuộn khi kéo sát mép trên/dưới ở buffer chính).
  - Menu nổi "Sao chép", "Dán", "Chọn tất cả" neo phía trên vùng chọn (không che hai đầu kéo). Sao chép xong hiện "Đã sao chép".
- Đang có vùng chọn/menu: chạm ngoài hai đầu kéo sẽ bỏ chọn và đóng menu (không bật/tắt bàn phím). Gõ phím cũng đóng menu.
- Hai ngón tay chụm/mở: đổi cỡ chữ 1–24, bước 0.5, nhãn "N pt" giữa màn hình khi đang kéo; nhả tay thì lưu cỡ chữ.
- Chưa có: chọn khối (block selection).

## Code map

- `lib/terminal_screen.dart` — `_TerminalScreenState`: `_onPointerDown/Move/Up/Cancel`, `_startLongPressSelection`, `_updateLongPressSelection`, `_onAltScrollStart/Update/End`, `_onAltFlingTick`, `_onTerminalStateChanged`, `_onScrollPositionChanged`, `_scrollToBottom`, `_toggleKeyboard`, `_hideKeyboard`, `_showContextMenu`, `_menuAnchors`, `_copySelection`, `_selectAll`, `_dismissSelectionAndMenu`, `_onPinchStart/Update/End`.
- `lib/selection_handles.dart` — `TerminalSelectionHandles`: hai đầu kéo vùng chọn (bắt đầu/kết thúc), vùng chạm 44×44, rung mỗi lần đổi ô, tự cuộn sát mép.
- `lib/key_handler.dart` — `FixedMouseHandler`: sửa mã cuộn chuột của xterm 4.0.0 (`wheelUp` = 64, `wheelDown` = 65 thay vì 68/69 kèm bit Shift khiến tmux bỏ qua) và sửa lệch dòng ở chế độ normal/utf.
- `lib/terminal_gestures.dart` — `PinchGestureRecognizer` (chỉ nhận khi ≥ 2 ngón), `TerminalScrollBehavior`, `snapFontSize`, `formatFontSize`, `minTerminalFontSize` (1), `maxTerminalFontSize` (24), `terminalFontSizeDivisions` (46).
- `lib/terminal_input.dart` — `TerminalInputState.show`, `hide`, `isAttached`.

## Luồng xử lý

1. `TerminalView` bọc trong `Listener` (không vào gesture arena), `RawGestureDetector` (`PinchGestureRecognizer` và thêm `VerticalDragGestureRecognizer` khi ở alternate buffer), `ScrollConfiguration(TerminalScrollBehavior)` và `Scrollbar`; `TerminalSelectionHandles` nằm trên `TerminalView` trong cùng `Stack`.
2. Cuộn dọc:
   - Buffer chính: `TerminalScrollBehavior` dùng vật lý cuộn nền tảng (iOS không ép `AlwaysScrollableScrollPhysics`), `TerminalView` tự cuộn `ScrollController`; khi cuộn lên quá 1.5 dòng thì hiện nút `↓`.
   - Alternate buffer: `TerminalScrollBehavior` tắt cuộn nội bộ (`NeverScrollableScrollPhysics`, tránh `InfiniteScrollView` của xterm dùng toạ độ toàn cục và bị `Scrollable` trong cướp trên iOS); `VerticalDragGestureRecognizer` tích luỹ `dy` theo `lineHeight`, nhả tay chạy `FrictionSimulation` và gửi `wheelUp`/`wheelDown` (hoặc `↑`/`↓`). Chuyển vào alternate buffer sẽ đặt `ScrollController` về `0`.
3. Nhấn giữ chọn chữ:
   - Giữ đủ `kLongPressTimeout` → rung `mediumImpact`, `_startLongPressSelection` chọn từ (hoặc 1 ký tự nếu là dấu), giữ tay kéo sẽ mở rộng liên tục.
   - Nhả tay → hiện hai đầu kéo `TerminalSelectionHandles` và `_showContextMenu` neo phía trên vùng chọn (không đặt lớp chặn toàn màn hình để hai đầu kéo luôn kéo được).
   - Kéo một đầu kéo → ẩn menu tạm thời, giữ cố định đầu kia, cập nhật vùng chọn theo từng ô kèm `selectionClick`, tự cuộn khi sát mép 36 px; nhả tay thì hiện lại menu.
   - Khi đang có vùng chọn, `setSuspendPointerInput(true)` chặn gửi sự kiện chuột sang tmux.
4. Sao chép: `Terminal.buffer.getText(selection)` → `Clipboard.setData`. Dán: `_paste` (`Terminal.paste`, bracketed paste). Chọn tất cả: chọn các dòng đang thấy trong khung nhìn hiện tại.
5. Ngón thứ hai chạm → `PinchGestureRecognizer` thắng arena, loại cuộn/chạm/nhấn giữ; `_onPinchStart` tạm `setSuspendPointerInput(true)`, `_onPinchUpdate` đặt `fontSize = snapFontSize(gốc × scale)`, `_onPinchEnd` khôi phục và `Settings.save()`.
6. Bàn phím bị hệ điều hành đóng (vuốt xuống) → `viewInsets.bottom` về 0 → frame sau gọi `_hideKeyboard` để lần chạm sau mở lại được ngay.

## Dữ liệu & giao thức

- Cỡ chữ lưu ở key `fontSize` (chi tiết: [cai-dat.md](cai-dat.md)); đổi cỡ chữ làm terminal đổi cột/dòng và gửi khung resize ([api_specifications.md](../api_specifications.md)).

## Quy tắc & lưu ý

- `TerminalView` của xterm 4.0.0 không gọi `onTapUp` truyền vào (chỉ `onSingleTapUp` nội bộ) và luôn `requestFocus` khi chạm xuống, nên chạm được bắt bằng `Listener`, và `TerminalInput` không còn tự mở bàn phím khi có focus (`_onFocus` chỉ đóng kết nối khi mất focus).
- Không bọc thêm `GestureDetector(onLongPress…)`: `LongPressGestureRecognizer` của xterm sẽ thắng và recognizer ngoài bị loại; nhấn giữ được nhận bằng hẹn giờ trong `Listener`.
- Menu nằm trên `Overlay`: khoá app (`_lockNow`) và lúc app ra nền phải gọi `_dismissSelectionAndMenu`, nếu không menu nổi trên màn khoá.
- Bàn phím cứng (không có `viewInsets`) thì thanh phím bị ẩn.

## Còn để lại

- Trong `tmux`, để vuốt dọc cuộn được lịch sử của tmux cần bật `set -g mouse on` trên server; khi `mouse off`, vuốt trong alternate buffer chỉ gửi phím `↑`/`↓`.
- Chạm 2 ngón lệch nhau > 100 ms khi chương trình bật chuột (tmux mouse): xterm có thể đã gửi "nhấn chuột" trước khi pinch thắng, không gửi "nhả".
- Đang cuộn một ngón rồi mới đặt ngón thứ hai: không pinch được, phải nhả tay làm lại.
- Chạm đúp nhanh để mở rồi đóng bàn phím: lần chạm 2 thành chọn từ và hiện menu.
- Mỗi bước 0.5 khi pinch gửi một khung resize lên server (chưa gộp).
- Chưa thử trên máy thật.
