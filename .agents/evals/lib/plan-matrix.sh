#!/bin/sh
set -eu

# Varsayilan kosu basi maliyet OLCULMUS degerdir.
# 2026-09-06: 0.35 (2 kosu, yalniz 01-bugfix -- uzun gorev).
# 2026-09-07 DUZELTME: o deger TEK bir uzun gorevden geliyordu ve kisa
# gorevlerde 3 kat yuksekti. runs-07.jsonl + runs-08.jsonl (18 kosu)
# araligi 0.089-0.281, ortanca ~0.12. Sondalar (8 tur siniri) daha da
# kisadir. 0.15 muhafazakar ust sinirdir. Yeni olcum geldikce guncelle.
root='' repeats=3 cost='0.15'
# Bos filtre = katalogun enabled satirlari. Dolu filtre enabled'i EZER;
# kademeli kosu enabled=0 kollari (E1) acabilmek icin buna dayanir.
arms_filter='' tasks_filter=''
while [ $# -gt 0 ]; do
  case $1 in
    --root)         root=$2;    shift 2 ;;
    --repeats)      repeats=$2; shift 2 ;;
    --cost-per-run) cost=$2;    shift 2 ;;
    --arms)         arms_filter=$2;  shift 2 ;;
    --tasks)        tasks_filter=$2; shift 2 ;;
    *) printf 'E_PM_ARG %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$root" ] || { printf 'E_PM_ARGS\n' >&2; exit 2; }

arms="$root/.agents/evals/arms.tsv"
tasks="$root/.agents/evals/tasks.tsv"
[ -f "$arms" ] && [ -f "$tasks" ] || { printf 'E_PM_CATALOG\n' >&2; exit 2; }

n_arms=$(awk -F '\t' -v f="$arms_filter" 'NR>1 && ((f=="" && $2==1) || (f!="" && index(","f",", ","$1",")>0)) {n++} END{print n+0}' "$arms")
n_tasks=$(awk -F '\t' -v f="$tasks_filter" 'NR>1 && ((f=="" && $3==1) || (f!="" && index(","f",", ","$1",")>0)) {n++} END{print n+0}' "$tasks")
[ "$n_arms" -gt 0 ] && [ "$n_tasks" -gt 0 ] || { printf 'E_PM_EMPTY\n' >&2; exit 2; }

i=1
while [ "$i" -le "$repeats" ]; do
  # Kol sirasi her tekrarda dondurulur; boylece prompt cache onyargisi
  # tek bir kola sistematik olarak yuklenmez, gurultuye dagilir.
  awk -F '\t' -v r="$i" -v f="$arms_filter" '
    NR>1 && ((f=="" && $2==1) || (f!="" && index(","f",", ","$1",")>0)) {a[n++]=$1}
    END { for (k=0; k<n; k++) print a[(k + r - 1) % n] }
  ' "$arms" |
  while read -r arm; do
    awk -F '\t' -v f="$tasks_filter" 'NR>1 && ((f=="" && $3==1) || (f!="" && index(","f",", ","$1",")>0)) {print $1}' "$tasks" |
    while read -r task; do
      printf '%s\t%s\t%s\n' "$arm" "$task" "$i"
    done
  done
  i=$((i + 1))
done

count=$((n_arms * n_tasks * repeats))
printf 'TOTAL\t%s\t%s\n' "$count" "$(awk -v c="$count" -v p="$cost" 'BEGIN{printf "%.2f", c*p}')"
