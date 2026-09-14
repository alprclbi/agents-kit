#!/bin/sh
# Metni URL-guvenli slug'a cevirir.
slugify() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^a-z0-9]/-/g' |
    sed 's/^-//; s/-$//'
}

if [ "${0##*/}" = slugify.sh ] && [ $# -gt 0 ]; then
  slugify "$1"
fi
