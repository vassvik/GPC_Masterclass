package masterclass 

import gl_font "gl_font";

Font :: gl_font.Font

Font_Color :: enum {
	Black = 0,
	Red,
	Green,
	Blue,
	Yellow,
	Purple,
	Cyan,
	White
};

font_colors := [Font_Color]gl_font.Vec4 {
	.Black  = {0.0, 0.0, 0.0, 1.0},
	.Red    = {1.0, 0.0, 0.0, 1.0},
	.Green  = {0.0, 1.0, 0.0, 1.0},
	.Blue   = {0.0, 0.0, 1.0, 1.0},
	.Yellow = {1.0, 1.0, 0.0, 1.0},
	.Purple = {1.0, 0.0, 1.0, 1.0},
	.Cyan   = {0.0, 1.0, 1.0, 1.0},
	.White  = {1.0, 1.0, 1.0, 1.0},
};

init_font :: proc(filename: string) -> gl_font.Font {
	sizes := [?]int{72, 68, 64, 60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12};
	codepoints: [95]rune;
	for i in 0..<95 do codepoints[i] = rune(32+i);
	font, font_success := gl_font.init_from_ttf_gl(filename, "Consola", false, sizes[:], codepoints[:]);
	if !font_success do panic("Failed to load font.");

	for v in Font_Color do gl_font.colors[v] = font_colors[v];
	gl_font.update_colors(0, len(Font_Color));

	return font
}

set_font_state :: gl_font.set_state
draw_string :: gl_font.draw_string