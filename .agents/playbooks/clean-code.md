# Clean Code Playbook

## Ne zaman oku

- Refactor, okunabilirlik veya bakım iyileştirmesi isteniyorsa.
- Tekrarlanan karar mantığı, derin dallanma, karışık abstraction level veya gizli side-effect görülüyorsa.
- Kod incelemesinde karmaşıklık, adlandırma veya sorumluluk sorunu araştırılıyorsa.

## Ne zaman okuma

- Yalnız otomatik formatlama, belge veya veri güncellemesi yapılıyorsa.
- Mevcut davranışı etkilemeyen küçük değişiklikte ek refactor gerekmiyorsa.

## Sorumluluk ve okuma seviyesi

- Fonksiyon ve modülleri tutarlı bir sorumlulukta tut.
- Bir fonksiyonda yüksek seviye orchestration ile düşük seviye SQL, indeks, string veya serileştirme ayrıntısını karıştırma.
- Üst düzey akışı yukarıdan aşağı okunabilir bırak; ayrıntıyı yalnız anlamlı isim taşıyan birimlere çıkar.
- Her extraction iyi değildir; arayüzü büyütüp anlamayı azaltan shallow abstraction üretme.

## Command–query ve side-effect

- Query gözlem yapmalı; gizlice sistem durumunu değiştirmemelidir.
- Command değişikliği açıkça yapmalı ve sonucu projenin hata modeliyle bildirmelidir.
- Bir fonksiyon hem değer döndürüp hem beklenmeyen kalıcı yan etki oluşturuyorsa sorumlulukları ayırmayı değerlendir.
- Yan etkileri I/O veya adapter sınırında görünür tut; saf hesaplamayı mümkün olduğunda ayır.

## Adlandırma ve yorum

- İsimler niyeti, alan dilini ve birimi açıklasın; türü veya uygulama ayrıntısını gereksiz yere tekrar etmesin.
- Yorum kodun ne yaptığını tekrarlamak yerine nedeni, kısıtı, riski veya düzenleyici gereksinimi açıklasın.
- Eski, yanlış veya artık gereksiz yorumları bırakma.

## Karar ve bağımlılık yerelliği

- Aynı token, flag veya type üzerinde yinelenen iş kararlarını araştır.
- Gerçekten aynı politika tekrarlanıyorsa uygun tek noktada topla.
- Uzun erişim zincirleri ve reach-through bağımlılıklarında ara sözleşmeyi veya sorumluluk sınırını değerlendir.

## Veri ve davranış

- Veri taşıyan yapıları davranış saklayan nesneler gibi göstermeye çalışma.
- Davranış taşıyan modeli yalnız getter/setter çantasına dönüştürme.
- Functional core / imperative shell ve nesne yönelimli boundary birlikte kullanılabilir.

## DRY ve sadelik

- Tekrarlanan syntax ile tekrarlanan iş kuralını ayır.
- İş kuralı tekrarını merkezileştir; henüz kararlı olmayan benzer kodu erken soyutlama.
- Salt metrik düşürmek veya fonksiyonları küçültmek için kodu parçalama.

## Teslimde bildir

- Düzeltilen asıl okunabilirlik veya değişim problemi.
- Korunan davranış ve çalıştırılan testler.
- Eklenen soyutlamanın neden gerekli olduğu.
- Bilinçli olarak yapılmayan refactor ve gerekçesi.
