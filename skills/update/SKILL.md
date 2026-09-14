---
name: update
description: Use when refreshing an installed Agents Kit scaffold to the version shipped with the currently installed plugin.
---

# İskele Güncelleme

## Amaç

Projedeki **iskeleyi** plugin ile gelen sürüme getir. **Soru sorma**, kullanıcı akışını kesme. Sonunda ne yapıldığını kısaca bildir.

## Girdi

Proje kökü ve plugin kökü. Plugin kökü `${CLAUDE_PLUGIN_ROOT}` değişkeninden gelir; kullanıcıdan **yol isteme**, ağdan sürüm indirme. Klon gerekmez.

Plugin kökü çözülemiyorsa dur ve bildir; tahminle bir dizin seçme.

## Kapsam

Yalnız iskele: `AGENTS.md`, `AGENT-KIT-START.md` ve `.agents/{config.json, playbooks/, contracts/, templates/, schemas/, VERSION}`.

`CLAUDE.md` ayrı kuralla yönetilir (adım 4a); içeriği **hiçbir koşulda** yeni sürümle değiştirilmez.

Araçları (skill, hook, doğrulayıcı, adaptör) **plugin yönetir**; onlara dokunma. Kullanıcı onları istemcinin kendi güncelleme akışıyla alır.

## Dokunulmayan üç alan

- `.agents/project.md` — proje kuralları. Manifestte hash'i yok, karşılaştırılamaz.
- `.agents/local/` — kişisel tercihler. Manifeste hiç girmez.
- `.agents/changes/` — iş kayıtları. Manifeste hiç girmez.

Bunlara hiçbir koşulda yazma.

## İş akışı

1. Git durumunu, kurulu `VERSION` ile plugin `VERSION` değerini ve iki manifesti salt okunur doğrula. Şema uyumsuzluğunda dur ve bildir.
2. Kurulu sürüm plugin sürümüne eşitse hiçbir şey yazma; "güncel" de ve çık.
3. `.agents/config.json` içindeki `profile` değerini **koru**. Şema yeni alan getirdiyse yalnız eksik alanları ekle; kullanıcının kararını ezme.
4. Kalan her iskele yolu için kurulu hash ile mevcut dosya hash'ini karşılaştır. Fark varsa kullanıcı o dosyayı elle değiştirmiştir: **önce yedekle** (`.agents/runtime/update-yedek/<tarih>/`, dizin yapısı korunur), sonra yeni sürümü yaz.
4a. `CLAUDE.md` bu kuralın dışındadır. Dosya kullanıcının kendi proje talimatlarını taşır; hash farkı "bozulmuş" değil, "kullanıcı kendi kurallarını yazmış" demektir. Yalnız kitin **import bloğunun** güncel ve dosyada bulunduğunu doğrula; eksikse başa ekle. Kullanıcının satırlarına dokunma, dosyayı yeni sürümle değiştirme. Bu kural `init` adım 7 ile aynıdır; ikisi çelişirse `init` esastır.
5. Yeni sürümde olup projede olmayan iskele yollarını ekle. Çıkarılmış ve kullanıcının değiştirmediği yolları kaldır; değiştirdiği yolu kaldırma, yedeğe taşı.
6. Eksik opsiyonel dosyaları oluştur: `.agents/local/preferences.md` yoksa `preferences.example.md` dosyasından, `.gitattributes` yoksa kit yolları için LF kuralıyla. Var olana dokunma.
7. Hedef manifesti gerçekten kurulu dosyalara indir; kaynak manifest kitin kendi deposunu anlatır.
8. `kit-doctor` ve manifest check çalıştır. Başarısızlıkta yedekten geri dönüş yolunu göster.

## Rapor kuralı

Beş satırı geçme: kaç dosya güncellendi, kaç eklendi, kaç kaldırıldı, yedeklenen yollar, doctor ve manifest sonucu. Dosya listesi dökme; kullanıcı isterse ver.

## Yetki sınırı

Ağdan sürüm indirmez; global ayar, hook trust, GitHub, commit, push veya harici sisteme yazma yetkisi vermez.

Kullanıcının elle değiştirdiği dosyayı yedeklemeden değiştirme. Yedeksiz silme yapma.
