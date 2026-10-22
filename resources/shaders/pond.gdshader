// Вся вода карты одним проходом (PondLayer). Пиксель арта — вода, если его
// центр внутри хоть одного круга зоны, как в MapManager.is_water, поэтому
// пересекающиеся пруды сливаются в одно озеро с общим берегом. Цвета задаёт
// PondLayer из WorldColors — только из палитры.
shader_type canvas_item;

// Должно совпадать с PondLayer.MAX_ZONES.
const int MAX_ZONES = 16;
// UiTokens.PIXEL: сторона пикселя арта в пикселях мира.
const float PIXEL = 2.0;
// Ширина песчаного берега в пикселях арта. Берег лежит снаружи зоны: на
// песке игрок ещё не замедлен.
const float SHORE = 2.0;
// Наибольшее отклонение края от круга зоны, в пикселях арта.
const float WOBBLE = 1.5;

uniform vec3 path_light;
uniform vec3 path;
uniform vec3 path_dark;
uniform vec3 water_light;
uniform vec3 water;
uniform vec3 water_dark;
uniform vec3 water_deep;

// x, y — центр зоны в координатах узла, z — радиус.
uniform vec3 zones[MAX_ZONES];
uniform int zone_count = 0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

// Насколько центр пикселя арта cell внутри зоны, в пикселях арта:
// > 0 — вода, от -SHORE до 0 — берег, дальше — трава. Край чуть волнистый
// (до WOBBLE пикселя арта), чтобы пруды не были циркульными кругами; для
// механики это неощутимо.
float depth(vec2 cell) {
	vec2 at = (cell + 0.5) * PIXEL;
	float best = -1e6;
	for (int i = 0; i < zone_count; i++) {
		vec2 offset = at - zones[i].xy;
		float angle = atan(offset.y, offset.x);
		float phase = float(i) * 1.7;
		float wobble = (0.6 * sin(angle * 3.0 + phase) + 0.4 * sin(angle * 5.0 + phase * 2.3)) * WOBBLE;
		best = max(best, (zones[i].z - length(offset)) / PIXEL + wobble);
	}
	return best;
}

bool is_water(vec2 cell) {
	return depth(cell) > 0.0;
}

bool is_land(vec2 cell) {
	return depth(cell) <= -SHORE;
}

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(local_position / PIXEL);
	float here = depth(cell);
	if (here <= -SHORE) {
		discard;
	}
	vec3 color;
	if (here <= 0.0) {
		// Берег со светом сверху слева, как у остальных предметов мира.
		if (is_land(cell + vec2(0.0, 1.0)) || is_land(cell + vec2(1.0, 0.0))) {
			color = path_dark;
		} else if (is_land(cell - vec2(0.0, 1.0)) || is_land(cell - vec2(1.0, 0.0))) {
			color = path_light;
		} else {
			color = path;
		}
	} else if (!is_water(cell - vec2(0.0, 1.0))) {
		// Верхний берег отбрасывает тень на воду, нижняя кромка — светлая.
		color = water_deep;
	} else if (!is_water(cell - vec2(0.0, 2.0))) {
		color = water_dark;
	} else if (!is_water(cell + vec2(0.0, 1.0))) {
		color = water_light;
	} else {
		// Блики — чёрточки в три пикселя, мерцают каждая в своём ритме.
		float glint = hash(vec2(floor(cell.x / 3.0), cell.y));
		bool shines = glint < 0.015 && here > 4.0 && fract(TIME * 0.4 + glint * 37.0) < 0.6;
		color = shines ? water_light : water;
	}
	COLOR = vec4(color, 1.0);
}
