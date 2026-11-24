#!/bin/sh
set -eu

platform=${PLATFORM:-ios}
branch=${BRANCH:-main}
wait=${WAIT:-1}
out_dir=${OUT_DIR:-$HOME/Downloads/ttyd-keys-$platform}
repo=${REPO:-mihb123/ttyd-keys}

latest() {
  gh run list -R "$repo" -w build.yml -b "$branch" -L 1 --json databaseId,status,conclusion,number \
    --jq '.[0] // empty | "\(.databaseId) \(.status) \(.conclusion) \(.number)"'
}

run=$(latest)
[ -n "$run" ] || { echo "Chưa có run build.yml trên nhánh $branch" >&2; exit 1; }
set -- $run
while [ "$2" != completed ]; do
  [ "$wait" = 1 ] || { echo "Run #$4 đang $2, chạy lại sau hoặc bỏ WAIT=0" >&2; exit 1; }
  echo "Run #$4 đang $2, chờ 30s..."
  sleep 30
  set -- $(latest)
done

job_ok=$(gh run view "$1" -R "$repo" --json jobs --jq ".jobs[] | select(.name == \"$platform\") | .conclusion")
[ "$job_ok" = success ] || { echo "Job $platform của run #$4 kết thúc: ${job_ok:-không có}" >&2; exit 1; }

mkdir -p "$out_dir"
gh run download "$1" -R "$repo" -n "ttyd-keys-$platform" -D "$out_dir"
ls -lt "$out_dir" | head -3
