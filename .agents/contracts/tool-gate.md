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
| mcp__.* | Harici sistem; yetkisi bilinmez, kapsam dışı bırakılamaz |

## Salt okunur kabuk kalıpları

Kabuk araçlarında komut aşağıdaki kalıplardan birine uyuyorsa salt okunur sayılır ve kapı uygulanmaz. Liste dardır; tanınmayan her komut mutasyon sayılır.

Amaç kapıyı gevşetmek değil: engellenen kullanıcının durumu görüp çözebilmesi. Tanı komutları da kapanırsa kapı kendi kendini kilitler.

| Kalıp | Örnek |
| --- | --- |
| `git status` | `git status --short` |
| `git log` | `git log --oneline` |
| `git diff` | `git diff HEAD` |
| `git show` | `git show 6e03b01` |
| `ls` | `ls -la` |
| `cat` | `cat AGENTS.md` |
| `head` | `head -20 x` |
| `tail` | `tail -5 x` |
| `wc` | `wc -l x` |
| `pwd` | `pwd` |
| `echo` | `echo test` |

## Her zaman mutasyon sayılan işaretler

Kalıp eşleşse bile şu işaretlerden biri varsa komut mutasyondur:

`>` `>>` `|` `&` `;` `` ` `` `$(` `${` `&&` `||` `<`

Yönlendirme dosyaya yazar, boru hattının sonu yazan bir komut olabilir, zincirleme ikinci bir komut çalıştırır ve değişken genişletmesi komutu çalışma anında değiştirir. Hiçbiri kalıpla güvenli biçimde ayrıştırılamaz, bu yüzden hepsi fail-closed kabul edilir.
