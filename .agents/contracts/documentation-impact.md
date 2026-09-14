# Dokümantasyon Etkisi

## Amaç

Kod, yapılandırma, API, operasyon veya kullanıcı akışı değişikliğinin kalıcı belgelerle kapanışta uzlaştırılmasını sağlar.

## Girdiler

- İş kapsamı, değişen davranış ve üretilmiş doküman kaynakları.
- README, reference, ADR, runbook, changelog ve release note gereksinimleri.

## Çıktılar

- `documentationImpact`: `none`, `possible`, `required` veya `generated`.
- Güncellenen belge yolları ya da neden belge değişmediğine ilişkin doğrulanabilir açıklama.

## Değişmezler

- `none`: kullanıcı/operasyon/API sözleşmesi etkilenmez.
- `possible`: etki henüz doğrulanmamıştır; kapanıştan önce çözülür.
- `required`: kalıcı belge güncellemesi olmadan iş tamamlanmaz.
- `generated`: kanonik kaynağın üreticisi çalıştırılır; üretilmiş dosya elle yamalanmaz.
- Aynı talimat birden fazla belgede çoğaltılmaz; kanonik kaynağa bağlantı verilir.

## Hata ve Belirsizlik

- `possible` ile `done` durumuna geçilemez.
- Çalıştırılamayan generator veya bozuk bağlantı açık engel olarak kaydedilir.

## Doğrulama

- `close-work`, başlangıç etkisi ile gerçek diff'i karşılaştırır.
- Değişen komut/API/şema için ilgili belge veya açık `none` gerekçesi aranır.
