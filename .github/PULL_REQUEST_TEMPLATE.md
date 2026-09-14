## Ne değişti ve neden

## Doğrulama

Çalıştırdığın **exact** komutları ve gerçek çıktılarını yaz. "Testler geçti" yetmez.

```text
sh .agents/tests/run.sh                                          → 
sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check → 
sh .agents/tests/static/line-endings.sh "$PWD"                   → 
```

Windows'ta doğrulayıcı değiştiysen:

```text
.agents\tests\run.ps1 → 
```

## Kontrol listesi

- [ ] Davranış değişikliğinin testi var
- [ ] Yeni kontrolü **kasten bozdum**, kırıldığını gördüm
- [ ] Oracle yazdıysam iki yönlü doğruladım ve **kendi ilk sürümümü kıran** örneği ekledim
- [ ] `sh` ve PowerShell doğrulayıcıları aynı davranıyor
- [ ] Satır sonları LF
- [ ] Dosya değiştirdiysem manifesti yeniden ürettim
- [ ] Kural ekliyorsam `.agents/rule-inventory.md` kaydı var

## Atlanan kontroller

Kontrol, nedeni ve telafi edici kanıt:

## Kalan riskler

---

Ayrıntılı rehber: [CONTRIBUTING.md](../CONTRIBUTING.md)
