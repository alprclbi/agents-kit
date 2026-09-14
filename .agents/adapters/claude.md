# Claude Code Adaptörü

`CLAUDE.md`, kök talimatı ve paylaşılan proje yapılandırmasını import eder. `.claude/skills/` altındaki dosyalar yalnız kanonik `.agents/skills/` dosyalarına yönlendiren ince adaptörlerdir.

## Hook seçimi

Paketle gelen `.claude/settings.json` **bash parçasını kurulu getirir**. Claude Code'un hook `shell` alanı yalnız `bash` ve `powershell` değerlerini kabul eder; varsayılanı `bash`, Windows'ta Git Bash yoksa `powershell` olur.

| Ortam | Kurulu gelen parça | Ek adım |
| --- | --- | --- |
| Linux, macOS | `claude/hooks.bash.json` | yok |
| Windows + Git Bash | `claude/hooks.bash.json` | yok |
| Windows, Git Bash yok | — | `claude/hooks.powershell.json` içeriğiyle değiştir |

İki parça aynı `SessionStart`, `PreToolUse` ve `Stop` olaylarını çağırır ve aynı doğrulayıcı davranışını üretir. Hook komutları tam proje kökünü kullanır, ağ erişmez ve ek commit, branch, izin ya da harici yazma yetkisi vermez.

Hook'lar `CLAUDE_PROJECT_DIR` kullandığından Git deposu gerektirmez. Mevcut `.claude/settings.json` dosyası olan bir projeye katılırken parça sessizce kurulmaz: `init` yalnız alan düzeyinde diff sunar, açık onay ister ve sonuç `/hooks` gözlemiyle doğrulanır.

## Auto memory sınırı

`~/.claude/projects/<project>/memory/` altındaki auto memory makine-yerel yardımcı önbellektir. Kişisel öğrenme ve kısa işaretçiler taşıyabilir; ekip politikası, aktif iş durumu, spec, plan veya karar için kanonik takım kaydı değildir. Bu bilgiler sırasıyla `.agents/project.md` ve `.agents/changes/active/<work-id>/` altında tutulur; memory yalnız kanonik kaynağa işaret edebilir.

## Tanılama

Claude Code içinde `/context`, `/hooks` ve debug çıktısındaki `InstructionsLoaded` olaylarıyla yüklenen talimatlar doğrulanır. `kit-doctor` salt okunur depo kontrollerini yürütür. Mevcut ayarların birleştirilmesi otomatik değildir.

Kaynaklar: https://code.claude.com/docs/en/hooks ve https://code.claude.com/docs/en/memory
