#!/bin/sh
# Lấy bản build của commit (xem pull-build.sh) rồi cài lên máy đang cắm USB.
# iOS: plumesign ký bằng Apple ID đã đăng nhập trong Impactor; Android: adb.
set -eu

platform=${PLATFORM:-ios}
here=$(dirname "$0")
plume_version=v2.7.3
plume_sha256=d7d631d04fd80bf134fef9a7c71f704e9ae92f3d8f7e4895f10de4236acdc177
plume_config=${XDG_CONFIG_HOME:-$HOME/.config}/PlumeImpactor

die() { echo "$*" >&2; exit 1; }

# Kiểm máy trước khi tải để báo lỗi sớm.
case $platform in
  ios)
    command -v idevice_id >/dev/null || die "Thiếu libimobiledevice: sudo pacman -S --needed usbmuxd libimobiledevice"
    if [ -z "${UDID:-}" ]; then
      udids=$(idevice_id -l)
      [ -n "$udids" ] || die "Không thấy iPhone qua USB: mở khoá máy, cắm lại cáp, sudo systemctl restart usbmuxd"
      [ "$(echo "$udids" | wc -l)" = 1 ] || die "Có nhiều iPhone, chọn một bằng UDID=...: $(echo $udids)"
      UDID=$udids
    fi
    name=$(ideviceinfo -u "$UDID" -k DeviceName 2>/dev/null) \
      || die "iPhone $UDID chưa tin cậy máy này: mở khoá, bấm Tin cậy, chạy idevicepair pair"

    [ -f "$plume_config/accounts.json" ] && jq -e '.selected_account // empty' "$plume_config/accounts.json" >/dev/null \
      || die "Chưa đăng nhập Apple ID: mở Impactor đăng nhập một lần, hoặc chạy plumesign account login -u <email>"

    plumesign=${PLUMESIGN:-$(command -v plumesign || echo "$HOME/.local/bin/plumesign")}
    if [ ! -x "$plumesign" ]; then
      echo "Tải plumesign $plume_version (CLI của Impactor) về $plumesign..." >&2
      mkdir -p "$(dirname "$plumesign")"
      tmp=$(mktemp)
      curl -fsSL -o "$tmp" "https://github.com/khcrysalis/Impactor/releases/download/$plume_version/plumesign-linux-x86_64"
      echo "$plume_sha256  $tmp" | sha256sum -c --quiet - || { rm -f "$tmp"; die "plumesign tải về sai checksum"; }
      chmod +x "$tmp" && mv "$tmp" "$plumesign"
    fi
    ;;
  android)
    command -v adb >/dev/null || die "Thiếu adb (Android SDK platform-tools)"
    [ -n "${ANDROID_SERIAL:-}" ] || {
      n=$(adb devices | awk 'NR > 1 && $2 == "device"' | wc -l)
      [ "$n" = 1 ] || die "Cần đúng 1 máy Android đã bật gỡ lỗi USB (đang thấy $n), hoặc đặt ANDROID_SERIAL=..."
    }
    ;;
  *) die "PLATFORM phải là ios hoặc android" ;;
esac

file=$(PLATFORM=$platform "$here/pull-build.sh" | tail -1)

case $platform in
  ios)
    # plumesign --udid so với DeviceID số của usbmuxd (plume_utils::get_device_for_id), không phải UDID.
    mux_id=$(python3 -I - "$UDID" <<'EOF'
import plistlib, socket, struct, sys
s = socket.socket(socket.AF_UNIX)
s.connect("/var/run/usbmuxd")
body = plistlib.dumps({"MessageType": "ListDevices", "ClientVersionString": "ttyd-keys", "ProgName": "ttyd-keys"})
s.sendall(struct.pack("<IIII", 16 + len(body), 1, 8, 1) + body)
size = struct.unpack("<I", s.recv(4))[0]
data = b""
while len(data) < size - 4:
    data += s.recv(size - 4 - len(data))
devices = plistlib.loads(data[12:])["DeviceList"]
ids = [d["DeviceID"] for d in devices
       if d["Properties"].get("SerialNumber") == sys.argv[1] and d["Properties"].get("ConnectionType") == "USB"]
print(ids[0] if ids else "")
EOF
)
    [ -n "$mux_id" ] || die "usbmuxd không thấy $UDID qua USB"
    echo "Ký và cài $(basename "$file") lên $name ($UDID)..." >&2
    # plumesign giải nén vào $TMPDIR và để lại thư mục khi lỗi: cho nó thư mục riêng rồi xoá.
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    TMPDIR=$work RUST_LOG=${RUST_LOG:-error,plumesign=info} "$plumesign" sign --package "$file" \
      --apple-id --register-and-install --udid "$mux_id"
    ;;
  android)
    echo "Cài $(basename "$file") qua adb..." >&2
    adb install -r "$file"
    ;;
esac
echo "Xong: đã cài $(basename "$file")" >&2
