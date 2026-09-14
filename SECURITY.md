# Güvenlik Politikası

## Desteklenen sürümler

| Sürüm | Destek |
| --- | --- |
| 1.0.x | evet |
| 1.0.0 öncesi | yok (kapalı geliştirme dönemi) |

## Açık bildirimi

**Güvenlik açığını public issue olarak açma.** Depoyu okuyan herkes onu düzeltilmeden görür.

Bildirim yolu: deponun **Security** sekmesi → **Report a vulnerability**. Bu GitHub'ın özel bildirim kanalıdır; yalnız bakımcı görür.

Proje tek bakımcılı ve gönüllüdür; yanıt veya düzeltme süresi taahhüt edilmez. Bildirim alındığında ve durum değiştiğinde sana yazılır.

## Bu kit için ne "açık" sayılır

Kit; kabuk betikleri, hook'lar ve ajan talimatlarından oluşur. Şunları güvenlik açığı olarak bildir:

- **Hook veya doğrulayıcıda komut enjeksiyonu.** Hazırlanmış bir dosya adı, iş kaydı veya hook girdisi doğrulayıcıya kod çalıştırtıyorsa.
- **Proje kökünden kaçış.** `manifest`, `update`, `remove-kit` veya paketleyicinin proje dizini dışına yazması ya da silmesi.
- **Talimat enjeksiyonu.** Depo içeriğinin (README, issue metni, log, iş kaydı) ajana yetkisiz eylem yaptırabilmesi. `AGENTS.md` §6 bunu güvenilmeyen veri sayar; sayamadığı bir yol varsa açıktır.
- **Secret sızıntısı.** Doğrulayıcı, oturum bağlamı veya dağıtım paketinin secret, token ya da kişisel veri taşıması.
- **Manifest bütünlüğünün atlatılması.** Değiştirilmiş bir dosyanın `manifest --check` tarafından fark edilmemesi.

## Açık sayılmayanlar

- **Hook'un onay istememesi.** Kit 1.0.0'da tehlikeli komut denetimi yok; `git reset --hard`, force-push ve `rm -rf` durdurulmaz. Bu bilinçli bir tasarım kararıdır, [CHANGELOG.md](CHANGELOG.md) içinde kayıtlı. İstemcinin kendi izin akışı geçerlidir.
- **Hook güveni verilmemiş ortamda mekanik korumanın düşmesi.** Beklenen davranıştır ve `kit-doctor` bunu raporlar.
- **Kullanıcının kendi yazdığı komutun çalışması.** Kit ajanı kısıtlar, kullanıcıyı değil.
- **Ajan modelinin bir kurala uymaması.** Kurallar ajanı yönlendirir, garanti etmez. Bu bir kalite sorunudur, açık değildir.

## Bildirirken

Tekrar üretme adımlarını, etkilenen dosyayı ve etkiyi yaz. Kanıt eklerken **kendi secret'ını temizle**.
