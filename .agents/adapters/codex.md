# Codex Adaptörü

Kanonik kurallar kök `AGENTS.md`, sözleşmeler ve `.agents/skills/` altındadır. `.codex/hooks.json` yalnız bu kuralları mekanik olarak çağırır; yeni yetki üretmez.

## Etkinleştirme ve güven

- Codex proje katmanını yalnız güvenilen projelerde yükler. `/hooks` ile üç hook'u ve tam komutlarını inceleyip güven kararını kullanıcı verir.
- Hook'lar varsayılan olarak etkindir; kuruluş politikası veya `[features] hooks = false` bunları kapatabilir. `kit-doctor` bunu düşürülmüş koruma olarak raporlar.
- Unix ve Windows komutları önce Git kökünü dener. Git yoksa oturum `cwd`'sinden yukarı doğru birlikte bulunan `AGENTS.md` ve `.agents/config.json` işaretçilerini arar; validator bulunamazsa açık hata ile durur. Proje `.codex` katmanının istemci tarafından keşfi ve trust kararı yine Codex yapılandırma kurallarına bağlıdır.
- `PreToolUse` yerel araç yollarını kapsayan bir guardrail'dir. Hosted araçlar ve istemcinin hook yolundan geçirmediği özel araçlar için tam güvenlik sınırı sayılmaz.

## Tanılama

Codex'te `/hooks` ile kaynak, matcher, trust ve son durum incelenir. `kit-doctor` salt okunur depo tarafı kontrollerini tamamlar. Komutlar sohbet transcript'ini okumaz veya kalıcı log üretmez.

Kaynak: https://developers.openai.com/codex/hooks
