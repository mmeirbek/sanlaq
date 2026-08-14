class_name BotProfile
extends Resource

enum Difficulty { EASY, MEDIUM, HARD }

@export var profile_id: String = ""
@export var display_name: String = ""
@export var difficulty: Difficulty = Difficulty.MEDIUM

@export_range(0.5, 1.5) var wander_speed_mult: float = 0.7
@export_range(50, 500) var fear_distance: float = 200.0
@export_range(0.0, 1.0) var hide_tendency: float = 0.4
@export_range(0.0, 1.5) var reaction_delay: float = 0.3
@export_range(0.0, 1.0) var noise_mistake_chance: float = 0.15

@export var can_sprint: bool = false
@export var use_hiding_spots: bool = true
@export var taunt_chance: float = 0.05
