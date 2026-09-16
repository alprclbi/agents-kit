# Değişiklik Günlüğü

Halka açık sürümlerin kaydı. Biçim [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) esaslıdır; sürümleme [SemVer](https://semver.org/lang/tr/).

Kapalı geliştirme dönemine ait mühendislik günlüğü [`.agents/CHANGELOG.md`](.agents/CHANGELOG.md) dosyasındadır; oradaki sürüm numaraları bu halka açık seriden bağımsızdır.

## [Yayınlanmadı]

Henüz kayıt yok.

## [1.0.1] - 2026-09-16

Yama sürümü. Kit kurulu olmayan projelerde hook'lar artık sessiz.

### Düzeltildi

- **Kit kurulu olmayan projelerde hook'lar artık sessizce geçiyor.** Plugin kullanıcı kapsamında etkinleştirildiğinde `hooks/hooks.json` her projede çalışır. `pre-tool-use` ve `stop-check`, `.agents/config.json` yokluğunu denetlemeden profil okuduğu için iskelesi olmayan projede 2 ile düşüyor ve istemci her mutasyon aracında hook hatası gösteriyordu. Üç giriş noktası da artık kapıdan geçiyor: çıktı yok, çıkış 0.

### Değişti

- **Oturum başındaki `Iskele: yok` satırı kaldırıldı.** Kit kurulu olmayan projede oturum bağlamı hiçbir şey basmaz. Keşif yolu `/agents-kit:init` komutunun her projede görünür olmasıdır. JSON biçiminde sözleşme korunur, `context` boş döner.

## [1.0.0] - 2026-09-14

İlk halka açık sürüm.

### Ne var

- **Kural çekirdeği.** `AGENTS.md` her oturumda yüklenir. Koşullu playbook'lar yalnız tetiklendiklerinde okunur.
- **Kalıcı iş kaydı.** Her iş `.agents/changes/active/<iş-adı>/` altında spec, plan, durum ve kanıt dosyalarıyla tutulur. Oturum kapansa da kayıt diskte kalır.
- **Hook denetimi.** `PreToolUse` iş kaydı kapılarını denetler. `team` profilinde sahiplik çakışması ve eksik iş kaydı engellenir; `solo` profilinde uyarı kalır. Salt okunur tanı komutları her zaman geçer.
- **On komut.** İş başlatma, devam, checkpoint, kapanış, arşiv; kurulum, güncelleme, kaldırma, tanı ve çıktı yönlendirme.
- **İki katmanlı kurulum.** Araçlar plugin'den gelir ve tek komutla bütün projelerde güncellenir; kurallar projenin içinde durur ve proje başına güncellenir.
- **Claude Code ve Codex desteği.** İkisine de bağımlı değil; hook'lar her iki istemcinin kendi mekanizmasıyla çalışır.
- **Çevrimdışı kurulum.** `install.sh` ve `install.ps1` ağ kullanmadan kurar.

### Notlar

- Sürüm numarası halka açılıştan önce `1.0.0`'a sıfırlandı. Önceki seri depo kapalıyken çıkarıldı, hiç halka açık olmadı ve release'leri kaldırıldı.
- Kitin kendi kodu ağa çıkmaz. Plugin paketini indiren istemcidir.
- Kit kendi başına commit, push, PR veya issue oluşturmaz.
