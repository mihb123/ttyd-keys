#!/bin/sh
set -eu

env_file=${TTYD_KEYS_CODEMAGIC_ENV:-$HOME/.config/ttyd-keys/codemagic.env}
[ -r "$env_file" ] && . "$env_file"
: "${CODEMAGIC_API_TOKEN:?Thiếu CODEMAGIC_API_TOKEN (đặt trong $env_file)}"
: "${CODEMAGIC_APP_ID:?Thiếu CODEMAGIC_APP_ID (đặt trong $env_file)}"
app_id=$CODEMAGIC_APP_ID
workflow=${WORKFLOW:-ios-unsigned}
branch=${BRANCH:-main}
wait=${WAIT:-1}
case $workflow in
  android-apk) ext=apk; out_dir=${OUT_DIR:-$HOME/Downloads/ttyd-keys-android} ;;
  *) ext=ipa; out_dir=${OUT_DIR:-$HOME/Downloads/ttyd-keys-ios} ;;
esac

api() {
  curl -fsSL -H "x-auth-token: $CODEMAGIC_API_TOKEN" "$@"
}

latest() {
  api "https://api.codemagic.io/builds?appId=$app_id&branch=$branch" |
    jq -c --arg wf "$workflow" '[.builds[] | select((.fileWorkflowId // .workflowId) == $wf and .status != "skipped")] | sort_by(.createdAt) | last // empty'
}

build=$(latest)
[ -n "$build" ] || { echo "Chưa có build $workflow trên nhánh $branch" >&2; exit 1; }

while :; do
  status=$(printf '%s' "$build" | jq -r .status)
  case $status in
    finished) break ;;
    failed | canceled | skipped | timeout)
      echo "Build #$(printf '%s' "$build" | jq -r .index) kết thúc với trạng thái $status" >&2
      exit 1 ;;
  esac
  [ "$wait" = 1 ] || { echo "Build mới nhất đang $status, chạy lại sau hoặc bỏ WAIT=0" >&2; exit 1; }
  echo "Build #$(printf '%s' "$build" | jq -r .index) đang $status, chờ 30s..."
  sleep 30
  build=$(latest)
done

url=$(printf '%s' "$build" | jq -r --arg ext ".$ext" '[.artefacts[]? | select(.name | endswith($ext))][0].url // empty')
[ -n "$url" ] || { echo "Build không có file .$ext" >&2; exit 1; }
sha=$(printf '%s' "$build" | jq -r '.commit.hash // "" | .[0:7]')
name=$(basename "$url" ".$ext")${sha:+-$sha}.$ext

mkdir -p "$out_dir"
api -o "$out_dir/$name" "$url"
ls -l "$out_dir/$name"
