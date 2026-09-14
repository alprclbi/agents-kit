#!/bin/sh
set -eu

# Ham claude JSON'unu normalize satira cevirir.
#
# context_tokens ucunu birden toplar cunku prompt cache ayni icerigi sicak
# kosuda cache_read, soguk kosuda cache_creation olarak raporlar. Fiyat
# degisir, SAYI degismez -> yalniz bu toplam kollar arasi karsilastirilabilir.
#
# Istem, transcript, result metni, session_id ve uuid kasitli olarak DISARIDA
# birakilir (spec: gizlilik, kabul kriteri 8).
# Ham token bilesenleri AYRI tutulur. Toplam tek basina yaniltici:
# her turda cache okumasi yeniden sayildigi icin tur sayisiyla
# olcekleniyor ve talimat dosyasinin sabit bedelini gurultuye gomuyor
# (olculen: ~%5). Talimat yukunun temiz olcusu cache_creation alanidir.
normalize() {
  jq -c '{
    client: "claude",
    ok: (.is_error | not),
    num_turns: (.num_turns // 0),
    duration_ms: (.duration_ms // 0),
    total_cost_usd: (.total_cost_usd // 0),
    context_tokens: (
      (.usage.input_tokens // 0)
      + (.usage.cache_creation_input_tokens // 0)
      + (.usage.cache_read_input_tokens // 0)
    ),
    cache_creation_tokens: (.usage.cache_creation_input_tokens // 0),
    cache_read_tokens: (.usage.cache_read_input_tokens // 0),
    input_tokens: (.usage.input_tokens // 0),
    context_tokens_per_turn: (
      ((.usage.input_tokens // 0)
       + (.usage.cache_creation_input_tokens // 0)
       + (.usage.cache_read_input_tokens // 0))
      / (if (.num_turns // 0) > 0 then .num_turns else 1 end)
      | floor
    ),
    output_tokens: (.usage.output_tokens // 0),
    thinking_tokens: (.usage.output_tokens_details.thinking_tokens // 0),
    permission_denials: ((.permission_denials // []) | length),
    stop_reason: (.stop_reason // "unknown"),
    response_chars: ((.result // "") | length),
    response_turkish_chars: ((.result // "") | [scan("[ğüşıöçĞÜŞİÖÇ]")] | length),
    model: ((.modelUsage // {}) | keys | first // "unknown")
  }' "$1"
}

case ${1:-} in
  --normalize) normalize "$2"; exit 0 ;;
esac

cwd='' prompt='' max_turns=30 settings='' model='' dry=0
while [ $# -gt 0 ]; do
  case $1 in
    --cwd)       cwd=$2;       shift 2 ;;
    --prompt)    prompt=$2;    shift 2 ;;
    --max-turns) max_turns=$2; shift 2 ;;
    --settings)  settings=$2;  shift 2 ;;
    --model)     model=$2;     shift 2 ;;
    --dry-run)   dry=1;        shift ;;
    *) printf 'E_CL_ARG %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ "$dry" = 1 ]; then
  printf '{"client":"claude","dry_run":true,"ok":true,"num_turns":0,"duration_ms":0,"total_cost_usd":0,"context_tokens":0,"output_tokens":0,"thinking_tokens":0,"permission_denials":0,"stop_reason":"dry_run","model":"none"}\n'
  exit 0
fi

command -v claude >/dev/null 2>&1 || {
  printf '{"client":"claude","status":"SKIP","reason":"AKS503-claude-binary-unavailable","ok":false,"num_turns":0,"duration_ms":0,"total_cost_usd":0,"context_tokens":0,"output_tokens":0,"thinking_tokens":0,"permission_denials":0,"stop_reason":"skip","model":"none"}\n'
  exit 0
}

raw=$(mktemp)
err=$(mktemp)
trap 'rm -f "$raw" "$err"' EXIT

# Izolasyon: ag araclari kapali, ambient MCP sunucusu yok, tur sinirli.
set -- -p --output-format json --max-turns "$max_turns" \
       --permission-mode acceptEdits \
       --strict-mcp-config \
       --disallowed-tools WebFetch WebSearch
[ -n "$settings" ] && [ -f "$settings" ] && set -- "$@" --settings "$settings"
[ -n "$model" ] && set -- "$@" --model "$model"

if ! (cd "$cwd" && claude "$@" < "$prompt") > "$raw" 2>"$err"; then
  # Kismi JSON gelmis olabilir: cagri yarida oldugunde bile telemetriyi
  # kurtar, yoksa kosunun bedeli olculemez hale gelir.
  if [ -s "$raw" ] && jq -e . "$raw" >/dev/null 2>&1; then
    normalize "$raw" | jq -c '. + {ok: false, stop_reason: "invocation_failed_partial"}'
    exit 0
  fi
  # Hata metnini yut ma; ilk satirini kisaltip tanilama icin tasi.
  # Yol ve token benzeri uzun dizeler disari cikmasin diye 200 karakterle sinirli.
  reason=$(head -c 2000 "$err" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)
  [ -n "$reason" ] || reason='bilinmeyen hata, stderr bos'
  jq -cn --arg r "$reason" '{
    client:"claude", ok:false, num_turns:0, duration_ms:0, total_cost_usd:0,
    context_tokens:0, output_tokens:0, thinking_tokens:0, permission_denials:0,
    stop_reason:"invocation_failed", model:"unknown", error:$r
  }'
  exit 0
fi

normalize "$raw"
