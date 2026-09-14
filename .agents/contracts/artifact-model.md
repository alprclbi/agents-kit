# Kanonik Artifact Modeli

## Amaç

Her iş için tek bir mantıksal doğruluk kaynağı ve sabit artifact rolleri tanımlar; aynı spec veya planın birden fazla fiziksel kopyasını engeller.

## Girdiler

- Çözümlenmiş `work-id` ve işin `work.json` kaydı.
- Seçilmiş backend ve görevin gerektirdiği artifact rolü.
- Kullanıcının açıkça verdiği kalıcı çıktı yolu.

## Çıktılar

- `spec`, `plan`, `tasks`, `status`, `outcome`, `decisions`, `research`, `test-plan` veya `evidence` rollerinden biri için tek proje-göreli yol.
- Native backend'de varsayılan kök `.agents/changes/active/<work-id>/`.

## Değişmezler

- Kalıcı artifact yolu `work.json.artifacts` içinde kayıtlıdır.
- Native backend'de `tasks`, plan içindeki checkbox listesine eşlenebilir; ikinci görev dosyası zorunlu değildir.
- Superpowers brainstorming `spec`, writing-plans `plan` ve `tasks` rolüne bağlanır.
- Runtime çıktısı kalıcı artifact sayılmaz; kapanıştan önce kanonik role aktarılır veya silinir.
- `null`, boş, eksik ve bilinmeyen artifact birbirine dönüştürülmez.

## Hata ve Belirsizlik

- İş kimliği veya backend belirsizse yazma yapılmaz.
- Aynı rol için birden fazla fiziksel kaynak bulunursa seçim yapılmaz; kullanıcı kararı istenir.
- Proje dışı, mutlak veya üst dizine çıkan yol engellenir.

## Doğrulama

- `artifact-router` sonucu `router-result.schema.json` ile uyumlu olmalıdır.
- Kaçak yollar `stop-check` ve kabul senaryolarında aranır.
