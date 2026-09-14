---
name: resume-work
description: Use when continuing a durable project change in a new session, after compaction, or when the correct active work context is uncertain.
---

# İşi Sürdürme

## Genel bakış

Sohbet belleğine güvenmek yerine doğrulanmış work kaydı ve gerçek depo durumundan devam et.

## Çalışma sözleşmesi

1. İş kimliğini açık work-id → doğrulanmış branch/worktree → issue/PR bağlantısı → tek aktif iş sırasıyla çöz.
2. Birden fazla aday kalırsa en yeni dosyayı seçme; adayları ve ayırıcı kanıtı gösterip kullanıcıya sor.
3. Önce `work.json` ve `status.md`, sonra yalnız `status.md` içindeki mevcut aşamanın gerektirdiği spec, plan, test-plan, karar veya evidence dosyalarını oku.
4. Kayıtlı branch, worktree ve HEAD değerlerini gerçek Git durumu, `git status` ve ilgili diff ile karşılaştır. Gerçek durum eski checkpoint'ten önceliklidir.
5. Son doğrulanmış işlem, açık engel, sahiplik ve sıradaki en küçük güvenli adımı özetle.
6. İlk mutasyondan önce profil, artifact ve sahiplik kapılarını çalıştır; hook yoksa düşürülmüş korumayı bildir.
7. Arşivi, bütün aktif işleri veya bütün playbook'ları toplu okuma.
8. Çözülen work-id değerini `.agents/runtime/current-work` dosyasına yaz; hook hangi işte olunduğunu ancak buradan görür.

## Hızlı başvuru

| Gözlem | Sonuç |
| --- | --- |
| Açık work-id geçerli | O işi kullan |
| Tek branch eşleşmesi | Eşleşmeyi doğrula |
| Tek aktif iş | Onu kullan |
| Birden fazla aday | Sor; yazma yapma |
| Checkpoint ve Git farklı | Git'i esas al, farkı kaydet |

## Sık hatalar

- Dosya zamanını aktif iş seçme ölçütü yapmak.
- Bütün arşivi bağlama yüklemek.
- Eski checkpoint'i mevcut diff'ten daha güvenilir saymak.
- Belirsiz işte “küçük değişiklik” gerekçesiyle yazmaya başlamak.
