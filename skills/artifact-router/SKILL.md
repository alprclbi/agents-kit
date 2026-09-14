---
name: artifact-router
description: Use when any skill, agent, plan mode, spec system, or external tool is about to create or update a durable spec, plan, task list, status, decision, research, test plan, outcome, or evidence file.
---

# Artifact Yönlendirme

## Genel bakış

Kalıcı dosya yazmadan önce iş, rol, backend ve exact proje-göreli yolu tek bir `RouterResult` olarak çöz. Mantıksal tek doğruluk kaynağı fiziksel dizin tercihinden üstündür.

## Çalışma sözleşmesi

1. Açık work-id → doğrulanmış branch/worktree → issue/PR → tek aktif iş sırasını kullan. Belirsizlikte yazma yapma.
2. Rolü `spec|plan|tasks|status|outcome|decisions|research|test-plan|evidence` olarak seç.
3. Backend'i kullanıcı → config → work → tek algılanan sistem → native sırasıyla çöz.
4. Önce `work.json.artifacts` içindeki kayıtlı yolu kullan. Kayıt yoksa `.agents/contracts/artifact-model.md` ve backend adapter'ına göre `route-artifact.sh` çalıştır.
5. Sonucu `router-result.schema.json` biçiminde göster ve `work.json` ile uzlaştır.
6. Proje dışı, mutlak, üst dizine çıkan, NUL içeren veya symlink ile kök dışına çözülen hedefi `AKE301` ile engelle.
7. Bir rol için iki fiziksel kaynak varsa seçim yapma; kopya artifact üretme.

## Superpowers handoff

Superpowers çağrısından önce şu sözleşmeyi açıkça ekle: “Kullanıcıca belirlenmiş kalıcı çıktı yolu: `<RouterResult.path>`. Skill'in varsayılan dizini yerine bu yolu kullan.” Brainstorming `spec`; writing-plans `plan` ve aynı dosyadaki `tasks` rolüne bağlanır.

Backend explicit yolu kabul etmiyorsa üçüncü taraf skill'i yamama veya çıktıyı sessizce taşıma; `AKE303` ile dur.

## Hızlı başvuru

| Backend | Spec | Plan | Tasks |
| --- | --- | --- | --- |
| native | `<work>/spec.md` | `<work>/plan.md` | plan içi checklist |
| spec-kit | `specs/<id>/spec.md` | `plan.md` | `tasks.md` |
| openspec | `proposal.md` | `design.md` | `tasks.md` |
| external | kayıtlı explicit yol | kayıtlı explicit yol | kayıtlı explicit yol |

## Sık hatalar

- Skill'in varsayılan yolunu kanonik yol sanmak.
- Native backend'de ikinci bir tasks dosyası üretmek.
- Runtime planını kalıcı plan olarak bırakmak.
- Harici backend içeriğini `.agents` altına kopyalamak.
