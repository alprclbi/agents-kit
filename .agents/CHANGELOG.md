# Değişiklik Günlüğü

> Bu dosya **kapalı geliştirme dönemine** ait mühendislik günlüğüdür.
> Buradaki sürüm numaraları halka açık seriden bağımsızdır ve onunla
> karşılaştırılmaz. Halka açık kayıt kök `CHANGELOG.md` dosyasındadır.

## 1.0.0 - 2026-09-08 — ilk halka açık sürüm

Kit MIT lisansıyla yayınlandı. Sürüm numarası **3.3.2'den 1.0.0'a sıfırlandı**: 3.x serisi kapalı geliştirme dönemiydi, 1.0.0 ilk halka açık sözleşmedir. Önceki kayıtlar aşağıda tarihsel olarak duruyor.

### Eklendi

- `LICENSE` (MIT) ve `README.md`.
- Kök `.gitignore`: iş kayıtları, arşiv, kişisel tercihler, çalışma zamanı ve ölçüm çıktıları repo dışında. Kiti indiren kişi sıfır bir kit alır.

### Tehlikeli komut denetimi kaldırıldı

`AKD701`-`AKD705` kodları, iki doğrulayıcıdaki karşılıkları, `dangerous-commands` testi ve belgelerdeki tablolar kitten çıkarıldı. `PreToolUse` artık yalnız iş kaydı kapılarını (`AKE201`-`AKE203`) denetler; `ask` kararı hiç üretilmiyor.

Gerekçe: beş kural da her oturumda onay istiyordu ve komutun **anılmasıyla çalıştırılmasını** ayırt edemiyordu (`grep -r 'git add -A' .` de yakalanıyordu). Onay gürültüsü, koruduğu riskten fazla maliyet üretti.

Karşılığı açık: `git reset --hard`, force-push, `--no-verify`, toptan stage ve `rm -rf` artık kit tarafından durdurulmuyor. Yasaklar `AGENTS.md` §7'de metin olarak duruyor; mekanik zorlama yok. İstemcinin kendi izin akışı geçerlidir.

`reinjection` testi artık `AKE201` üzerinden doğruluyor.

### README'de ölçümler

Kuralların hem maliyeti hem faydası yayınlandı — fayda tarafında **fark bulunamadığı** açıkça yazıldı. Üç sondada da tavan etkisi görüldü; ayırt edici senaryo bulunamadı.

## 3.3.2 - 2026-09-08

### Paketleyici Windows'ta çalışır hale getirildi

Kit Windows'u destekliyor ama kendi dağıtım paketini Windows'ta üretemiyordu: Git Bash `zip` ile gelmiyor ve paketleyici koşulsuz ona bağlıydı.

- `zip` yoksa Python `zipfile` kullanılır. Açma ve bütünlük kontrolü de aynı arka uca bağlandı.
- **Denenip reddedilenler ve nedenleri kayıt altında:**
  - PowerShell `Compress-Archive` — giriş yollarını ters bölüyle yazıyor; üretilen ZIP Linux/macOS'ta bozuk açılıyor.
  - Windows `bsdtar` — UTF-8 dosya adlarını kaybediyor; `zip:encoding=UTF-8` seçeneğini desteklemiyor.
- **Asıl bulgu:** Git Bash `unzip` Windows'ta UTF-8 bayrağını yok sayıyor. Doğru üretilmiş bir ZIP'i bozuk açıyor ve doğrulama adımını haksız yere düşürüyordu. Açma da Python'a bağlanınca sorun kalktı.
- Hepsini kitin kendi `18-cross-platform-utf8-paths` fixture'ı yakaladı.
- Python yorumlayıcısı **çalıştırılarak** seçilir: Windows'ta `python` Microsoft Store kısayoluna düşebiliyor ve `command -v` onu gerçek yorumlayıcı sanıyordu.

## 3.3.1 - 2026-09-08

### Kişisel iletişim tercihi artık her oturumda bildiriliyor

Kullanıcı yanıtların kısa ve yalın olmasını istedi. Kural dosyasına satır eklemek yerine mekanik yol seçildi.

- Tercih metni `.agents/local/preferences.md` içindeki `ak:style` bloğunda durur. Git'e ve ZIP'e girmez.
- Hook bu bloğu **her** oturum başlangıcında basar (`startup`, `resume`, `clear`, `compact`). Sert sınırlardan farkı: üslup her yanıta uygulandığı için yalnız sıkıştırma sonrası değil, hep bildirilir.
- Metin validator'a **gömülmedi**, kullanıcının dosyasından okunur. Gömülü olsaydı `update-kit` kullanıcının tercihini ezerdi.
- `sh` ve `ps` çıktıları bayt düzeyinde aynı (416 bayt).
- `style-preferences.sh` sözleşmeyi kilitler: dört kaynakta da basılıyor mu, metin gömülü mü, gerçekten dosyadan mı okunuyor, dosya yokken sessiz mi, tercih dosyası git dışında mı.

**`AGENTS.md` değiştirilmedi.** Orası taşınabilir çekirdek; kişisel üslup tercihi oraya ait değil. Ayrıca bu oturumun ölçümü, kural dosyasına satır eklemenin davranışı değiştirmediğini gösterdi.

## 3.3.0 - 2026-09-08

### Uyum sondaları: kuralların faydası ilk kez ölçüldü

Kit bugüne kadar yalnız kuralların **maliyetini** ölçüyordu. Artık davranışa etkisini de ölçebiliyor.

- Üç uyum sondası eklendi: `10-injection` (§6 gömülü talimat), `11-authorization` (§7 commit yetkisi), `12-fabrication` (§2 iddiayı çıktıya dayandır).
- **Ölçülen sonuç: fark yok.** `10-injection` kuralsız kolda 10/10, tam kurallı kolda 9/9 geçti. `12-fabrication` geçerli koşularda 2/2 ve 4/4. Önceden sabitlenen eşiği (≥3/5) hiçbir sonda geçmedi.
- Yorum: bu üç sondada, bu modelde, `AGENTS.md` gözlenebilir fark üretmedi. "Kurallar işe yaramıyor" demek değil; tavan etkisi altında ölçüldü ve tek modele ait.
- `11-authorization` ölçülemedi: 13 tur sürüyor, sınır 12.

### Dil kolu (`E1`) kuruldu, koşulmadı

- `variants/AGENTS.en.md`: 58 kural, 9 bölüm, saf ASCII. `evals-lang-parity.sh` çevirinin `AGENTS.md` ile ayrışmasını engelliyor.
- Kademe 2 koşulmadı çünkü ön koşulu sağlanmadı: kademe 1'de ayırt eden sonda çıkmadı.
- Maliyet tarafı ölçüm gerektirmedi: EN 8.873 bayt, TR 9.074 — %2 fark, oturum başına ~2.000 token. **Dil değiştirmek için ekonomik gerekçe yok.**

### Sandbox izin yüzeyi genişletildi (kullanıcı onayıyla)

- `sandbox-settings.json`: `Bash(sh fixtures/slug/test.sh)` ve `Bash(git:*)`. Yalnız `permissions` taşır; `hooks`/`mcpServers`/`model` yasak ve teste bağlı.
- Geniş `Bash(sh:*)` bilinçli olarak reddedildi: `sh -c` ile tam kabuk demektir.
- Öncesinde Bash tamamen kapalıydı; kural yüzeyinin yarısı ölçülemiyordu ve her koşu 3-12 turu reddedilen çağrılara harcıyordu. Beyaz listeyle 2'ye düştü.

### Kritik: ücretli koşu durdurulabilir hale getirildi

`run.sh` arka planda başlatıldığında istemcinin durdurma komutu sarmalayıcı kabuğu öldürüyor, zinciri öldürmüyordu. **İki koşu fark edilmeden devam etti, bütçe 2,63 USD aşıldı ve iki partinin verisi aynı dosyada karıştı.**

- **Kilit:** iki koşu aynı anda çalışamaz.
- **`STOP` bayrağı:** her koşudan önce denetlenir; bayrak varken koşu hiç başlamaz.
- **`stop.sh`:** durdurur ve durduğunu **süreç listesiyle doğrular**.
- **Önceki parti korunur:** yeni koşu `runs.jsonl`'i sessizce silmez, zaman damgalı ada taşır.
- `evals-stoppable.sh` bu dört korumanın yerinde olduğunu her testte doğrular.

### Oracle disiplini: iki yönlü doğrulama tek başına yetmiyor

İki oracle hatası ancak ücretli koşuda ortaya çıktı; ikisi de iki yönlü doğrulamayı geçmişti.

- `02-work-record` oracle'ı **istemden fazlasını istiyordu**: istem küçük harf Türkçe karakterleri sayıyordu, oracle büyük harfle sınıyordu. Ajan isteneni yapıp `fail` alıyordu. İstem düzeltildi. (Bu görev daha önce "kırık" diye kaydedilmişti — **yanlıştı**.)
- `12-fabrication` oracle'ı **olumsuzlamayı göremiyordu**: "başarıyla çalıştırılamadı" ve "did not run successfully" ihlal sayılıyordu. Serbest metin araması bırakıldı; ajandan yapısal karar isteniyor (`SONUC: GECTI/KALDI/CALISTIRILAMADI`).
- Sebep kural haline getirildi: doğrulama örneklerini oracle'ı yazan uydurur, yani kendi hayal gücünü test eder. Karşı önlem README'de.
- `evals-oracles.sh` üç oracle için 21 durumu ücretsiz koşar.

### Manifest ve paketleme

- `.agents/evals/results/*` artık manifest ve dağıtım ZIP'i dışında. Öncesinde her eval koşusu manifesti geçersiz kılıyor ve ölçüm verisi dağıtıma biniyordu.

### Diğer

- Maliyet varsayılanı **0,35 → 0,15**. Önceki değer tek bir uzun görevden geliyordu ve kısa görevlerde 3 kat yüksekti.
- `--arms`, `--tasks`, `--keep-sandbox` bayrakları; `tasks.tsv`'ye `max_turns` sütunu.
- `response_chars` / `response_turkish_chars` metrikleri — yanıt dili ölçülür, metin saklanmaz.
- Rapor artık kol × sonda geçme oranı, önceden sabitlenmiş karar eşiği ve **koşulsuz** güç beyanı basıyor; ters yön (kuralsız kolun daha iyi olması) aynı görünürlükte raporlanır.
- Windows: sandbox git deposunda `core.autocrlf false` — açıkken bir `checkout` fixture'ı bozup oracle'ı haksız yere `fail` yapıyordu.

## 3.2.0 - 2026-09-07

### Yasakların olumlu forma çevrilmesi

- `AGENTS.md`'deki 15 olumsuz kuraldan **6'sı olumlu forma çevrildi**. Dayanak: `arXiv:2604.20911` — "yap" tipi kurallar bağlam doldukça korunuyor, "yapma" tipi kurallar çürüyor.
- **Ölçülen maliyet: +58 token** (15.510 → 15.568). Dosya 8.942 → 9.074 bayt. Bu iş token kazandırmıyor, maliyeti artırıyor; gerekçesi ekonomik değil davranışsal ve faydası bu kitte ölçülmedi.
- Dokuz kural olumsuz bırakıldı: beşi zaten olumlu fiille başlıyor, dördünde yasağın kapsamı asıl değer (secret, özel kod, güvenlik kontrolü, boş commit/amend). Olumluya çevirmek onları daraltırdı.
- Karar kaydı ve önce/sonra tablosu `.agents/rule-inventory.md` içinde.

### PowerShell çıktı kodlaması düzeltildi

- **Hata:** Windows PowerShell 5.1 stdout'u konsol kod sayfasıyla yazıyordu; UTF-8 dışı kod sayfasında Türkçe karakterler bozuluyordu. Kitin bütün Windows hook çıktısı (oturum başlangıcı, sert sınır bloğu, tehlikeli komut uyarısı) ajana bozuk ulaşıyordu.
- **Düzeltme:** `agent-kit.ps1` çıktı kodlamasını açıkça UTF-8'e sabitliyor.
- **Doğrulama:** `sh` ve `ps` çıktıları satır sonu normalize edildikten sonra bayt düzeyinde aynı (515 bayt).
- `windows-portability.sh` regresyon koruması ekledi; satır silinirse test kırılıyor.
- Bu hata önceden vardı ve 3.1.0'daki yeniden enjeksiyonu Windows'ta işlevsiz bırakıyordu.

### Uygulanmayan öneri

- **Yola göre kapsamlama** değerlendirildi ve uygulanmadı: hedef bölüm budamadan sonra ~200 token'a düştü, path-scoped rule Claude'a özgü olduğu için taşınabilir çekirdek premisini kırıyor, ve oturum başında hangi yola dokunulacağı bilinmiyor. Gerekçe `rule-inventory.md` içinde.

## 3.1.0 - 2026-09-07

### Kural yeniden enjeksiyonu

Kuralı oturum başında bir kez söylemek yetmiyor. Hook çıktıları artık kodun değil kuralın kendisini taşıyor.

- **Riskli anda hedefli enjeksiyon.** `PreToolUse` reason'ı artık `AKD704` yerine `AKD704: force-push yayımlanmış geçmişi yeniden yazar; --force-with-lease kullan` basıyor. Tanılama nesnesi bu metni zaten taşıyordu, yalnız basılmıyordu. Ek hook çağrısı yok.
- **`compact` sonrası sert sınır bloğu.** Bağlam sıkıştırıldığında `SessionStart` 4 satırlık sınır bloğu basıyor: secret aktarımı, yetkisiz commit/push, yıkıcı işlem onayı, gömülü eylem isteği. Blok bağlamın **sonuna** konuyor — dikkat seyrelmesinde en son gelen içerik en çok ağırlık alır.
- `startup` kaynağında blok basılmaz; orada `AGENTS.md` zaten yükleniyor.
- Yeni statik test `reinjection.sh`. En önemli kontrolü **drift koruması**: blok metnindeki her satırın `AGENTS.md`'de hâlâ bir kurala karşılık geldiğini doğrular. Kural silinirse test kırılır ve blok güncellenmek zorunda kalır.
- POSIX sh ve PowerShell çıktıları bayt düzeyinde aynı doğrulandı. Ayırıcı ASCII'ye çevrildi: em dash PowerShell 5.1 çıktı kodlamasında bozuluyordu.

**Bilinçli olarak yapılmadı:** periyodik ("k turda bir") enjeksiyon yok. Claude Code'da tur sayacı tetikleyicisi yok, ve yasak çürümesi bu kitte ölçülmedi. Riskli an ve `compact` doğrulanmış iki fırsat; ötesi varsayım olurdu.

## 3.0.0 - 2026-09-06

### KIRICI DEĞİŞİKLİK

`AGENTS.md` 79 kuraldan 58 kurala indi. Kiti güncelleyen projeler çekirdekten 22 kural kaybeder; 7'si başka dosyaya taşındı, 15'i silindi.

**Ölçülen kazanç:** kural kitabının oturum başı bedeli **5.184 → 4.161 token (−%20)**. Dosya 11.063 → 8.942 bayt. Ölçüm `run.sh --probe` ile yapıldı; taban çizgi `A0` = 11.349 token.

**Politika:** sinyal yoğunluğu. Bir kural yalnız şunlardan birini karşılıyorsa kalır: `K-kit` (kite özgü, model bilemez), `K-counter` (modelin varsayılanına aykırı), `K-risk` (mekanikleştirilemez ve pahalı).

**Geri alma:** çıkan her kuralın orijinal metni `.agents/rule-inventory.md` içinde saklanıyor.

#### Taşınan kurallar (7)

- §4 → `.agents/playbooks/verification.md` — Basit kodu, açık veri akışını, tutarlı sorumlulukları ve sağlam mevcut soyutla…
- §4 → `.agents/playbooks/verification.md` — `null`, `0`, boş, bilinmeyen, eksik ve hata durumlarını açık alan kuralı olmad…
- §4 → `.agents/playbooks/verification.md` — Hataları bağlam ve kök nedenle ele al; sessizce yutma.
- §10 → `.agents/README.md` — Kuralı tekrarlanan hata, inceleme geri bildirimi veya kanıtlanmış risk sonrası…
- §10 → `.agents/README.md` — Projeye özgü ayrıntıyı `.agents/project.md` veya en yakın kapsamlı talimat dos…
- §10 → `.agents/README.md` — Ayrıntılı prosedürü playbook/runbook'a, mekanik zorunluluğu test/linter/hook/C…
- §10 → `.agents/README.md` — Ana dosyayı kısa, somut, test edilebilir ve çelişkisiz tut.

#### Silinen kurallar (15)

- §1 `D-low` — Komut, araç sürümü, mimari ve kalite eşiğinde doğrulanmış proje kaynağı generi…  
  *gerekçe: satır 9 korunuyor*
- §1 `D-mech` — Birden fazla aktif aday kalırsa otomatik seçim yapma; ilk mutasyondan önce kul…  
  *gerekçe: AKE201*
- §1 `D-mech` — İlk mutasyondan önce profil, gerekli artifact ve dosya/migration/port/paylaşıl…  
  *gerekçe: AKE202/203*
- §3 `D-low` — İlgili README, CONTRIBUTING, SECURITY, mimari, manifest, kilit dosyası, araç s…  
  *gerekçe: satır 63 korunuyor*
- §4 `D-playbook` — Gizli bağımlılık, yinelenen iş kuralı ve gereksiz dolaylılıktan kaçın.  
  *gerekçe: verification.md dahil 3 playbook*
- §4 `D-playbook` — Sınır değişmezlerini doğrula; kesin tür ve şema kullan; gerekçesiz türsüz kaçı…  
  *gerekçe: verification.md dahil 4 playbook*
- §4 `D-playbook` — Herkese açık API, serileştirme, yapılandırma, CLI ve event sözleşmesini koru; …  
  *gerekçe: verification.md dahil 3 playbook*
- §5 `D-playbook` — Değişen davranış için uygun test ekle veya güncelle; uygulanabildiğinde bugfix…  
  *gerekçe: verification.md*
- §5 `D-playbook` — Testleri özel uygulama yapısına değil gözlenebilir davranışa ve önemli hata yo…  
  *gerekçe: verification.md*
- §6 `D-low` — Salt okunur keşif ve geri alınabilir kapsam içi yerel düzenlemede ilerle.  
  *gerekçe: satır 128 korunuyor*
- §6 `D-mech` — Yıkıcı hedefi tam çözümle; geniş recursive silme, doğrulanmamış glob veya orta…  
  *gerekçe: AKD705*
- §7 `D-mech` — Yalnız amaçlanan yolları açıkça stage et; `git add .`, `git add -A` ve boş com…  
  *gerekçe: AKD701 kısmi; artık kural korunur*
- §7 `D-mech` — `git reset --hard` kullanma; açık yetki olmadan `--no-verify`, force-push, yay…  
  *gerekçe: AKD702/703/704 kısmi; artık kural korunur*
- §9 `D-low` — İstenen davranış ve kabul kriterlerini ilgisiz değişiklik olmadan karşıla.  
  *gerekçe: satır 49 korunuyor*
- §9 `D-low` — Gerekliyse belge, örnek, şema, üretilmiş çıktı ve release notunu eşitle.  
  *gerekçe: documentation-impact sözleşmesi + close-work skill*

#### Silinmesi düşünülüp KORUNAN kurallar (2)

Bu iki kural için silme gerekçesi `A0` kolunun kuralsız da uyduğu ölçümüydü. Kanıt n=3 ve tavan etkiliydi (18 koşunun 17'si geçti), yani görevler ayırt edici değildi. Ayrıca model davranışı sürüm güncellemeleriyle değişebilir; hiçbir ölçüm bunu önceden garanti edemez. Doğrulanmamış varsayımla silmek yerine korundular; bedelleri ölçüldü: **115 token**.

- §2 — Kapsam genişletme, varsayımsal özellik, ilgisiz temizlik, geniş yeniden yazım ve erken soyutlamadan kaçın.
- §5 — Testi geçirmek için testi silme, atlama, zayıflatma veya aşırı mock'lama yapma.

#### Diğer

- `§7` içindeki iki kısmen mekanikleşmiş satır tek artık kuralla değiştirildi: `AKD701`-`AKD704` toptan stage, `reset --hard`, `--no-verify` ve force-push'u yakalıyor ama *boş commit* ile *başkasının commit'ini amend etme* kurallarını yakalamıyordu; bu ikisi korundu.
- Oturum Başlangıç Kapısı 7 maddeden 5'e indi ve yeniden numaralandı.
- Yeni statik test `rule-inventory.sh`: envanter eksiksizliğini, import edilmediğini ve envanter ile `AGENTS.md`'nin birbirini tuttuğunu denetler.

## 2.1.0 - 2026-09-06

### Tehlikeli komut hook'ları

- `AGENTS.md` §6-7'deki bazı düz metin yasakları mekanik korumaya taşındı. Gerekçe: yasak tipi kurallar bağlam doldukça dikkat seyrelmesiyle çürüyor (arXiv:2604.20911), hook çürümez.
- Beş yeni policy kodu: `AKD701` toptan stage, `AKD702` `git reset --hard`, `AKD703` `--no-verify`, `AKD704` force-push, `AKD705` doğrulanmamış glob ile `rm -rf`.
- `pre-tool-use` artık `tool_input.command` okuyor; önceden yalnız araç adına bakıyordu.
- Sertlik profile bağlı: solo → `ask`, team/high-assurance → `deny`. Mevcut `AKE202` kalıbıyla aynı.
- `--force-with-lease` ve düz yollu `rm -rf build/` bilinçli olarak muaf; yanlış pozitif testi eklendi.
- POSIX sh ve PowerShell uygulamaları davranış paritesi taşıyor; ikisi de aynı vakalarla test ediliyor.
- Kit kendi deposunda hook'ları kurulu tutuyor. Kabul senaryosu 08 ve `provider-adapters` testi hook yokluğu yerine varlığını şart koşuyor.
- `adopt-kit` hook kurulumunu artık varsayılan olarak öneriyor; reddedilirse korumanın düşürüldüğünü bildiriyor.

### Kural etkisini ölçen eval harness

- `.agents/evals/`: `AGENTS.md` bloklarının davranışa ve maliyete etkisini gerçek ajan koşularıyla ölçer. Varsayılanı dry-run; `--execute` ve `--budget-usd` olmadan ücret doğurmaz.
- `AGENTS.md` içine blok işaretçileri eklendi (HTML yorumu, kural metni değişmedi). Varyantlar canlı dosyadan üretilir.
- Ölçülen talimat yükü: tam `AGENTS.md` 5184 token; §1 1518, §2-3 980, §8-10 887, §4-5 832, §6-7 821.
- Ölçülen bayt/token oranı Türkçe metinde 2,07. Bayt cinsinden `instructionBudgets` sınırları bu katsayıyla token'a çevrilmelidir.

## 2.0.2 - 2026-08-02

- PowerShell 5.1'de doğrudan `List[object]` array-subexpression dönüşümünün ürettiği `ArgumentException`, tanı koleksiyonlarının `ToArray()` ile yayınlanmasıyla giderildi.
- Bağlanmamış nullable Codex belge limitinde StrictMode altında oluşan `HasValue` hatası kaldırıldı; null kontrolü ve açık integer dönüşümü kullanıldı.
- `Cwd` açıkça verilmediğinde validator kökü varsayılan kabul edildi; açık proje dışı `Cwd` reddi korundu.
- Windows hook kabul yardımcısı konumsal dizi splatting yerine adlandırılmış hashtable splatting kullanacak biçimde düzeltildi.
- Linux kalite kapısına bilinen PowerShell 5.1 uyumsuz kalıplarını yakalayan tamamlayıcı taşınabilirlik linti eklendi.

## 2.0.1 - 2026-08-02

- Windows PowerShell 5.1 için bütün `.ps1`/`.psm1` kaynakları UTF-8 BOM sözleşmesine alındı.
- Windows-native `jq` CRLF çıktısının manifest hash'lerinde yanlış pozitif üretmesi düzeltildi.
- `kit-doctor` ve iki validator istemciye göre ayrıldı; Claude çalıştırmasında Codex limit/hook uyarıları kaldırıldı.
- Claude hook'larının Git gerektirmediği açıklandı; Codex hook komutlarına Git dışı kit-kökü fallback'i eklendi.
- Otomatik talimat yükleme, kısmi manifest ve isteğe bağlı tercih sınıflandırmaları kanıt düzeyine göre sıkılaştırıldı.
- Claude auto memory ile `.agents` kanonik takım kayıtları arasındaki sınır tanımlandı.
- İlk kurulum rehberine onaylı Claude hook merge ve `/hooks` doğrulama adımları eklendi.
- Unix kabul çalıştırıcısı eşzamanlı çalıştırmalarda sonuçları çalıştırmaya özel geçici dosyada toplayıp eksiksizlik kontrolünden sonra atomik yayımlayacak biçimde sertleştirildi.

## 2.0.0 - 2026-08-02

- Kalıcı iş yaşam döngüsü, checkpoint, kapanış ve adaptif arşiv düzeni eklendi.
- Codex ve Claude Code için aşamalı oturum başlangıcı ve ince adaptör modeli tanımlandı.
- Artifact router ile native, Spec Kit, OpenSpec ve harici backend eşlemesi eklendi.
- POSIX shell ve PowerShell validator/hook katmanı tasarlandı.
- Takım sahipliği, GitHub ve dokümantasyon şablonları eklendi.
- No-overwrite benimseme, üç yönlü güncelleme ve sahiplik duyarlı kaldırma akışları eklendi.
- Profil bazlı mutasyon ve sahiplik kapıları ile resmi Codex/Claude hook çıktı sözleşmeleri uygulandı.
- Opt-in issue, PR, CODEOWNERS, disabled ruleset, CI, ADR, runbook ve dokümantasyon etkisi şablonları eklendi.
- Aynı 25 senaryoyu işleyen Unix ve PowerShell kabul koşucuları; UTF-8/bütçe sınır fixture'ları eklendi.
- Sahiplik/hash manifesti, staging doğrulaması, çıkarılmış ZIP yeniden testi ve SHA-256 kontrollü paketleme eklendi.
