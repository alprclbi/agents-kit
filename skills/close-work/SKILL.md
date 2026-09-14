---
name: close-work
description: Use when implementation appears complete or a durable project change must be cancelled and its outcome reconciled before archival.
---

# İşi Kapatma

## Genel bakış

Tamamlanma iddiasını kabul kriteri, doğrulama, dokümantasyon ve gerçek diff kanıtına bağla.

## Çalışma sözleşmesi

1. `work.json`, onaylı spec/plan, kabul kriterleri, gerçek diff ve son `status.md` dosyasını hedefli oku.
2. Her kabul kriterini `karşılandı`, `karşılanmadı` veya `uygulanamaz` olarak kanıt yoluyla uzlaştır.
3. İlgili test, format, lint, tür, build, güvenlik ve manuel kontrolleri çalıştır; başarısız veya çalıştırılmamış kontrolü saklama.
4. `documentationImpact` değerini gerçek değişiklikle karşılaştır. `possible` çözülmeden, `required` belge güncellenmeden veya `generated` kaynak üretici çalışmadan kapatma.
5. `outcome.md` içine gerçekleşen kapsam, doğrulama, kalıcı belge değişiklikleri, uyumluluk/migration, kalan risk ve takip işlerini yaz.
6. Tamamlanan işi `done`, bilinçli bırakılan işi gerekçeyle `cancelled` yap; kanıt yoksa mevcut durumu koru.
7. Harici issue veya PR durumunu, commit'i, merge'i, release'i ya da deploy'u açık yetki olmadan değiştirme.
8. Kapanan iş `.agents/runtime/current-work` içinde yazılıysa dosyayı sil; bayat işaretçi sonraki oturumu yanıltır.

## Hızlı başvuru

| Kapı | Gerekli kanıt |
| --- | --- |
| Kabul | Kriter başına sonuç ve yol |
| Test | Tam komut ve sonuç |
| Doküman | Güncellenen yol veya `none` gerekçesi |
| Risk | Kalan risk ve kurtarma yolu |
| Sonuç | `outcome.md` |

## Sık hatalar

- Yalnız hedefli test geçince bütün işi tamamlanmış saymak.
- SKIP veya başlangıç hatasını PASS olarak raporlamak.
- Takip işini sessizce kapsam dışına atmak.
- Kapanışı otomatik commit, issue kapatma veya merge yetkisi saymak.
