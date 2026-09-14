# İş Yaşam Döngüsü

## Amaç

Oturumlar arasında bağlamı koruyan, kapanışı kanıta bağlayan ve arşivi kontrollü yapan durum makinesini tanımlar.

## Girdiler

- Geçerli `work.json`, `status.md`, kabul kriterleri ve doğrulama kanıtı.
- Kullanıcı kararı, issue/PR bağlantısı ve depo durumu varsa doğrulanmış halleri.

## Çıktılar

- Güncellenmiş iş durumu, kısa checkpoint özeti, sonuç kaydı ve gerektiğinde arşiv hedefi.

## Değişmezler

- Durumlar: `draft`, `ready`, `in_progress`, `blocked`, `review`, `done`, `cancelled`, `archived`.
- `archived` yalnız `done` veya `cancelled` durumundan sonra mümkündür.
- `done` için kabul kriterleri, test/doküman etkisi ve kalan riskler uzlaştırılır.
- `status.md` son doğrulanmış durumu ve sıradaki en küçük güvenli adımı taşır; sohbet dökümü değildir.
- Harici issue veya PR durumu açık yetki olmadan değiştirilmez.

## Hata ve Belirsizlik

- Başarısız veya çalıştırılmamış kontrol gizlenmez; `done` engellenir ya da açık istisna gerekir.
- Çoklu aktif işte otomatik en-yeni seçimi yapılmaz.
- Checkpoint ile gerçek HEAD/diff uyuşmuyorsa gerçek depo durumu önceliklidir ve fark raporlanır.

## Doğrulama

- Durum geçişleri lifecycle fixture'larıyla doğrulanır.
- Kapanış ve arşiv skill'leri bilgi aktarımı olmadan kaynak artifact silmemelidir.
