---
name: init
description: Use when installing Agents Kit scaffolding into a project, including projects that already contain agent instructions or an older file-based kit installation.
---

# Kit Kurulumu

## Amaç

İskeleyi projeye kur, kullanıcıyı uğraştırma. **En çok iki soru sor.**

## Rapor kuralı

Sınıflandırma tablosu, dosya listesi dökümü ve ara rapor basma. Plan ve kapanış raporu beşer satırı geçmesin.

## Sorular

**1. Çalışma biçimi.** Her kurulumda sorulur; cevap `.agents/config.json` içindeki `profile` alanına yazılır. Profil çalışma anında çıkarımla bulunmaz.

```
Bu projede nasil calisiyorsun?
  [1] Yalniz                  -> solo   (varsayilan)
  [2] Ekiple, paylasilan repo -> team
```

Varsayılanı kanıttan öner: uzak repo varsa ve `git shortlog -sn` birden fazla yazar gösteriyorsa `[2]`.

**2. Mevcut `AGENTS.md`.** Yalnız dosya varsa sorulur.

```
Mevcut AGENTS.md bulundu (<bayt>, <bolum> bolum).
  [1] Kurallarimi koru -> .agents/project.md'ye tasinir   (varsayilan)
  [2] Kiti kullan      -> yedeklenir, kit cekirdegi gelir
```

Kullanıcı niyetini baştan bildirdiyse sorma.

## İş akışı

1. Salt okunur envanter: repo kökü, branch, `AGENTS.md`, `CLAUDE.md`, `.agents`, `.codex`, `.claude`. Sonucu ekrana dökme.
2. **Eski dosya tabanlı kurulumu tanı:** `.agents/manifest.json` varsa göç gerekir (adım 3), yoksa adım 5.
3. Göç yedeği: `.agents/runtime/gocis-yedek/<tarih>/`, dizin yapısı korunur.
4. Göç. Kaldırılacak küme **iki manifestin farkından** çıkar; elle yol listesi tutma ve manifestteki `ownership` alanına bakma.
   1. **Önce** `.claude/settings.json` içinden kitin kendi **hook bloğunu** çıkar. Dosya silmeden önce yap: ters sırada göç yarıda kalırsa hook artık olmayan `.agents/validators/...` yolunu göstermeye devam eder.
   2. Kaldırılacak küme = projedeki **eski** manifestin yolları − kurulacak **yeni** sürümün kurulum seti. Sonucu `.agents/`, `.claude/` ve `.codex/` ile sınırla; repo köküne ve `.github/` altına hiç dokunma.
   3. Yalnız **hash**'i hâlâ eşleşeni kaldır. Eşleşmeyene dokunma; yedeğe al ve raporda **adıyla** işaretle.
   4. Boşalan dizinleri de kaldır.
   Kural fark tabanlı olduğu için her iki sette de bulunan `CLAUDE.md`, `.claude/settings.json` ve `.codex/config.toml` kendiliğinden korunur; ayrı istisna listesi tutma. Elle yol listesi her sürümde eksik kalır: 1.0.0'dan 1.2.x'e geçişte kaldırılması gereken 208 dosyanın 171'i `.agents/tests/` ve `.agents/evals/` altındadır.
5. İskeleyi yaz: `AGENTS.md`, `CLAUDE.md`, `AGENT-KIT-START.md`, `.agents/{config.json, playbooks/, contracts/, templates/, schemas/, VERSION}`. Dokunulacak her dosyayı **önce yedekle**: `.agents/runtime/adopt-yedek/<tarih>/`.
6. Soru 2 seçim [1] ise projeye özgü kuralları `.agents/project.md` dosyasına taşı, kit çekirdeğini `AGENTS.md` yap; kitle örtüşen kuralı tekrarlama. Seçim [2] ise yalnız kit çekirdeğini yaz.
7. `CLAUDE.md` varsa kullanıcının içeriğini koru, kit import satırını ekle. `.claude/settings.json` varsa **alan düzeyinde birleştir**; kullanıcının hook'ları kalır.
8. Hedef manifesti kurulan dosyalara indir. `.agents/local/preferences.md` yoksa `preferences.example.md` dosyasından oluştur. `.gitattributes` yoksa kit yolları için LF kuralıyla oluştur.
9. **Öz denetim:** seçim [1] ise eski dosyadaki her madde yeni yerlerden birinde bulunmalı; bulunmayanı raporda işaretle.
10. `kit-doctor` çalıştır. Göç yapıldıysa hook'un **tam bir kez** yüklendiğini ve skill listesinde kopya olmadığını raporla.
11. Kapanış: kaç dosya, doctor sonucu, yedek yolu, geri alma komutu, kalan adım.

## Yetki sınırı

Bu skill plugin kurmaz, global Codex/Claude ayarı değiştirmez, GitHub ruleset/workflow uygulamaz, commit/push/PR oluşturmaz ve harici sisteme yazmaz.

Yedeklemeden hiçbir dosyayı değiştirme veya kaldırma. Kullanıcının hook'unu, ayarını veya talimatını silme.
