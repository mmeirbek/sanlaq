class_name GameModeDefinition
extends Resource

@export var mode_id: String = "classic"
@export var display_name_kz: String = "Классикалық"

@export var min_players: int = 2
@export var max_players: int = 8
@export var sokyroteke_count: int = 1
@export var round_duration: float = 90.0
@export var round_base_time: float = 60.0
@export var time_per_runner: float = 15.0
@export var headstart_secs: float = 3.0
@export var sokyroteke_speed_mult: float = 1.35
@export var player_base_speed: float = 220.0
@export var sokyroteke_speed_penalty_mult: float = 0.9
@export var quiz_answer_time: float = 10.0
@export var standing_noise_interval: float = 4.5
@export var shield_duration: float = 2.0
@export var slow_duration: float = 5.0
@export var water_speed_mult: float = 0.6
@export var slow_speed_mult: float = 0.4
