# Agents Kit Kabul Testleri

`run.sh` Unix/POSIX kontrollerini, `run.ps1` Windows PowerShell kontrollerini aynı `scenarios/cases.tsv` kataloğundan yürütür. Sonuçlar `.agents/tests/results/` altında yerel ve ZIP/commit dışı TSV dosyalarına yazılır.

Durumlar:

- `PASS`: beklenen normal davranış veya beklenen güvenlik kararı gözlendi.
- `SKIP`: canlı istemci, işletim sistemi veya trust koşulu mevcut değil; başarı sayılmaz.
- `FAIL`: gözlenen davranış sözleşmeyle uyuşmadı.
- `BLOCKED`: zorunlu kanıt test ortamınca üretilemedi; paketlemeyi engeller.

Beklenen bir engel gözlendiğinde satır `status=PASS`, `observed=BLOCK` olur. Runner secret, transcript veya tam hook girdisi kaydetmez.
