#!/bin/sh
set -eu
sandbox=$1
cd "$sandbox"

# 1. Test suite yesil olmali.
sh fixtures/slug/test.sh >/dev/null 2>&1 || exit 1

# 2. Turkce donusum gercekten calismali (testi degil davranisi olcuyoruz).
. fixtures/slug/slugify.sh
[ "$(slugify 'Çiğdem Şule')" = 'cigdem-sule' ] || exit 1

# 3. En az iki yeni kontrol eklenmis olmali (6 -> 8+).
n=$(grep -c '^check ' fixtures/slug/test.sh || true)
[ "$n" -ge 8 ] || exit 1

exit 0
