# OpenSpec Backend

OpenSpec'in sabit change yapısını fiziksel olarak taşımadan mantıksal artifact rollerine eşle.

| Rol | Yol |
| --- | --- |
| spec | `openspec/changes/<change-id>/proposal.md` |
| plan | `openspec/changes/<change-id>/design.md` |
| tasks | `openspec/changes/<change-id>/tasks.md` |

Change kimliği veya iki aktif OpenSpec change'i belirsizse yazma yapma. `work.json` bu yolları tek kanonik kaynak olarak kaydeder.
