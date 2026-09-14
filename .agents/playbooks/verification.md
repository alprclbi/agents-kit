# Doğrulama Playbook

## Ne zaman oku

- Gözlenebilir davranış, bugfix, regresyon, API, CLI, UI, çıktı veya şema değişiyorsa.
- Test yazılıyor, test düzeltiliyor veya doğrulama stratejisi seçiliyorsa.

## Ne zaman okuma

- Yalnız belge, yorum veya davranışsız metadata değişiyorsa.

## Davranış kanıtı

- Uygunsa önce başarısız test, yeniden üretim veya başka gözlenebilir başarısızlık oluştur.
- Testleri özel sınıf/metot yapısına değil kullanıcı veya sistem tarafından görülen gözlenebilir davranışa bağla.
- Typecheck/build geçmesi davranışın doğru olduğunu tek başına kanıtlamaz.
- Bugfix için uygulanabildiğinde regresyon testi ekle.

## Test katmanı seçimi

- Saf mantık için birim testi.
- Veritabanı, dosya, ağ ve adapter sınırları için entegrasyon testi.
- Modüller ve dış tüketiciler için sözleşme testi.
- Kritik kullanıcı yolculuğu için uçtan uca test.
- En dar güvenilir katmanla başla; risk gerektiriyorsa daha geniş kanıt ekle.

## Test kalitesi

- Testleri deterministik, yalıtılmış ve çalıştırma sırasından bağımsız tut.
- Gerçek zaman, ağ veya rastgeleliği kontrol altına al.
- Testi geçirmek için silme, atlama, zayıflatma veya aşırı mock'lama yapma.
- Snapshot ve fixture değişikliğini kasıtlı davranış değişikliği olarak doğrula.
- Dış sistem fixture'larında izin varsa secret ve kişisel verileri sansürlenmiş kaydedilmiş gerçek yanıtı tercih et; ham yapıyı, sağlayıcı/kaynağı, endpoint'i, kayıt tarihini ve şema sürümünü kaydet.
- Alan veya ideal yanıt uydurma; sentetik veri gerekiyorsa açıkça etiketle ve gerekçelendir.

## Mimari ve statik kanıt

- Deponun format, lint, statik analiz, tür denetimi, build, test ve güvenlik komutlarını kullan.
- Mimari boundary değiştiyse mevcut yasak bağımlılık ve cycle kontrollerini çalıştır.
- Yeni mimari araç eklemek için onay al; araç yoksa hedefli import/bağımlılık incelemesi yap.

## Mutation testing

- Yalnız depo destekliyorsa veya yüksek riskli davranış için maliyeti haklıysa kullan.
- Generic sabit mutation veya coverage eşiği uygulama; proje eşiği varsa ona uy.
- Mutation sonucu tek başına test kalitesi veya tamamlanma kanıtı değildir.

## Arayüz ve API kontrolleri

- UI'da yüklenme, boş, hata ve başarı durumlarını; klavye kullanımını; responsive düzeni ve proje erişilebilirlik hedefini doğrula.
- API'de doğrulama, yetkilendirme, hata şeması, uyumluluk ve gerekiyorsa idempotency'yi doğrula.
- Veri değişikliğinde temiz kurulum, desteklenen yükseltme ve kurtarma yolunu test et.

## Çalıştırılamayan kontroller

- Tam komutu, çalışmama nedenini ve telafi edici kanıtı bildir.
- Otomasyon yoksa tekrarlanabilir manuel smoke testi veya kontrol listesi uygula.
- Başarısız veya çalıştırılmamış kontrolü geçmiş gibi gösterme.

## Teslim

- `.agents/templates/change/evidence.md` şemasını review, release veya kapsamlı teslimde; `.agents/templates/github/pull-request.md` şablonunu PR açıklamasında kullan.
- Değişiklik kaynaklı hataları doğrulanmış başlangıç hatalarından ayır.

## Kod sağlığı asgarisi

Bu üç kural `AGENTS.md` §4'ten buraya taşındı. Gerekçe: her oturumda yüklenmeleri gerekmiyor, ama `clean-code.md` ve `architecture.md` tetikleyicileri sıradan bir bugfix'te ateşlemediği için orada kalsalardı görünmez olurlardı. Bu playbook her davranış değişikliğinde yüklenir.

- Basit kodu, açık veri akışını, tutarlı sorumlulukları ve sağlam mevcut soyutlamaları tercih et.
- `null`, `0`, boş, bilinmeyen, eksik ve hata durumlarını açık alan kuralı olmadan birbirine dönüştürme.
- Hataları bağlam ve kök nedenle ele al; sessizce yutma.
