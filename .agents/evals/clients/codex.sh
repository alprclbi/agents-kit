#!/bin/sh
set -eu

# Ham `codex exec --json` olay akisini (JSONL) claude.sh ile ayni normalize
# satira cevirir. Rapor betikleri istemciyi bilmeden ayni alanlari okur.
#
# Alan eslemesi (Codex olay akisi: turn.completed.usage, item.completed):
#   context_tokens        = input_tokens (OpenAI'da cached_input_tokens
#                           input_tokens'in ALT KUMESIDIR, ayrica eklenmez)
#   cache_read_tokens     = cached_input_tokens
#   cache_creation_tokens = input_tokens - cached_input_tokens. Codex cache
#                           yazimini raporlamaz; onbellekten gelmeyen girdi
#                           ayni kosu icindeki en yakin karsiliktir. Talimat
#                           yuku kollar ARASI karsilastirilabilir, Claude
#                           sayilariyla dogrudan karsilastirilamaz.
#   thinking_tokens       = reasoning_output_tokens
#   num_turns             = tamamlanan arac ve mesaj ogesi sayisi (reasoning
#                           ve error haric). Claude'un tur sayisiyla ayni
#                           sey degil.
#   total_cost_usd        = 0 ve cost_reported=false. Codex maliyet basmaz;
#                           run.sh butce kapisi bu durumda kosu basi tahmini
#                           kullanir, sifir saymaz.
#
# Istem, transcript, mesaj metni ve thread_id kasitli olarak DISARIDA
# birakilir (spec: gizlilik, kabul kriteri 8). Yanittan yalniz iki tam
# sayi turetilir.
normalize() {
  # Akista JSON olmayan satir olabilir (uyari, ilerleme); tek bozuk satir
  # butun kosunun telemetrisini dusurmesin.
  jq -cR 'fromjson? | select(type == "object")' "$1" | jq -s -c --arg model "${2:-default}" '
    . as $events
    | [$events[] | select(.type == "turn.completed") | .usage // {}] as $usage
    | ($usage | map(.input_tokens // 0) | add // 0) as $input
    | ($usage | map(.cached_input_tokens // 0) | add // 0) as $cached
    | ($usage | map(.output_tokens // 0) | add // 0) as $output
    | ($usage | map(.reasoning_output_tokens // 0) | add // 0) as $reasoning
    | [$events[] | select(.type == "item.completed") | .item // {}] as $items
    | ([$items[] | select(.type == "agent_message") | (.text // "")] | last // "") as $reply
    | ([$items[] | select(.type != "reasoning" and .type != "error")] | length) as $turns
    # Ust duzey "error" olaylari cogunlukla yeniden baglanma bildirimidir ve
    # tur yine tamamlanabilir; basarisizligi yalniz turn.failed belirler.
    | (any($events[]; .type == "turn.failed")) as $failed
    | {
        client: "codex",
        ok: (($usage | length) > 0 and ($failed | not)),
        num_turns: $turns,
        duration_ms: 0,
        total_cost_usd: 0,
        cost_reported: false,
        context_tokens: $input,
        cache_creation_tokens: ([$input - $cached, 0] | max),
        cache_read_tokens: $cached,
        input_tokens: $input,
        context_tokens_per_turn: ($input / (if $turns > 0 then $turns else 1 end) | floor),
        output_tokens: $output,
        thinking_tokens: $reasoning,
        permission_denials: 0,
        stop_reason: (if $failed then "turn_failed" elif ($usage | length) > 0 then "completed" else "incomplete" end),
        response_chars: ($reply | length),
        response_turkish_chars: ($reply | [scan("[ğüşıöçĞÜŞİÖÇ]")] | length),
        model: $model
      }'
}

case ${1:-} in
  --normalize) normalize "$2" "${3:-default}"; exit 0 ;;
esac

# --max-turns ve --settings Claude'a ozgudur; arayuz ayni kalsin diye kabul
# edilir ama Codex'e gecirilmez. Codex'te tur siniri yoktur; izin yuzeyi
# Claude izin listesi degil workspace-write sandbox'idir.
cwd='' prompt='' model='' dry=0
while [ $# -gt 0 ]; do
  case $1 in
    --cwd)       cwd=$2;    shift 2 ;;
    --prompt)    prompt=$2; shift 2 ;;
    --max-turns) shift 2 ;;
    --settings)  shift 2 ;;
    --model)     model=$2;  shift 2 ;;
    --dry-run)   dry=1;     shift ;;
    *) printf 'E_CX_ARG %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ "$dry" = 1 ]; then
  printf '{"client":"codex","dry_run":true,"ok":true,"num_turns":0,"duration_ms":0,"total_cost_usd":0,"cost_reported":false,"context_tokens":0,"output_tokens":0,"thinking_tokens":0,"permission_denials":0,"stop_reason":"dry_run","model":"none"}\n'
  exit 0
fi

command -v codex >/dev/null 2>&1 || {
  printf '{"client":"codex","status":"SKIP","reason":"AKS503-codex-binary-unavailable","ok":false,"num_turns":0,"duration_ms":0,"total_cost_usd":0,"cost_reported":false,"context_tokens":0,"output_tokens":0,"thinking_tokens":0,"permission_denials":0,"stop_reason":"skip","model":"none"}\n'
  exit 0
}

raw=$(mktemp)
err=$(mktemp)
trap 'rm -f "$raw" "$err"' EXIT

# Izolasyon: kullanici config'i (MCP sunuculari, plugin ve hook'lar)
# yuklenmez, oturum diske yazilmaz, komutlar workspace-write sandbox'inda
# calisir. Kimlik dogrulama CODEX_HOME'dan gelmeye devam eder.
set -- exec --json --sandbox workspace-write --skip-git-repo-check \
       --ephemeral --ignore-user-config --color never --cd "$cwd"
[ -n "$model" ] && set -- "$@" --model "$model"
set -- "$@" -

started=$(date +%s)
if ! codex "$@" < "$prompt" > "$raw" 2>"$err"; then
  # Kismi akis gelmis olabilir: kesilen kosunun da telemetrisi kurtarilir.
  if [ -s "$raw" ]; then
    normalize "$raw" "${model:-default}" | jq -c '. + {ok: false, stop_reason: "invocation_failed_partial"}'
    exit 0
  fi
  # Yol ve token benzeri uzun dizeler disari cikmasin diye 200 karakterle sinirli.
  reason=$(head -c 2000 "$err" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)
  [ -n "$reason" ] || reason='bilinmeyen hata, stderr bos'
  jq -cn --arg r "$reason" '{
    client:"codex", ok:false, num_turns:0, duration_ms:0, total_cost_usd:0,
    cost_reported:false, context_tokens:0, output_tokens:0, thinking_tokens:0,
    permission_denials:0, stop_reason:"invocation_failed", model:"unknown", error:$r
  }'
  exit 0
fi
finished=$(date +%s)

normalize "$raw" "${model:-default}" | jq -c --argjson ms "$(( (finished - started) * 1000 ))" '.duration_ms = $ms'
