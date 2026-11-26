# Kiểm thử

| Lớp | Lệnh | Khi nào |
|---|---|---|
| Lint / phân tích tĩnh | `make analyze` | Mỗi thay đổi Dart |
| Tài liệu | `make docs-check` | Mỗi thay đổi `.md` |
| Build thật | push `main` → GitHub Actions build iOS, `make install-ios` / `make install-android` (Android build theo yêu cầu; tải đúng build của commit rồi cài qua USB) | Trước khi thử trên máy thật |
| Thủ công trên điện thoại | checklist bên dưới | Thay đổi kết nối, bàn phím, thanh phím |

Chưa có thư mục `test/`. Chỗ nên thêm unit test đầu tiên (`flutter test`): `applyModifiers`, `Modifiers`, `FixedKeyHandler`, `normalizeHost` (đều public, không cần widget). `_onMessage` là private, muốn test phải tách parser khung ra hàm public.

## Checklist thủ công

| Kịch bản | Mong đợi | Tài liệu |
|---|---|---|
| Đăng nhập đúng, tắt app mở lại | Màn khoá + Face ID tự bật; xác thực xong thấy terminal, đèn xanh | [khoa-app.md](feature/khoa-app.md) |
| Sang app khác < 10 phút rồi quay lại | Không hỏi Face ID; mất kết nối thì tự nối lại | [khoa-app.md](feature/khoa-app.md) |
| Sang app khác ≥ 10 phút (hoặc khoá màn hình) rồi quay lại | Màn khoá, Face ID; sheet Cài đặt đang mở bị đóng | [khoa-app.md](feature/khoa-app.md) |
| Máy không có Face ID/vân tay, đăng nhập lần đầu | Bắt tạo mã PIN 4 số (nhập 2 lần) | [khoa-app.md](feature/khoa-app.md) |
| Nhập sai PIN 10 lần | Báo còn N lần; lần 10 về màn đăng nhập "Nhập sai mã PIN quá 10 lần, đã đăng xuất." | [khoa-app.md](feature/khoa-app.md) |
| Chạm terminal khi bàn phím mở / đóng | Đóng / mở bàn phím; thanh phím ẩn/hiện theo | [cu-chi-terminal.md](feature/cu-chi-terminal.md) |
| Nhấn giữ lên chữ hoặc dấu, nhả ra kéo 2 đầu giọt nước → Sao chép; nhấn giữ chỗ trống → Dán | Hai đầu kéo bám đúng vùng chọn, tự cuộn sát mép; clipboard có chữ đã chọn, "Đã sao chép" | [cu-chi-terminal.md](feature/cu-chi-terminal.md) |
| Vuốt dọc xem dòng cũ (shell thường và trong tmux có `set -g mouse on`) | Cuộn mượt lên dòng cũ (shell thường hiện nút `↓` về cuối, tmux vào copy-mode cuộn đúng pane) | [cu-chi-terminal.md](feature/cu-chi-terminal.md) |
| Hai ngón tay chụm/mở xuống 6 pt, tắt app mở lại | Cỡ chữ giảm được tới 6 pt, nhãn "6 pt"; cỡ chữ được giữ | [cu-chi-terminal.md](feature/cu-chi-terminal.md) |
| Cài đặt tắt thanh phím / ẩn bớt phím / bấm phím custom | Thanh phím ẩn hoặc chỉ hiện phím đã chọn; mỗi phím rung haptic khi bấm | [thanh-phim.md](feature/thanh-phim.md) |
| Chữ tiếng Việt có dấu (`[Mất kết nối]`), thanh trạng thái tmux có icon | Dấu nằm đúng trên chữ, icon hiện đúng (không còn ô `?`) | [cai-dat.md](feature/cai-dat.md) |
| Sai mật khẩu | "Sai username hoặc mật khẩu." | [ket-noi-ttyd.md](feature/ket-noi-ttyd.md) |
| Cập nhật từ bản một host | Server cũ thành server đầu tiên, không phải đăng nhập lại | [nhieu-server.md](feature/nhieu-server.md) |
| Thêm server thứ 2, vuốt từ mép trái chuyển qua lại | Sidebar mở; server cũ vẫn xanh, lịch sử cuộn còn nguyên, không chạy lại lệnh tự chạy | [nhieu-server.md](feature/nhieu-server.md) |
| Cài đặt → Chuyển server: Thanh tab; mở 3 server, bấm × tab đang xem | Header thành dải tab, không vuốt mở sidebar được; × đóng tab, chuyển sang tab bên phải; + liệt kê server chưa mở | [nhieu-server.md](feature/nhieu-server.md) |
| Nhấn giữ server → Ngắt kết nối / Xoá server; xoá server cuối cùng | Chấm xám / server biến mất; xoá hết thì về màn đăng nhập trống | [nhieu-server.md](feature/nhieu-server.md) |
| Đổi mật khẩu trên server rồi mở lại app | Chỉ server đó hiện form nhập mật khẩu, server khác vẫn dùng được | [nhieu-server.md](feature/nhieu-server.md) |
| Kết nối > 5 s, tắt mạng vài giây rồi bật / đưa app xuống nền rồi mở lại | `[Mất kết nối]`, tự nối lại | [ket-noi-ttyd.md](feature/ket-noi-ttyd.md) |
| Lệnh tự chạy mặc định `tmux new -A -s mobile`, rớt mạng | Nối lại đúng phiên tmux cũ | [cai-dat.md](feature/cai-dat.md) |
| Ctrl chạm 1 lần + gõ `c` | Gửi `^C`, Ctrl tự tắt | [thanh-phim.md](feature/thanh-phim.md) |
| Ctrl chạm 2 lần + gõ nhiều chữ | Ctrl giữ nguyên (viền trắng) | [thanh-phim.md](feature/thanh-phim.md) |
| Giữ `←` trong shell | Con trỏ chạy liên tục | [thanh-phim.md](feature/thanh-phim.md) |
| Gõ tiếng Việt có dấu, xoá lùi nhiều lần | Chữ đúng, xoá đúng số ký tự | [nhap-ban-phim-ao.md](feature/nhap-ban-phim-ao.md) |
| Dán nhiều dòng bằng nút Dán của thanh phím trong bash/zsh | Nội dung hiện đủ, không tự chạy từng dòng (bracketed paste) | [thanh-phim.md](feature/thanh-phim.md) |
| Đổi cỡ chữ | Terminal vẽ lại, `tput cols` đổi | [cai-dat.md](feature/cai-dat.md) |
