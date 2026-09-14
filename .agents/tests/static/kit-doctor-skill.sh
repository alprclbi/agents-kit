#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
skill="$root/skills/kit-doctor/SKILL.md"
[ -f "$skill" ] || { printf 'E_KIT_DOCTOR_SKILL_MISSING\n' >&2; exit 2; }
grep -Fq 'name: kit-doctor' "$skill" || { printf 'E_KIT_DOCTOR_NAME\n' >&2; exit 2; }
for phrase in 'doctor' 'Warning' 'Blocker' 'SKIP' '/context' '/hooks' 'InstructionsLoaded'; do
  grep -Fq "$phrase" "$skill" || { printf 'E_KIT_DOCTOR_CONTRACT %s\n' "$phrase" >&2; exit 2; }
done
for phrase in 'otomatik yükleme PASS' 'aynı kontrolü hem PASS hem SKIP' 'genel manifest sonucu FAIL' 'isteğe bağlı' 'INFO'; do
  grep -Fiq "$phrase" "$skill" || { printf 'E_KIT_DOCTOR_EVIDENCE_CONTRACT %s\n' "$phrase" >&2; exit 2; }
done
grep -Fq 'kendiliğinden değiştirme' "$skill" || { printf 'E_KIT_DOCTOR_READ_ONLY\n' >&2; exit 2; }
# Plugin ile kurulmus projede dogrulayici proje kokunde YOKTUR. Skill yalniz
# oraya bakarsa her cagrida sessizce SKIP verir ve kullanici doctor sonucunu
# hic goremez. Giris cozumu once plugin kokunu aramali.
grep -Fq 'CLAUDE_PLUGIN_ROOT' "$skill" || { printf 'E_KIT_DOCTOR_NO_PLUGIN_ROOT\n' >&2; exit 2; }

[ "$(wc -w < "$skill" | tr -d ' ')" -le 500 ] || { printf 'E_KIT_DOCTOR_TOO_LONG\n' >&2; exit 2; }
printf 'PASS kit-doctor-skill\n'
