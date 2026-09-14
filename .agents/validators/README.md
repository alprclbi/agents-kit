# Agents Kit Validator

Validator, ajan talimatlarını tamamlayan mekanik kontrol katmanıdır. Ağ kullanmaz, proje kökü dışına yazmaz, hook girdisini komut olarak değerlendirmez ve keyfi proje dosyası içeriğini oturum özetine eklemez.

## Giriş noktaları

- POSIX: `sh .agents/validators/sh/agent-kit.sh <command>`
- Windows PowerShell 5.1+: `.agents\validators\ps\agent-kit.ps1 <command>`

Komutlar: `doctor`, `session-context`, `pre-tool-use`, `stop-check`, `manifest`.

Exit kodları: `0` başarılı/işlenmiş sonuç, `2` politika veya doğrulama engeli, `3` ortam ya da kullanım hatası. Hook mutasyon reddi, istemcinin JSON'u okuyabilmesi için exit `0` ile `permissionDecision: deny` döndürür.
