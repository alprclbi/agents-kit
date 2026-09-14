# Spec Kit Backend

Spec Kit kullanan işte feature kimliği doğrulanır ve kanonik `specs/<feature-id>/` yapısı korunur.

| Rol | Yol |
| --- | --- |
| spec | `specs/<feature-id>/spec.md` |
| plan | `specs/<feature-id>/plan.md` |
| tasks | `specs/<feature-id>/tasks.md` |

Feature kimliği belirsizse dur. İçeriği native `.agents/changes` altına kopyalama; `work.json` yalnız kanonik yolları kaydeder.
