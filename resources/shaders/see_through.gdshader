// Крыша юрты, под которой стоит сам игрок (как куст в Brawl Stars): пиксели
// арта прореживаются шахматкой, и сквозь крышу видно себя и тех, кто рядом.
// Прореживание по сетке пикселя арта (картинка сохранена ×2), поэтому дыры
// ровные и пиксельные, без полупрозрачности.
shader_type canvas_item;

// false — крыша целая, true — сквозная.
uniform bool open = false;
// Сколько пикселей картинки в одном пикселе арта.
uniform float art_pixel = 2.0;

void fragment() {
	if (open) {
		vec2 cell = floor(UV * vec2(textureSize(TEXTURE, 0)) / art_pixel);
		if (mod(cell.x + cell.y, 2.0) < 1.0) {
			discard;
		}
	}
}
