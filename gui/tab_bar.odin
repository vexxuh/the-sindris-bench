package main

import clay "../vendor/clay/clay-odin"
import rl "vendor:raylib"

TAB_BAR_HEIGHT :: 48

tab_bar :: proc(state: ^App_State) {
	if clay.UI(clay.ID("TabBar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(TAB_BAR_HEIGHT)},
			padding = {left = SPACE_LG, right = SPACE_LG},
			childGap = SPACE_LG,
			childAlignment = {y = .Center},
		},
		backgroundColor = NORD_POLAR_1,
		border = {width = {bottom = 1}, color = NORD_POLAR_3},
	},
	) {
		tab_button(state, .Diff, "DIFF")
		tab_button(state, .Json, "JSON")
		tab_button(state, .Passphrase, "PASSPHRASE")
	}
}

@(private = "file")
tab_button :: proc(state: ^App_State, tab: Tab, label: string) {
	is_active := state.active_tab == tab
	text_color := NORD_FROST_LIGHT if is_active else NORD_SNOW_0
	underline_color := NORD_FROST_LIGHT if is_active else NORD_POLAR_1

	if clay.UI(clay.ID(label))(
	{layout = {layoutDirection = .TopToBottom, childGap = SPACE_XS, childAlignment = {x = .Center}}},
	) {
		if clay.Hovered() && rl.IsMouseButtonPressed(.LEFT) {
			state.active_tab = tab
		}
		clay.Text(label, {fontId = FONT_HEADING, fontSize = FONT_SIZE_LABEL, textColor = text_color, letterSpacing = TRACKING_EYEBROW})
		if clay.UI(clay.ID(label, 1))(
		{layout = {sizing = {width = clay.SizingFixed(24), height = clay.SizingFixed(2)}}, backgroundColor = underline_color},
		) {}
	}
}
