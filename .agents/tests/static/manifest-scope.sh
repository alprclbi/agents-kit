#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# MANIFEST KAPSAMI SOZLESMESI.
#
# manifest --write kok altindaki HER dosyayi tariyordu. Kitin kendi deposunda
# dogru: orada zaten her dosya kitin. Kullanicinin projesinde felaket:
# uygulama kodu, .venv, build ciktisi manifeste girer ve kullanici tek satir
# kod degistirdigi anda "butunluk bozuldu" uyarisi alir.
#
# Kapsam koke bakilarak secilir. .claude-plugin/plugin.json yalniz kitin
# kendi deposunda bulunur; kullanicinin projesine hic kurulmaz.
#   kit deposu -> genis liste (skills/, hooks/, install.sh, LICENSE, ...)
#   proje      -> dar liste (.agents/, .claude/, .codex/ ve uc talimat dosyasi)

tmp=$(mktemp -d "$root/.agents/runtime/manifest-scope.XXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM

# --- 1. Kullanici projesi: uygulama kodu manifeste GIRMEMELI -----------
proje="$tmp/proje"
mkdir -p "$proje/.agents/runtime" "$proje/.agents/playbooks" "$proje/.claude" "$proje/src" "$proje/.venv/lib" "$proje/build"
cp "$root/.agents/tests/fixtures/validator/solo-one-active/repo/.agents/config.json" "$proje/.agents/config.json"
cp "$root/AGENTS.md" "$proje/AGENTS.md"
cp "$root/CLAUDE.md" "$proje/CLAUDE.md"
cp "$root/.agents/playbooks/verification.md" "$proje/.agents/playbooks/verification.md"
printf '{"plansDirectory":".agents/runtime/claude-plans"}\n' > "$proje/.claude/settings.json"
printf 'print("merhaba")\n' > "$proje/src/uygulama.py"
printf 'derleme ciktisi\n' > "$proje/build/cikti.bin"
printf 'paket\n' > "$proje/.venv/lib/paket.py"
printf '# Kullanicinin kendi README dosyasi\n' > "$proje/README.md"
printf 'MIT\n' > "$proje/LICENSE"
printf 'node_modules\n' > "$proje/.gitignore"

# Kullanicinin KIT DIZINLERI ICINDE actigi kendi icerigi. .agents/ altinda
# olmasi kitin sahibi oldugu anlamina gelmez: ornegin bir projede
# .agents/ads/ altinda gunluk nobet notlari tutulabilir. Bunlar manifeste girerse
# kullanici her not yazdiginda butunluk kontrolu duser.
mkdir -p "$proje/.agents/ads/anlik" "$proje/.agents/specs" "$proje/.agents/roadmaps" "$proje/.agents/changes/active/123" "$proje/.agents/local"
printf 'gunluk not\n' > "$proje/.agents/ads/2026-09-06.md"
printf '{}\n' > "$proje/.agents/ads/anlik/2026-09-06.json"
printf 'kendi specim\n' > "$proje/.agents/specs/kendi-specim.md"
printf 'yol haritam\n' > "$proje/.agents/roadmaps/plan.md"
printf 'is kaydi\n' > "$proje/.agents/changes/active/123/status.md"
printf 'kisisel tercih\n' > "$proje/.agents/local/preferences.md"
printf '{}\n' > "$proje/.claude/launch.json"
printf '{}\n' > "$proje/.claude/settings.local.json"

sh "$validator" manifest --root "$proje" --write >/dev/null

kullanici_yollari="src/uygulama.py build/cikti.bin .venv/lib/paket.py README.md LICENSE .gitignore"
kullanici_yollari="$kullanici_yollari .agents/ads/2026-09-06.md .agents/ads/anlik/2026-09-06.json"
kullanici_yollari="$kullanici_yollari .agents/specs/kendi-specim.md .agents/roadmaps/plan.md"
kullanici_yollari="$kullanici_yollari .agents/changes/active/123/status.md .agents/local/preferences.md"
kullanici_yollari="$kullanici_yollari .claude/launch.json .claude/settings.local.json"
for yol in $kullanici_yollari; do
  if jq -e --arg p "$yol" 'any(.files[]; .path == $p)' "$proje/.agents/manifest.json" >/dev/null; then
    printf 'FAIL kullanici dosyasi manifeste girdi: %s\n' "$yol" >&2
    fail=1
  fi
done

for yol in AGENTS.md CLAUDE.md .agents/config.json .agents/playbooks/verification.md .claude/settings.json; do
  if ! jq -e --arg p "$yol" 'any(.files[]; .path == $p)' "$proje/.agents/manifest.json" >/dev/null; then
    printf 'FAIL kit dosyasi manifeste girmedi: %s\n' "$yol" >&2
    fail=1
  fi
done

sh "$validator" manifest --root "$proje" --check >/dev/null \
  || { printf 'FAIL yeni yazilan manifest kendi kontrolunu gecmedi\n' >&2; fail=1; }

# Kullanicinin kodu degisince manifest bozulmamali; asil derdimiz buydu.
printf 'print("degisti")\n' > "$proje/src/uygulama.py"
sh "$validator" manifest --root "$proje" --check >/dev/null \
  || { printf 'FAIL uygulama kodu degisince manifest bozuldu\n' >&2; fail=1; }

# --- 2. Kit deposu: kapsam daralmamali --------------------------------
# Gercek depoda write calistirmak mevcut manifesti ezer; bu yuzden kitin
# kendi manifestinin hala butun oldugu ve YALNIZ kit deposunda bulunan
# yollari tasidigi sinanir. Bu yollar proje kapsaminda kasitla disarida.
if ! sh "$validator" manifest --root "$root" --check >/dev/null; then
  printf 'FAIL kit deposu manifesti butun degil\n' >&2
  fail=1
fi

kit_yollari="skills/kit-doctor/SKILL.md hooks/hooks.json install.sh LICENSE .claude-plugin/plugin.json .github/workflows/validation.yml"
for yol in $kit_yollari; do
  if ! jq -e --arg p "$yol" 'any(.files[]; .path == $p)' "$root/.agents/manifest.json" >/dev/null; then
    printf 'FAIL kit deposu kapsami daraldi, eksik: %s\n' "$yol" >&2
    fail=1
  fi
done

# --- 3. Bekci: yeni .agents/ girdisi siniflandirilmadan gecmesin -------
# Liste acik sayim oldugu icin kit .agents/ altina yeni bir dizin eklerse
# ve manifest_include guncellenmezse o dizin SESSIZCE manifest disi kalir.
# Sessiz kapsam kaybi, gurultulu bir testten cok daha pahalidir.
kit_sahibi="adapters contracts evals playbooks plugins schemas skills templates tests validators"
kullanici_alani="changes local runtime specs roadmaps logs"
kit_dosyalari=".gitignore CHANGELOG.md NOTICE.md README.md VERSION config.json manifest.json preferences.example.md project.md rule-inventory.md"
for girdi in "$root"/.agents/*; do
  ad=$(basename "$girdi")
  biliniyor=0
  for bilinen in $kit_sahibi $kullanici_alani $kit_dosyalari; do
    [ "$ad" = "$bilinen" ] && biliniyor=1
  done
  if [ "$biliniyor" -eq 0 ]; then
    printf 'FAIL .agents/%s siniflandirilmamis: manifest_include ve Test-ManifestIncluded listelerine ekle\n' "$ad" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ] || exit 1
printf 'PASS manifest-scope\n'
