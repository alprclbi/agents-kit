@AGENTS.md
@.agents/config.json
@.agents/project.md

## Claude Code adaptörü

- Plan Mode geçici çıktısını `.agents/runtime/claude-plans/` altında tut.
- Kalıcı spec, plan ve görev yolunu her zaman `artifact-router` ile çöz.
- `/context` ile başlangıç importlarını doğrula; hook koruması yoksa `kit-doctor` sonucunu bildir.
