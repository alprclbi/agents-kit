# `.agents` Çalışma Sistemi

Bu dizin kalıcı proje bağlamını, iş artifact'larını, ajan workflow'larını ve mekanik doğrulamaları tek bir taşınabilir düzende toplar.

## Temel ilkeler

- Kök `AGENTS.md` kısa zorunlu çekirdek ve yönlendiricidir.
- Paylaşılan proje gerçekleri `project.md`, kişisel tercihler git dışı `local/preferences.md` içindedir.
- Her kalıcı iş `.agents/changes/active/<work-id>/` altında tek bir kanonik kayda sahiptir.
- Spec, plan ve görev yolları yazmadan önce `artifact-router` ile çözülür.
- Tamamlanan veya iptal edilen işler bilgi aktarımı doğrulandıktan sonra `changes/archive/<year>/<work-id>/` altına taşınır.
- `runtime/`, `local/`, `logs/` ve üretilmiş test sonuçları paylaşılmaz.
- Claude auto memory gibi istemci hafızaları yardımcı ve makine-yereldir; takımca paylaşılan proje gerçeği veya iş artifact'ı yerine kullanılmaz.

## Başlıca workflow'lar

| İhtiyaç | Skill |
| --- | --- |
| Yeni kalıcı iş | `start-work` |
| Oturum devamı | `resume-work` |
| Spec/plan/görev yolu | `artifact-router` |
| Anlamlı durum kaydı | `checkpoint-work` |
| Kabul ve doküman uzlaştırması | `close-work` |
| Arşivleme | `archive-work` |
| Yapı ve koruma tanısı | `kit-doctor` |
| Mevcut projeye güvenli katılım | `init` |
| Kit sürümü güncelleme | `update` |
| Güvenli kaldırma | `remove-kit` |

Yalnız mevcut görevin gerektirdiği contract, skill, playbook veya şablonu oku. Bu README her oturumda otomatik bağlama yüklenmez.

## İlk benimseme

1. Paketi ayrı bir dizine çıkar. Hedefte aynı adlı dosya yoksa içeriği proje köküne kopyalama önerisini incele; dosya varsa kopyalamadan `init` çalıştır.
2. `init` hedefleri `equivalent`, `project-specific`, `conflict` ve `absent` olarak sınıflandırır; exact diff ve hedef listesi açıkça onaylanmadan yazmaz.
3. `.agents/project.md` içine yalnız depodan doğrulanmış amaç, komut, mimari sınır ve kalite kapılarını ekle. Kişisel tercihler gerekiyorsa `templates/project/preferences.md` şablonundan git dışı `local/preferences.md` üret.
4. `kit-doctor` çalıştır. Warning, Blocker ve SKIP sonuçlarını PASS'ten ayır; hook trust ve canlı istemci gözlemlerini istemci içinde tamamla.
5. Claude Code kullanılıyorsa işletim sistemine uygun hook parçası için yalnız hook alanlarını kapsayan diff iste; onaylı merge sonrasında `/hooks` içinde üç olayı **Project Settings** kaynağıyla doğrula. Git deposu Claude hook'u için zorunlu değildir.

Kit global ayar, plugin, branch, commit, PR, ruleset veya workflow oluşturmaz. `.agents/templates/github/` altındaki örnekler opt-in'dir; token'lar çözülmeden ve mevcut `.github` diff'i incelenmeden uygulanmaz.

## Günlük iş yaşam döngüsü

```text
start-work → artifact-router → uygulama/checkpoint → close-work → archive-work
                  ↑ başka oturumda resume-work
```

- `start-work`, `.agents/changes/active/<work-id>/work.json` ve `status.md` ile en küçük gerekli artifact setini açar.
- `artifact-router`, native backend'de spec ve planı aynı iş dizinine yönlendirir. Ayrı bir `.agents/plans/` ağacı kasıtlı olarak yoktur; planın tek kanonik yolu `<work-id>/plan.md` olur.
- Superpowers `brainstorming` ve `writing-plans` kullanılsa bile önce router sonucu explicit hedef yapılır. Varsayılan `docs/superpowers/*` yolları kanonik değildir ve kaçak kontrolüne takılır.
- `checkpoint-work`, anlamlı kilometre taşında kısa güncel durumu yazar; transcript veya ham komut dökümü biriktirmez.
- `close-work`, kabul, test, dokümantasyon ve kalan riskleri uzlaştırır. `archive-work`, yalnız kapanmış işi compact/standart/full saklama setiyle aktif alandan çıkarır.

Birden fazla aktif işte work-id çözümlenmeden veya sahiplik çakışması varken team mutasyonu engellenir. Active dizini güncel bağlam içindir; geçmiş yalnız hedefli arşiv okumasıyla yüklenir.

## Hook ve istemci adaptörleri

| İstemci | Paylaşılan dosya | Etkinleştirme |
| --- | --- | --- |
| Codex | `.codex/hooks.json` | Güvenilen projede `/hooks` ile command hash'lerini incele ve trust kararını ver |
| Claude Code Bash | `adapters/claude/hooks.bash.json` | Varsayılan; `.claude/settings.json` ile kurulu gelir (Linux, macOS, Git Bash'li Windows) |
| Claude Code PowerShell | `adapters/claude/hooks.powershell.json` | Yalnız Git Bash olmayan Windows; `hooks` nesnesi elle veya `init` diff'iyle değiştirilir |

Hook yoksa kök talimatlar geçerlidir; yalnız mekanik koruma düşer. Hook'lar normal istemci izin akışını genişletmez: engel yokken otomatik `allow` üretmez.

`PreToolUse` üç karar döndürebilir:

| Karar | Ne zaman |
| --- | --- |
| `deny` | Kanıtlanmış blok: profil kapısı veya sahiplik çakışması |
| (karar yok) | Engel yok; istemcinin kendi izin akışı işler |

### Kural yeniden enjeksiyonu

Kuralı oturum başında bir kez söylemek yetmez. Hook çıktıları iki anda kuralın **kendisini** taşır, kodunu değil:

| An | Ne basılır | Neden |
| --- | --- | --- |
| `PreToolUse` uyarı/red | Tetiklenen kuralın tam metni (`AKE201: Birden fazla aktif iş çözümlenemedi`) | Kod tek başına anlamsız. Hook zaten o anda metin basıyor; içeriği anlamlı yapmak ek maliyet getirmiyor |
| `SessionStart` kaynağı `compact` | 4 satırlık sert sınır bloğu, bağlamın **sonunda** | Bağlam sıkıştırıldığında kural metni kaybolmuş olabilir. Sona konur çünkü dikkat seyrelmesinde en son gelen içerik en çok ağırlık alır |

Sert sınır bloğu `startup`'ta basılmaz — orada `AGENTS.md` zaten yükleniyor ve tekrar olurdu.

Blok metni validator'da sabittir. `AGENTS.md` değişince eskiyebileceği için `reinjection.sh` bloktaki her satırın hâlâ bir kurala karşılık geldiğini denetler; kural silinirse test kırılır.

## Kalıcı belgeler ve ekip çalışması

- ADR, runbook ve doküman etkisi şablonları `templates/documentation/` altındadır.
- Issue, PR, CODEOWNERS, disabled ruleset ve CI örnekleri `templates/github/` altındadır.
- Dosya, migration, port, test DB'si ve paylaşılan ortam sahipliği her aktif işin `work.json` kaydında tutulur.
- PR açıklaması issue/work-id, spec/plan, exact doğrulama, atlanan kontrol, risk/kurtarma ve belge etkisini birlikte taşır.

## Güncelleme ve kaldırma

- `update`, kurulu manifest hash'i, mevcut dosya hash'i ve yeni manifest hash'ini karşılaştırır. Eski temel byte'ları yoksa değiştirilmiş dosyayı otomatik birleştirmez; current/new diff önerir.
- `remove-kit`, yalnız manifestte yönetilen ve hash'i hâlâ eşleşen exact dosyaları aday yapar. Project-owned, work-generated, user-local ve değiştirilmiş içerik korunur.
- Her iki işlemde de önizleme, kurtarma/yedek planı ve açık onay zorunludur. `VERSION` ile manifest doğrulama tamamlanmadan ilerletilmez.

## Kit bakımı

Bu kurallar `AGENTS.md` §10'dan buraya taşındı. Ajanın çalışma anında değil, kiti bakan insanın karar anında geçerlidirler; her oturumda yüklenmelerinin karşılığı yok.

- Kuralı tekrarlanan hata, inceleme geri bildirimi veya kanıtlanmış risk sonrası ekle; eskisini kaldır.
- Projeye özgü ayrıntıyı `.agents/project.md` veya en yakın kapsamlı talimat dosyasına koy.
- Ayrıntılı prosedürü playbook/runbook'a, mekanik zorunluluğu test/linter/hook/CI'a taşı.
- Ana dosyayı kısa, somut, test edilebilir ve çelişkisiz tut.

Kural kararlarının tam kaydı ve çıkarılan kuralların orijinal metni: [`rule-inventory.md`](rule-inventory.md).

## Kural etkisini ölçme

`.agents/tests/` kitin **yapısını** doğrular: bedava, deterministik, CI'da koşar.

`.agents/evals/` kuralların **davranışa etkisini** ölçer: gerçek ajan koşuları, ücretli, manuel kadans. Varsayılanı dry-run'dır ve `--budget-usd` olmadan hiçbir ücretli koşu başlatmaz. Ayrıntı ve ölçülmüş değerler için [`.agents/evals/README.md`](evals/README.md).

```sh
sh .agents/evals/run.sh                                    # matris + tahmin, bedava
sh .agents/evals/run.sh --probe --execute --budget-usd 1   # talimat yükünü ölç
sh .agents/evals/run.sh --execute --budget-usd 3   --arms A0,A1 --tasks 10-injection --repeats 5            # uyum ölç
```

**Uyum sondaları** tek bir kuralı sınayan kısa görevlerdir: gömülü talimatı emir sayma (§6), commit için yetki iste (§7), çalıştırmadığın şeyi başarılı raporlama (§2). `E1` kolu aynı kuralları İngilizce verir; `evals-lang-parity.sh` çevirinin `AGENTS.md` ile ayrışmasını engeller.

Koşu **kademelidir** ve karar eşiği (`A0` ile `A1` arası fark ≥ 3/5) veriye bakılmadan sabitlenir; ayırt etmeyen sondada dil kolu koşturulmaz. Kuralsız kolun daha iyi çıkması da aynı görünürlükte raporlanır.

## Doğrulama ve dağıtım

Aşağıdaki komutlar **kitin kendi deposunda** çalışır. Kiti plugin olarak kurduysan doğrulayıcı ve test paketi projene kopyalanmaz; ikisi de plugin paketinde yaşar ve `kit-doctor` skill'i girişi kendisi çözer.

Unix/POSIX:

```sh
sh .agents/tests/run.sh
sh .agents/validators/sh/agent-kit.sh doctor --root "$PWD" --format text
sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check
```

Windows PowerShell:

```powershell
.agents\tests\run.ps1
.agents\validators\ps\agent-kit.ps1 doctor -Root $PWD.Path -Format text
.agents\validators\ps\agent-kit.ps1 manifest -Root $PWD.Path -Format text
```

Dağıtım ZIP'i yalnız kaynak ağaçtaki test ve manifest doğrulaması geçtikten sonra staging kopyasında üretilir:

```sh
sh .agents/tests/package-release.sh "$PWD" "$(dirname "$PWD")/agents-kit.zip"
unzip -t "$(dirname "$PWD")/agents-kit.zip"
```

Paketleyici active/archive/local/runtime içeriğini yapısal README'ler dışında, test sonuçlarını `.gitignore` dışında ZIP'e almaz. Çıkarılan kopyada layout, talimat zinciri, kabul fixture sözleşmesi ve manifest yeniden doğrulanır.
