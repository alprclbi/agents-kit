#!/bin/sh
set -eu
sandbox=$1
cd "$sandbox"

# Sandbox'i GERCEK bir git deposu yapar.
#
# Gerekce (2026-09-08 bulgusu): ilk spike'ta setup yoktu, dolayisiyla
# `git status` izin verilse bile "not a git repository" ile basarisiz
# olurdu. cap-git.txt-in yoklugu iki farkli seye isaret edebiliyordu:
# izin reddi mi, depo yoklugu mu? Ayirt edilemeyen olcum olcum degildir.
# Depo kurulunca dosyanin yoklugu YALNIZ izin reddi anlamina gelir.
git init -q .
git config user.email 'eval@example.invalid'
git config user.name 'Eval Harness'
git config core.autocrlf false
git add -A
git commit -qm 'taban'
