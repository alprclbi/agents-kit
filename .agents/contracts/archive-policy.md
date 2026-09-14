# Arşiv Politikası

## Amaç

Aktif bağlamı küçük tutarken karar, sonuç ve kanıtın geri bulunabilir kalmasını sağlar.

## Girdiler

- İşin son durumu, risk profili, artifact listesi ve kalıcı doküman aktarımı.
- `.agents/config.json.archiveStrategy` değeri.

## Çıktılar

- `.agents/changes/archive/<year>/<work-id>/` hedefinde compact veya full arşiv seti.

## Değişmezler

- Küçük iş: `work.json`, son `status.md`, `outcome.md` ve gerekli evidence.
- Standart iş: küçük sete ek olarak onaylı spec/plan ve kalıcı kararlar.
- Yüksek güvence: bütün normatif artifact'lar, test planı, sansürlenmiş evidence ve denetim için gerekli araştırma.
- Kalıcı bilgi README/ADR/runbook/reference belgelerine aktarılmadan kaynak artifact silinmez.
- Arşiv otomatik başlangıç bağlamına yüklenmez.

## Hata ve Belirsizlik

- Durum `done|cancelled` değilse arşivleme engellenir.
- Hedef zaten varsa overwrite yapılmaz; içerik farkı raporlanır.
- Secret, transcript ve yerel runtime verisi arşive alınmaz.

## Doğrulama

- Küçük, standart ve yüksek güvence fixture'larında beklenen saklama seti karşılaştırılır.
- Kayıp kalıcı bilgi veya hedef çakışması arşivlemeyi başarısız yapmalıdır.
