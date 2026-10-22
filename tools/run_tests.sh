#!/usr/bin/env bash
# Прогоняет все headless-тесты tools/*_test.gd и выходит с кодом 1, если упал
# хоть один. Этот же скрипт запускает CI.
#
#   tools/run_tests.sh
#   GODOT=~/Desktop/Godot_v4/Godot_v4.7.2-stable_win64_console.exe tools/run_tests.sh
#
# Godot берётся из переменной GODOT, иначе из PATH.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# Импорт обязателен: без него на чистом клоне нет .godot/ и переводов.
"$GODOT" --headless --import --path . > /dev/null 2>&1

failed=()
for test in tools/*_test.gd; do
	echo "::group::$test"
	"$GODOT" --headless --path . --script "res://$test" || failed+=("$test")
	echo "::endgroup::"
done

if ((${#failed[@]})); then
	echo "Упали тесты: ${failed[*]}"
	exit 1
fi
echo "Все тесты прошли."
