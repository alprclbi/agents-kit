# Backend Çözümleme

## Amaç

Native, Spec Kit, OpenSpec veya harici spec sistemlerinden yalnız birini kanonik backend olarak seçer.

## Girdiler

- Kullanıcının açık seçimi veya çıktı yolu.
- `.agents/config.json` içindeki `artifactBackend`.
- `work.json.backend` ve depoda doğrulanmış backend işaretleri.

## Çıktılar

- `native`, `spec-kit`, `openspec` veya `external` değeri; kaynak alanıyla birlikte `work.json` içine kaydedilir.

## Değişmezler

- Öncelik: kullanıcı → config → work kaydı → tek doğrulanmış sistem → native fallback.
- Mevcut backend'in kendi kanonik fiziksel yapısı korunur; içerik native dizine kopyalanmaz.
- `auto` kalıcı bir work backend değeri değildir; çözümleme tamamlanınca somut türe dönüşür.

## Hata ve Belirsizlik

- İki veya daha fazla backend doğrulanırsa otomatik seçim yapılmaz.
- Harici backend yazma API'si yoksa yalnız yol kaydı ve rapor üretilir.
- Backend explicit artifact yolunu desteklemiyorsa `AKE303` ile fail-closed davranılır.

## Doğrulama

- Router fixture tablosu her backend için spec/plan/tasks eşlemesini doğrular.
- Aynı işte iki kanonik kaynak üretimi kaçak artifact kontrolünde hata sayılır.
