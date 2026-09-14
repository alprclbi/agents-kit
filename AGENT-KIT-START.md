# Agents Kit — Başlangıç

Bu projeye Agents Kit kurulu. Kit ajana kural verir, yaptığı işi diske kaydeder
ve kurallara uyup uymadığını denetler.

Ayrıntılı rehber: [README](https://github.com/alprclbi/agents-kit).

---

## İlk yapılacak

`.agents/project.md` dosyasını doldur. İçine **yalnız doğrulanmış** proje
gerçekleri yaz: projenin amacı, çalıştırma ve test komutları, mimari sınırlar.

Tahmin edilmiş komut yazma. Ajan oradaki her satırı gerçek kabul eder.

---

## Günlük kullanım

| Ne zaman | Komut |
| --- | --- |
| Yeni bir işe başlarken | `/agents-kit:start-work` |
| Başka oturumda kalınan işe dönerken | `/agents-kit:resume-work` |
| İş yarıdayken ara kayıt | `/agents-kit:checkpoint-work` |
| İş bittiğinde | `/agents-kit:close-work` |
| Bir şey ters gittiğinde | `/agents-kit:kit-doctor` |

`kit-doctor` hiçbir şeyi değiştirmez, sadece durumu söyler.

---

## İş kayıtları nerede

Her iş `.agents/changes/active/<iş-adı>/` altında durur. Oturum kapansa da kayıt
diskte kalır; ertesi gün `resume-work` ile kaldığın yerden devam edersin.

Kapanan işler `.agents/changes/archive/` altına taşınır.

---

## Güncelleme

**Araçlar** plugin'den gelir, tek komutla güncellenir ve bütün projelerini birden
kapsar:

```bash
claude plugin update agents-kit@agents-kit
```

**Kurallar** bu projenin içinde durur. Geride kalırsa oturum başında bir satır
uyarı görürsün; ajana `/agents-kit:update` dersin.

Güncelleme senin yazdıklarına dokunmaz: `.agents/project.md`, `.agents/local/`,
`.agents/changes/` ve `CLAUDE.md` içindeki kendi talimatların korunur.

---

## Windows notu

Hook'lar Git Bash kullanır; Git for Windows kuruluysa ek adım yok.

Git Bash yoksa ve kit **dosya olarak** kurulduysa tek adım gerekir:
`.agents/adapters/claude/hooks.powershell.json` içindeki `hooks` nesnesini
`.claude/settings.json` içine kopyala, `plansDirectory` satırını koru.

Plugin kurulumunda bu adım gerekmez.

---

## Hook'lar çalışıyor mu

Claude Code içinde `/hooks` aç; `SessionStart`, `PreToolUse` ve `Stop`
görünmeli. Codex'te de `/hooks` ile inceler, güven kararını sen verirsin.

Hook çalışmazsa kurallar yine geçerlidir — yalnız mekanik denetim düşer ve
`kit-doctor` bunu raporlar.

---

## Kit neyi yapmaz

Ağa çıkmaz. Global ayarlarını değiştirmez. Kendi başına commit, push, PR veya
issue oluşturmaz. Bunların hepsi ayrıca senin onayını gerektirir.

---

## Sistemin ayrıntısı

İş yaşam döngüsü, sahiplik kuralları, hook davranışı ve ekip şablonları:
[`.agents/README.md`](.agents/README.md). Yalnız gerektiğinde oku.
