---
name: start-work
description: Use when a new feature, bug fix, migration, refactor, or other durable project change needs tracked context across sessions.
---

# Yeni İş Başlatma

## Genel bakış

Kalıcı bir değişiklik başlamadan önce tek bir work kaydı oluştur. Salt okunur küçük sorular için gereksiz kayıt üretme.

## Çalışma sözleşmesi

1. Repo kökünü, geçerli talimatları, Git durumunu ve mevcut aktif işleri salt okunur keşfet.
2. Kimliği açık kullanıcı değeri → issue kimliği → branch adı → `YYYYMMDD-kisa-slug` sırasıyla çöz; mevcut kimlikle çakışırsa dur.
3. Profili `.agents/config.json` içinden oku. İş ekip, veri, güvenlik, üretim veya geri dönüş riski taşıyorsa `work.json` içinde `team` olarak sıkılaştır ve gerekçesini `profileReason` alanına yaz; gevşetme yapma.
4. Kullanıcı → config → mevcut work → tek doğrulanmış sistem → native sırasını uygula; backend çözülmeden artifact yazma.
5. `.agents/templates/change/work.json` ve `status.md` dosyalarını kanonik hedefe uygula. Yalnız işin gerektirdiği spec, plan, test-plan veya evidence artifact'larını oluştur.
6. Dosya, migration, port ve paylaşılan test kaynağı sahipliğini kaydet; aktif işlerle çakışmada mutasyon yapma.
7. Çözülen work-id değerini `.agents/runtime/current-work` dosyasına tek satır olarak yaz; dosya git dışındadır ve hook'un hangi işte olduğunu bilmesini sağlar.
8. Branch, worktree, issue veya commit için ayrıca açık yetki iste; bu skill bu yetkileri kendiliğinden üretmez.

## Hızlı başvuru

| Durum | Davranış |
| --- | --- |
| Salt okunur kısa soru | Work kaydı oluşturma |
| Tek dosyalı düşük riskli değişiklik | Compact artifact seti |
| Ekip, veri veya üretim riski | Team ve açık sahiplik |
| Backend belirsiz | Yazmadan önce sor |

## Sık hatalar

- Tarih veya branch bilgisini doğrulamadan uydurmak.
- Her görev için boş spec/plan dosyaları üretmek.
- Mevcut aktif işle çakışan sahipliği kaydetmeden başlamak.
- İş kaydı açmayı commit veya issue açma yetkisi saymak.
