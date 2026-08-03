#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="2026-08-03-no-wget-convert-links-v2"
echo "mirror.sh version: $SCRIPT_VERSION"

SOURCE_URL="${SOURCE_URL:-https://wumpus.ru/shd/}"
SOURCE_HOST="${SOURCE_HOST:-wumpus.ru}"
SOURCE_PATH="${SOURCE_PATH:-shd}"
OUTPUT_DIR="${OUTPUT_DIR:-public}"
WORK_DIR="${WORK_DIR:-.mirror-tmp}"

# VM-образы и форматы виртуальных дисков. Обычные PNG/JPEG не исключаются.
REJECT_EXTENSIONS="${REJECT_EXTENSIONS:-ova,ovf,vdi,vmdk,vhd,vhdx,qcow,qcow2,img,raw,iso}"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
wget \
  --mirror \
  --no-parent \
  --page-requisites \
  --no-span-hosts \
  --domains "$SOURCE_HOST" \
  --reject "$REJECT_EXTENSIONS" \
  --reject-regex='([?].*[{][{])|(/bin/minio([?].*)?$)' \
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

# Дополнительная защита от VM-образов с необычными URL или регистром.
find "$MIRRORED_ROOT" -type f \( \
  -iname '*.ova' -o -iname '*.ovf' -o -iname '*.vdi' -o \
  -iname '*.vmdk' -o -iname '*.vhd' -o -iname '*.vhdx' -o \
  -iname '*.qcow' -o -iname '*.qcow2' -o -iname '*.img' -o \
  -iname '*.raw' -o -iname '*.iso' \
\) -delete

# minio — крупный исполняемый файл, который сознательно не архивируем.
find "$MIRRORED_ROOT" -type f -iname 'minio' -delete

# Безопасно переписываем только ссылки на зеркалируемый раздел.
# Внешние ссылки остаются внешними. Шаблонные ?fam={{...}} удаляются.
python3 - "$MIRRORED_ROOT" "$SOURCE_HOST" "$SOURCE_PATH" <<'PY'
from pathlib import Path
import os
import re
import sys

root = Path(sys.argv[1]).resolve()
host = sys.argv[2]
source_path = sys.argv[3].strip('/')

attr_re = re.compile(r'(?P<prefix>\b(?:href|src)\s*=\s*["\'])(?P<url>[^"\']*)(?P<suffix>["\'])', re.I)

for page in root.rglob('*.html'):
    text = page.read_text(encoding='utf-8', errors='surrogateescape')
    relative_root = os.path.relpath(root, page.parent).replace(os.sep, '/')
    if relative_root == '.':
        relative_root = ''

    def local_url(rest: str) -> str:
        rest = rest.lstrip('/')
        return f"{relative_root}/{rest}" if relative_root else rest

    def replace(match: re.Match[str]) -> str:
        url = match.group('url')

        # Эти строки являются Go-шаблонами, а не рабочими статическими URL.
        if '{{' in url and '?' in url:
            return match.group('prefix') + '#' + match.group('suffix')

        prefixes = (
            f'https://{host}/{source_path}/',
            f'http://{host}/{source_path}/',
            f'//{host}/{source_path}/',
            f'/{source_path}/',
        )
        for prefix in prefixes:
            if url.startswith(prefix):
                return match.group('prefix') + local_url(url[len(prefix):]) + match.group('suffix')
        return match.group(0)

    updated = attr_re.sub(replace, text)
    page.write_text(updated, encoding='utf-8', errors='surrogateescape')
PY

# Публикуем только после успешной загрузки и проверки.
if [[ ! -f "$MIRRORED_ROOT/index.html" ]]; then
  echo "Ошибка: зеркало не содержит index.html; прежняя публикация не изменена" >&2
  exit 1
fi

FILE_COUNT="$(find "$MIRRORED_ROOT" -type f | wc -l)"
if (( FILE_COUNT < 10 )); then
  echo "Ошибка: скачано подозрительно мало файлов: $FILE_COUNT" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -a "$MIRRORED_ROOT"/. "$OUTPUT_DIR"/
touch "$OUTPUT_DIR/.nojekyll"

echo "Зеркало готово: $FILE_COUNT файлов"
du -sh "$OUTPUT_DIR"
