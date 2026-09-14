# Kaynak Sahipliği

## Amaç

Tek veya çok ajanlı çalışmada dosya, servis, port, migration ve paylaşılan test kaynağı çakışmalarını mutasyondan önce görünür yapar.

## Girdiler

- Aktif işlerin `ownership.paths`, `resources`, `ports` ve `migrations` alanları.
- Branch/worktree ve paylaşılan ortamın doğrulanmış durumu.

## Çıktılar

- Çakışan iş kimlikleri, kaynak türü ve çözüm gereksinimi içeren diagnostic listesi.

## Değişmezler

- Aynı dosya/glob, migration aralığı, port veya değiştirilebilir ortak kaynak iki aktif işte eşzamanlı sahiplenilemez.
- Paylaşılan test DB'si veya sunucu izolasyonu doğrulanmadan paralel mutasyon başlatılmaz.
- Süresi geçmiş görünen kayıt otomatik boş sayılmaz; kullanıcı veya doğrulanmış lifecycle kararı gerekir.
- Alt ajan kullanımı ayrıca açık yetki gerektirir.

## Hata ve Belirsizlik

- Glob kesişimi güvenle çözülemiyorsa team profilinde çakışma varsayılır.
- Solo profilde belirsizlik uyarılır; veri kaybı veya ortak durum riski varsa yine engellenir.

## Doğrulama

- Dosya, migration, port ve test kaynağı fixture'ları bağımsız çalıştırılır.
- Aynı kaynağı serbest bırakan kapanış sonrası çakışmanın kalktığı doğrulanır.
