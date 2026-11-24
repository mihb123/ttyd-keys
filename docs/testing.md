# Kiểm thử

| Lớp | Lệnh | Khi nào |
|---|---|---|
| Lint / phân tích tĩnh | `make analyze` | Mỗi thay đổi Dart |
| Tài liệu | `make docs-check` | Mỗi thay đổi `.md` |
| Build thật | push `main` → GitHub Actions, `make ios-ipa` / `make android-apk` | Trước khi cài lên máy |
| Thủ công trên điện thoại | checklist bên dưới | Thay đổi kết nối, bàn phím, thanh phím |

Chưa có thư mục `test/`. Chỗ nên thêm unit test đầu tiên (`flutter test`): `applyModifiers`, `Modifiers`, `FixedKeyHandler`, `normalizeHost` (đều public, không cần widget). `_onMessage` là private, muốn test phải tách parser khung ra hàm public.

## Checklist thủ công

| Kịch bản | Mong đợi | Tài liệu |
|---|---|---|
| Đăng nhập đúng, bật "Nhớ mật khẩu", tắt app mở lại | Vào thẳng terminal, đèn xanh | [ket-noi-ttyd.md](feature/ket-noi-ttyd.md) |
| Sai mật khẩu | "Sai username hoặc mật khẩu." | [ket-noi-ttyd.md](feature/ket-noi-ttyd.md) |
| Kết nối > 5 s, tắt mạng vài giây rồi bật / đưa app xuống nền rồi mở lại | `[Mất kết nối]`, tự nối lại | [ket-noi-ttyd.md](feature/ket-noi-ttyd.md) |
| Lệnh tự chạy mặc định `tmux new -A -s mobile`, rớt mạng | Nối lại đúng phiên tmux cũ | [cai-dat.md](feature/cai-dat.md) |
| Ctrl chạm 1 lần + gõ `c` | Gửi `^C`, Ctrl tự tắt | [thanh-phim.md](feature/thanh-phim.md) |
| Ctrl chạm 2 lần + gõ nhiều chữ | Ctrl giữ nguyên (viền trắng) | [thanh-phim.md](feature/thanh-phim.md) |
| Giữ `←` trong shell | Con trỏ chạy liên tục | [thanh-phim.md](feature/thanh-phim.md) |
| Gõ tiếng Việt có dấu, xoá lùi nhiều lần | Chữ đúng, xoá đúng số ký tự | [nhap-ban-phim-ao.md](feature/nhap-ban-phim-ao.md) |
| Dán nhiều dòng bằng nút Dán của thanh phím trong bash/zsh | Nội dung hiện đủ, không tự chạy từng dòng (bracketed paste) | [thanh-phim.md](feature/thanh-phim.md) |
| Đổi cỡ chữ | Terminal vẽ lại, `tput cols` đổi | [cai-dat.md](feature/cai-dat.md) |
