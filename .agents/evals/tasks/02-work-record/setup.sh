#!/bin/sh
set -eu
sandbox=$1

# Bu gorev bir OZELLIK ekleme gorevidir, bugfix degil. Fixture'in temel
# hatasi (ardisik ayirici indirgemesi) burada kapatilir ki gorev yesil bir
# suite'ten baslasin.
#
# Gerekce: 2026-09-06 olcumunde bu gorev iki kolda da basarisiz oldu.
# Sebep ajanin yetersizligi degil, gorev tasariminin bozuklugu idi: istem
# yalniz Turkce destegi istiyordu ama fixture 3 kirik testle basliyordu ve
# istem bundan hic bahsetmiyordu. Ajan gorunmeyen ikinci bir isi de yapmak
# zorundaydi. Bozuk gorevle yapilan olcum butun sonuclari kirletir.
#
# Yama yerine dosya butunuyle yazilir: kabuk kacis dizileri bu projede
# iki kez sessiz hataya yol acti, dogrudan yazim belirsizlik birakmiyor.

f="$sandbox/fixtures/slug/slugify.sh"
[ -f "$f" ] || { printf 'E_SETUP_NO_FIXTURE\n' >&2; exit 2; }

cat > "$f" <<'FIXED'
#!/bin/sh
# Metni URL-guvenli slug'a cevirir.
slugify() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^a-z0-9]\{1,\}/-/g' |
    sed 's/^-//; s/-$//'
}

if [ "${0##*/}" = slugify.sh ] && [ $# -gt 0 ]; then
  slugify "$1"
fi
FIXED

# Baslangic durumu yesil olmali; degilse sessizce devam etme.
sh "$sandbox/fixtures/slug/test.sh" >/dev/null 2>&1 || {
  printf 'E_SETUP_NOT_GREEN\n' >&2; exit 2
}
exit 0
