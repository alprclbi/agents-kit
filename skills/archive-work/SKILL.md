---
name: archive-work
description: Use when a durable project change is done or cancelled and active context must be compacted without losing decisions, outcomes, or evidence.
---

# İşi Arşivleme

## Genel bakış

Aktif iş dizinini küçük tutarken geri bulunabilir kanıtı koru. Arşivleme kapanıştan ayrı ve geri alınabilir bir adımdır.

## Çalışma sözleşmesi

1. `work.json.status` değerinin `done` veya `cancelled` olduğunu ve `outcome.md` bulunduğunu doğrula.
2. Dokümantasyon etkisi, kararlar ve operasyon bilgisinin kalıcı README/ADR/runbook/reference hedeflerine aktarıldığını doğrula.
3. Config ve profile göre compact, standart veya full saklama setini seç; seçimi `outcome.md` içinde gerekçelendir.
4. Exact hedef `.agents/changes/archive/<year>/<work-id>/` yolunu çöz; mevcut farklı hedefi overwrite etme.
5. Önizlemede taşınacak, korunacak ve dışlanacak dosyaları listele. Secret, transcript, local/runtime ve yeniden üretilebilir geçici çıktıyı dışla.
6. Bilgi aktarımı doğrulanmadan kaynak artifact silme veya taşıma. Önce kopyala, bütünlük ve hedefi doğrula; sonra kaynak için açık ve geri alınabilir işlem kullan.
7. `work.json.status` değerini yalnız başarılı doğrulama sonrası `archived` yap; harici issue/PR veya Git geçmişini değiştirme.
8. Arşivlenen iş `.agents/runtime/current-work` içinde yazılıysa dosyayı sil.

## Hızlı başvuru

| Yoğunluk | Saklama seti |
| --- | --- |
| Compact | work, son status, outcome, gerekli evidence |
| Standart | Compact + onaylı spec/plan + kararlar |
| Full | Normatif artifact'lar + test planı + sansürlenmiş kanıt/araştırma |

## Sık hatalar

- Aktif veya blocked işi arşivlemek.
- Hedef varlığını doğrulamadan recursive taşıma yapmak.
- Kalıcı karar aktarılmadan spec/planı silmek.
- Runtime veya sohbet dökümünü denetim kanıtı sanmak.
