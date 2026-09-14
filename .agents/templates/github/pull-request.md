## Bağlantılar

- Issue:
- work-id:
- Spec yolu:
- Plan yolu:

## Değişiklik özeti ve gerekçe

Tek baskın değişim nedeni, kullanıcıya/operasyona etkisi ve bilinçli kapsam dışı işler:

## Sınırlar ve uygulama

- Etkilenen policy veya mimari sınır:
- İç katman değişikliği:
- Adapter/framework ayrımı:
- Merkezileştirilen karar mantığı:

## Doğrulama

Çalıştırılan exact komutları ve gerçek sonuçlarını yaz; kanıt üretmeden başarı iddia etme:

```text
<komut> → <gerçek sonuç>
```

## Atlanan veya başarısız kontroller

Kontrol, nedeni ve telafi edici kanıt:

## Risk, migration ve kurtarma

- Güvenlik/veri/uyumluluk etkisi:
- Geriye dönük uyumluluk:
- Migration/backfill:
- Rollback veya forward-fix:
- Kalan risk:

## Dokümantasyon ve sürüm etkisi

`none|possible|required|generated`; güncellenen README/reference/ADR/runbook/changelog/release note yolları:

## UI kanıtı

Görsel değişiklik varsa önce/sonra ekran görüntüsü, erişilebilirlik ve responsive doğrulama; yoksa `Uygulanamaz` gerekçesi:

## İnceleme odağı

- Değişiklik tek amaca ve tanımlı work-id'ye bağlı mı?
- Aynı iş kararı başka yerde tekrar ediyor mu?
- Testler özel yapıyı değil gözlenebilir davranışı koruyor mu?
- Diff güvenlik, veri kaybı, eşzamanlılık ve uyumluluk açısından incelendi mi?
