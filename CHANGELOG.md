# Changelog

Mỗi commit thay đổi tính năng, sửa lỗi, build hoặc tài liệu thêm một dòng dưới ngày commit (`## YYYY-MM-DD`, mới nhất ở trên), **trong chính commit đó**:

```markdown
- Thanh phím: thêm phím F1–F12 ([thanh-phim](docs/feature/thanh-phim.md)).
- Sửa: tự nối lại sau khi đăng xuất.
```

- Mở đầu bằng nhóm (`Kết nối`, `Thanh phím`, `Bàn phím ảo`, `Cài đặt`, `Build`, `Tài liệu`, tên tính năng mới) hoặc `Sửa:`. Nói người dùng thấy gì thay đổi, không kể quá trình; link feature tuỳ chọn.
- Không ghi hash (commit không chứa được hash của chính nó); cần hash thì `git blame CHANGELOG.md`. Dòng cũ có hash giữ nguyên.
- Không tạo commit riêng cho changelog: `git add CHANGELOG.md <file đã sửa> && git commit`.

## 2026-11-27

- Tài liệu: tên commit theo dạng `type(scope): mô tả` như repo central, vd `feat(nhieu-server): …`, `fix(ios): …` ([AGENTS.md](AGENTS.md#commit)).
- Nhiều server: Cài đặt có thêm mục "Chuyển server" để chọn sidebar hoặc thanh tab ở header kiểu Ghostty (tab đang xem nổi bật, × đóng tab, + mở server khác) ([nhieu-server](docs/feature/nhieu-server.md)).
- Nhiều server: mỗi server đăng nhập một lần, vuốt từ mép trái (hoặc nút ☰) mở danh sách server để chuyển qua lại, server đã mở giữ kết nối; thêm/sửa/ngắt/xoá server, lệnh tự chạy riêng từng server, bỏ ô "Nhớ mật khẩu" (luôn lưu) ([nhieu-server](docs/feature/nhieu-server.md)).
- Build: đổi tên app thành **TapShell** và thay icon mặc định của Flutter bằng logo mới (terminal `>_` + thanh phím), cả iOS và Android adaptive.
- Tài liệu: agent làm xong việc thì tự push `main` và theo dõi CI tới khi xanh ([AGENTS.md](AGENTS.md#commit)).

## 2026-11-26

- Bàn phím ảo: bộ gõ Telex gõ `w` một lần ra `w` (không cần `ww`); muốn `ư` gõ `uw` ([nhap-ban-phim-ao](docs/feature/nhap-ban-phim-ao.md)).
- Sửa: bộ gõ Telex gõ `ww` rồi gõ tiếp (vd `whoami`) không còn mất chữ `w` ([nhap-ban-phim-ao](docs/feature/nhap-ban-phim-ao.md)).
- Sửa: `cat` trong tmux hiện đủ tới prompt cuối, không còn đứng giữa chừng phải vuốt xuống; lỗi `ESC[1K` của xterm 4 làm parser ném lỗi ([ket-noi-ttyd](docs/feature/ket-noi-ttyd.md)).
- Sửa: tmux prefix+w gõ bằng bộ gõ Telex (`w` thành `ư`) vẫn mở danh sách window ([nhap-ban-phim-ao](docs/feature/nhap-ban-phim-ao.md)).

## 2026-11-25

- Tài liệu: dòng CHANGELOG commit chung với thay đổi, không ghi hash, không tách commit riêng.
- `a481564` Sửa: `cat` file lớn bám sát output thật và về cuối ngay khi xong; ttyd 1.7.4 bỏ qua PAUSE nên app dừng đọc socket để chặn server ([ket-noi-ttyd](docs/feature/ket-noi-ttyd.md)).
- `cf0a377` Sửa: in output lớn (vd `cat` file dài) không còn treo app; output ghi dần theo frame và tạm dừng server khi tồn đọng ([ket-noi-ttyd](docs/feature/ket-noi-ttyd.md)).
- `e7b1abb` Tài liệu: AGENTS.md thêm quy tắc commit ngay khi xong (không push, mỗi agent tự commit phần mình) và chỉ dùng Gemini 4 Neon khi giao agy viết code; CHANGELOG ghi hash commit cho từng dòng.
- `d8d89f4` Kết nối: nút lớn "Kết nối lại" khi mất kết nối và mục menu ⋮ "Kết nối lại" ép nối lại; Cài đặt: cỡ chữ nhỏ nhất 1 pt, công tắc chỉ ẩn hàng phím thứ hai; Thanh phím: trượt cùng bàn phím ảo khi đóng/mở, hết giật ([thanh-phim](docs/feature/thanh-phim.md)).
- `08e9e69` Thanh phím: cho phép ẩn cả thanh hoặc chọn ẩn/hiện từng phím trong Cài đặt, kèm phản hồi rung haptic khi bấm ([thanh-phim](docs/feature/thanh-phim.md)); Cài đặt: giảm cỡ chữ nhỏ nhất xuống 6 pt ([cai-dat](docs/feature/cai-dat.md)); Cử chỉ: sửa vuốt dọc xem nội dung cũ (buffer chính + alternate buffer/tmux) và bổ sung 2 đầu kéo chọn chữ kiểu mobile để sao chép ([cu-chi-terminal](docs/feature/cu-chi-terminal.md)).
- `cbd4ea5` Build: push `main` chỉ build iOS; Android chỉ build khi chạy `make android-apk` / `make install-android` (tự gọi `build-android.yml` rồi tải về).
- `7bdeca8` Khoá app: mở app bằng mật khẩu đã nhớ phải mở khoá bằng Face ID (máy không có thì mã PIN 4 số, sai 10 lần tự đăng xuất); rời app từ 10 phút trở lên thì khoá lại; màn đen che terminal trong trình chuyển app ([khoa-app](docs/feature/khoa-app.md)).
- `7bdeca8` Cử chỉ: chạm terminal để bật/tắt bàn phím, thanh phím chỉ hiện cùng bàn phím ảo; nhấn giữ để sao chép/dán; hai ngón tay để đổi cỡ chữ ([cu-chi-terminal](docs/feature/cu-chi-terminal.md)).
- `7bdeca8` Sửa: chữ tiếng Việt có dấu bị tách dấu, lệch dòng và icon tmux hiện ô `?` (nhúng font JetBrains Mono Nerd Font).
- `cd206aa` Build: `make install-ios` / `make install-android` tải bản build đúng commit hiện tại về `build-ios/`, `build-android/` rồi cài lên máy cắm USB; file build CI gắn sha commit.
- `8c91eec` Build: chuyển `.gitignore` sang dạng whitelist để file build thêm vào gốc repo không bị git track.
- `abd8040` Build chuyển từ Codemagic sang GitHub Actions (`.github/workflows/build.yml`); `make ios-ipa` / `make android-apk` tải artifact bằng `gh`.
- `bf43b42` Mặc định mới: "Nhớ mật khẩu" tắt, lệnh tự chạy `tmux new -A -s mobile`.
- `bf43b42` Tài liệu: thêm `docs/` (kiến trúc, giao thức, build, kiểm thử, 4 tính năng, mẫu feature), `AGENTS.md`, `CHANGELOG.md`, lệnh `make docs-check`.

## 2026-11-24

- `25e9d64` Phát hành đầu: terminal Flutter cho ttyd sau ttyd-auth, thanh phím Esc/Tab/Ctrl/Alt/Shift/mũi tên, nhớ mật khẩu, lệnh tự chạy, build Codemagic.
