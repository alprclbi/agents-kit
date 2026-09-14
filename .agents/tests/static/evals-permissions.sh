#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
s=.agents/evals/sandbox-settings.json
[ -f "$s" ] || { printf 'E_PERM_MISSING\n' >&2; exit 2; }

# 1. YALNIZ permissions tasimali. hooks/mcpServers/model olcumu kirletir:
#    kollar arasi sabit olsa bile etkiyi AGENTS.md disi bir kaynaga bulastirir.
jq -e '(keys == ["permissions"])' "$s" >/dev/null \
  || { printf 'E_PERM_EXTRA_KEYS %s\n' "$(jq -c 'keys' "$s")" >&2; exit 2; }

# 2. Allow listesi tam olarak iki giris (spec D1).
jq -e '.permissions.allow | length == 2' "$s" >/dev/null \
  || { printf 'E_PERM_ALLOW_COUNT %s\n' "$(jq -c '.permissions.allow' "$s")" >&2; exit 2; }

# 3. Genis kabuk izni YASAK: sh:* tam kabuk demektir (spec G6). "sh -c '<her
#    sey>'" listeyi anlamsizlastirir; izin tam komut olmali.
jq -e '[.permissions.allow[] | test("^Bash\\(sh:")] | any | not' "$s" >/dev/null \
  || { printf 'E_PERM_WILDCARD_SH\n' >&2; exit 2; }

# 4. run-task.sh bu dosyayi gercekten geciriyor olmali. Dosyanin varligi
#    kullanildigi anlamina gelmez.
grep -Fq 'sandbox-settings.json' .agents/evals/lib/run-task.sh \
  || { printf 'E_PERM_NOT_WIRED run-task.sh\n' >&2; exit 2; }

# 5. probe-arm.sh de ayni yuzeyi kullanmali; farkli olursa sonda ve gorev
#    kosulari iki ayri iskeletten olculur.
grep -Fq 'sandbox-settings.json' .agents/evals/lib/probe-arm.sh \
  || { printf 'E_PERM_NOT_WIRED probe-arm.sh\n' >&2; exit 2; }

# 6. Ayar dosyasi sandbox'a KOPYALANMAMALI: ajan onu gorup okuyabilirdi.
grep -Eq 'cp .*sandbox-settings\.json .*\$sandbox' .agents/evals/lib/run-task.sh \
  && { printf 'E_PERM_COPIED_INTO_SANDBOX\n' >&2; exit 2; }

printf 'PASS evals-permissions allow=%s\n' "$(jq -r '.permissions.allow | length' "$s")"
