# Зеркало wumpus.ru/shd для GitHub Pages

Содержимое раздела `https://wumpus.ru/shd/` скачивается во время GitHub Actions и публикуется в GitHub Pages.

Исключаются образы виртуальных машин и дисков:

- `.ova`, `.ovf`
- `.vdi`, `.vmdk`
- `.vhd`, `.vhdx`
- `.qcow`, `.qcow2`
- `.img`, `.raw`, `.iso`

Остальные файлы скачиваются, включая материалы из `bin/`.

## Запуск

1. Создайте пустой GitHub-репозиторий.
2. Поместите в него файлы из этого набора и отправьте ветку `main`.
3. В GitHub откройте **Settings → Pages**.
4. В поле **Source** выберите **GitHub Actions**.
5. Откройте **Actions**, выберите workflow и нажмите **Run workflow**.

Workflow также обновляет зеркало ежедневно в 03:17 UTC.

## Локальная проверка

```bash
./mirror.sh
python3 -m http.server 8000 --directory public
```

После этого сайт доступен по адресу `http://localhost:8000/`.

## Важное ограничение

GitHub Pages публикует сайты размером не более 1 ГБ. Скрипт выводит итоговый размер каталога после скачивания.
