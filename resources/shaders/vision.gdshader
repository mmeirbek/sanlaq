// Обзор Соқыртеке (VisionSystem): ясный круг radius, за ним — три ступени
// пиксельной шахматки (25, 50, 75 % тёмных пикселей), дальше — сплошная тьма.
// Считается по пикселям арта, поэтому край ровный и пиксельный при любом
// размере окна.
shader_type canvas_item;

// Ширина одной ступени в пикселях арта.
const float STEP = 3.0;
// Порядок Байера 4×4: с какой доли затемнения пиксель становится тёмным.
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

// Центр и радиус круга — в координатах ColorRect, как и pixel (сторона
// пикселя арта на экране).
uniform vec2 center;
uniform float radius = 100.0;
uniform float pixel = 2.0;
uniform float darkness = 0.95;
// Цвет тьмы — UiTokens.OUTLINE, как контуры: тьма тёплая, а не чёрная.
uniform vec3 shade;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 cell = floor(local_position / pixel);
	float outside = distance((cell + 0.5) * pixel, center) - radius;
	// 0 — внутри круга, 1–3 — ступени шахматки, 4 — сплошная тьма.
	float band = clamp(ceil(outside / (STEP * pixel)), 0.0, 4.0);
	ivec2 in_tile = ivec2(mod(cell, 4.0));
	float threshold = (BAYER[in_tile.x + in_tile.y * 4] + 0.5) / 16.0;
	bool dark = threshold < band / 4.0;
	COLOR = vec4(shade, dark ? darkness : 0.0);
}
