# İşbirliği ve Süreklilik Playbook

## Ne zaman oku

- Çok ajanlı, paralel branch/worktree veya paylaşılan kaynak kullanılan işte.
- Uzun süren görev, checkpoint, devir teslim veya mevcut progress/state/memory düzeni varsa.

## Ne zaman okuma

- Tek ajanlı, kısa ve tamamen yerel görevde ek koordinasyon gerekmiyorsa.

## Sahiplik ve kapsam

- Her ajan için görev, dosya kapsamı, beklenen çıktı ve doğrulama ölçütünü açıkça tanımla.
- Paralel işte aynı dosyada veya aynı mantıksal kararda çakışan düzenleme yapma.
- Mümkünse ayrı branch/worktree kullan; ana çalışma ağacındaki kullanıcı değişikliklerini koru.
- Alt ajan çıktısını ana ajan birleştirir, kanıtlarını kontrol eder ve çelişkileri çözer.

## Paylaşılan kaynaklar

- Ortak DB, sunucu, migration aralığı, çalışma alanı, port veya canlı ortam için sahipliği ve yalıtımı doğrula.
- Ortak durumu sıfırlayan ya da aynı fixture'ı değiştiren testleri paralel çalıştırma.
- Migration kimliği veya ortam rezervasyonu gerekiyorsa işe başlamadan yap.
- Bir ajan kaynak üzerinde çalışırken başka ajan aynı hedefi değiştirmemelidir.

## Oturum sürekliliği

- Depoda `PROGRESS.md`, current-task, state veya memory sistemi varsa başlangıçta aktif özeti oku.
- Mevcut kod, en yeni karar ve aktif durum eski arşivden önceliklidir.
- Anlamlı checkpoint ve teslimde aktif özeti güncelle.
- Aktif özeti kısa tut; geçmişi arşivle ve yalnız ilgili arşivi hedefli oku.
- Kalıcı notta tarih, kaynak, güven düzeyi ve çıkarımı ayrı tut.

## Devir teslim

- Tamamlanan iş, değişen dosyalar, doğrulama sonuçları, açık riskler ve sıradaki en küçük adımı kaydet.
- Başarısız veya çalıştırılmayan kontrolü gizleme.
- Başka ajanın doğrulamadığı çıktıyı tamamlanmış kabul etme.

## Harici iş kayıtları

- Kullanıcı bağlantılı issue, PR veya proje öğesini doğruluk kaynağı kabul et.
- Yetki olmadan iş öğesi oluşturma, kapatma, etiketleme, yeniden atama veya taşıma.
