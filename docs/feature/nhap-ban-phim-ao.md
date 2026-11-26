# Nhập liệu từ bàn phím ảo (IME)

## Mục tiêu

Nhận chữ từ bàn phím ảo iOS/Android (kể cả gõ tiếng Việt, xoá, Enter) và chuyển thành input terminal, vì `TerminalView` của xterm chỉ dùng bàn phím cứng (`hardwareKeyboardOnly: true`).

## Phạm vi hiện tại

- Gõ chữ, xoá, Enter từ bàn phím ảo; ghép modifier dính của thanh phím vào ký tự vừa gõ.
- Bộ gõ tiếng Việt Telex: gõ `w` một lần ra `w`/`W` (bộ gõ chèn `ư`/`Ư` mới, không thay chữ nào thì gửi `w`/`W`), nên lệnh như `whoami`, prefix+w của tmux, Ctrl+w chạy mà không cần đổi bộ gõ. Muốn ra `ư` thì gõ `uw` (bộ gõ thay `u` bằng `ư`, giữ nguyên).
- Tắt autocorrect, gợi ý, smart quotes/dashes, học cá nhân; bàn phím tối.
- Chạm vào terminal → bật/tắt bàn phím; nhấn giữ → menu Sao chép/Dán ([cu-chi-terminal.md](cu-chi-terminal.md)).

## Code map

- `lib/terminal_input.dart` — `TerminalInputState` (`TextInputClient`): `show`, `hide`, `isAttached` (báo đổi qua `onAttachChanged`), `reset`, `updateEditingValue`, `_emit`, `performAction`, `connectionClosed`.
- `lib/terminal_input.dart` — `_telexW` (bảng `ư`→`w`).
- `lib/terminal_screen.dart` — `_onTyped`, `_onDelete`, `_onEnter` (nối IME với `Terminal` và `Modifiers`).

## Luồng xử lý

1. `show()` xin focus (nếu chưa có) rồi gắn `TextInput` với giá trị giả: 16 ký tự zero-width space (`\u200B`), con trỏ ở cuối.
2. `updateEditingValue`:
   - Đang có vùng composing (đang gõ dấu) → chờ, chưa gửi.
   - So text mới (đã bỏ `\u200B`) với `_typed` cũ theo rune: phần chung đầu giữ nguyên, phần cũ thừa = số lần xoá, phần mới = chữ thêm.
   - Số `\u200B` giảm so với lần trước (`_padLeft`) khi bộ đệm chữ đã rỗng và lần này không thêm chữ (phím xoá thật) → cộng số `\u200B` mất vào số lần xoá. Còn chữ trong bộ đệm (giữ phím xoá iOS xoá cả từ lẫn đệm) hoặc có thêm chữ thì bỏ qua: Telex soạn lại từ có thể ăn `\u200B` (U+200B không phải ranh giới từ).
   - Không xoá chữ cũ nào và phần mới đúng là `ư`/`Ư` → đổi thành `w`/`W` và reset bộ đệm, để Telex không ghép `ư` với phím sau (vd `ưr` → `ử`).
3. Xoá → `_onDelete(count)`: có modifier và `count == 1` → `keyInput(backspace)` có Ctrl/Alt; còn lại gửi `0x7f` × count.
4. Chữ thêm → `_emit`: tách theo xuống dòng; mỗi đoạn → `_onTyped`, mỗi dấu xuống dòng → `_onEnter`.
5. `_onTyped`: có modifier và đúng 1 rune → `applyModifiers` rồi `consume`, yêu cầu reset bộ đệm; ngược lại gửi nguyên.
6. Nút Done/Return (`performAction`) → `_onEnter` + `reset`.
7. Reset bộ đệm khi: vừa đổi `ư`→`w`, vừa áp modifier, vừa Enter, thiếu `\u200B` mà bộ đệm chữ đã rỗng hoặc vừa gõ dấu cách (không reset giữa từ đang soạn), gõ dấu cách khi bộ đệm > 40 rune, hoặc bộ đệm > 200 rune.

## Dữ liệu & giao thức

- Không lưu gì; bộ đệm `_typed` chỉ trong bộ nhớ.
- Output qua `Terminal.textInput`/`keyInput` → khung input `0`: [api_specifications.md](../api_specifications.md#khung-tin-nhắn-ttyd-174).

## Quy tắc & lưu ý

- Chỉ đổi `ư` do bộ gõ chèn mới; `ư` thay cho `u` (`uw`, `tuw`, `nguoiw` → `ngươi`) giữ nguyên. `tw` ra `tw`, không ra `tư`. `[`/`]` (Telex mở rộng ra `ư`/`ơ`) không đổi.
- Bộ đệm `_typed` giữ chữ đã gõ trong từ hiện tại để IME còn sửa được (gõ dấu, gợi ý).
- Đệm `\u200B` để phím xoá luôn có ký tự để xoá khi bộ đệm rỗng.
- So khác biệt theo rune, không theo code unit.
- Có focus không tự mở bàn phím (`_onFocus` chỉ đóng kết nối khi mất focus), vì xterm `requestFocus` ở mọi lần chạm; mở/đóng do `_TerminalScreenState` quyết định.
- Hằng số trong `lib/terminal_input.dart`: `_pad = 16`, `_maxBuffer = 200`, ngưỡng reset khi gõ cách `40`.
- Dán từ menu/thanh gợi ý của bàn phím ảo đi qua `_emit`: văn bản nhiều dòng bị tách và **gửi Enter sau từng dòng** (lệnh chạy ngay). Nút Dán trên thanh phím dùng `Terminal.paste` (bracketed paste), an toàn hơn.

## Còn để lại

- Chưa có test tự động cho thuật toán so khác biệt; kiểm thủ công theo [testing.md](../testing.md).
- Gõ `ww` theo thói quen Telex cũ giờ ra `ww` (sau prefix tmux: `w` đầu mở danh sách window, `w` thứ hai gửi vào `choose-tree`).
- Chưa kiểm chứng trên iPhone thật việc bàn phím Telex bỏ ngữ cảnh `ư` sau khi app reset; nếu không, phím dấu ngay sau (`s f r x j`) có thể ra chữ có dấu.
