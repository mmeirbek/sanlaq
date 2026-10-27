#!/usr/bin/env bash
# Собирает САҢЛАҚ для macOS: export/macos/Sanlaq.app и архив Sanlaq-macos.zip.
#
#   tools/build_macos.sh
#   GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot tools/build_macos.sh
#
# Только на macOS. Нужны шаблоны экспорта той же версии, что и Godot
# (~/Library/Application Support/Godot/export_templates/<версия>/macos.zip).
#
# Godot называет исполняемый файл и .pck именем проекта — «САҢЛАҚ - Sañlaq». Подпись
# пакета с такими именами macOS проверить не может (codesign: «a sealed resource is
# missing or invalid»), а имя проекта менять нельзя: по нему лежат сохранения игроков.
# Поэтому после экспорта файлы получают латинское имя Sanlaq, и пакет подписывается
# заново — ad-hoc, без сертификата Apple: для запуска на своих Mac, не для App Store.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

OUT=export/macos
NAME=Sanlaq
# Собираем и подписываем во временной папке: в синхронизируемых с iCloud папках
# («Рабочий стол», «Документы») macOS вешает на файлы служебные данные, и codesign
# отказывается подписывать («resource fork, Finder information... not allowed»).
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/$NAME.app"

"$GODOT" --headless --path . --export-release "macOS" "$APP"

contents="$APP/Contents"
binary=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$contents/Info.plist")
if [ "$binary" != "$NAME" ]; then
	mv "$contents/MacOS/$binary" "$contents/MacOS/$NAME"
	mv "$contents/Resources/$binary.pck" "$contents/Resources/$NAME.pck"
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $NAME" "$contents/Info.plist"
fi
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --keepParent "$APP" "$WORK/$NAME-macos.zip"

mkdir -p "$OUT"
rm -rf "${OUT:?}/$NAME.app" "$OUT/$NAME-macos.zip"
ditto "$APP" "$OUT/$NAME.app"
cp "$WORK/$NAME-macos.zip" "$OUT/"
echo "Готово: $OUT/$NAME.app и $OUT/$NAME-macos.zip"
