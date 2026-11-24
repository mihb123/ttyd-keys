# Tài liệu ttyd keys

App Flutter (iOS + Android) làm terminal native cho ttyd sau ttyd-auth, kèm thanh phím Esc/Tab/Ctrl/Alt/Shift/mũi tên. Không có backend trong repo; build qua GitHub Actions.

## Bắt đầu từ đâu

| Bạn cần | Đọc |
|---|---|
| Quy tắc khi sửa code và cập nhật docs | [AGENTS.md](../AGENTS.md) |
| Hiểu app trong 5 phút | [architecture.md](architecture.md) |
| Build, tải `.ipa`/`.apk`, biến môi trường | [deployment_guide.md](deployment_guide.md) |
| Sửa một tính năng | [feature/](#tính-năng) (mỗi file có Code map) |
| Giao thức với ttyd-auth/ttyd | [api_specifications.md](api_specifications.md) |
| Kiểm thử | [testing.md](testing.md) |
| Viết tài liệu tính năng mới | [templates/feature.md](templates/feature.md) |
| Lịch sử thay đổi | [CHANGELOG.md](../CHANGELOG.md) |

## Sơ đồ tài liệu

### Nền tảng

1. **[architecture.md](architecture.md)** — sơ đồ tổng thể, module, màn hình, luồng dữ liệu, bảo mật.
2. **[techstack.md](techstack.md)** — Flutter, package, CI kèm phiên bản.
3. **[api_specifications.md](api_specifications.md)** — HTTP đăng nhập, WebSocket và khung tin nhắn ttyd.
4. **[deployment_guide.md](deployment_guide.md)** — lệnh `make`, biến môi trường, GitHub Actions, cài iPhone.
5. **[testing.md](testing.md)** — lint, checklist thủ công.

### Tính năng

| File | Nội dung |
|---|---|
| [feature/ket-noi-ttyd.md](feature/ket-noi-ttyd.md) | Đăng nhập, khóa tab, WebSocket, tự đăng nhập lại, tự nối lại |
| [feature/thanh-phim.md](feature/thanh-phim.md) | Thanh phím, Ctrl/Alt/Shift dính, chuỗi escape, lặp phím |
| [feature/nhap-ban-phim-ao.md](feature/nhap-ban-phim-ao.md) | Cầu nối bàn phím ảo (IME) → terminal |
| [feature/cai-dat.md](feature/cai-dat.md) | Lưu cài đặt, mật khẩu, cỡ chữ, lệnh tự chạy |

### Mẫu

- [templates/feature.md](templates/feature.md) — khung bắt buộc cho `feature/*.md`.

## Trạng thái tính năng (2026-11-25)

| Nhóm | Trạng thái |
|---|---|
| Đăng nhập + kết nối ttyd, tự đăng nhập lại, tự nối lại | Xong |
| Thanh phím + modifier dính + lặp phím | Xong |
| Nhập từ bàn phím ảo | Xong |
| Cài đặt (cỡ chữ, lệnh tự chạy, nhớ mật khẩu) | Xong |
| Build iOS/Android trên GitHub Actions | Xong |
| Unit test | Chưa làm |
| Nhiều host / nhiều tab | Chưa làm |

## Quy ước viết tài liệu

- Tiếng Việt, ngắn, gạch đầu dòng và bảng; không emoji; giữ nguyên tên code, lệnh.
- Code là nguồn đúng: mọi con số (timeout, hằng số, key lưu trữ) phải kiểm trong code trước khi ghi, kèm tên file/hàm.
- Mỗi điều nằm ở một chỗ, chỗ khác link sang (giao thức ở `api_specifications.md`, key lưu trữ ở `feature/cai-dat.md`).
- `feature/*.md` theo đúng khung [templates/feature.md](templates/feature.md): Mục tiêu → Phạm vi hiện tại → Code map → Luồng xử lý → Dữ liệu & giao thức → Quy tắc & lưu ý → Còn để lại; mục không áp dụng ghi `Không có.` (`make docs-check` kiểm).
- Link tương đối; mermaid quote nhãn có ký tự đặc biệt; chạy `make docs-check` trước khi xong.
- Quy tắc cập nhật docs + CHANGELOG khi sửa code: [AGENTS.md](../AGENTS.md#cập-nhật-tài-liệu-sau-mỗi-thay-đổi).
