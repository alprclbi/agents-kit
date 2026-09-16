#!/bin/sh

ak_find_root() {
  start=$1
  current=$(CDPATH= cd -- "$start" 2>/dev/null && pwd -P) || return 3
  while :; do
    if [ -f "$current/AGENTS.md" ] && [ -f "$current/.agents/config.json" ]; then
      printf '%s\n' "$current"
      return 0
    fi
    [ "$current" != / ] || return 3
    current=$(dirname -- "$current")
  done
}

ak_json_get() {
  file=$1
  expression=$2
  if command -v jq >/dev/null 2>&1; then
    jq -r "$expression // empty" "$file"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
value=json.load(open(sys.argv[1],encoding="utf-8"))
for part in sys.argv[2].lstrip(".").split("."):
    if not part: continue
    if not isinstance(value,dict) or part not in value: sys.exit(0)
    value=value[part]
if value is None: sys.exit(0)
if isinstance(value,bool): print(str(value).lower())
elif isinstance(value,(dict,list)): print(json.dumps(value,ensure_ascii=False,separators=(",",":")))
else: print(value)' "$file" "$expression"
  elif command -v node >/dev/null 2>&1; then
    node -e 'const fs=require("fs"); let v=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); for(const p of process.argv[2].replace(/^\./,"").split(".")){if(!p)continue;if(v===null||typeof v!=="object"||!(p in v))process.exit(0);v=v[p]} if(v!==null)process.stdout.write(typeof v==="object"?JSON.stringify(v):String(v));' "$file" "$expression"
  else
    printf 'AKE901 JSON ayrıştırıcı bulunamadı\n' >&2
    return 3
  fi
}

ak_json_quote() {
  value=$1
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$value" | jq -Rsa .
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1],ensure_ascii=False))' "$value"
  elif command -v node >/dev/null 2>&1; then
    node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$value"
  else
    printf 'AKE901 JSON ayrıştırıcı bulunamadı\n' >&2
    return 3
  fi
}

ak_json_array_from_lines() {
  if command -v jq >/dev/null 2>&1; then
    jq -sc .
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps([json.loads(line) for line in sys.stdin if line.strip()],ensure_ascii=False,separators=(",",":")))'
  elif command -v node >/dev/null 2>&1; then
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.stringify(s.split(/\r?\n/).filter(Boolean).map(JSON.parse))))'
  else
    printf 'AKE901 JSON ayrıştırıcı bulunamadı\n' >&2
    return 3
  fi
}

ak_diag() {
  code=$1 severity=$2 blocking=$3 message=$4 path=$5 remediation=$6
  q_code=$(ak_json_quote "$code")
  q_severity=$(ak_json_quote "$severity")
  q_message=$(ak_json_quote "$message")
  if [ -n "$path" ]; then q_path=$(ak_json_quote "$path"); else q_path=null; fi
  if [ -n "$remediation" ]; then q_remediation=$(ak_json_quote "$remediation"); else q_remediation=null; fi
  printf '{"code":%s,"severity":%s,"blocking":%s,"message":%s,"path":%s,"remediation":%s}\n' "$q_code" "$q_severity" "$blocking" "$q_message" "$q_path" "$q_remediation"
}

ak_active_status() {
  case "$1" in draft|ready|in_progress|blocked|review) return 0 ;; *) return 1 ;; esac
}

ak_list_active_work() {
  root=$1
  active_root="$root/.agents/changes/active"
  [ -d "$active_root" ] || return 0
  for file in "$active_root"/*/work.json; do
    [ -f "$file" ] || continue
    status=$(ak_json_get "$file" '.status') || exit $?
    if ak_active_status "$status"; then
      id=$(ak_json_get "$file" '.id') || exit $?
      [ -n "$id" ] && printf '%s\t%s\n' "$id" "$file"
    fi
  done
}

# Salt okunur kabuk komutu siniflandirmasi. Fail-closed: taninmayan her
# komut mutasyondur. Sozlesme: .agents/contracts/tool-gate.md
#
# Amac kapiyi gevsetmek degil: engellenen kullanicinin durumu gorup
# cozebilmesi. Tani komutlari da kapanirsa kapi kendi kendini kilitler.
ak_readonly_command() {
  command_text=$1
  [ -n "$command_text" ] || return 1
  case "$command_text" in
    *'>'*|*'<'*|*'|'*|*'&'*|*';'*|*'`'*|*'$('*|*'${'*) return 1 ;;
  esac
  verb=$(printf '%s' "$command_text" | awk '{print $1}')
  case "$verb" in
    ls|cat|head|tail|wc|pwd|echo) return 0 ;;
    git)
      sub=$(printf '%s' "$command_text" | awk '{print $2}')
      case "$sub" in status|log|diff|show) return 0 ;; *) return 1 ;; esac
      ;;
    *) return 1 ;;
  esac
}

# Kit bu projede kurulu mu? Plugin kullanici seviyesinde etkinlestirildiginde
# hooks/hooks.json HER projede calisir, yalniz iskelenin bulundugu projede
# degil. Kurulu olmayan projede dogrulayicinin yapacagi is yoktur: hicbir
# cikti vermeden cekilir.
#
# Isaret olarak config.json secilir cunku ak_profile'in okudugu dosya odur;
# daha gevsek bir isaret (ornegin yalniz .agents/ dizini) kapiyi gercek
# ihtiyactan genis acar ve kitin kurulu oldugu projede denetimi sessizce
# dusurebilir.
ak_kit_installed() {
  [ -f "$1/.agents/config.json" ]
}

# Profil yalniz BEYANDAN cozulur. Aktif is sayisi burada hic okunmaz:
# tek gelistirici on isi acik tutup ayri oturumlarda yurutebilir ve bu
# onu ekip yapmaz. Sayimdan cikarim yapmak kullaniciyi kilitliyordu.
#
# high-assurance ve auto kaldirildi; eski degerler reddedilmez, sirasiyla
# team ve solo olarak calisir ve AKW102 ile uyarilir.
ak_profile() {
  root=$1
  configured=$(ak_json_get "$root/.agents/config.json" '.profile') || return $?
  base=solo
  case "$configured" in
    solo|team) base=$configured ;;
    high-assurance) base=team ;;
    *) base=solo ;;
  esac
  # work.json yalniz SIKILASTIRABILIR: solo -> team. Ters yon kabul edilmez.
  if [ "$base" = solo ]; then
    set +e
    resolved=$(ak_resolve_work_id "$root" "${2:-}" "${3:-}" 2>/dev/null)
    set -e
    if [ -n "$resolved" ]; then
      work_file="$root/.agents/changes/active/$resolved/work.json"
      if [ -f "$work_file" ]; then
        work_profile=$(ak_json_get "$work_file" '.profile' 2>/dev/null) || work_profile=''
        case "$work_profile" in team|high-assurance) base=team ;; esac
      fi
    fi
  fi
  printf '%s\n' "$base"
}

# Cozum sirasi: acik work-id -> isaretci dosyasi -> branch -> tek aktif is.
#
# Hook ayri surecte calisir ve sohbetteki niyeti goremez; on is acikken
# hangisinde olundugunu ancak isaretci dosyasi soyler.
#
# Cikti tek satir, sekmeyle ayrilmis: <id>\t<kaynak>\t<bayat-isaretci>
# Cozulemedigi durumda id bostur ama kaynak ve bayat bilgisi yine basilir;
# komut ikamesi alt kabukta calistigi icin degisken ile bildirilemez.
# Kaynak degerleri: explicit, pointer, branch, single, none.
ak_resolve_work() {
  root=$1 branch=${2:-} explicit_id=${3:-}
  stale=''
  active=$(ak_list_active_work "$root") || return $?
  if [ -n "$explicit_id" ]; then
    matches=$(printf '%s\n' "$active" | awk -F '\t' -v id="$explicit_id" '$1==id')
    if [ "$(printf '%s\n' "$matches" | awk 'NF {n++} END {print n+0}')" -eq 1 ]; then
      printf '%s\texplicit\t\n' "$explicit_id"
      return 0
    fi
    printf '\tnone\t\n'
    return 1
  fi
  pointer_file="$root/.agents/runtime/current-work"
  if [ -f "$pointer_file" ]; then
    pointer_id=$(tr -d ' \r\n' < "$pointer_file")
    if [ -n "$pointer_id" ]; then
      pointer_match=$(printf '%s\n' "$active" | awk -F '\t' -v id="$pointer_id" '$1==id')
      if [ "$(printf '%s\n' "$pointer_match" | awk 'NF {n++} END {print n+0}')" -eq 1 ]; then
        printf '%s\tpointer\t\n' "$pointer_id"
        return 0
      fi
      # Bayat isaretci: sessizce yanlis ise yazma, cagirana bildir.
      stale=$pointer_id
    fi
  fi
  if [ -n "$branch" ]; then
    branch_matches=''
    while IFS="$(printf '\t')" read -r id file; do
      [ -n "$id" ] || continue
      work_branch=$(ak_json_get "$file" '.git.branch') || return $?
      [ "$work_branch" = "$branch" ] && branch_matches="${branch_matches}${id}\n"
    done <<EOF
$active
EOF
    count=$(printf '%b' "$branch_matches" | awk 'NF {n++} END {print n+0}')
    if [ "$count" -eq 1 ]; then
      printf '%s\tbranch\t%s\n' "$(printf '%b' "$branch_matches" | awk 'NF && !seen {print; seen=1}')" "$stale"
      return 0
    fi
    if [ "$count" -gt 1 ]; then
      printf '\tnone\t%s\n' "$stale"
      return 2
    fi
  fi
  count=$(printf '%s\n' "$active" | awk 'NF {n++} END {print n+0}')
  if [ "$count" -eq 1 ]; then
    printf '%s\tsingle\t%s\n' "$(printf '%s\n' "$active" | awk -F '\t' 'NF && !seen {print $1; seen=1}')" "$stale"
    return 0
  fi
  printf '\tnone\t%s\n' "$stale"
  [ "$count" -eq 0 ] && return 1
  return 2
}

# Yalniz work-id isteyen cagiranlar icin ince sarmalayici.
ak_resolve_work_id() {
  ak_resolve_work "$@" | awk -F '\t' 'NR==1 {print $1}'
}

ak_instruction_budget() {
  root=$1 cwd=$2 explicit_limit=${3:-}
  root=$(CDPATH= cd -- "$root" && pwd -P) || return 3
  cwd=$(CDPATH= cd -- "$cwd" && pwd -P) || return 3
  case "$cwd" in "$root"|"$root"/*) ;; *) return 3 ;; esac
  total=0
  current=$root
  while :; do
    instruction=''
    [ ! -f "$current/AGENTS.override.md" ] || instruction="$current/AGENTS.override.md"
    [ -n "$instruction" ] || { [ ! -f "$current/AGENTS.md" ] || instruction="$current/AGENTS.md"; }
    if [ -n "$instruction" ]; then
      size=$(wc -c < "$instruction" | tr -d ' ')
      total=$((total + size))
    fi
    [ "$current" != "$cwd" ] || break
    remainder=${cwd#"$current"/}
    component=${remainder%%/*}
    current="$current/$component"
  done
  if [ -n "$explicit_limit" ]; then
    limit=$explicit_limit source=explicit
  elif [ -f "$root/.codex/config.toml" ]; then
    limit=$(sed -n 's/^[[:space:]]*project_doc_max_bytes[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$root/.codex/config.toml" | tail -n 1)
    if [ -n "$limit" ]; then source=project; else limit=$(ak_json_get "$root/.agents/config.json" '.instructionBudgets.codexDefaultProjectDocMaxBytes'); source=reference; fi
  else
    limit=$(ak_json_get "$root/.agents/config.json" '.instructionBudgets.codexDefaultProjectDocMaxBytes')
    source=reference
  fi
  printf '%s\t%s\t%s\n' "$total" "$limit" "$source"
}

ak_limit_utf8() {
  text=$1 max=$2
  if command -v jq >/dev/null 2>&1; then
    jq -nr --arg text "$text" --argjson max "$max" '$text[0:$max]'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys; print(sys.argv[1][:int(sys.argv[2])],end="")' "$text" "$max"
  elif command -v node >/dev/null 2>&1; then
    node -e 'process.stdout.write(Array.from(process.argv[1]).slice(0,Number(process.argv[2])).join(""))' "$text" "$max"
  else
    return 3
  fi
}

ak_path_overlap() {
  left=$(printf '%s\n' "$1" | sed 's:/\*\*$::')
  right=$(printf '%s\n' "$2" | sed 's:/\*\*$::')
  [ "$left" = "$right" ] && return 0
  case "$left/" in "$right/"*) return 0 ;; esac
  case "$right/" in "$left/"*) return 0 ;; esac
  return 1
}

ak_detect_conflicts() {
  root=$1 selected_id=$2
  command -v jq >/dev/null 2>&1 || return 0
  selected_file=$(ak_list_active_work "$root" | awk -F '\t' -v id="$selected_id" '$1==id && !seen {print $2; seen=1}')
  [ -n "$selected_file" ] || return 0
  while IFS="$(printf '\t')" read -r other_id other_file; do
    [ -n "$other_id" ] || continue
    [ "$other_id" != "$selected_id" ] || continue
    for section in resources ports migrations; do
      left_values=$(jq -r ".ownership.$section[]?" "$selected_file")
      right_values=$(jq -r ".ownership.$section[]?" "$other_file")
      for left in $left_values; do
        printf '%s\n' "$right_values" | grep -Fx "$left" >/dev/null && { printf '%s:%s:%s\n' "$other_id" "$section" "$left"; return 0; }
      done
    done
    while IFS= read -r left; do
      [ -n "$left" ] || continue
      while IFS= read -r right; do
        [ -n "$right" ] || continue
        ak_path_overlap "$left" "$right" && { printf '%s:paths:%s|%s\n' "$other_id" "$left" "$right"; return 0; }
      done <<EOF
$(jq -r '.ownership.paths[]?' "$other_file")
EOF
    done <<EOF
$(jq -r '.ownership.paths[]?' "$selected_file")
EOF
  done <<EOF
$(ak_list_active_work "$root")
EOF
}


# --- Claude hook kaynagi -------------------------------------------------
#
# AKW401 "hook yok" demeden once hook'un gelebilecegi her kaynak taranir.
# Kit 1.2.0 ile hook'lar plugin paketiyle geliyor: goc edilmis bir projede
# .claude/settings.json bos kalir ama mekanik koruma calisir. Yalniz proje
# dosyasina bakmak o projelerin hepsinde yanlis uyari uretir.

ak_claude_config_dir() {
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then printf '%s\n' "$CLAUDE_CONFIG_DIR"; return 0; fi
  [ -n "${HOME:-}" ] || return 1
  printf '%s/.claude\n' "$HOME"
}

# Bos nesne yapilandirma degildir: "hooks": {} hicbir hook yuklemez.
ak_claude_settings_hooks() {
  ak_settings_file=$1
  [ -f "$ak_settings_file" ] || return 1
  ak_settings_hooks=$(ak_json_get "$ak_settings_file" '.hooks') || return 1
  ak_settings_hooks=$(printf '%s' "$ak_settings_hooks" | tr -d ' \t\r\n')
  case "$ak_settings_hooks" in ''|'{}'|'[]'|null) return 1 ;; *) return 0 ;; esac
}

# Ilk arguman installed_plugins.json, kalanlar enabledPlugins tasiyabilecek
# ayar dosyalari ARTAN oncelik sirasinda: kullanici, proje, proje yerel.
# Ayni anahtar icin son dosya kazanir; Claude Code ayar onceligi de boyle
# calisir. Birlesim almak yanlis olurdu: kullanici acmis ama proje kapatmissa
# o projede hook yuklenmez. Etkinlik kontrolu atlanamaz; kurulu ama kapali bir
# plugin hic hook yuklemez ve sessiz kalmak korumayi oldugundan genis gosterir.
ak_claude_enabled_plugin_paths() {
  if command -v jq >/dev/null 2>&1; then
    jq -rs '
      (.[0].plugins // {}) as $installed
      | (reduce .[1:][] as $settings ({}; . + ($settings.enabledPlugins // {}))) as $merged
      | [$merged | to_entries[] | select(.value == true) | .key] as $enabled
      | $installed | to_entries[]
      | select(.key as $key | $enabled | index($key))
      | .value
      | (if type == "array" then .[] else . end)
      | select(type == "object" and .installPath != null)
      | .installPath
    ' "$@"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
def load(path):
    try:
        with open(path,encoding="utf-8") as handle: return json.load(handle)
    except Exception: return None
installed=(load(sys.argv[1]) or {}).get("plugins") or {}
merged={}
for path in sys.argv[2:]:
    settings=load(path) or {}
    merged.update(settings.get("enabledPlugins") or {})
enabled=set(key for key,value in merged.items() if value is True)
for key,value in installed.items():
    if key not in enabled: continue
    for entry in (value if isinstance(value,list) else [value]):
        if isinstance(entry,dict) and entry.get("installPath"): print(entry["installPath"])' "$@"
  elif command -v node >/dev/null 2>&1; then
    node -e 'const fs=require("fs");
const load=p=>{try{return JSON.parse(fs.readFileSync(p,"utf8"))}catch(e){return null}};
const installed=(load(process.argv[1])||{}).plugins||{};
const merged={};
for(const p of process.argv.slice(2)){const s=load(p)||{};Object.assign(merged,s.enabledPlugins||{})}
const enabled=new Set(Object.entries(merged).filter(([,v])=>v===true).map(([k])=>k));
for(const[k,v] of Object.entries(installed)){if(!enabled.has(k))continue;for(const e of (Array.isArray(v)?v:[v]))if(e&&typeof e==="object"&&e.installPath)console.log(e.installPath)}' "$@"
  else
    printf 'AKE901 JSON ayrıştırıcı bulunamadı\n' >&2
    return 3
  fi
}

# Windows'ta jq (ve bazi awk yapilari) stdout'a CRLF yazar. Yola yapisan
# \r sessizce "dosya yok" sonucu uretir; hata yalniz POSIX kabuklarinda
# gorunur cunku Git Bash'in bash'i CR'i yutuyor. Bu yuzden kabuga donen
# her yol listesi tr -d ile temizlenir.
ak_claude_plugin_hooks() {
  ak_hook_root=$1
  ak_hook_config=$2
  ak_hook_installed="$ak_hook_config/plugins/installed_plugins.json"
  [ -f "$ak_hook_installed" ] || return 1
  set -- "$ak_hook_installed"
  for ak_hook_settings in "$ak_hook_config/settings.json" "$ak_hook_root/.claude/settings.json" "$ak_hook_root/.claude/settings.local.json"; do
    if [ -f "$ak_hook_settings" ]; then set -- "$@" "$ak_hook_settings"; fi
  done
  [ "$#" -gt 1 ] || return 1
  ak_hook_paths=$(ak_claude_enabled_plugin_paths "$@" 2>/dev/null | tr -d '\r') || return 1
  [ -n "$ak_hook_paths" ] || return 1
  ak_hook_ifs=$IFS
  IFS='
'
  ak_hook_found=1
  for ak_hook_package in $ak_hook_paths; do
    [ -n "$ak_hook_package" ] || continue
    if [ -f "$ak_hook_package/hooks/hooks.json" ]; then ak_hook_found=0; break; fi
  done
  IFS=$ak_hook_ifs
  return $ak_hook_found
}

ak_claude_hooks_active() {
  ak_active_root=$1
  ak_claude_settings_hooks "$ak_active_root/.claude/settings.json" && return 0
  ak_claude_settings_hooks "$ak_active_root/.claude/settings.local.json" && return 0
  ak_active_config=$(ak_claude_config_dir 2>/dev/null) || ak_active_config=''
  [ -n "$ak_active_config" ] || return 1
  ak_claude_settings_hooks "$ak_active_config/settings.json" && return 0
  ak_claude_plugin_hooks "$ak_active_root" "$ak_active_config" && return 0
  return 1
}

# --- Codex hook kaynagi --------------------------------------------------
#
# Claude tarafiyla ayni hata sinifi: yalniz <proje>/.codex/hooks.json dosyasina
# bakmak, plugin ile kurulmus projelerde yanlis uyari uretir. Codex'in kayit
# yeri JSON degil TOML'dur ve kurulu plugin listesi tutan bir dosya yoktur;
# tek otorite <CODEX_HOME>/config.toml dosyasidir.

ak_codex_home() {
  if [ -n "${CODEX_HOME:-}" ]; then printf '%s\n' "$CODEX_HOME"; return 0; fi
  [ -n "${HOME:-}" ] || return 1
  printf '%s/.codex\n' "$HOME"
}

# [plugins."ad@market"] bloklarindan enabled = true olanlarin anahtarlarini
# basar. Tam TOML ayristirmaya gerek yok: Codex bu bloklari bolum basligi
# olarak yazar ve anahtar @ tasidigi icin daima tirnaklidir. Alt bolum
# ([plugins."ad@market".policy]) kasitla eslesmez; oradaki enabled baska
# seyi anlatir.
ak_codex_enabled_plugins() {
  ak_codex_config=$1
  [ -f "$ak_codex_config" ] || return 0
  awk '
    /^[[:space:]]*\[/ {
      current = ""
      header = $0
      if (header ~ /^[[:space:]]*\[plugins\."[^"]+"\][[:space:]]*$/) {
        sub(/^[[:space:]]*\[plugins\."/, "", header)
        sub(/"\][[:space:]]*$/, "", header)
        current = header
      }
      next
    }
    current != "" && $0 ~ /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true[[:space:]]*(#.*)?$/ { print current }
  ' "$ak_codex_config"
}

# Codex hook'u kaydedip kullanici guvendiyse config.toml icine
# [hooks.state."<anahtar>:<dosya>:<olay>:i:j"] yazar. Bu kayit paket
# yerlesiminden bagimsiz ve guven duzeyinde bir kanittir.
ak_codex_hook_state() {
  ak_state_config=$1
  ak_state_key=$2
  [ -f "$ak_state_config" ] || return 1
  grep -F "[hooks.state.\"$ak_state_key:" "$ak_state_config" >/dev/null 2>&1
}

ak_codex_plugin_hooks() {
  ak_codex_dir=$1
  ak_codex_file="$ak_codex_dir/config.toml"
  [ -f "$ak_codex_file" ] || return 1
  ak_codex_keys=$(ak_codex_enabled_plugins "$ak_codex_file" | tr -d '\r') || return 1
  [ -n "$ak_codex_keys" ] || return 1
  ak_codex_ifs=$IFS
  IFS='
'
  ak_codex_found=1
  for ak_codex_key in $ak_codex_keys; do
    [ -n "$ak_codex_key" ] || continue
    if ak_codex_hook_state "$ak_codex_file" "$ak_codex_key"; then ak_codex_found=0; break; fi
    ak_codex_name=${ak_codex_key%@*}
    ak_codex_market=${ak_codex_key#*@}
    [ "$ak_codex_name" != "$ak_codex_key" ] || continue
    for ak_codex_package in "$ak_codex_dir/plugins/cache/$ak_codex_market/$ak_codex_name"/*; do
      [ -f "$ak_codex_package/hooks/hooks.json" ] || continue
      ak_codex_found=0
      break
    done
    [ "$ak_codex_found" = 1 ] || break
  done
  IFS=$ak_codex_ifs
  return $ak_codex_found
}

ak_codex_hooks_active() {
  ak_codex_project=$1
  [ ! -f "$ak_codex_project/.codex/hooks.json" ] || return 0
  ak_codex_home_dir=$(ak_codex_home 2>/dev/null) || ak_codex_home_dir=''
  [ -n "$ak_codex_home_dir" ] || return 1
  [ ! -f "$ak_codex_home_dir/hooks.json" ] || return 0
  ak_codex_plugin_hooks "$ak_codex_home_dir" && return 0
  return 1
}
