#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
only=${2:-all}
cd "$root"

check_skill() {
  skill=$1
  shift
  path="skills/$skill/SKILL.md"
  [ -f "$path" ] || { printf 'E_SKILL_MISSING %s\n' "$skill" >&2; exit 2; }
  grep -Fqx -- '---' "$path"
  grep -Fqx "name: $skill" "$path"
  grep -Eq '^description: Use when .+' "$path"
  grep -Fqx '## Çalışma sözleşmesi' "$path"
  # BUYUK/KUCUK HARF DUYARLI, bilerek.
  #
  # Onceki surum `grep -Fiq` kullaniyordu. `-i` ASCII disi harfleri ancak
  # UTF-8 locale altinda katlar; LANG ve LC_ALL bos oldugunda (Git Bash
  # varsayilani) C locale devreye girer ve "O" ile "o" eslesmez. Test bu
  # yuzden kirikti ve locale-e bagli oldugu icin bazi makinelerde geciyor,
  # bazilarinda kaliyordu -- en kotu hata turu.
  #
  # C.utf8 her sistemde yok (Alpine, bazi CI imajlari). Locale kurmak
  # yerine kaliplar dosyadaki HALIYLE yazilir; sonuc deterministik ve
  # tasinabilir olur. Skill metni yeniden yazilirsa test kirilir; bu
  # istenen davranistir, cunku test sozlesme dilini denetliyor.
  for marker do
    grep -Fq "$marker" "$path" || { printf 'E_SKILL_CONTRACT %s %s\n' "$skill" "$marker" >&2; exit 2; }
  done
}

case "$only" in
  start-work)
    check_skill start-work 'backend çözülmeden artifact yazma' 'Branch, worktree, issue veya commit için ayrıca açık yetki'
    ;;
  resume-work)
    check_skill resume-work 'Birden fazla aday' 'Önce `work.json` ve `status.md`' 'gerçek Git durumu'
    ;;
  checkpoint-work)
    check_skill checkpoint-work 'Anlamlı checkpoint' 'komut çıktısı dökümü değildir'
    ;;
  close-work)
    check_skill close-work 'kabul kriterleri' 'başarısız veya çalıştırılmamış' 'Harici issue veya PR'
    ;;
  archive-work)
    check_skill archive-work '`done` veya `cancelled`' 'Bilgi aktarımı doğrulanmadan' '.agents/changes/archive/<year>/<work-id>/'
    ;;
  all)
    sh "$0" "$root" start-work
    sh "$0" "$root" resume-work
    sh "$0" "$root" checkpoint-work
    sh "$0" "$root" close-work
    sh "$0" "$root" archive-work

    templates='work.json status.md spec.md plan.md tasks.md outcome.md decisions.md research.md test-plan.md evidence.md'
    for template in $templates; do
      path=".agents/templates/change/$template"
      [ -f "$path" ] || { printf 'E_TEMPLATE_MISSING %s\n' "$template" >&2; exit 2; }
    done
    sh .agents/tests/lib/json-parse.sh .agents/templates/change/work.json
    grep -Fqx '## Son tamamlanan işlem' .agents/templates/change/status.md
    grep -Fqx '## Sıradaki en küçük güvenli adım' .agents/templates/change/status.md
    ;;
  *)
    printf 'E_LIFECYCLE_TEST_TARGET %s\n' "$only" >&2
    exit 3
    ;;
esac

printf 'PASS lifecycle-skills %s\n' "$only"
