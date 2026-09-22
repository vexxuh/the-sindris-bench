package main

import clay "../vendor/clay/clay-odin"
import rl "vendor:raylib"

Button_Variant :: enum {
	Primary,
	Secondary,
}

// Draws a clickable button, returning true on the exact frame it's
// clicked. `id_index` disambiguates buttons that would otherwise share a
// label (Clay element ids must be unique per parent).
button :: proc(label: string, variant := Button_Variant.Secondary, id_index: u32 = 0) -> bool {
	clicked := false

	bg := NORD_POLAR_2
	text_color := NORD_SNOW_2
	if variant == .Primary {
		bg = NORD_FROST_DEEP
	}

	if clay.UI(clay.ID(label, id_index))(
	{
		layout = {
			padding = {left = SPACE_MD, right = SPACE_MD, top = SPACE_SM, bottom = SPACE_SM},
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = bg,
		cornerRadius = clay.CornerRadiusAll(RADIUS_SM),
	},
	) {
		if clay.Hovered() && rl.IsMouseButtonPressed(.LEFT) {
			clicked = true
		}
		clay.Text(label, {fontId = FONT_BODY, fontSize = FONT_SIZE_BODY, textColor = text_color})
	}

	return clicked
}

// A small toggle-style button: highlighted with the accent color when
// `active` is true, otherwise styled like a plain secondary button.
toggle_button :: proc(label: string, active: bool, id_index: u32 = 0) -> bool {
	clicked := false

	bg := NORD_FROST_DEEP if active else NORD_POLAR_2
	text_color := NORD_SNOW_2 if active else NORD_SNOW_0

	if clay.UI(clay.ID(label, id_index))(
	{
		layout = {
			padding = {left = SPACE_SM, right = SPACE_SM, top = SPACE_XS, bottom = SPACE_XS},
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = bg,
		cornerRadius = clay.CornerRadiusAll(RADIUS_SM),
	},
	) {
		if clay.Hovered() && rl.IsMouseButtonPressed(.LEFT) {
			clicked = true
		}
		clay.Text(label, {fontId = FONT_BODY, fontSize = FONT_SIZE_LABEL, textColor = text_color})
	}

	return clicked
}
