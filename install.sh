#!/bin/sh
# Agents Kit kurulumu -- CEVRIMDISI ve CI yolu.
#
# Claude Code veya Codex kullaniyorsan bu betige ihtiyacin yok:
#   /plugin marketplace add alprclbi/agents-kit
#   /plugin install agents-kit@agents-kit
# Plugin yolu klon istemez ve araclari kendi kendine gunceller.
#
# Bu betik aga kapali ortam, CI ve plugin kullanmayan kurulum icindir.
#
# Kullanim: kendi projenin KOKUNDE calistir.
#   git clone --depth 1 https://github.com/alprclbi/agents-kit /tmp/ak
#   cd /senin/projen
#   sh /tmp/ak/install.sh
#
# Hedef her zaman calisma dizinidir ($PWD), kitin bulundugu yer degil.
#
# Cikis kodlari:
#   0  kuruldu
#   2  hata (yanlis hedef, bozuk kaynak)
#   3  hicbir sey yazilmadi: cakisma, iptal, ya da kit zaten kurulu
set -eu

assume_yes=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) assume_yes=1 ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^#\{1,\} \{0,1\}//'; exit 0 ;;
    *) printf 'HATA: bilinmeyen secenek: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

kit=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
target=$(pwd -P)
manifest="$kit/.agents/manifest.json"

[ -f "$manifest" ] || { printf 'HATA: kit kaynagi eksik: %s\n' "$manifest" >&2; exit 2; }

# --- Hedef dogrulamasi -------------------------------------------------
# En sik hata: kullanici kendi projesine cd etmeyi unutur ve kiti ev
# dizinine ya da kit kaynaginin icine kurar. Ucu de reddedilir.
case "$target" in
  "$kit"|"$kit"/*)
    printf 'HATA: kit kaynaginin icindesin.\n' >&2
    printf 'Once kendi projenin koküne cd et, sonra bu betigi calistir.\n' >&2
    exit 2
    ;;
esac
[ "$target" != "/" ] || { printf 'HATA: hedef kok dizin olamaz.\n' >&2; exit 2; }
if [ -n "${HOME:-}" ] && [ "$target" = "$HOME" ]; then
  printf 'HATA: hedef ev dizini olamaz. Kendi projenin koküne cd et.\n' >&2
  exit 2
fi

version=$(tr -d ' \r\n' < "$kit/.agents/VERSION" 2>/dev/null || printf 'bilinmiyor')

if [ -e "$target/.agents/manifest.json" ]; then
  printf 'Kit bu projede zaten kurulu.\n\n'
  printf 'Guncelleme icin ajanina soyle:  update skill%sini calistir\n' "'"
  printf 'Kaldirma icin:                  remove-kit skill%sini calistir\n' "'"
  exit 3
fi

# --- Kurulacak dosyalar ------------------------------------------------
# Liste manifestten uretilir, elle tutulmaz: kit buyudukce kurulum
# listesi kendiliginden guncel kalir.
#
# Kok belgeler (README, LICENSE, CONTRIBUTING, SECURITY, CHANGELOG,
# CODE_OF_CONDUCT) ve .github KURULMAZ. Onlar kitin kendi deposuna
# aittir; kullanicinin projesinde onun dosyalarini ezerlerdi.
#
# Kok .gitignore de kurulmaz. Kit deposunda is kayitlarini disarida
# tutar, ama kullanicinin projesinde is kayitlari genelde takimla
# paylasilir. Kisisel tercihler zaten .agents/.gitignore ile korunur.
work=$(mktemp -d "${TMPDIR:-/tmp}/agents-kit-install.XXXXXX") || exit 2
cleanup() { [ -z "${work:-}" ] || rm -rf -- "$work"; }
trap cleanup EXIT HUP INT TERM

payload="$work/payload"
conflicts="$work/conflicts"
: > "$conflicts"

# Skill kaynagi kit deposunda skills/ altinda yasar; plugin paketlemesi
# orayi bekler. Kullanicinin projesinde ise .agents/skills/ altina gider:
# Codex'in repo duzeyindeki kanonik yolu orasi ve .claude/skills/
# adaptorleri de oraya isaret eder. Tek kaynak, iki hedef.
target_path() {
  case "$1" in
    skills/*) printf '.agents/%s\n' "$1" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# .agents/tests ve .agents/evals kitin KENDI gelistirme altyapisidir;
# kullanicinin deposunda is gormez, yer kaplar ve onun kendi test
# dizinleriyle karisir. Plugin manifestleri de kuruluma girmez: onlar
# kitin dagitim paketini anlatir, kullanicinin projesini degil.
sed -n 's/.*"path": "\([^"]*\)".*/\1/p' "$manifest" \
  | grep -E '^([.]agents/|[.]claude/|[.]codex/|skills/|AGENTS[.]md$|CLAUDE[.]md$|AGENT-KIT-START[.]md$)' \
  | grep -vE '^[.]agents/(tests|evals)/' \
  > "$payload" || true

total=$(awk 'NF {n++} END {print n+0}' "$payload")
[ "$total" -gt 0 ] || { printf 'HATA: kurulacak dosya bulunamadi.\n' >&2; exit 2; }

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  [ -e "$kit/$rel" ] || { printf 'HATA: kaynakta eksik dosya: %s\n' "$rel" >&2; exit 2; }
  dst=$(target_path "$rel")
  [ ! -e "$target/$dst" ] || printf '%s\n' "$dst" >> "$conflicts"
done < "$payload"

conflict_count=$(awk 'NF {n++} END {print n+0}' "$conflicts")

client=''
[ ! -d "$target/.claude" ] || client='Claude Code'
if [ -z "$client" ] && command -v claude >/dev/null 2>&1; then client='Claude Code'; fi
if [ -z "$client" ] && [ -d "$target/.codex" ]; then client='Codex'; fi
if [ -z "$client" ] && command -v codex >/dev/null 2>&1; then client='Codex'; fi
[ -n "$client" ] || client='tespit edilemedi'

printf 'Agents Kit %s\n' "$version"
printf 'Hedef   : %s\n' "$target"
printf 'Istemci : %s\n' "$client"
printf '\n'

if [ "$conflict_count" -gt 0 ]; then
  printf 'Cakisan dosyalar var; HICBIR SEY YAZILMADI (%s dosya):\n\n' "$conflict_count"
  sed 's/^/  /' "$conflicts"
  printf '\nMevcut dosyalarini ezmek yerine ajanina soyle:\n\n'
  printf '  Su dosyayi oku ve uygula: %s/skills/init/SKILL.md\n' "$kit"
  printf '  Kit koku: %s\n\n' "$kit"
  printf 'init her hedefi siniflar ve exact diff onaylanmadan yazmaz.\n'
  printf 'Kit kaynagini SILME; skill oradan okunuyor.\n'
  exit 3
fi

printf 'Cakisma yok. %s dosya kopyalanacak.\n' "$total"
if [ "$assume_yes" -eq 0 ]; then
  printf 'Devam edilsin mi? [e/H] '
  if [ -r /dev/tty ]; then read -r answer < /dev/tty; else read -r answer || answer=''; fi
  case "${answer:-}" in
    e|E|evet|Evet|y|Y|yes) ;;
    *) printf 'Iptal edildi, hicbir sey yazilmadi.\n'; exit 3 ;;
  esac
fi

copied=0
: > "$work/installed"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  dst=$(target_path "$rel")
  dir=$(dirname -- "$dst")
  [ "$dir" = '.' ] || mkdir -p -- "$target/$dir"
  cp -p -- "$kit/$rel" "$target/$dst"
  printf '%s\t%s\n' "$rel" "$dst" >> "$work/installed"
  copied=$((copied + 1))
done < "$payload"

printf '\nkopyalandi   : %s dosya\n' "$copied"

# --- Hedefteki manifesti kurulan dosyalara indir ------------------------
# Kaynak manifest kitin KENDI deposunu anlatir; README, LICENSE ve
# .github gibi kurmadigimiz dosyalari da listeler. Oldugu gibi birakirsak
# kullanicinin ilk "manifest --check" komutu "dosya eksik" der.
# Yol yeniden eslemesi de manifeste yansir: skills/x kaynakta, hedefte
# .agents/skills/x. Yansitilmazsa kullanicinin ilk manifest --check
# komutu "dosya eksik" der.
if command -v jq >/dev/null 2>&1; then
  awk -F '\t' 'NF == 2 {printf "{\"src\":\"%s\",\"dst\":\"%s\"}\n", $1, $2}' "$work/installed" \
    | jq -s . > "$work/map.json"
  if jq --slurpfile map "$work/map.json" '
        ($map[0] | map({key: .src, value: .dst}) | from_entries) as $m
        | .files |= (map(select(.path as $p | ($m[$p] != null) or $p == ".agents/manifest.json"))
                     | map(if $m[.path] != null then .path = $m[.path] else . end))
      ' "$target/.agents/manifest.json" > "$work/manifest.json" 2>/dev/null; then
    tr -d '\r' < "$work/manifest.json" > "$target/.agents/manifest.json"
  fi
fi

# --- Kisisel tercih dosyasini tohumla ----------------------------------
# Uslup kurallari .agents/local/preferences.md icinde yasar ve o dosya
# git disinda oldugu icin KURULUMA GIRMEZ. Tohumlanmazsa yeni kurulumda
# hic uslup kurali olmaz; ajan uzun yazar ve kullanici sebebini bilmez.
# Var olan dosyaya dokunmuyoruz.
prefs_target="$target/.agents/local/preferences.md"
prefs_example="$kit/.agents/preferences.example.md"
if [ ! -e "$prefs_target" ] && [ -f "$prefs_example" ]; then
  mkdir -p "$target/.agents/local"
  cp -p -- "$prefs_example" "$prefs_target"
  printf 'tercihler    : .agents/local/preferences.md olusturuldu (uslup kurallari)\n'
fi

# --- Satir sonu korumasi ------------------------------------------------
# Manifest hash'leri LF'e bagli. Hedef depoda .gitattributes yoksa git
# kit dosyalarini CRLF ile checkout edebilir ve dogrulama TAKIM
# ARKADASINDA duser. Var olan dosyaya dokunmuyoruz.
if [ ! -e "$target/.gitattributes" ]; then
  {
    printf '# Agents Kit dosyalari LF olmali: manifest dogrulamasi bayt\n'
    printf '# duzeyinde calisir, CRLF sizarsa klonlayanda duser.\n'
    printf '.agents/** text eol=lf\n'
    printf '.claude/** text eol=lf\n'
    printf '.codex/** text eol=lf\n'
    printf 'AGENTS.md text eol=lf\n'
    printf 'CLAUDE.md text eol=lf\n'
    printf 'AGENT-KIT-START.md text eol=lf\n'
  } > "$target/.gitattributes"
  printf 'gitattributes: olusturuldu (kit dosyalari icin LF)\n'
fi

doctor="$target/.agents/validators/sh/agent-kit.sh"
if [ -f "$doctor" ]; then
  if sh "$doctor" manifest --root "$target" --check >/dev/null 2>&1; then
    printf 'manifest     : butunluk dogrulandi\n'
  else
    printf 'manifest     : DOGRULANAMADI\n' >&2
  fi
  if sh "$doctor" doctor --root "$target" --client codex --format text 2>/dev/null \
     | grep -F 'AKW401' >/dev/null; then
    printf 'hook         : etkin degil, mekanik koruma dusuk\n'
  else
    printf 'hook         : yapilandirilmis\n'
  fi
fi

printf '\nSonraki adim:\n'
if [ "$client" = 'Codex' ]; then
  printf '  1. Codex ac, /hooks ile uc hook%su incele ve guven karari ver\n' "'"
else
  printf '  1. Ajani ac; kurallar ve hook%slar ilk oturumda devreye girer\n' "'"
fi
printf '  2. .agents/project.md dosyasini doldur\n'
printf '\nAyrinti: AGENT-KIT-START.md\n'

# Bu betik artik BIRINCIL yol degil. Plugin yolu klon, gecici dizin ve
# yol yapistirma istemez; ayrica araclari kendi kendine gunceller.
# Onerilmezse kullanici zor yolu tek yol sanir.
printf '\nNOT: Bu betik cevrimdisi ve CI kurulumu icindir.\n'
printf 'Claude Code veya Codex kullaniyorsan plugin yolu daha kolay:\n'
printf '  /plugin marketplace add alprclbi/agents-kit\n'
printf '  /plugin install agents-kit@agents-kit\n'
printf 'Codex: codex plugin marketplace add alprclbi/agents-kit\n'
exit 0
