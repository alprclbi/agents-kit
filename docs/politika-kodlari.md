# Politika Kodları

Kitin doğrulayıcıları, hook'ları ve skill'leri bir sorun bildirirken `AK` ile
başlayan bir kod basar. Bu sayfa her kodun ne demek olduğunu, hangi profilde ne
kadar sert davrandığını ve nasıl çözüleceğini anlatır.

Kodun anlam satırı [`.agents/validators/policy-codes.json`](../.agents/validators/policy-codes.json)
kataloğundan birebir alınır. `.agents/tests/static/policy-codes-doc.sh` her
koşuda iki yönü denetler: katalogdaki ve doğrulayıcıların ürettiği her kodun
burada bölümü olmalı, buradaki her bölüm de katalogda veya kodda bulunmalı.
Katalog değişip sayfa güncellenmezse test kırmızı olur.

## Kodu okumak

| Önek | Anlamı |
| --- | --- |
| `AKE` | Hata. Profile göre işlemi durdurabilir |
| `AKW` | Uyarı. Hiçbir profilde işlemi durdurmaz |
| `AKS` | Atlandı. Kontrol bu ortamda çalıştırılamadı; başarı sayılmaz |

Rakamların ilk hanesi alanı söyler:

| Hane | Alan |
| --- | --- |
| `1xx` | Talimat bütçesi, profil ve yükleme zinciri |
| `2xx` | İş kaydı ve sahiplik |
| `3xx` | Spec, plan ve diğer artifact yolları |
| `4xx` | Hook güveni |
| `5xx` | Canlı istemci testleri |
| `6xx` | Manifest bütünlüğü |
| `9xx` | Komut satırı ve yerel araç hataları |

Şiddet sütununda "engeller" yazıyorsa hook işlemi reddeder; "uyarır" yazıyorsa
ajan uyarıyı görür ve normal izin akışı sürer.

Kit yalnız `.agents/config.json` bulunan projede çalışır. O dosya yoksa üç
hook da hiçbir çıktı vermeden geçer; bu sayfadaki kodların hiçbiri basılmaz.

Profil `.agents/config.json` içindeki `profile` alanından okunur. Etkin işin
`work.json` kaydı profili yalnız sıkılaştırabilir: `solo` projede `team`
işaretli bir iş açıksa kapı o iş için `team` gibi davranır.

## Hızlı bakış

| Kod | Anlam | `solo` | `team` |
| --- | --- | --- | --- |
| `AKW101` | AGENTS.md hedef bütçeyi aşıyor | uyarır | uyarır |
| `AKE102` | AGENTS.md kit üst sınırını aşıyor | artık üretilmiyor | artık üretilmiyor |
| `AKW102` | Profil değeri tanınmıyor veya desteklenmiyor | uyarır | uyarır |
| `AKW103` | Geçerli iş işaretçisi bayat | uyarır | uyarır |
| `AKW110` | Codex etkin talimat limiti belirlenemedi | uyarır | uyarır |
| `AKW111` | Codex talimat zinciri referans limitini aşıyor | uyarır | uyarır |
| `AKE112` | Codex talimat zinciri etkin limiti aşıyor | artık üretilmiyor | artık üretilmiyor |
| `AKE120` | Claude import zinciri döngülü veya dört hop sınırını aşıyor | elle tanı | elle tanı |
| `AKE201` | Birden fazla aktif iş çözümlenemedi | uyarır | uyarır |
| `AKE202` | Kaynak sahipliği çakışıyor | uyarır | engeller |
| `AKE203` | Profil için gerekli iş kaydı eksik | basılmaz | engeller |
| `AKE301` | Artifact hedefi kayıtlı değil veya proje dışında | engeller | engeller |
| `AKE302` | Bilinen kaçak Superpowers yolu | uyarır | engeller |
| `AKE303` | Backend explicit artifact hedefini desteklemiyor | engeller | engeller |
| `AKW301` | Aktif işin status.md dosyası son değişiklikten eski | uyarır | uyarır |
| `AKW401` | Etkin istemci hook güveni veya kapsamı doğrulanamadı | uyarır | uyarır |
| `AKS501` | İstemci veya platform canlı testi çalıştırılamadı | atlanır | atlanır |
| `AKE601` | Manifest eksik veya güncel değil | engeller | engeller |
| `AKE900` | Bilinmeyen komut veya seçenek | engeller | engeller |
| `AKE901` | Gerekli yerel ayrıştırıcı bulunamadı | engeller | engeller |

## Kodlar

### AKW101

**Anlam:** AGENTS.md hedef bütçeyi aşıyor

**Nerede:** Oturum başlangıcı ve `kit-doctor`. `AGENTS.md` boyutu
`.agents/config.json` içindeki `instructionBudgets.agentsTargetBytes` veya
`agentsMaxBytes` değerini geçince basılır.

**Şiddet:** Her profilde uyarı. Bütçe maliyet ve kalite konusudur, ekip
çalışmasıyla ilgisi yoktur.

**Çözüm:** Ayrıntıyı koşullu bir playbook, contract veya skill dosyasına taşı.
Yeni kural eklemeden önce mekanik karşılığının (hook, test) yazılıp
yazılamayacağına bak.

### AKE102

**Anlam:** AGENTS.md kit üst sınırını aşıyor

**Nerede:** Artık hiçbir yerde üretilmiyor. Üst sınır aşımı da `AKW101` ile
uyarı olarak bildirilir.

**Şiddet:** Yok.

**Çözüm:** Eski bir kayıtta görüyorsan `AKW101` gibi ele al.

### AKW102

**Anlam:** Profil değeri tanınmıyor veya desteklenmiyor

**Nerede:** `PreToolUse` kapısı ve `kit-doctor`. `.agents/config.json` içindeki
`profile` değeri `solo` veya `team` değilse basılır. Eski `high-assurance`
değeri `team`, tanınmayan her değer `solo` gibi çalışır.

**Şiddet:** Her profilde uyarı.

**Çözüm:** `profile` alanını `solo` veya `team` yap.

### AKW103

**Anlam:** Geçerli iş işaretçisi aktif bir işi göstermiyor

**Nerede:** `PreToolUse` kapısı ve `kit-doctor`. `.agents/runtime/current-work`
dosyası artık `.agents/changes/active/` altında olmayan bir işi gösteriyorsa
basılır. Bayat işaretçi yok sayılır.

**Şiddet:** Her profilde uyarı.

**Çözüm:** `/agents-kit:resume-work` ile işi seç veya dosyayı sil.

### AKW110

**Anlam:** Codex etkin talimat limiti belirlenemedi

**Nerede:** Codex oturum başlangıcı ve `kit-doctor --client codex`. Codex'in
etkin `project_doc_max_bytes` değeri okunamayınca referans varsayılan
kullanılır.

**Şiddet:** Her profilde uyarı.

**Çözüm:** Etkin değeri Codex'in kendi tanılamasıyla doğrula.

### AKW111

**Anlam:** Codex talimat zinciri referans limitini aşıyor

**Nerede:** Codex oturum başlangıcı ve `kit-doctor --client codex`. Kökten
çalışma dizinine kadar okunan talimat dosyalarının toplamı limiti geçince
basılır. Codex limiti aşan kısmı modele hiç göndermez.

**Şiddet:** Her profilde uyarı.

**Çözüm:** Talimat zincirini buda veya limiti bilinçli bir proje kararıyla
yükselt.

### AKE112

**Anlam:** Codex talimat zinciri etkin limiti aşıyor

**Nerede:** Artık hiçbir yerde üretilmiyor. Limit aşımı `AKW111` ile uyarı
olarak bildirilir.

**Şiddet:** Yok.

**Çözüm:** Eski bir kayıtta görüyorsan `AKW111` gibi ele al.

### AKE120

**Anlam:** Claude import zinciri döngülü veya dört hop sınırını aşıyor

**Nerede:** Doğrulayıcılar bu kodu üretmez. `CLAUDE.md` içindeki `@` import
zincirini incelerken ajan veya `kit-doctor` elle raporlar.

**Şiddet:** Her profilde elle tanı. Claude Code döngülü veya çok derin
importu sessizce keser; kural yüklenmemiş olur.

**Çözüm:** `CLAUDE.md` importlarını düzleştir, döngüyü kır. `/context` ile
yüklenen dosyaları doğrula.

### AKE201

**Anlam:** Birden fazla aktif iş çözümlenemedi

**Nerede:** `PreToolUse` kapısı ve `kit-doctor`. `.agents/changes/active/`
altında birden fazla iş varken hangisinde çalışıldığı işaretçiden, branch'ten
veya work-id'den çözülemezse basılır.

**Şiddet:** Her profilde uyarı. Birden fazla aktif iş normaldir; gerçek risk
çakışmadır ve onu `AKE202` ölçer.

**Çözüm:** `/agents-kit:resume-work` ile işi seç veya work-id belirt.

### AKE202

**Anlam:** Kaynak sahipliği çakışıyor

**Nerede:** `PreToolUse` kapısı. Etkin işin `work.json` içindeki
`ownership` alanı başka bir aktif işle aynı yolu, kaynağı, portu veya
migration'ı sahiplenirse basılır.

**Şiddet:** `solo` uyarır, `team` engeller.

**Çözüm:** Sahipliği iki işten birinde daralt veya diğer işi kapat. Çözmeden
ortak kaynağı değiştirme.

### AKE203

**Anlam:** Profil için gerekli iş kaydı eksik

**Nerede:** `PreToolUse` kapısı ve `kit-doctor`. Dosya yazan, salt okunur
olmayan bir komut çalıştıran veya yazan bir MCP aracı çağıran araç çağrısında
`.agents/changes/active/` altında hiç iş yoksa basılır.

**Şiddet:** Yalnız `team` profilinde basılır ve engeller. `solo` profilde aktif
iş zorunlu değildir; kod basılmaz. Salt okunur tanı komutları ve adı `get`,
`list`, `read` veya `search` ile başlayan MCP araçları her profilde geçer
(ayrıntı: `.agents/contracts/tool-gate.md`).

**Çözüm:** `/agents-kit:start-work` ile işi başlat.

### AKE301

**Anlam:** Artifact hedefi kayıtlı değil veya proje dışında

**Nerede:** `artifact-router` ve `route-artifact.sh`. Hedef yol mutlak, üst
dizine çıkan, proje dışına çözülen veya geçersiz work-id, rol ya da backend
taşıyorsa basılır.

**Şiddet:** Her profilde engeller; yazma yapılmaz.

**Çözüm:** Yolu proje göreli ver ve işin `work.json` kaydındaki artifact
rolüne bağla.

### AKE302

**Anlam:** Bilinen kaçak Superpowers yolu

**Nerede:** `Stop` hook'u. `docs/superpowers/specs` veya
`docs/superpowers/plans` altında dosya varsa basılır; bu, Superpowers
skill'inin kanonik yol yerine kendi varsayılanına yazdığı anlamına gelir.

**Şiddet:** `solo` uyarır, `team` kapanışı engeller.

**Çözüm:** Dosyayı `artifact-router` ile çözülen kanonik yola taşı ve
kaçak dizini temizle.

### AKE303

**Anlam:** Backend explicit artifact hedefini desteklemiyor

**Nerede:** `artifact-router` skill'i. Seçilen backend (Spec Kit, OpenSpec veya
harici sistem) kitin verdiği exact yolu kabul etmiyorsa basılır.

**Şiddet:** Her profilde engeller. Kopya üretilmez, üçüncü taraf skill
yamanmaz.

**Çözüm:** Backend'i `.agents/config.json` içinde `native` yap veya backend'in
kabul ettiği yolu kullanıcıyla netleştir.

### AKW301

**Anlam:** Aktif işin status.md dosyası son değişiklikten eski

**Nerede:** `Stop` hook'u. Aktif iş varken git'in değişmiş veya izlenmeyen
(ignore dışı) gördüğü bir dosya `status.md` dosyasından daha yeniyse
basılır. `.agents/changes/`, `.agents/runtime/` ve `.agents/local/`
sayılmaz; git yoksa veya proje depo değilse kontrol sessiz geçer.

**Şiddet:** İki profilde de uyarır; kapanışı engellemez.

**Çözüm:** Oturum kapanmadan `checkpoint-work` ile `status.md` dosyasını
güncelle.

### AKW401

**Anlam:** Etkin istemci hook güveni veya kapsamı doğrulanamadı

**Nerede:** `kit-doctor`. Plugin, proje, proje yerel veya kullanıcı
ayarlarının hiçbirinde kit hook'u etkin bulunamazsa basılır.

**Şiddet:** Her profilde uyarı. Kurallar uygulanmaya devam eder ama mekanik
koruma düşmüştür.

**Çözüm:** Plugin'in kurulu ve etkin olduğunu doğrula; `/hooks` ile hook
kaynağını gör. Codex'te hook'lara güven kararını `/hooks` panelinden ver.

### AKS501

**Anlam:** İstemci veya platform canlı testi çalıştırılamadı

**Nerede:** Test paketi. Canlı istemci (Claude Code, Codex) veya PowerShell
gibi bir platform ortamda yoksa ilgili vaka `SKIP` olur.

**Şiddet:** Her profilde atlanır. `SKIP` başarı sayılmaz.

**Çözüm:** Eksik istemci veya platformun bulunduğu ortamda testi yeniden
çalıştır.

### AKE601

**Anlam:** Manifest eksik veya güncel değil

**Nerede:** `manifest --check` ve CI. `.agents/manifest.json` yoksa, geçersizse
veya bir kit dosyasının hash'i kayıtla uyuşmuyorsa basılır.

**Şiddet:** Her profilde engeller; komut 2 ile çıkar.

**Çözüm:** Projede `/agents-kit:update` çalıştır; elle değiştirdiğin dosya
önce yedeklenir. Kitin kendi deposunda çalışıyorsan
`sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --write`.

### AKE900

**Anlam:** Bilinmeyen komut veya seçenek

**Nerede:** Doğrulayıcı komut satırı. Bilinmeyen alt komut, seçenek, format,
istemci veya proje dışı çalışma dizini verilirse basılır.

**Şiddet:** Her profilde engeller; komut 3 ile çıkar.

**Çözüm:** Komutu ve seçenekleri `.agents/validators/README.md` ile karşılaştır.
Hook'ta görüyorsan hook komutu elle değiştirilmiş olabilir; `/agents-kit:update`.

### AKE901

**Anlam:** Gerekli yerel ayrıştırıcı bulunamadı

**Nerede:** Doğrulayıcı. `jq`, SHA-256 aracı veya manifest geçici dizini
bulunamazsa basılır.

**Şiddet:** Her profilde engeller; komut 3 ile çıkar.

**Çözüm:** `jq` ve `sha256sum` (macOS'ta `shasum`) kur. Windows'ta Git Bash
yoksa PowerShell doğrulayıcısını kullan.
