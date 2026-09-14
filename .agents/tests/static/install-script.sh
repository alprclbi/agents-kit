#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# KURULUM BETIGI SOZLESMESI.
#
# install.sh kullanicinin ilk temas noktasi. Sessizce yanlis yere
# kurmasi ya da mevcut dosyalari ezmesi geri alinmasi zor bir hata olur.
# Bu test davranisi GERCEKTEN KOSARAK dogrular, metin aramaz.
#
# Sandbox depo agacinin DISINDA kurulur: install.sh kendi kaynagina
# kurulumu reddeder, .agents/runtime kullanilsa test hep 2 donerdi.

[ -f install.sh ]  || { printf 'E_IS_MISSING_SH\n' >&2; exit 2; }
[ -f install.ps1 ] || { printf 'E_IS_MISSING_PS1\n' >&2; exit 2; }
sh -n install.sh

tmp=$(mktemp -d)
case "$tmp" in /*) ;; *) printf 'E_IS_TMP %s\n' "$tmp" >&2; exit 2 ;; esac
cleanup_is() { case "$tmp" in /*/*) rm -rf -- "$tmp" ;; esac; }
trap cleanup_is EXIT HUP INT TERM

kit=$(pwd -P)

# --- 1. Bos projeye kurulum -------------------------------------------
mkdir -p "$tmp/bos"
( cd "$tmp/bos" && sh "$kit/install.sh" --yes >/dev/null 2>&1 ) \
  || { printf 'E_IS_FRESH_FAILED\n' >&2; exit 2; }

for want in AGENTS.md CLAUDE.md AGENT-KIT-START.md .agents/manifest.json .claude/settings.json .codex/hooks.json; do
  [ -e "$tmp/bos/$want" ] || { printf 'E_IS_MISSING_PAYLOAD %s\n' "$want" >&2; exit 2; }
done

# Kok belgeler kitin kendi deposuna ait; kullanicinin projesine GIRMEZ.
for deny in README.md LICENSE CONTRIBUTING.md SECURITY.md CHANGELOG.md CODE_OF_CONDUCT.md .github .gitignore; do
  [ ! -e "$tmp/bos/$deny" ] || { printf 'E_IS_LEAKED %s\n' "$deny" >&2; exit 2; }
done

# Kurulan projede manifest KENDI icerigini anlatmali; kaynak manifest
# oldugu gibi kopyalanirsa kullanicinin ilk kontrolu "dosya eksik" der.
( cd "$tmp/bos" && sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check >/dev/null 2>&1 ) \
  || { printf 'E_IS_MANIFEST_NOT_FILTERED\n' >&2; exit 2; }

# Satir sonu korumasi: hedefte .gitattributes yoksa olusturulmali.
[ -f "$tmp/bos/.gitattributes" ] || { printf 'E_IS_NO_GITATTRIBUTES\n' >&2; exit 2; }
grep -F 'eol=lf' "$tmp/bos/.gitattributes" >/dev/null || { printf 'E_IS_GITATTRIBUTES_CONTENT\n' >&2; exit 2; }

# Uslup kurallari .agents/local/preferences.md icinde yasar ve o dosya
# git disinda oldugu icin kuruluma GIRMEZ. Tohumlanmazsa yeni kurulumda
# hic uslup kurali olmaz. 2026-09-11: gercek kullanimda ajan uzun yazdi,
# cunku o projede blok hic yoktu.
[ -f "$tmp/bos/.agents/local/preferences.md" ] \
  || { printf 'E_IS_NO_PREFS tercih dosyasi tohumlanmadi\n' >&2; exit 2; }
grep -F 'ak:style' "$tmp/bos/.agents/local/preferences.md" >/dev/null \
  || { printf 'E_IS_PREFS_NO_STYLE tercih dosyasinda ak:style blogu yok\n' >&2; exit 2; }

# Blok oturum baglaminda GERCEKTEN basilmali; dosyanin varligi yetmez.
ctx=$( cd "$tmp/bos" && sh .agents/validators/sh/agent-kit.sh session-context \
       --root "$PWD" --client claude --source startup --format text 2>/dev/null )
printf '%s' "$ctx" | grep -F 'Iletisim tercihi' >/dev/null \
  || { printf 'E_IS_PREFS_NOT_INJECTED uslup blogu oturum baglaminda yok\n' >&2; exit 2; }

# --- 2. Cakisma varsa HICBIR SEY yazilmamali ---------------------------
mkdir -p "$tmp/dolu"
printf 'kullanicinin kendi dosyasi\n' > "$tmp/dolu/CLAUDE.md"
code=0
( cd "$tmp/dolu" && sh "$kit/install.sh" --yes >/dev/null 2>&1 ) || code=$?
[ "$code" = 3 ] || { printf 'E_IS_CONFLICT_CODE %s (3 bekleniyor)\n' "$code" >&2; exit 2; }
[ ! -e "$tmp/dolu/AGENTS.md" ] || { printf 'E_IS_CONFLICT_WROTE\n' >&2; exit 2; }
[ ! -e "$tmp/dolu/.agents" ] || { printf 'E_IS_CONFLICT_WROTE_AGENTS\n' >&2; exit 2; }
[ "$(cat "$tmp/dolu/CLAUDE.md")" = 'kullanicinin kendi dosyasi' ] \
  || { printf 'E_IS_CONFLICT_OVERWROTE\n' >&2; exit 2; }

# --- 2b. Cakisma mesaji UYGULANABILIR olmali --------------------------
# 2026-09-11: mesaj "init skill'ini calistir" diyordu. Ama kit
# HENUZ KURULMADIGI icin o skill projede YOKTU; kullanicinin ajani
# "boyle bir skill bulamadim" dedi. Talimat, klondaki SKILL.md yolunu
# vermeli.
msg=$( cd "$tmp/dolu" && sh "$kit/install.sh" --yes 2>&1 || true )
printf '%s' "$msg" | grep -F 'skills/init/SKILL.md' >/dev/null   || { printf 'E_IS_NO_SKILL_PATH cakisma mesajinda skill yolu yok
' >&2; exit 2; }
printf '%s' "$msg" | grep -F "$kit" >/dev/null   || { printf 'E_IS_NO_KIT_ROOT cakisma mesajinda kit koku yok
' >&2; exit 2; }
grep -F 'skills\init\SKILL.md' install.ps1 >/dev/null   || { printf 'E_IS_PS1_NO_SKILL_PATH
' >&2; exit 2; }
# Eski yol kalintisi: kaynak skills/ altina tasindi, .agents/skills artik
# yalniz KURULU projede var. Klon icindeki yolu gosteren mesaj eskiyse
# kullanicinin ajani dosyayi bulamaz.
! grep -F '.agents\skills\init' install.ps1 >/dev/null   || { printf 'E_IS_PS1_STALE_SKILL_PATH
' >&2; exit 2; }
! grep -F '.agents/skills/init/SKILL.md' install.sh >/dev/null   || { printf 'E_IS_SH_STALE_SKILL_PATH
' >&2; exit 2; }

# Kontrol karakteri sizintisi: betikler duzenlenirken "BS-a" gibi kacis
# dizileri gercek BEL karakterine donusup yollari bozdu. Once PowerShell
# ciktisinda "skillsdopt-kit" olarak gorundu.
for f in install.sh install.ps1; do
  if LC_ALL=C grep -qU "$(printf '')" "$f"; then
    printf 'E_IS_CONTROL_CHAR %s icinde BEL var
' "$f" >&2; exit 2
  fi
done


# --- 3. Zaten kuruluysa tekrar kurmamali -------------------------------
code=0
( cd "$tmp/bos" && sh "$kit/install.sh" --yes >/dev/null 2>&1 ) || code=$?
[ "$code" = 3 ] || { printf 'E_IS_REINSTALL_CODE %s (3 bekleniyor)\n' "$code" >&2; exit 2; }

# --- 4. Yanlis hedefi reddetmeli ---------------------------------------
code=0
( cd "$kit" && sh "$kit/install.sh" --yes >/dev/null 2>&1 ) || code=$?
[ "$code" = 2 ] || { printf 'E_IS_SELF_TARGET %s (2 bekleniyor)\n' "$code" >&2; exit 2; }

# --- 5. Iki betik ayni sozlesmeyi anlatmali ----------------------------
for marker in 'AGENT-KIT-START.md' 'init' 'update' 'gitattributes'; do
  grep -F "$marker" install.sh  >/dev/null || { printf 'E_IS_SH_MARKER %s\n' "$marker" >&2; exit 2; }
  grep -F "$marker" install.ps1 >/dev/null || { printf 'E_IS_PS1_MARKER %s\n' "$marker" >&2; exit 2; }
done

# --- 5b. Yuk filtresi ve yol eslemesi iki betikte de olmali ------------
# PowerShell betigi bu testte CALISTIRILAMIYOR (Linux CI'da pwsh yok),
# bu yuzden parite metin duzeyinde zorlanir. Biri degisip digeri
# degismezse kullanicilarin yarisi farkli bir kurulum alir.
grep -F 'tests|evals' install.sh >/dev/null \
  || { printf 'E_IS_SH_NO_DEV_FILTER tests/evals filtresi yok\n' >&2; exit 2; }
grep -F "notlike '.agents/tests/*'" install.ps1 >/dev/null \
  || { printf 'E_IS_PS1_NO_DEV_FILTER tests filtresi yok\n' >&2; exit 2; }
grep -F "notlike '.agents/evals/*'" install.ps1 >/dev/null \
  || { printf 'E_IS_PS1_NO_EVALS_FILTER evals filtresi yok\n' >&2; exit 2; }
grep -F 'target_path()' install.sh >/dev/null \
  || { printf 'E_IS_SH_NO_REMAP yol eslemesi yok\n' >&2; exit 2; }
grep -F 'Get-TargetPath' install.ps1 >/dev/null \
  || { printf 'E_IS_PS1_NO_REMAP yol eslemesi yok\n' >&2; exit 2; }

# --- 5c. Betikler plugin yolunu ONERMELI -------------------------------
# Betikler artik birincil yol degil. Plugin yolu klon, gecici dizin ve
# yol yapistirma istemez; betikleri cevrimdisi ve CI icin tutuyoruz.
# Onerilmezse kullanici zor yolu tek yol sanir.
for f in install.sh install.ps1; do
  grep -F 'plugin marketplace add' "$f" >/dev/null \
    || { printf 'E_IS_NO_PLUGIN_HINT %s plugin yolunu onermiyor\n' "$f" >&2; exit 2; }
  grep -F 'cevrimdisi' "$f" >/dev/null \
    || { printf 'E_IS_NO_OFFLINE_NOTE %s cevrimdisi oldugunu soylemiyor\n' "$f" >&2; exit 2; }
done

# --help ciktisi basligi TAM kapsamali. Baslik uzatilip aralik
# guncellenmezse cikis kodlari sessizce kaybolur.
help_out=$(sh install.sh --help)
for marker in 'plugin marketplace add' 'Cikis kodlari' 'hicbir sey yazilmadi'; do
  printf '%s' "$help_out" | grep -Fq "$marker" \
    || { printf 'E_IS_HELP_TRUNCATED %s\n' "$marker" >&2; exit 2; }
done

cleanup_is
trap - EXIT HUP INT TERM
printf 'PASS install-script bos/cakisma/tekrar/yanlis-hedef\n'
