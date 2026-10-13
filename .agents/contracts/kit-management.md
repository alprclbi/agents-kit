# Kit Yönetimi

## Amaç

Kiti mevcut projeye dosya ezmeden benimsetir; sürüm güncellemesini sahiplik ve hash'e bağlar; kaldırmada proje verisini korur.

## Girdiler

- Mevcut proje, kurulu manifest, yeni kit kökü ve varsa exact eski temel kökü.
- Kullanıcının önizleme sonrası açık onayı.

## Çıktılar

- `equivalent`, `project-specific`, `conflict`, `absent`, `safe-update`, `preserve-and-merge`, `preserve-deletion` veya `propose-add` sınıflandırması.
- Uygulanmadan önce exact hedef listesi ve birleşik diff.

## Değişmezler

- Sahiplik sınıfları: `kit-managed`, `project-owned`, `user-local`, `work-generated`, `template`, `adapter`.
- Benimseme mevcut aynı adlı dosyayı otomatik ezmez.
- Güncelleme base/current/new hash'lerini karşılaştırır; gerçek üç yönlü merge için eski base byte'ları gerekir.
- Base byte'ları yoksa modified dosya korunur ve otomatik merge yapılmaz.
- Kaldırma yalnız hash'i değişmemiş `kit-managed` dosyaları otomatik aday yapar.
- Project-owned, user-local ve work-generated içerik hiçbir zaman otomatik overwrite veya remove edilmez.

## Hata ve Belirsizlik

- Manifest veya eski hash yoksa dosya güvenli sayılmaz.
- Kullanıcıca bilinçli silinen dosya sessizce geri getirilmez.
- Global ayar, plugin, GitHub ayarı veya harici yazma ayrıca açık yetki olmadan yapılmaz.

## Proje komutları

Kurulumdan sonra `.agents/project.md` boş şablon kalırsa ajan her oturumda komutları yeniden tahmin eder. `init` kapanışta bu boşluğu kullanıcı onayıyla doldurur.

- Yalnız komut bölümü hâlâ yer tutucu metin taşıyorsa uygulanır; dolu bölüme dokunulmaz. `update` bu adımı hiç çalıştırmaz.
- Adaylar yalnız depoda açıkça bildirilmiş komutlardan çıkar: `package.json` `scripts` alanı (kilit dosyasına göre `npm`, `pnpm`, `yarn` veya `bun`), `Makefile` ve `justfile` hedefleri, `pyproject.toml` içindeki araç tabloları, `Cargo.toml`, `go.mod`, `composer.json` `scripts` alanı ve CI iş akışlarındaki `run:` satırları.
- Her aday kaynağıyla birlikte gösterilir (`npm test` ← `package.json`). Kaynağı olmayan komut önerilmez.
- Aday komutlar çalıştırılmaz; kurulum, ağ veya yan etki doğurabilir.
- Tek bir evet/hayır onayı istenir; kullanıcı listeden satır çıkarabilir. Yalnız onaylanan satırlar yazılır, yazılan her satır kaynağını taşır.
- Aday yoksa veya kullanıcı reddederse soru tekrarlanmaz; bölüm olduğu gibi kalır ve kapanış raporu bunu bir satırla söyler.

## Doğrulama

- Boş repo, mevcut talimat, modified managed, base içeriği eksik ve remove-preserves-work fixture'ları çalıştırılır.
- Uygulama sonrası `kit-doctor`, manifest ve talimat yükleme kontrolleri geçmelidir.
