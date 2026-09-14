#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

for skill in init update remove-kit; do
  # Kaynak kit deposunda skills/ altinda; kurulu projede .agents/skills/
  # altinda. Stub KURULU yolu gosterir, cunku kullaniciya o gider.
  canonical="skills/$skill/SKILL.md"
  installed=".agents/skills/$skill/SKILL.md"
  wrapper=".claude/skills/$skill/SKILL.md"
  [ -f "$canonical" ] || { printf 'E_MANAGEMENT_SKILL_MISSING %s\n' "$skill" >&2; exit 2; }
  [ -f "$wrapper" ] || { printf 'E_MANAGEMENT_WRAPPER_MISSING %s\n' "$skill" >&2; exit 2; }
  grep -Fq "\`$installed\` dosyasını tamamen oku ve uygula." "$wrapper" || { printf 'E_MANAGEMENT_WRAPPER_TARGET %s\n' "$skill" >&2; exit 2; }
  grep -Fq "\`$canonical\`" "$wrapper" || { printf 'E_MANAGEMENT_WRAPPER_NO_SOURCE %s\n' "$skill" >&2; exit 2; }
  grep -Fq 'Bu adaptör ek commit, branch, worktree, alt ajan veya harici yazma yetkisi vermez.' "$wrapper" || { printf 'E_MANAGEMENT_WRAPPER_AUTHORITY %s\n' "$skill" >&2; exit 2; }
  [ "$(wc -w < "$canonical" | tr -d ' ')" -le 500 ] || { printf 'E_MANAGEMENT_SKILL_TOO_LONG %s\n' "$skill" >&2; exit 2; }
done

# init EN COK IKI SORU sozlesmesi. 2026-09-11: gercek kullanimda skill
# alti ayri karar noktasi sordu ve uc uzun rapor bastirdi; kullanici "bu
# kadar ugrasmamam gerekiyor" dedi. Sozlesme metinde durmazsa davranis
# geri kayar.
init=skills/init/SKILL.md
for marker in 'En çok iki soru' 'önce yedekle' 'Öz denetim' 'Rapor kuralı'; do
  grep -Fq "$marker" "$init" || { printf 'E_MANAGEMENT_INIT_CONTRACT %s\n' "$marker" >&2; exit 2; }
done
# Sorulardan biri calisma bicimi: profil artik cikarimla bulunmuyor,
# kurulumda bir kez soruluyor ve config.json'a yaziliyor.
for choice in 'Yalniz' 'Ekiple' 'profile'; do
  grep -Fq "$choice" "$init" || { printf 'E_MANAGEMENT_INIT_PROFILE %s\n' "$choice" >&2; exit 2; }
done
# Ikinci soru ONAY DEGIL, gercek bir secim: kullanicinin kendi
# kurallarini koruyup korumayacagini ajan tahmin edemez.
for choice in 'Kurallarimi koru' 'Kiti kullan'; do
  grep -Fq "$choice" "$init" || { printf 'E_MANAGEMENT_INIT_CHOICE %s\n' "$choice" >&2; exit 2; }
done
# Kullanicinin hook'lari kurulumda kaybolmamali.
grep -Fq 'alan düzeyinde birleştir' "$init" \
  || { printf 'E_MANAGEMENT_INIT_SETTINGS_MERGE\n' >&2; exit 2; }
grep -Fq 'preferences.example.md' "$init" \
  || { printf 'E_MANAGEMENT_INIT_PREFS tercih tohumlama sozlesmede yok\n' >&2; exit 2; }
# GOC: eski dosya tabanli kurulum plugin ile yan yana kalirsa hook IKI
# KEZ calisir ve skill'ler iki kez listelenir. Sessiz ve kafa karistirici.
for marker in 'gocis-yedek' 'tam bir kez' 'hash' 'hook bloğunu'; do
  grep -Fq "$marker" "$init" || { printf 'E_MANAGEMENT_INIT_MIGRATION %s\n' "$marker" >&2; exit 2; }
done

# update SORU SORMAZ sozlesmesi. 2026-09-11: onceki hali her
# guncellemede onay istiyordu ve elle degistirilmis dosyayi hic
# guncellemiyordu -- o dosya zamanla geride kaliyordu. Artik kit surumu
# her zaman uygulanir, once yedeklenir. Dokunulmayan uc alan sozlesmede
# yazili olmazsa davranis geri kayar.
upd=skills/update/SKILL.md
for marker in 'Soru sorma' 'önce yedekle' 'Dokunulmayan üç alan' 'Rapor kuralı' 'preferences.example.md'; do
  grep -Fq "$marker" "$upd" || { printf 'E_MANAGEMENT_UPDATE_CONTRACT %s\n' "$marker" >&2; exit 2; }
done
for guarded in '.agents/project.md' '.agents/local/' '.agents/changes/'; do
  grep -Fq "$guarded" "$upd" || { printf 'E_MANAGEMENT_UPDATE_GUARD %s\n' "$guarded" >&2; exit 2; }
done
# Kaynak plugin kokunden gelir; kullanicidan yol istemek ve agdan surum
# indirmek YASAK. Klon zorunlulugu tam olarak bu yuzden kalkti.
grep -Fq 'CLAUDE_PLUGIN_ROOT' "$upd" \
  || { printf 'E_MANAGEMENT_UPDATE_NO_PLUGIN_ROOT\n' >&2; exit 2; }
grep -Fq 'yol isteme' "$upd" \
  || { printf 'E_MANAGEMENT_UPDATE_ASKS_PATH\n' >&2; exit 2; }
# Profil kullanicinin kararidir; guncelleme onu ezmemeli.
grep -Fq 'profile' "$upd" \
  || { printf 'E_MANAGEMENT_UPDATE_PROFILE\n' >&2; exit 2; }
# Guncelleme yalniz ISKELEYI kapsar; araclari plugin yonetir.
grep -Fq 'iskele' "$upd" \
  || { printf 'E_MANAGEMENT_UPDATE_SCAFFOLD\n' >&2; exit 2; }

fixtures=.agents/tests/fixtures/adoption
for file in \
  "$fixtures/empty-repo/new/manifest.json" \
  "$fixtures/empty-repo/expected.json" \
  "$fixtures/existing-instructions/new/manifest.json" \
  "$fixtures/existing-instructions/expected.json" \
  "$fixtures/modified-managed/base/manifest.json" \
  "$fixtures/modified-managed/new/manifest.json" \
  "$fixtures/modified-managed/expected.json" \
  "$fixtures/modified-managed/expected-without-base.json" \
  "$fixtures/remove-preserves-work/manifest.json" \
  "$fixtures/remove-preserves-work/expected.json"; do
  [ -f "$file" ] || { printf 'E_MANAGEMENT_FIXTURE_MISSING %s\n' "$file" >&2; exit 2; }
  jq -e . "$file" >/dev/null
done

jq -e '.recommendation == "direct-install" and .externalWrites == false and .requiresApproval == true' "$fixtures/empty-repo/expected.json" >/dev/null
jq -e '.recommendation == "merge-required" and .overwrite == false and .requiresApproval == true' "$fixtures/existing-instructions/expected.json" >/dev/null
jq -e '.classification == "preserve-and-merge" and .currentPreserved == true' "$fixtures/modified-managed/expected.json" >/dev/null
jq -e '.classification == "base-bytes-unavailable" and .automaticMerge == false' "$fixtures/modified-managed/expected-without-base.json" >/dev/null
jq -e '.deleteCandidates == ["AGENTS.md"] and (.preserved | sort) == ([".agents/changes/active/123/status.md", ".agents/project.md"] | sort)' "$fixtures/remove-preserves-work/expected.json" >/dev/null

base_hash=$(sha256sum "$fixtures/modified-managed/base/AGENTS.md" | awk '{print $1}')
current_hash=$(sha256sum "$fixtures/modified-managed/current/AGENTS.md" | awk '{print $1}')
new_hash=$(sha256sum "$fixtures/modified-managed/new/AGENTS.md" | awk '{print $1}')
[ "$base_hash" != "$current_hash" ] && [ "$base_hash" != "$new_hash" ] && [ "$current_hash" != "$new_hash" ] || { printf 'E_MANAGEMENT_THREE_WAY_FIXTURE\n' >&2; exit 2; }

expected_remove_hash=$(jq -r '.files[] | select(.path == "AGENTS.md") | .sha256' "$fixtures/remove-preserves-work/manifest.json")
actual_remove_hash=$(sha256sum "$fixtures/remove-preserves-work/repo/AGENTS.md" | awk '{print $1}')
[ "$expected_remove_hash" = "$actual_remove_hash" ] || { printf 'E_MANAGEMENT_REMOVE_HASH\n' >&2; exit 2; }

if grep -rEn 'overwrite.*doğrudan|git[[:space:]]+add[[:space:]]+\.|git[[:space:]]+add[[:space:]]+-A|reset[[:space:]]+--hard' skills/init skills/update skills/remove-kit >/dev/null 2>&1; then
  printf 'E_MANAGEMENT_FORBIDDEN_PATTERN\n' >&2
  exit 2
fi

printf 'PASS kit-management\n'
