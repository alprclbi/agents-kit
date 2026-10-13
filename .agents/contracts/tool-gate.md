# Kapı Sözleşmesi

Kapının kapsadığı araç adlarının ve salt okunur kabuk kalıplarının tek doğruluk kaynağı. Matcher taşıyan her dosya bu listeyi eksiksiz içerir; `.agents/tests/static/tool-gate.sh` bunu her koşuda doğrular.

## Kapsanan araçlar

| Araç | Neden |
| --- | --- |
| Bash | Kabuk; komut salt okunur değilse yazar |
| PowerShell | Kabuk; Windows'ta Bash ile aynı yetkiye sahip |
| Write | Dosya yazar |
| Edit | Dosya yazar |
| MultiEdit | Dosya yazar |
| NotebookEdit | Dosya yazar |
| mcp__.* | Harici sistem; yetkisi bilinmez, kapsam dışı bırakılamaz. Salt okunur eylemler aşağıda |

## Salt okunur kabuk kalıpları

Kabuk araçlarında komut aşağıdaki kalıplardan birine uyuyorsa salt okunur sayılır ve kapı uygulanmaz. Liste dardır; tanınmayan her komut mutasyon sayılır.

Amaç kapıyı gevşetmek değil: engellenen kullanıcının durumu görüp çözebilmesi. Tanı komutları da kapanırsa kapı kendi kendini kilitler.

| Kalıp | Örnek |
| --- | --- |
| `git status` | `git status --short` |
| `git log` | `git log --oneline` |
| `git diff` | `git diff HEAD` |
| `git show` | `git show 6e03b01` |
| `git rev-parse` | `git rev-parse --show-toplevel` |
| `ls` | `ls -la` |
| `cat` | `cat AGENTS.md` |
| `head` | `head -20 x` |
| `tail` | `tail -5 x` |
| `wc` | `wc -l x` |
| `pwd` | `pwd` |
| `echo` | `echo test` |
| `grep` | `grep -rn TODO src` |
| `rg` | `rg -n TODO src` |
| `find` | `find . -name '*.md'` |
| `jq` | `jq .profile .agents/config.json` |

### Boru hatları

`|` ile bağlanan zincir yalnız **her parçası** yukarıdaki kalıplardan birine uyuyorsa salt okunurdur: `git log --oneline | head -5` geçer, `git log | xargs rm` ve `cat x | sh` mutasyondur. Boş parça (`ls |`) reddedilir.

### Kalıp içi yasaklar

Bazı salt okunur araçlar bayrakla yazabilir veya komut çalıştırabilir. Bu bayraklar tırnak ve ters bölü silindikten sonra aranır; `'-ex''ec'` yazımı kabukta `-exec` olarak çalıştığı için gizlenemez.

| Araç | Mutasyon sayılan bayrak | Neden |
| --- | --- | --- |
| `find` | `-exec`, `-execdir`, `-ok`, `-okdir`, `-delete`, `-fprint*`, `-fls` | Komut çalıştırır, siler veya dosyaya yazar |
| `rg` | `--pre`, `--pre-glob` | Her dosya için keyfi komut çalıştırır |
| `git` | `--output` | diff/log çıktısını dosyaya yazar |

## Her zaman mutasyon sayılan işaretler

Kalıp eşleşse bile şu işaretlerden biri varsa komut mutasyondur:

`>` `>>` `<` `||` `&` `&&` `;` `` ` `` `$(` `${` `(` satır sonu

Yönlendirme dosyaya yazar, zincirleme ikinci bir komut çalıştırır, satır sonu yeni bir komut başlatır, değişken genişletmesi komutu çalışma anında değiştirir ve parantez PowerShell'de alt ifade çalıştırır (`echo (Remove-Item x)` silmeyi çalıştırır). Hiçbiri kalıpla güvenli biçimde ayrıştırılamaz, bu yüzden hepsi fail-closed kabul edilir. Tek `|` bu listede değildir; yukarıdaki boru hattı kuralına tabidir.

## Salt okunur MCP araçları

MCP aracı matcher'dan çıkarılmaz; kapı her çağrıda çalışır ve yalnız adı `mcp__<sunucu>__<eylem>` biçimindeki aracın eylem fiiline bakar. Eylem aşağıdaki fiillerden biriyse araç salt okunur sayılır. Tanınmayan her fiil mutasyondur.

| Fiil | Eşleşen | Eşleşmeyen |
| --- | --- | --- |
| `get` | `get`, `get_me`, `getFile` | `getter`, `target_list` |
| `list` | `list`, `list_issues`, `listIssues` | `listen` |
| `read` | `read`, `read_file` | `ready` |
| `search` | `search`, `search_code` | `searchable` |

Fiil, eylemin başında durmalı ve ardından ya hiçbir şey, ya `_`, ya da büyük harf gelmeli. İçinde `_and_` veya `_or_` geçen bileşik eylem (`get_or_create_issue`) her zaman mutasyondur.

Sınıflandırma yalnız ada dayanır; sunucunun aracı gerçekten salt okunur uygulayıp uygulamadığını doğrulamaz. Okuma adı taşıyıp yazan bir araç kapıyı geçer. Bu kabul edilen risktir: alternatif, her okuma çağrısında uyarı veya `team` profilinde ret üretmekti.
