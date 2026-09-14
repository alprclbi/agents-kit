# Katkı Rehberi

Teşekkürler. Bu dosya ne göndereceğini ve neyin kabul edildiğini anlatır.

Proje şu an **Türkçe**. İngilizce çeviri planlı ama henüz yok; PR'ını Türkçe gönder.

## Önce konuş

Küçük düzeltmeyi doğrudan PR olarak gönder. **Kural, skill, playbook veya doğrulayıcı davranışı değiştiren büyük değişiklikte önce issue aç.** Kapsamda anlaşmadan yazılan kod boşa gidebilir.

## Geliştirme gereksinimleri

| Ortam | Gereken |
| --- | --- |
| Linux, macOS | POSIX `sh`, `git`, `jq`, `sha256sum` veya `shasum` |
| Windows | Git for Windows (Git Bash) + Windows PowerShell 5.1 |

Doğrulayıcıyı değiştiriyorsan iki ortama da erişimin olmalı; parite zorunlu.

Test betikleri yalnız POSIX araçlarına dayanır. `rg`, `fd`, `bat` gibi araçları kullanma — `posix-tools.sh` bunu denetler.

## Hızlı başlangıç

```sh
sh .agents/tests/run.sh
sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check
```

İkisi de geçmeden PR gönderme. Test paketi `FAIL=0` olmalı.

Windows'ta:

```powershell
.agents\tests\run.ps1
```

## Branch adlandırma

`<tip>/<kısa-slug>` biçimini kullan. Tipler: `feat`, `fix`, `docs`, `test`, `chore`.

```text
fix/codex-hook-kok-cozumu
docs/katki-rehberi
```

İlgili issue varsa slug'a numarasını ekle: `fix/42-manifest-crlf`.

## Neyi nereye

| Ne ekliyorsun | Nereye | Yanına ne gerekir |
| --- | --- | --- |
| Yeni kural | `AGENTS.md` | Gerekçe + `rule-inventory.md` kaydı |
| Yeni skill | `skills/<ad>/SKILL.md` | `lifecycle-skills.sh` içine sözleşme kontrolü |
| Yeni playbook | `.agents/playbooks/` | `AGENTS.md` tetikleyici tablosuna satır |
| Yeni eval sondası | `.agents/evals/tasks/<ad>/` | `evals-oracles.sh` içine iki yönlü durum |

**Her davranış değişikliğinin testi olur.** Testsiz PR kapatılır.

## Zorunlu kurallar

### Test yazmadan davranış değiştirme

Yeni bir kontrol eklediyse, onu **kasten bozup kırıldığını gör**. Geçmesi kanıt değildir — bozuk bir test de geçer.

### Oracle yazıyorsan iki yönlü doğrula

Hem ihlali reddetmeli hem uyumu kabul etmeli.

**İki yönlü doğrulama tek başına yetmez.** Örnekleri oracle'ı yazan üretir; bu, oracle'ı değil örnek üretenin hayal gücünü test eder. Doğrulama durumlarına **kendi ilk sürümünü kıran** örnekleri koy. Ayrıntı: [`.agents/evals/README.md`](.agents/evals/README.md).

### Satır sonları LF

CRLF gönderirsen CI keser. Manifest hash'leri satır sonlarına bağlıdır; CRLF sızarsa `manifest --check` klonlayan herkeste düşer.

```sh
sh .agents/tests/static/line-endings.sh "$PWD"
```

### Dosya değiştirdiysen manifesti üret

```sh
sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --write
```

### İki platform paritesi

`sh` ve PowerShell doğrulayıcıları **aynı davranmalı**. Birini değiştirdiysen diğerini de değiştir ve aynı girdiyle iki doğrulayıcının çıktısını karşılaştır.

PowerShell dosyaları **BOM taşır**; düzenlerken koru.

### `AGENTS.md` bütçesi

Kural eklemek bedava değil — her oturumda token harcar. Ölçülmüş yük: tam dosya ~4.200 token.

Yeni kural önerirken şunu cevapla: **bu kuralın mekanik karşılığı yazılabilir mi?** Yazılabiliyorsa kural yerine hook veya test ekle; mekanik kontrol bağlam bütçesinden yemez. Bu tercihin ayrıntılı gerekçesi [`.agents/rule-inventory.md`](.agents/rule-inventory.md) içinde.

## Kural eklemeden önce oku

[`.agents/rule-inventory.md`](.agents/rule-inventory.md) hangi kuralın **neden çıkarıldığını** kaydeder. Daha önce çıkarılmış bir kuralı geri önermeden önce oraya bak.

## Ölçüm iddiaları

`.agents/evals/` gerçek ajan koşuları yapar ve **para harcar**. PR'ında ölçüm sonucu paylaşıyorsan:

- Kaç koşu, hangi model, hangi tarih — yaz.
- Karar eşiğini **veriye bakmadan önce** sabitle.
- Beklediğin yönde çıkmayan sonucu da raporla.

Ölçmediğin şeyi ölçülmüş gibi sunma.

## PR açarken

`.agents/templates/github/pull-request.md` şablonunu kullan. Şunları taşımalı:

- Ne değişti ve **neden**
- Çalıştırdığın **tam** komutlar ve çıktıları
- Atladığın kontroller
- Kalan riskler

"Testler geçti" yetmez; hangi komutu çalıştırdığını yaz.

## Hata bildirimi

`.agents/templates/github/bug-issue.md` şablonunu kullan. Hata iletisini **secret ve kişisel veriden arındır**.

Tekrar üretme adımları olmayan hata raporu kapatılır.

## Davranış kuralları

Katılımla [CODE_OF_CONDUCT.md](https://github.com/alprclbi/agents-kit/blob/main/CODE_OF_CONDUCT.md) şartlarını kabul etmiş olursun.

## Neyi kabul etmiyoruz

- Testsiz davranış değişikliği
- Yalnız bir platformu güncelleyen doğrulayıcı değişikliği
- Ölçülmemiş performans veya uyum iddiası
- Kişisel tercihi taşınabilir çekirdeğe (`AGENTS.md`) koyma girişimi — orası kişisel değil; tercihler `.agents/local/preferences.md` içine
- Gerekçesiz kapsam genişlemesi

## Lisans

Katkın MIT altında yayınlanır. PR açarak bunu kabul etmiş olursun.
