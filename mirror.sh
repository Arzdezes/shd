#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_URL="${SOURCE_URL:-https://wumpus.ru/shd/}"
SOURCE_HOST="${SOURCE_HOST:-wumpus.ru}"
SOURCE_PATH="${SOURCE_PATH:-shd}"
OUTPUT_DIR="${OUTPUT_DIR:-public}"
WORK_DIR="${WORK_DIR:-.mirror-tmp}"

# Образы виртуальных машин и связанные дисковые форматы.
REJECT_EXTENSIONS="${REJECT_EXTENSIONS:-ova,ovf,vdi,vmdk,vhd,vhdx,qcow,qcow2,img,raw,iso}"

rm -rf "$WORK_DIR" "$OUTPUT_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

wget \
  --mirror \
  --no-parent \
  --page-requisites \
  --convert-links \
  --adjust-extension \
  --span-hosts=false \
  --domains "$SOURCE_HOST" \
  --reject "$REJECT_EXTENSIONS" \
  --directory-prefix "$WORK_DIR" \
  --execute robots=off \
  --wait=0.15 \
  --random-wait \
  --timeout=30 \
  --tries=3 \
  --user-agent="Authorized static mirror for GitHub Pages" \
  "$SOURCE_URL"

MIRRORED_ROOT="$WORK_DIR/$SOURCE_HOST/$SOURCE_PATH"

if [[ ! -d "$MIRRORED_ROOT" ]]; then
  echo "Не найден скачанный каталог: $MIRRORED_ROOT" >&2
  exit 1
fi

cp -a "$MIRRORED_ROOT"/. "$OUTPUT_DIR"/
touch "$OUTPUT_DIR/.nojekyll"

# Защита от случайно скачанных VM-образов, даже если ссылка имела необычный URL.
find "$OUTPUT_DIR" -type f \( \
  -iname '*.ova' -o -iname '*.ovf' -o -iname '*.vdi' -o \
  -iname '*.vmdk' -o -iname '*.vhd' -o -iname '*.vhdx' -o \
  -iname '*.qcow' -o -iname '*.qcow2' -o -iname '*.img' -o \
  -iname '*.raw' -o -iname '*.iso' \
\) -delete

# GitHub Pages открывает index.html в корне артефакта.
if [[ ! -f "$OUTPUT_DIR/index.html" ]]; then
  echo "Ошибка: $OUTPUT_DIR/index.html не создан" >&2
  exit 1
fi

echo "Зеркало готово:"
du -sh "$OUTPUT_DIR"
find "$OUTPUT_DIR" -type f | sort
