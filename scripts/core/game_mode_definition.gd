class_name GameModeDefinition
extends Resource

@export var mode_id: String = "classic"
@export var display_name_kz: String = "Классикалық"
@export var display_name_ru: String = "Классика"

@export var min_players: int = 4
@export var max_players: int = 6
@export var sokyroteke_count: int = 1
@export var round_duration: float = 90.0
@export var catches_needed: int = 3
@export var headstart_secs: float = 3.0
@export var sokyroteke_speed_mult: float = 1.2
@export var player_base_speed: float = 220.0
@export var sokyroteke_speed_penalty_mult: float = 0.9
@export var quiz_answer_time: float = 10.0
@export var total_rounds: int = 3
@export var standing_noise_interval: float = 4.5
@export var shield_duration: float = 2.0
@export var slow_duration: float = 5.0
@export var water_speed_mult: float = 0.6
@export var slow_speed_mult: float = 0.4
