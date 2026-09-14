# Oturum Başlangıç Sözleşmesi

## Amaç

Yeni veya devam eden her oturumda gerekli en küçük bağlamı güvenli sırayla yükler; arşiv ve tüm doküman ağacının bağlamı şişirmesini önler.

## Girdiler

- İstemcinin yüklediği kök talimat zinciri.
- `.agents/config.json`, `.agents/project.md` ve varsa `.agents/local/preferences.md`.
- Açık work-id, branch/worktree, issue/PR ve aktif iş kayıtları.

## Çıktılar

- Çözümlenmiş profil, backend, aktif iş ve en fazla 8000 karakterlik kısa oturum özeti.
- Okunması gereken aşama artifact'larının hedefli listesi.

## Değişmezler

- Sıra: otomatik çekirdek → config/project/local → aktif `work.json`/`status.md` → aşama artifact'ları → hedefli contract/skill/playbook.
- İş çözümleme: açık work-id → doğrulanmış branch/worktree → issue/PR → tek aktif iş.
- Birden fazla adayda mutasyon öncesi kullanıcıya sorulur.
- Arşivler, tüm spec/plan ağacı ve bütün playbook'lar toplu okunmaz.
- Salt okunur küçük soru için gereksiz iş kaydı oluşturulmaz.
- Claude auto memory ve benzeri istemci hafızaları makine-yerel yardımcı önbellek kabul edilir. Ekip politikası, aktif durum, spec, plan ve kararın kanonik kaydı `.agents` altında kalır; memory en fazla bu kayda kısa işaretçi taşır.

## Hata ve Belirsizlik

- Hook yoksa çekirdek talimatlar çalışır; mekanik koruma düşüşü görünür uyarıdır.
- Özet sınırı aşarsa UTF-8 karakteri bölmeden kırpılır; secret veya transcript eklenmez.
- Modelin “okudum” beyanı yükleme veya uyum kanıtı sayılmaz.
- Dosyanın varlığı ya da manuel okunması otomatik istemci yüklemesi kanıtı sayılmaz; istemci gözlemi yoksa sonuç `SKIP` olarak ayrılır.

## Doğrulama

- Sıfır, bir ve çoklu aktif iş fixture'ları denenir.
- SessionStart çıktısı karakter ve gizli veri sınırlarıyla doğrulanır.
