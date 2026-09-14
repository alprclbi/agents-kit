# Agents Kit

[![Doğrulama](https://github.com/alprclbi/agents-kit/actions/workflows/validation.yml/badge.svg)](https://github.com/alprclbi/agents-kit/actions/workflows/validation.yml)
[![Sürüm](https://img.shields.io/github/v/tag/alprclbi/agents-kit?label=s%C3%BCr%C3%BCm&color=blue)](https://github.com/alprclbi/agents-kit/tags)
[![Lisans MIT](https://img.shields.io/badge/lisans-MIT-blue.svg)](LICENSE)

Kodlama ajanına kural veren ve yaptığı işi kayıt altına alan bir kit.
Claude Code ve Codex ile çalışır.

Dil: Türkçe.

---

## Neden?

Ajanla çalışırken üç şey sürekli kaybolur:

- **Oturum kapanınca bağlam gider.** Ertesi gün "nerede kalmıştık" diye baştan anlatırsın.
- **Kurallar her projede yeniden yazılır.** Aynı talimatları defalarca kopyalarsın.
- **Ajan ne yaptığını unutur.** Hangi dosyaya neden dokunduğu kayıtsız kalır.

Kit bu üçünü çözer: kuralları bir kez yazar, işi diske kaydeder, ajanın kurallara
uyup uymadığını denetler.

---

## Kurulum

İki adım. Klon yok, dizin değiştirme yok.

### Claude Code

Terminalde:

```bash
claude plugin marketplace add alprclbi/agents-kit
```

```bash
claude plugin install agents-kit@agents-kit
```

Claude Code'un içindeyken (terminal veya masaüstü uygulaması) aynı işi slash
komutuyla da yapabilirsin:

```text
/plugin marketplace add alprclbi/agents-kit
/plugin install agents-kit@agents-kit
```

> Masaüstü uygulamasında `/plugin` etkileşimli bir panel açar. Panel açılmıyorsa
> yukarıdaki `claude plugin ...` komutlarını terminalden çalıştır; sonuç aynıdır.

Kurulumdan sonra Claude Code'u yeniden başlat.

### Codex

```bash
codex plugin marketplace add alprclbi/agents-kit
```

```bash
codex plugin add agents-kit@agents-kit
```

Codex CLI içinde `/plugins` yazarak etkileşimli tarayıcıdan da kurabilirsin.

Hook'lar için `/hooks` komutunu aç, üç hook'u ve komutlarını incele, güven
kararını sen ver. Kit senin adına hiçbir ayarı değiştirmez.

### Kurulum kapsamı

Claude Code sorarsa **kullanıcı** kapsamını seç; araçlar bir kez kurulur, bütün
projelerinde geçerli olur.

Codex'te kapsam bayrağı yoktur.

---

## İlk kullanım

Kurulumdan sonra herhangi bir projeyi aç ve ajana şunu yaz:

```text
/agents-kit:init
```

Ajan en fazla iki soru sorar:

| Soru | Ne demek |
| --- | --- |
| Yalnız mı, ekiple mi? | Ekipte kurallar sıkı, tek başına uyarı düzeyinde |
| Mevcut `AGENTS.md` var | Kuralların korunsun mu, kit çekirdeği mi gelsin |

Dokunduğu her dosyayı önce yedekler. Varsa `CLAUDE.md` içindeki kendi
talimatlarına dokunmaz.

---

## Komutlar

Hepsi `/agents-kit:` ön ekiyle çağrılır. Ön ek istemcinin çakışma önlemi.

### Günlük kullanım

| Komut | Ne zaman |
| --- | --- |
| `start-work` | Yeni bir işe başlarken. Özellik, hata, refactor — fark etmez |
| `resume-work` | Başka oturumda kalınan işe dönerken. "Nerede kalmıştık" sorusunu kaldırır |
| `checkpoint-work` | İş yarıdayken ara kayıt. Uzun işlerde bağlam kaybını önler |
| `close-work` | İş bitti. Kabul ölçütlerini kanıtla kapatır |
| `archive-work` | Kapanan işi aktif listeden arşive taşır |

### Kurulum ve bakım

| Komut | Ne zaman |
| --- | --- |
| `init` | Kiti projeye kurar. Eski kurulum varsa göçü kendi yapar |
| `update` | Projedeki kuralları plugin sürümüne çeker |
| `kit-doctor` | Bir şey ters gidiyorsa. Hiçbir şeyi değiştirmez, sadece bakar |
| `remove-kit` | Kiti kaldırır. Senin yazdıklarına dokunmaz |

### Arka planda çalışan

| Komut | Ne yapar |
| --- | --- |
| `artifact-router` | Spec, plan ve görev dosyalarının nereye yazılacağını çözer. Genelde sen çağırmazsın |

---

## Güncelleme

İki ayrı şey güncellenir ve ikisi farklı çalışır.

### Araçlar — tek komut, bütün projeler

```bash
claude plugin update agents-kit@agents-kit
```

Codex'te:

```bash
codex plugin marketplace upgrade agents-kit
```

Kaç projede kullandığın fark etmez; hepsi aynı anda güncellenir. Hiçbir projeye
dokunmazsın. Sonra istemciyi yeniden başlat.

### Kurallar — proje proje

Kurallar projenin içinde durur, o yüzden proje başına güncellenir. Geride
kaldıysa oturum başında tek satır görürsün:

```text
Iskele: 1.0.0 (plugin 1.1.0)
```

Ajana şunu de:

```text
/agents-kit:update
```

Soru sormaz, beş satırda ne yaptığını söyler.

**Üç yere hiçbir koşulda dokunmaz:**

| Yer | İçinde ne var |
| --- | --- |
| `.agents/project.md` | Senin proje kuralların |
| `.agents/local/` | Kişisel tercihlerin |
| `.agents/changes/` | İş kayıtların |

`CLAUDE.md` içindeki kendi talimatların da korunur. Bir kit dosyasını elle
değiştirdiysen üzerine yazmadan önce yedeklenir.

---

## Kaldırma

```text
/agents-kit:remove-kit
```

Yalnız kitin kendi dosyalarını siler ve **silmeden önce onay ister**. İş
kayıtların, proje kuralların ve elle değiştirdiğin dosyalar kalır.

Plugin'i de kaldırmak istersen:

```bash
claude plugin uninstall agents-kit@agents-kit
```

Codex'te:

```bash
codex plugin remove agents-kit@agents-kit
```

---

## Nereye ne kurulur

| Ne | Nerede durur | Kim günceller |
| --- | --- | --- |
| Araçlar (komutlar, denetim) | Plugin — bütün projeler | Tek komut, hepsi birden |
| Kurallar (`AGENTS.md`, `.agents/`) | Projenin içinde | Sen onaylayınca |

Projene yazılanlar: `AGENTS.md`, `CLAUDE.md`, `AGENT-KIT-START.md`, `.agents/`,
`.claude/`, `.codex/`.

Kitin kendi deposuna ait olan ve **projene kurulmayanlar**: `README.md`,
`LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, `.github/`,
`.agents/tests/`, `.agents/evals/`.

---

## Bir şey ters giderse

Önce şunu çalıştır:

```text
/agents-kit:kit-doctor
```

Hiçbir şeyi değiştirmez, sadece durumu söyler.

| Belirti | Sebebi | Ne yapmalı |
| --- | --- | --- |
| Komutlar görünmüyor | İstemci yeniden başlatılmadı | Claude Code'u kapat aç |
| `Iskele: ... (plugin ...)` satırı | Kurallar geride kaldı | `/agents-kit:update` |
| `AKE203` uyarısı | Aktif iş kaydı yok | `/agents-kit:start-work` veya salt okunur çalış |
| Manifest hatası | Bir kit dosyası elle değişti | `/agents-kit:update` — değişikliğin yedeklenir |

---

## Gereksinimler

| Ortam | Gereken |
| --- | --- |
| Linux, macOS | `git`, `jq`, `sha256sum` |
| Windows | Git for Windows (Git Bash) |
| Windows, Git Bash yok | PowerShell 5.1+ — bkz. [AGENT-KIT-START.md](AGENT-KIT-START.md) |

---

## Ağ ve gizlilik

**Kitin kendi kodu ağa çıkmaz.** Komutlar ve denetimler hiçbir istek yapmaz,
hiçbir veri göndermez.

Plugin paketini indiren istemcidir — Claude Code veya Codex, kendi marketplace
mekanizmasıyla.

Kit kendi başına commit, push, PR veya issue oluşturmaz.

---

## Plugin kullanmadan kurmak

Ağa kapalı ortam veya CI için betikler duruyor:

```bash
git clone --depth 1 https://github.com/alprclbi/agents-kit /tmp/agents-kit
cd /senin/projen
sh /tmp/agents-kit/install.sh
```

Windows'ta `install.ps1`.

---

## Daha fazlası

| Konu | Dosya |
| --- | --- |
| Sürüm geçmişi | [CHANGELOG.md](CHANGELOG.md) |
| Katkı rehberi | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Güvenlik bildirimi | [SECURITY.md](SECURITY.md) |
| Kurulum ayrıntısı ve Windows notları | [AGENT-KIT-START.md](AGENT-KIT-START.md) |

Lisans: MIT — bkz. [LICENSE](LICENSE).
