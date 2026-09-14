# Mimari Playbook

## Ne zaman oku

- Yeni özellik veya harici entegrasyon ekleniyorsa.
- Domain, use-case, modül bağımlılığı veya mimari sınır değişiyorsa.
- Veritabanı, HTTP, queue, UI, framework veya ORM sınırına dokunuluyorsa.
- Kullanıcı mimari, Clean Architecture, SOLID, ports/adapters veya dependency inversion istiyorsa.

## Ne zaman okuma

- Yalnız yazım, belge, veri veya format değişikliği varsa.
- Küçük ve sınır geçmeyen yerel bir düzeltmede mimari karar gerekmiyorsa.

## Karar sırası

1. Değişikliği `policy`, `use-case`, `boundary` veya `detail` olarak sınıflandır.
2. Deponun mevcut ve geçerli mimarisini belirle; yeni bir örüntüyü sırf bu playbook nedeniyle dayatma.
3. Yüksek seviye kural ile düşük seviye ayrıntının bağımlılık yönünü kontrol et.
4. En küçük uyumlu sınır değişikliğini seç.
5. Mimari kararı davranış ve bağımlılık kanıtıyla doğrula.

## Dependency Rule

- Yüksek seviye iş kuralları veritabanı, web, framework, ORM veya dış servis ayrıntılarına kaynak kod düzeyinde bağımlı olmamalıdır.
- İç katmanda dış katmanda tanımlanmış request, response, ORM entity, database row veya framework tipi kullanma.
- Akış dıştan içe ilerleyebilir; kaynak kod bağımlılığı gerektiğinde port veya arayüzle ters çevrilebilir.
- Proje farklı ama geçerli bir mimari tanımlıyorsa onun bağımlılık kurallarına uy.

## Sade sınır verisi

- Sınırlar arasında DTO, record, primitive veya projede tanımlı sade veri sözleşmeleri taşı.
- Dış sistem tiplerini sınırda doğrula ve iç sözleşmeye dönüştür.
- Alanları uydurma veya kayıp, boş ve bilinmeyen değerleri sessizce birleştirme.

## Değişim ve karar yerelliği

- Aynı iş kararı birden fazla yerde tekrarlanıyorsa uygun composition point, policy veya mevcut soyutlamada merkezileştir.
- İkinci bir branch tek başına factory/strategy gerekçesi değildir; gerçek ve kararlı varyasyonu kanıtla.
- Bir değişiklik birden fazla bağımsız reason-to-change taşıyorsa işi mantıksal parçalara ayır.

## SOLID karar sezgileri

- SRP: Farklı aktörlerin veya iş nedenlerinin değişikliklerini aynı modülde toplama.
- OCP: Kararlı politika için mevcut extension seam'i kullan; erken soyutlama üretme.
- LSP: Alt tür kullanan kod özel durum kontrolü yapmak zorundaysa sözleşmeyi yeniden değerlendir.
- ISP: İstemciyi kullanmadığı operasyonlara bağlayan geniş arayüzlerden kaçın.
- DIP: Yüksek seviye politika düşük seviye ayrıntıya değil, uygun iç sözleşmeye bağımlı olsun.

## Ayrıntıları erteleme

- Geri döndürülmesi pahalı teknoloji kararlarını gereksinim kanıtlanmadan kilitleme.
- Çalışan ince bir dikey dilim oluşturmak, UI veya veritabanıyla sıkı bağ kurmayı gerektirmez.
- Küçük script, spike ve kısa ömürlü prototiplerde katman sayısını bağlama göre azalt.

## Mimari doğrulama

- Deponun mevcut mimari testlerini ve yasak bağımlılık kontrollerini çalıştır.
- Yeni mimari araç veya bağımlılık eklemeden önce açık onay al.
- Araç yoksa bağımlılık yönünü hedefli arama, import incelemesi ve davranış testleriyle kanıtla.

## Teslimde bildir

- Sınıflandırılan policy/use-case/detail kararı.
- Eklenen veya korunan boundary.
- Ertelenen teknoloji kararı.
- Çalıştırılan mimari ve davranış kontrolleri.
- Bilinen trade-off ve kalan risk.
