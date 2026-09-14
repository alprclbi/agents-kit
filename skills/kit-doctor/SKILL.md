---
name: kit-doctor
description: Use when installing, adopting, updating, troubleshooting, or validating Agents Kit in a project.
---

# Kit Doctor

## Amaç

Kitin talimat, yapılandırma, aktif iş, hook, bütçe ve manifest durumunu salt okunur kanıtlarla raporla. Tanılama, ayar değiştirme yetkisi değildir.

## İş akışı

1. Proje kökünü, işletim sistemini ve doğrulayıcı girişini belirle. Girişi **sırayla** ara: önce plugin kökü `${CLAUDE_PLUGIN_ROOT}`, sonra proje kökü. Unix/macOS'ta `.agents/validators/sh/agent-kit.sh`, Windows'ta `.agents/validators/ps/agent-kit.ps1`. Plugin ile kurulmuş bir projede doğrulayıcı proje kökünde **yoktur**; yalnız oraya bakıp `SKIP` yazma. İkisinde de yoksa veya runtime eksikse `SKIP` kaydet ve nedenini bildir.
2. Uygun girişle `doctor` komutunu çalıştır. Önce metin çıktısını kullanıcı için özetle; ayrıntılı otomasyon gerekiyorsa JSON biçimini kullan.
3. Her bulguyu ayır:
   - **Blocker:** mutasyondan önce çözülmesi gereken ve profil gereği fail-closed olan durum.
   - **Warning:** çekirdek çalışsa da mekanik korumayı veya güven düzeyini düşüren durum.
   - **INFO:** isteğe bağlı katmanın yokluğu veya eylem gerektirmeyen bağlam; Warning gibi sunma.
   - **SKIP:** araç, platform, trust ya da gözlem eksikliği nedeniyle doğrulanamayan kontrol; PASS gibi sunma.
4. Codex'te `/hooks` ile hook kaynağı, matcher ve trust durumunu; etkin talimat/bütçe bilgisini istemci tanılamasıyla doğrulat. Proje katmanının güvenilmediği durumda hook ve `.codex/config.toml` yüklenmeyebilir.
5. Claude Code'da `/context`, `/hooks` ve debug kaydındaki `InstructionsLoaded` gözlemiyle `CLAUDE.md`, `AGENTS.md`, config ve proje dosyalarının yüklenmesini doğrulat.
6. Kanıt düzeyini ayrı tut:
   - Dosya varlığı, doğru import sözdizimi veya manuel okuma yalnız `mevcut/uygun` kanıtıdır; `/context` ya da `InstructionsLoaded` yoksa otomatik yükleme PASS verme ve istemci kontrolünü `SKIP` yaz.
   - Aynı kontrolü hem PASS hem SKIP gösterme. Çıkarımı açıkça `inference` olarak etiketle.
   - İsteğe bağlı `.agents/local/preferences.md` yokluğunu INFO yaz.
7. Manifest varsa `manifest --check` çalıştır. Herhangi bir `hashPolicy: required` dosyası eksik veya farklıysa genel manifest sonucu FAIL'dir; eşleşen hash sayısını yalnız kısmi kanıt olarak ver. Manifest yoksa yeni kurulum ile bozulmayı bağlama göre ayır.
8. Sonuçta kullanılan komutları, PASS/Warning/Blocker/INFO/SKIP durumlarını ve en küçük güvenli düzeltme önerisini ver.

## Güvenlik sınırı

Bu skill ayarı, hook trust kararını, dosyayı veya manifesti kendiliğinden değiştirmez. `--write`, hook merge, bağımlılık kurulumu ve global istemci ayarı için ilgili workflow ve açık kullanıcı onayı gerekir.
