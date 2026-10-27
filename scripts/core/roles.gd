class_name Roles
extends RefCounted
## Роли Соқыртеке и победитель раунда. В телеметрию уходят прежние строковые
## id (ROLE_IDS, WINNER_IDS), чтобы отчёты не сломались.

enum Role { SOKYROTEKE, RUNNER }
enum Winner { SOKYROTEKE, RUNNERS }

const ROLE_IDS := {Role.SOKYROTEKE: "sokyroteke", Role.RUNNER: "runner"}
const WINNER_IDS := {Winner.SOKYROTEKE: "sokyroteke", Winner.RUNNERS: "players"}


## Жребий, как в документации: ловцом становится один из участников наугад.
## Возвращает роль игрока, если всего участников players (игрок + боты).
static func draw(players: int) -> Role:
	return Role.SOKYROTEKE if randi() % maxi(1, players) == 0 else Role.RUNNER
