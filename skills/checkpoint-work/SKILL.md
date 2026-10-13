---
name: checkpoint-work
description: Use when a durable project change reaches a meaningful milestone, decision, blocker, handoff, review transition, or session boundary.
---

# İş Checkpoint'i

## Genel bakış

`status.md` dosyasını kısa, doğrulanmış ve sonraki oturumun doğrudan kullanabileceği bir devir özeti olarak güncelle.

## Çalışma sözleşmesi

1. Anlamlı checkpoint tetikleyicisini doğrula: spec/plan onayı, bağımsız görev tamamlanması, önemli test/karar/engel, devir, PR aşaması veya oturum kapanışı.
2. Gerçek repo durumunu, değişen yolları ve çalıştırılmış kontrolleri yeniden oku.
3. `status.md` içinde amaç, mevcut aşama, son tamamlanan işlem, son doğrulanmış depo durumu, doğrulamalar, engeller/riskler, sahiplik ve sıradaki en küçük güvenli adımı güncelle; `work.json` içindeki `updatedAt` alanını checkpoint zamanına getir (oturum başı özetindeki "Son checkpoint" buradan okunur).
4. Başarısız ve çalıştırılmamış kontrolleri sonuçlarıyla ayır; geçmediği bir kontrolü geçmiş yazma.
5. Kalıcı karar varsa `decisions.md` veya ADR'ye; ayrıntılı araştırma varsa tarih/kaynak/güven düzeyiyle `research.md` dosyasına yönlendir.
6. Checkpoint bir komut çıktısı dökümü değildir; sohbet transcript'i, secret veya geçici log ekleme.
7. Commit, push veya harici iş kaydı değişikliği yalnız ayrıca yetkilendirilmişse yapılır.
8. Stop hook'u `AKW301` ile aktif işte `status.md` dosyasından yeni bir değişiklik bulduğunu bildirirse oturum kapanmadan bu skill'i uygula; uyarı kapanışı engellemez.

## Hızlı başvuru

| Olay | Checkpoint |
| --- | --- |
| Bir test komutu daha çalıştı | Genellikle hayır |
| Plan onaylandı | Evet |
| Bağımsız task tamamlandı | Evet |
| Yeni engel veya karar çıktı | Evet |
| Oturum devrediliyor | Evet |

## Sık hatalar

- Her araç çağrısından sonra status şişirmek.
- Kanıt yolunu vermeden “testler geçti” yazmak.
- Uzun araştırma veya karar gerekçesini kısa status içine gömmek.
- Sonraki adımı “devam et” gibi ölçülemez bırakmak.
