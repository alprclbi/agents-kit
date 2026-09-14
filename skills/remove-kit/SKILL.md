---
name: remove-kit
description: Use when safely removing Agents Kit components while preserving project work, user data, and modified files.
---

# Kiti Güvenli Kaldırma

## Amaç

Manifest sahipliği ve gerçek hash kanıtıyla yalnız değişmemiş kit dosyalarını geri alınabilir biçimde kaldırma adayı yap.

## İş akışı

1. Repo kökünü, Git durumunu, `.agents/manifest.json` ve bütün manifest yollarını salt okunur doğrula. Manifest yoksa veya geçersizse otomatik silme adayı üretme.
2. Her yol için mevcut dosya türünü, sahipliği ve SHA-256 hash'ini belirle. Symlink veya proje dışına çözümlenen yolu reddet.
3. Yalnız `ownership: kit-managed|adapter|template`, `hashPolicy: required` ve mevcut hash manifestle tam eşleşiyorsa otomatik aday yap.
4. Şunları her zaman koru:
   - değiştirilmiş managed dosyalar;
   - `project-owned`, `work-generated` ve `user-local` içerik;
   - `.agents/changes/active`, `.agents/changes/archive`, spec/roadmap artifact'ları;
   - local/runtime/log ve manifest dışı proje dosyaları.
5. Silme adaylarını ve korunma gerekçelerini exact yol/hashes ile göster. Boş kalabilecek dizinleri ayrıca belirt; geniş recursive hedef, glob veya çözümlenmemiş değişken kullanma.
6. Mümkünse aynı dosya sistemi içinde timestamp'li yedek veya işletim sistemi trash seçeneği öner. Kurtarma yolu olmadan yüksek etkili silme yapma.
7. Yalnız kullanıcı exact listeyi onaylarsa adayları tek tek kaldır. Her işlemden sonra hedefi yeniden doğrula; beklenmedik değişimde dur.
8. Kalan proje talimatlarını, hook/settings referanslarını ve aktif işleri doğrula. Kısmi kaldırma varsa kırık import bırakma; gereken manuel birleşimi raporla.

## Yetki sınırı

Bu skill aktif işi, kullanıcı değişikliğini, Git geçmişini, global istemci ayarını veya harici sistemi silmez. Commit, push, PR ve GitHub ayarı için ayrıca açık yetki gerekir.
