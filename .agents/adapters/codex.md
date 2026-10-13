# Codex Adaptörü

Kanonik kurallar kök `AGENTS.md`, sözleşmeler ve `.agents/skills/` altındadır. `.codex/hooks.json` yalnız bu kuralları mekanik olarak çağırır; yeni yetki üretmez.

## Etkinleştirme ve güven

- Codex proje katmanını yalnız güvenilen projelerde yükler. `/hooks` ile üç hook'u ve tam komutlarını inceleyip güven kararını kullanıcı verir.
- Hook'lar varsayılan olarak etkindir; kuruluş politikası veya `[features] hooks = false` bunları kapatabilir. `kit-doctor` bunu düşürülmüş koruma olarak raporlar.
- Hook komutu yalnız doğrulayıcı betiği oturum `cwd`'sinden yukarı doğru arar ve `--discover-root` (Windows'ta `-DiscoverRoot`) ile çağırır. Kök çözümü doğrulayıcıdadır: önce Git kökü denenir, orada `.agents/config.json` yoksa `cwd`'den yukarı doğru birlikte bulunan `AGENTS.md` ve `.agents/config.json` işaretçileri aranır. Betik veya kök bulunamazsa komut açık hata ile durur (`AKE900`, çıkış 3). Proje `.codex` katmanının istemci tarafından keşfi ve trust kararı yine Codex yapılandırma kurallarına bağlıdır.
- `PreToolUse` yerel araç yollarını kapsayan bir guardrail'dir. Hosted araçlar ve istemcinin hook yolundan geçirmediği özel araçlar için tam güvenlik sınırı sayılmaz.

## Tanılama

Codex'te `/hooks` ile kaynak, matcher, trust ve son durum incelenir. `kit-doctor` salt okunur depo tarafı kontrollerini tamamlar. Komutlar sohbet transcript'ini okumaz veya kalıcı log üretmez.

Kaynak: https://developers.openai.com/codex/hooks
