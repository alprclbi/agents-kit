# Değişiklik Günlüğü

Halka açık sürümlerin kaydı. Biçim [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) esaslıdır; sürümleme [SemVer](https://semver.org/lang/tr/).

Kapalı geliştirme dönemine ait mühendislik günlüğü [`.agents/CHANGELOG.md`](.agents/CHANGELOG.md) dosyasındadır; oradaki sürüm numaraları bu halka açık seriden bağımsızdır.

## [Yayınlanmadı]

## [1.1.0] - 2026-10-13

Küçük sürüm. `solo` profilde gereksiz `AKE203` uyarısı susturuldu; oturum başı özeti, kayıt güncelliği uyarısı, `update` önizlemesi ve Codex eval desteği eklendi.

### Değişti

- **`solo` profilde aktif iş kaydı yokken `AKE203` uyarısı artık basılmıyor.** `solo` için aktif iş zorunlu değil; uyarı her araç çağrısında gürültü üretiyordu. `team` profilindeki engelleme (deny) aynen duruyor.
- **Salt okunur MCP araçları mutasyon kapısından geçiyor.** Adı `mcp__<sunucu>__<eylem>` olan araçta eylem `get`, `list`, `read` veya `search` fiiliyle başlıyorsa araç okuma sayılır; `team` profilinde aktif iş yokken de reddedilmez. Bileşik eylem (`get_or_create_*`) ve tanınmayan her fiil mutasyon kalır. Kural `.agents/contracts/tool-gate.md` içinde.
- **`kit-doctor` eksik plugin paketini adıyla bildiriyor.** Plugin kökünde `.agents/validators/` yoksa sonuç `SKIP` değil Blocker'dır.
- **Salt okunur komut listesi genişledi.** `grep`, `rg`, `find`, `jq` ve `git rev-parse` artık kapıdan geçiyor. Her parçası salt okunur olan boru zincirleri (`git log --oneline | head -5`) de geçiyor; yazabilen tek bir parça (`| xargs rm`, `| sh`) zinciri mutasyon yapar. `find -exec/-delete`, `rg --pre` ve `git --output` tırnakla gizlense bile mutasyon sayılır.
- **Codex hook'larında kök çözümü doğrulayıcıya taşındı.** `.codex/hooks.json` içinde üç hook × iki kabukta altı kez yazılı kök bulma döngüsü yerine dosya yalnız doğrulayıcıyı bulup `--discover-root` (Windows'ta `-DiscoverRoot`) ile çağırıyor. Davranış aynı: önce Git kökü, sonra `AGENTS.md` + `.agents/config.json` araması.

### Eklendi

- **Stop hook'u kayıt güncelliğini denetliyor (`AKW301`).** Aktif iş varken çalışma ağacında `status.md` dosyasından daha yeni bir değişiklik varsa oturum kapanışında uyarı basılır ve `checkpoint-work` önerilir. Kaynak git'tir (değişmiş ve izlenmeyen, ignore dışı dosyalar); iş kaydı ve runtime sayılmaz. Hiçbir profilde kapanışı engellemez. Kapanış uyarıları artık kodun yanında mesajın kendisini de taşıyor.
- **`update` için önizleme modu.** `/agents-kit:update önizle` her iskele yolunu `yaz`, `yedekle+yaz`, `ekle`, `kaldır`, `yedeğe taşı`, `import bloğu` veya `atla` olarak tabloyla gösterir ve hiçbir şey yazmaz. Varsayılan davranış değişmedi: `update` soru sormadan uygular.
- **Eval harness Codex'i de ölçüyor.** `run.sh --client codex` aynı kolları ve görevleri `codex exec --json` ile koşar; `clients/codex.sh` Claude ile aynı normalize satırı üretir. Codex maliyet raporlamadığı için bütçe kapısı koşu başı tahmini kullanır; tur sınırı ve izin listesi Codex'te uygulanmaz (`.agents/evals/README.md`).
- **Oturum başında "nerede kalmıştık" özeti.** Aktif iş çözüldüğünde oturum bağlamı `Özet:` bloğuyla açılır: `status.md` içindeki mevcut aşama ve sıradaki adım, `work.json` `updatedAt` değeri ve spec'teki işaretlenmemiş kabul kriterleri (en çok beş). Eksik alan `kayıtlı değil` yazar; tahmin üretilmez. Spec yolu proje dışına çıkıyorsa okunmaz. `checkpoint-work` artık `updatedAt` alanını da güncelliyor.

### Düzeltildi

- **`AKW102` ve `AKW103` politika kodu kataloğunda.** İki doğrulayıcı da bu kodları üretiyordu ama `policy-codes.json` tanımıyordu. Yeni statik test üretilen her kodun katalogda olduğunu denetliyor.
- **Windows'ta Codex oturum bağlamı boş gidiyordu.** `agent-kit.ps1 session-context -Format text` bağlam metni yerine nesne basıyordu; PowerShell bunu tabloya çevirip hook'a boş satır gönderiyordu. Artık metnin kendisi basılıyor (sh ile aynı).
- **Satır sonuyla zincirlenen komut ve PowerShell alt ifadesi artık salt okunur sayılmıyor.** `ls` ardından yeni satırda `rm -rf x` ya da `echo (Remove-Item x)` önceden ilk kelimeye bakılarak geçiyordu.

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
