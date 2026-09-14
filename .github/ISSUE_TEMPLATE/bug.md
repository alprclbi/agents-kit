---
name: Hata
about: Tekrarlanabilir bir davranış sapmasını bildir
title: "[Bug] "
labels: ""
assignees: ""
---

## Gözlenen davranış

Hata iletisini **secret ve kişisel veriden arındırarak** yaz:

## Beklenen davranış

## Tekrar adımları

1.

## Ortam

| | |
| --- | --- |
| Kit sürümü (`.agents/VERSION`) | |
| İşletim sistemi | |
| Kabuk (sh / Git Bash / PowerShell) | |
| İstemci (Claude Code / Codex / diğer) | |

## Doğrulama çıktısı

Şu iki komutu çalıştır ve **çıktıyı olduğu gibi** yapıştır:

```sh
sh .agents/tests/run.sh
sh .agents/validators/sh/agent-kit.sh doctor --root "$PWD" --format text
```

```text

```

## Etki

Hangi iş akışı bozuluyor; her zaman mı, aralıklı mı?

---

Tekrar üretme adımı olmayan hata raporu kapatılır.
