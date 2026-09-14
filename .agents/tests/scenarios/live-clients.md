# Canlı İstemci Doğrulaması

Bu kontroller otomatik runner'da istemci binary'si, proje trust'ı veya interaktif gözlem yoksa `SKIP` olur; PASS uydurulmaz.

## Codex

Güvenilen test kopyasında, salt okunur istemlerle:

```bash
codex --ask-for-approval never "Aktif talimat kaynaklarını sırayla listele."
codex --cd . --ask-for-approval never "Geçerli oturum başlangıç kurallarını özetle."
```

`/hooks` görünümünde proje `.codex/hooks.json` kaynağını, matcher'ları ve trust durumunu doğrula. Hook trust yoksa `SKIP/DEGRADED` kaydet.

## Claude Code

İnteraktif oturumda `/context`, `/hooks` ve `/doctor` çalıştır. Debug kaydında `InstructionsLoaded` olayının `session_start` nedenini; `CLAUDE.md`, `AGENTS.md`, `.agents/config.json` ve `.agents/project.md` yüklenmesini doğrula. Binary/trust yoksa `SKIP/DEGRADED` kaydet.

Transcript, token, secret veya tam hook girdisini sonuç dosyasına kopyalama.
