# Nhập liệu từ bàn phím ảo (IME)

## Mục tiêu

Nhận chữ từ bàn phím ảo iOS/Android (kể cả gõ tiếng Việt, xoá, Enter) và chuyển thành input terminal, vì `TerminalView` của xterm chỉ dùng bàn phím cứng (`hardwareKeyboardOnly: true`).

## Phạm vi hiện tại

- Gõ chữ, xoá, Enter từ bàn phím ảo; ghép modifier dính của thanh phím vào ký tự vừa gõ.
- Tắt autocorrect, gợi ý, smart quotes/dashes, học cá nhân; bàn phím tối.
- Chạm vào terminal → bật/tắt bàn phím; nhấn giữ → menu Sao chép/Dán ([cu-chi-terminal.md](cu-chi-terminal.md)).

## Code map

- `lib/terminal_input.dart` — `TerminalInputState` (`TextInputClient`): `show`, `hide`, `isAttached` (báo đổi qua `onAttachChanged`), `reset`, `updateEditingValue`, `_emit`, `performAction`, `connectionClosed`.
- `lib/terminal_screen.dart` — `_onTyped`, `_onDelete`, `_onEnter` (nối IME với `Terminal` và `Modifiers`).

## Luồng xử lý

1. `show()` xin focus (nếu chưa có) rồi gắn `TextInput` với giá trị giả: 16 ký tự zero-width space (`\u200B`), con trỏ ở cuối.
2. `updateEditingValue`:
   - Đang có vùng composing (đang gõ dấu) → chờ, chưa gửi.
   - So text mới (đã bỏ `\u200B`) với `_typed` cũ theo rune: phần chung đầu giữ nguyên, phần cũ thừa = số lần xoá, phần mới = chữ thêm.
   - Số `\u200B` còn lại < 16 → cộng thêm số `\u200B` bị mất vào số lần xoá.
3. Xoá → `_onDelete(count)`: có modifier và `count == 1` → `keyInput(backspace)` có Ctrl/Alt; còn lại gửi `0x7f` × count.
4. Chữ thêm → `_emit`: tách theo xuống dòng; mỗi đoạn → `_onTyped`, mỗi dấu xuống dòng → `_onEnter`.
5. `_onTyped`: có modifier và đúng 1 rune → `applyModifiers` rồi `consume`, yêu cầu reset bộ đệm; ngược lại gửi nguyên.
6. Nút Done/Return (`performAction`) → `_onEnter` + `reset`.
7. Reset bộ đệm khi: vừa áp modifier, vừa Enter, mất bất kỳ `\u200B` nào (`padLeft < _pad`), gõ dấu cách khi bộ đệm > 40 rune, hoặc bộ đệm > 200 rune.

## Dữ liệu & giao thức

- Không lưu gì; bộ đệm `_typed` chỉ trong bộ nhớ.
- Output qua `Terminal.textInput`/`keyInput` → khung input `0`: [api_specifications.md](../api_specifications.md#khung-tin-nhắn-ttyd-174).

## Quy tắc & lưu ý

- Bộ đệm `_typed` giữ chữ đã gõ trong từ hiện tại để IME còn sửa được (gõ dấu, gợi ý).
- Đệm `\u200B` để phím xoá luôn có ký tự để xoá khi bộ đệm rỗng.
- So khác biệt theo rune, không theo code unit.
- Có focus không tự mở bàn phím (`_onFocus` chỉ đóng kết nối khi mất focus), vì xterm `requestFocus` ở mọi lần chạm; mở/đóng do `_TerminalScreenState` quyết định.
- Hằng số trong `lib/terminal_input.dart`: `_pad = 16`, `_maxBuffer = 200`, ngưỡng reset khi gõ cách `40`.
- Dán từ menu/thanh gợi ý của bàn phím ảo đi qua `_emit`: văn bản nhiều dòng bị tách và **gửi Enter sau từng dòng** (lệnh chạy ngay). Nút Dán trên thanh phím dùng `Terminal.paste` (bracketed paste), an toàn hơn.

## Còn để lại

- Chưa có test tự động cho thuật toán so khác biệt; kiểm thủ công theo [testing.md](../testing.md).
