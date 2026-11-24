#!/bin/sh
# Lấy bản build GitHub Actions ứng với một commit, lưu vào build-<platform>/.
# In đường dẫn file ra stdout (dòng cuối), thông báo ra stderr.
set -eu

platform=${PLATFORM:-ios}
ref=${REF:-HEAD}
wait=${WAIT:-1}
repo=${REPO:-mihb123/ttyd-keys}
root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
out_dir=${OUT_DIR:-$root/build-$platform}
# Giữ khớp với on.push.paths trong .github/workflows/build.yml
build_paths="lib assets ios android pubspec.yaml pubspec.lock .github/workflows/build.yml"

case $platform in
  ios) ext=ipa suffix=-unsigned ;;
  android) ext=apk suffix= ;;
  *) echo "PLATFORM phải là ios hoặc android" >&2; exit 1 ;;
esac

log() { echo "$*" >&2; }

# Commit sinh ra bản build: commit gần nhất (tính từ REF) có đổi file build.
# Commit chỉ sửa docs/scripts không kích hoạt build nên dùng build của commit trước đó.
# shellcheck disable=SC2086
sha=$(git -C "$root" log -1 --format=%H "$ref" -- $build_paths)
[ -n "$sha" ] || { log "Không tìm thấy commit nào đổi file build tính từ $ref"; exit 1; }
short=$(echo "$sha" | cut -c1-7)
log "Commit build: $short $(git -C "$root" log -1 --format=%s "$sha")"

cached=$(find "$out_dir" -maxdepth 1 -name "TtydKeys-*-$short$suffix.$ext" 2>/dev/null | sort -V | tail -1)
if [ -n "$cached" ]; then
  log "Đã có sẵn: $cached"
  echo "$cached"
  exit 0
fi

run_of() {
  gh run list -R "$repo" -w build.yml -c "$sha" -L 1 --json databaseId,status,conclusion,number \
    --jq '.[0] // empty | "\(.databaseId) \(.status) \(.conclusion) \(.number)"'
}

run=$(run_of)
[ -n "$run" ] || { log "Chưa có run build.yml cho commit $short (đã push main chưa?)"; exit 1; }
set -- $run
while [ "$2" != completed ]; do
  [ "$wait" = 1 ] || { log "Run #$4 đang $2, chạy lại sau hoặc bỏ WAIT=0"; exit 1; }
  log "Run #$4 đang $2, chờ 30s..."
  sleep 30
  set -- $(run_of)
done

job_ok=$(gh run view "$1" -R "$repo" --json jobs --jq ".jobs[] | select(.name == \"$platform\") | .conclusion")
[ "$job_ok" = success ] || { log "Job $platform của run #$4 kết thúc: ${job_ok:-không có}"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
log "Tải artifact ttyd-keys-$platform của run #$4..."
gh run download "$1" -R "$repo" -n "ttyd-keys-$platform" -D "$tmp" >&2
src=$(find "$tmp" -name "*.$ext" | head -1)
[ -n "$src" ] || { log "Artifact không có file .$ext"; exit 1; }

# Đặt tên theo số run + commit để lần sau dùng lại, kể cả artifact cũ chưa gắn commit.
mkdir -p "$out_dir"
dest="$out_dir/TtydKeys-$4-$short$suffix.$ext"
mv "$src" "$dest"
log "Đã lưu: $dest"
echo "$dest"
