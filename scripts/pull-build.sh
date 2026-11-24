#!/bin/sh
# Lấy bản build GitHub Actions ứng với một commit, lưu vào build-<platform>/.
# iOS: build.yml tự chạy khi push main. Android: build-android.yml chỉ chạy khi được gọi,
# chưa có run cho commit thì script tự gọi (gh workflow run) rồi chờ.
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
  ios) ext=ipa suffix=-unsigned workflow=build.yml ;;
  android) ext=apk suffix= workflow=build-android.yml ;;
  *) echo "PLATFORM phải là ios hoặc android" >&2; exit 1 ;;
esac

log() { echo "$*" >&2; }

# Commit sinh ra bản build: commit gần nhất (tính từ REF) có đổi file build.
# Commit chỉ sửa docs/scripts không kích hoạt build nên dùng build của commit trước đó.
# shellcheck disable=SC2086
build_sha_of() { git -C "$root" log -1 --format=%H "$1" -- $build_paths; }
sha=$(build_sha_of "$ref")
[ -n "$sha" ] || { log "Không tìm thấy commit nào đổi file build tính từ $ref"; exit 1; }
short=$(echo "$sha" | cut -c1-7)
log "Commit build: $short $(git -C "$root" log -1 --format=%s "$sha")"

cached=$(find "$out_dir" -maxdepth 1 -name "TtydKeys-*-$short$suffix.$ext" 2>/dev/null | sort -V | tail -1)
if [ -n "$cached" ]; then
  log "Đã có sẵn: $cached"
  echo "$cached"
  exit 0
fi

# Run mới nhất của workflow có head_sha cùng bản build với $sha (chính nó, hoặc commit sau
# chỉ sửa docs/scripts — vd run Android gọi tay trên main). In "id status số_run".
run_of() {
  gh run list -R "$repo" -w "$workflow" -L 50 --json databaseId,status,number,headSha \
    --jq '.[] | "\(.databaseId) \(.status) \(.number) \(.headSha)"' |
  while read -r id status num head; do
    if [ "$head" = "$sha" ] || { git -C "$root" cat-file -e "$head^{commit}" 2>/dev/null \
        && [ "$(build_sha_of "$head")" = "$sha" ]; }; then
      echo "$id $status $num"
      break
    fi
  done
}

# Chỉ Android: gọi build-android.yml trên main. main phải đang ở đúng bản build $sha.
dispatch() {
  git -C "$root" fetch -q origin main
  main_sha=$(build_sha_of origin/main)
  [ "$main_sha" = "$sha" ] || {
    log "origin/main đang ở bản build $(echo "$main_sha" | cut -c1-7), khác $short: push main trước (hoặc dùng REF=origin/main)"
    exit 1
  }
  log "Chưa có bản Android cho $short, gọi $workflow trên GitHub..."
  gh workflow run "$workflow" -R "$repo" --ref main >&2
  i=0
  while run=$(run_of); [ -z "$run" ]; do
    i=$((i + 1))
    [ "$i" -le 12 ] || { log "Không thấy run $workflow mới sau 60s"; exit 1; }
    sleep 5
  done
}

run=$(run_of)
if [ -z "$run" ]; then
  [ "$platform" = android ] || { log "Chưa có run $workflow cho commit $short (đã push main chưa?)"; exit 1; }
  dispatch
fi
set -- $run
while [ "$2" != completed ]; do
  [ "$wait" = 1 ] || { log "Run #$3 đang $2, chạy lại sau hoặc bỏ WAIT=0"; exit 1; }
  log "Run #$3 đang $2, chờ 30s..."
  sleep 30
  set -- $(run_of)
done

job_ok=$(gh run view "$1" -R "$repo" --json jobs --jq ".jobs[] | select(.name == \"$platform\") | .conclusion")
[ "$job_ok" = success ] || { log "Job $platform của run #$3 kết thúc: ${job_ok:-không có} (chạy lại: gh run rerun $1 -R $repo)"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
log "Tải artifact ttyd-keys-$platform của run #$3..."
gh run download "$1" -R "$repo" -n "ttyd-keys-$platform" -D "$tmp" >&2
src=$(find "$tmp" -name "*.$ext" | head -1)
[ -n "$src" ] || { log "Artifact không có file .$ext"; exit 1; }

# Đặt tên theo số run + commit để lần sau dùng lại, kể cả artifact cũ chưa gắn commit.
mkdir -p "$out_dir"
dest="$out_dir/TtydKeys-$3-$short$suffix.$ext"
mv "$src" "$dest"
log "Đã lưu: $dest"
echo "$dest"
