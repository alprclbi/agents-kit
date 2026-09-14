#!/bin/sh
set -eu

backend=''
work_id=''
role=''
source='fallback'
explicit_path=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --backend) [ "$#" -ge 2 ] || exit 3; backend=$2; shift 2 ;;
    --work-id) [ "$#" -ge 2 ] || exit 3; work_id=$2; shift 2 ;;
    --role) [ "$#" -ge 2 ] || exit 3; role=$2; shift 2 ;;
    --source) [ "$#" -ge 2 ] || exit 3; source=$2; shift 2 ;;
    --path) [ "$#" -ge 2 ] || exit 3; explicit_path=$2; shift 2 ;;
    *) printf 'AKE900 bilinmeyen seçenek: %s\n' "$1" >&2; exit 3 ;;
  esac
done

case "$backend" in native|spec-kit|openspec|external) ;; *) printf 'AKE301 geçersiz backend\n' >&2; exit 2 ;; esac
case "$work_id" in
  ''|*[!0-9A-Za-z._-]*|[!0-9A-Za-z]*) printf 'AKE301 geçersiz work-id\n' >&2; exit 2 ;;
esac
case "$role" in spec|plan|tasks|status|outcome|decisions|research|test-plan|evidence) ;; *) printf 'AKE301 geçersiz artifact rolü\n' >&2; exit 2 ;; esac
case "$source" in user|config|work|detected|fallback) ;; *) printf 'AKE301 geçersiz kaynak\n' >&2; exit 2 ;; esac

native_root=".agents/changes/active/$work_id"
case "$backend:$role" in
  native:spec) path="$native_root/spec.md" ;;
  native:plan|native:tasks) path="$native_root/plan.md" ;;
  native:status) path="$native_root/status.md" ;;
  native:outcome) path="$native_root/outcome.md" ;;
  native:decisions) path="$native_root/decisions.md" ;;
  native:research) path="$native_root/research.md" ;;
  native:test-plan) path="$native_root/test-plan.md" ;;
  native:evidence) path="$native_root/evidence.md" ;;
  spec-kit:spec) path="specs/$work_id/spec.md" ;;
  spec-kit:plan) path="specs/$work_id/plan.md" ;;
  spec-kit:tasks) path="specs/$work_id/tasks.md" ;;
  openspec:spec) path="openspec/changes/$work_id/proposal.md" ;;
  openspec:plan) path="openspec/changes/$work_id/design.md" ;;
  openspec:tasks) path="openspec/changes/$work_id/tasks.md" ;;
  external:*) path=$explicit_path ;;
  *) path="$native_root/$(printf '%s' "$role" | tr '-' '_').md" ;;
esac

case "$path" in
  ''|/*|[A-Za-z]:[\\/]*|..|../*|*/..|*/../*) printf 'AKE301 artifact hedefi proje dışında veya eksik: %s\n' "$path" >&2; exit 2 ;;
esac

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg workId "$work_id" --arg backend "$backend" --arg role "$role" --arg path "$path" --arg source "$source" '{workId:$workId,backend:$backend,role:$role,path:$path,source:$source,authorityRequired:[]}'
elif command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys; print(json.dumps({"workId":sys.argv[1],"backend":sys.argv[2],"role":sys.argv[3],"path":sys.argv[4],"source":sys.argv[5],"authorityRequired":[]},ensure_ascii=False,separators=(",",":")))' "$work_id" "$backend" "$role" "$path" "$source"
elif command -v node >/dev/null 2>&1; then
  node -e 'const a=process.argv.slice(1); process.stdout.write(JSON.stringify({workId:a[0],backend:a[1],role:a[2],path:a[3],source:a[4],authorityRequired:[]}));' "$work_id" "$backend" "$role" "$path" "$source"
else
  printf 'AKE901 JSON parser bulunamadı\n' >&2
  exit 3
fi
