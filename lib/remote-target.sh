#!/usr/bin/env bash
set -euo pipefail

target_root="${1:-}"

fail() {
  printf '[target-preflight:error] %s\n' "$*" >&2
  exit 1
}

[[ "$target_root" == /* ]] || fail "target root must be absolute"
[[ -d "$target_root" ]] || fail "target root does not exist"
[[ -d "$target_root/wp-content" ]] || fail "target wp-content does not exist"
[[ -w "$target_root" ]] || fail "target root is not writable"
command -v rsync >/dev/null 2>&1 || fail "rsync is unavailable"
command -v tar >/dev/null 2>&1 || fail "tar is unavailable"

wp_state="unavailable"
content_state="unknown"
content_items=0
user_count=0
upload_files=0
if command -v wp >/dev/null 2>&1 && (cd "$target_root" && wp --skip-plugins --skip-themes core is-installed >/dev/null 2>&1); then
  wp_state="installed"
  content_items="$(cd "$target_root" && wp --skip-plugins --skip-themes post list --post_type=post,page,attachment --post_status=any --format=count 2>/dev/null)"
  user_count="$(cd "$target_root" && wp --skip-plugins --skip-themes user list --format=count 2>/dev/null)"
  [[ "$content_items" =~ ^[0-9]+$ ]] || fail "target content count could not be measured"
  [[ "$user_count" =~ ^[0-9]+$ ]] || fail "target user count could not be measured"
  if [[ -d "$target_root/wp-content/uploads" ]]; then
    upload_files="$(find "$target_root/wp-content/uploads" -type f -print 2>/dev/null | awk 'END {print NR + 0}')"
  fi
  # A new WordPress install may contain the sample post/page and privacy page.
  # User-created accounts or media are never accepted for an automated overlay.
  if [[ "$content_items" -le 3 && "$user_count" -le 1 && "$upload_files" -eq 0 ]]; then
    content_state="clean"
  else
    content_state="modified"
  fi
fi

available_kb="$(df -Pk "$target_root" | awk 'NR == 2 {print $4}')"
[[ "$available_kb" =~ ^[0-9]+$ ]] || fail "target free space could not be measured"

printf 'target_root=%s\n' "$target_root"
printf 'wp_state=%s\n' "$wp_state"
printf 'content_state=%s\n' "$content_state"
printf 'content_items=%s\n' "$content_items"
printf 'user_count=%s\n' "$user_count"
printf 'upload_files=%s\n' "$upload_files"
printf 'rsync=available\n'
printf 'available_kb=%s\n' "$available_kb"
