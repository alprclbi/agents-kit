# Uçtan Uca Örnek İş

Bu sayfa küçük bir işi baştan sona izler ve her adımda diske ne bıraktığını
gösterir. Örnek proje bir web API'si, profil `solo`. İş: giriş uç noktasına
deneme sınırı eklemek.

Dosyalardaki değerler örnektir. Gerçek işte kimlik, tarih, branch ve komutlar
senin projenden gelir; ajan bunları uydurmaz, doğrular.

## Akış

```text
start-work ──► checkpoint-work ──► resume-work ──► close-work ──► archive-work
```

`work.json` içindeki `status` alanı yol boyunca `draft` → `in_progress` →
`done` → `archived` ilerler. Engel çıkarsa `blocked`, incelemeye girerse
`review`, bilinçli bırakılırsa `cancelled` olur.

| Adım | Ne yapar | Diske ne yazar |
| --- | --- | --- |
| `start-work` | İşi açar, kimliği ve sahipliği kaydeder | `work.json`, `status.md`, gerekirse `plan.md`, `.agents/runtime/current-work` |
| `checkpoint-work` | Anlamlı bir aşamada durumu kaydeder | `status.md` |
| `resume-work` | Yeni oturumda kaldığın yeri bulur | `.agents/runtime/current-work` |
| `close-work` | Kabul ölçütlerini kanıtla kapatır | `outcome.md`, `work.json` durumu; işaretçiyi siler |
| `archive-work` | Kapanan işi arşive taşır | `.agents/changes/archive/<yıl>/<iş>/` |

## 1. İşi başlat

```text
/agents-kit:start-work giriş uç noktasına deneme sınırı ekle
```

Ajan önce salt okunur keşif yapar: repo kökü, branch, açık işler. Kimliği
kullanıcı değeri, issue, branch adı ve son olarak `YYYYMMDD-kisa-slug`
sırasıyla çözer. Burada branch `feat/giris-hiz-siniri`, issue yok; kimlik
tarih ve slug'dan gelir.

Sonuç:

```text
.agents/
├── changes/active/20261013-giris-hiz-siniri/
│   ├── work.json
│   ├── status.md
│   └── plan.md
└── runtime/current-work          ← "20261013-giris-hiz-siniri" (git dışı)
```

Küçük bir iş olduğu için spec yok; plan kabul ölçütlerini ve görev listesini
taşır. Ajan yalnız işin gerektirdiği dosyaları açar, boş şablon bırakmaz.

`work.json`:

```json
{
  "$schema": "../../../schemas/work.schema.json",
  "schemaVersion": "2.0.0",
  "id": "20261013-giris-hiz-siniri",
  "title": "Giriş uç noktasına deneme sınırı",
  "status": "in_progress",
  "profile": "solo",
  "profileReason": "Proje profili solo; iş üretim verisine veya paylaşılan kaynağa dokunmuyor.",
  "backend": {
    "type": "native",
    "source": "fallback",
    "root": ".agents/changes/active/20261013-giris-hiz-siniri"
  },
  "artifacts": {
    "spec": null,
    "plan": ".agents/changes/active/20261013-giris-hiz-siniri/plan.md",
    "tasks": null,
    "status": ".agents/changes/active/20261013-giris-hiz-siniri/status.md",
    "outcome": ".agents/changes/active/20261013-giris-hiz-siniri/outcome.md",
    "decisions": null,
    "research": null,
    "testPlan": null,
    "evidence": null
  },
  "ownership": {
    "paths": ["src/auth/**", "tests/auth/**"],
    "resources": [],
    "ports": [],
    "migrations": []
  },
  "links": {
    "issue": null,
    "pullRequest": null,
    "externalSpec": null
  },
  "git": {
    "branch": "feat/giris-hiz-siniri",
    "worktree": null,
    "head": "3f2c9a1"
  },
  "documentationImpact": "possible",
  "createdAt": "2026-10-13T09:12:00Z",
  "updatedAt": "2026-10-13T09:12:00Z"
}
```

Dikkat edilecekler:

- `ownership.paths` hook'un sahiplik çakışmasını (`AKE202`) ölçtüğü alandır.
  Aynı yolu başka bir aktif iş sahiplenirse `team` profilinde yazma reddedilir.
- `tasks` boş: native backend'de görev listesi `plan.md` içindeki checkbox'lardır.
- `documentationImpact: possible`: kapanışta çözülmesi gerekir; belirsiz
  bırakılarak iş kapatılamaz.

Ajan bu noktada branch açmaz, commit atmaz. Bunlar için ayrıca onay ister.

## 2. Çalış ve ara kayıt al

Ajan planı uygular. İlk görev bitince ve testler koştuktan sonra:

```text
/agents-kit:checkpoint-work
```

Her araç çağrısında değil, anlamlı bir aşamada çağrılır: plan onayı, bağımsız
bir görevin bitişi, yeni bir karar veya engel, oturum kapanışı.

`status.md`:

```markdown
# Giriş uç noktasına deneme sınırı — Durum

## Amaç

Aynı IP'den dakikada 5'ten fazla başarısız girişi 429 ile reddetmek.

## Mevcut aşama

Uygulama. Plan görevleri 1 ve 2 tamam, 3 kaldı.

## Son tamamlanan işlem

`src/auth/rate_limit.py` eklendi, giriş uç noktasına bağlandı.

## Son doğrulanmış depo durumu

Branch `feat/giris-hiz-siniri`, HEAD `3f2c9a1`, commit edilmemiş 3 dosya:
`src/auth/rate_limit.py`, `src/auth/routes.py`, `tests/auth/test_rate_limit.py`.

## Doğrulamalar

- `pytest tests/auth -q` → 14 geçti.
- `ruff check src/auth` → temiz.
- Tam test paketi çalıştırılmadı.

## Engeller ve riskler

Sayaç bellek içinde; birden fazla süreçte çalışan dağıtımda sınır süreç başına
uygulanır. Karar bekliyor.

## Sahiplik

`src/auth/**`, `tests/auth/**`.

## Sıradaki en küçük güvenli adım

Görev 3: README'ye yapılandırma anahtarını ekle, sonra tam test paketini koş.
```

Checkpoint komut dökümü veya sohbet özeti değildir. Çalıştırılmamış kontrol
"geçti" yazılmaz; ayrı satırda belirtilir.

## 3. Ertesi gün devam et

Yeni oturum açıldığında `SessionStart` hook'u aktif işi bulur ve bağlama kısa
bir özet ekler:

```text
Özet:
- Aşama: Uygulama. Plan görevleri 1 ve 2 tamam, 3 kaldı.
- Son checkpoint: 2026-10-13T09:12:00Z
- Sıradaki adım: Görev 3: README'ye yapılandırma anahtarını ekle, sonra tam test paketini koş.
- Açık kabul ölçütü: spec kayıtlı değil
```

Spec'li bir işte son satır spec'teki işaretlenmemiş kabul kriterlerini (en çok
beş) sayar ve listeler.

Ajana şunu demen yeter:

```text
/agents-kit:resume-work
```

Ajan önce `work.json` ve `status.md` okur, sonra kayıtlı branch ve HEAD'i
gerçek `git status` ile karşılaştırır. İkisi farklıysa gerçek depo durumu
kazanır ve fark raporlanır. Arşivi veya bütün planları toplu okumaz.

Tipik özet:

```text
İş: 20261013-giris-hiz-siniri (in_progress)
Son adım: rate_limit.py eklendi, auth testleri geçti
Açık: dağıtım başına sayaç kararı
Sıradaki: README'ye yapılandırma anahtarı, sonra tam test paketi
```

## 4. Kapat

Son görev ve tam test paketi geçtiğinde:

```text
/agents-kit:close-work
```

Ajan her kabul ölçütünü kanıt yoluyla `karşılandı`, `karşılanmadı` veya
`uygulanamaz` olarak işaretler, kontrolleri yeniden koşar ve
`documentationImpact` değerini çözer. Sonra `outcome.md` yazar:

```markdown
# Giriş uç noktasına deneme sınırı — Sonuç

## Gerçekleşen kapsam

Başarısız giriş sınırı (IP başına dakikada 5) ve 429 cevabı.

## Karşılanan kabul kriterleri

- 6. başarısız deneme 429 döner → karşılandı, `tests/auth/test_rate_limit.py::test_altinci_deneme`.
- Başarılı giriş sayacı sıfırlar → karşılandı, `test_basari_sifirlar`.

## Doğrulamalar ve kanıt yolları

- `pytest -q` → 212 geçti.
- `ruff check .` → temiz.

## Kalıcı dokümantasyon güncellemeleri

`README.md` içine `AUTH_RATE_LIMIT` anahtarı eklendi.

## Uyumluluk, migration ve operasyon etkisi

Yok. Varsayılan değer mevcut davranışı bozmaz.

## Kalan riskler

Sayaç süreç başına. Çok süreçli dağıtımda gerçek sınır süreç sayısıyla çarpılır.

## Takip işleri

Sayacı paylaşılan depoya taşı (ayrı iş).
```

`work.json` içinde `status` `done`, `documentationImpact` `required` olur ve
`.agents/runtime/current-work` silinir; bayat işaretçi sonraki oturumu yanıltır.

Kapanış commit, PR veya issue kapatma yetkisi değildir. Onları sen istersin.

## 5. Arşivle

```text
/agents-kit:archive-work
```

Ajan önce `status` değerinin `done` veya `cancelled` olduğunu ve
`outcome.md` bulunduğunu doğrular. Taşınacak, korunacak ve dışlanacak
dosyaları önizler, önce kopyalar, hedefi doğrular, sonra kaynağı kaldırır:

```text
.agents/changes/
├── active/                        ← iş artık burada değil
└── archive/2026/20261013-giris-hiz-siniri/
    ├── work.json                  ← status: "archived"
    ├── status.md
    ├── plan.md
    └── outcome.md
```

Hangi dosyaların saklandığı profile ve yapılandırmaya bağlıdır; seçim
gerekçesiyle `outcome.md` içine yazılır.

## Ne nerede durur

| Dosya | Git'te mi | Kim yazar |
| --- | --- | --- |
| `.agents/changes/active/<iş>/` | Evet, takımla paylaşılır | İş komutları |
| `.agents/changes/archive/<yıl>/<iş>/` | Evet | `archive-work` |
| `.agents/runtime/current-work` | Hayır | `start-work`, `resume-work`; kapanışta silinir |

İş kayıtları senindir: `update` ve `remove-kit` onlara dokunmaz.
