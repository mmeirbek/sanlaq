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

# Код выхода, когда движок падает сам (segfault), а не тест.
ENGINE_CRASH=139

# Импорт обязателен: без него на чистом клоне нет .godot/ и переводов.
# Godot изредка падает при выходе — тогда импорт повторяется: без него
# не найдутся ресурсы, и упадут все тесты разом.
for attempt in 1 2 3; do
	"$GODOT" --headless --import --path . > /dev/null 2>&1 && break
	echo "Импорт прервался (попытка $attempt), повторяю"
done

# Тест, на котором упал сам движок, перезапускается один раз. Обычный провал
# (exit 1 от check() или ошибки в логе) не повторяется.
run_test() {
	"$GODOT" --headless --path . --script "res://$1"
	local code=$?
	if [ "$code" -eq "$ENGINE_CRASH" ]; then
		echo "Движок упал (segfault), повторяю $1 один раз"
		"$GODOT" --headless --path . --script "res://$1"
		code=$?
	fi
	return "$code"
}

failed=()
for test in tools/*_test.gd; do
	echo "::group::$test"
	run_test "$test" || failed+=("$test")
	echo "::endgroup::"
done

if ((${#failed[@]})); then
	echo "Упали тесты: ${failed[*]}"
	exit 1
fi
echo "Все тесты прошли."
