package main

import clay "../vendor/clay/clay-odin"
import "../password"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

PASSPHRASE_WORD_MIN :: 2
PASSPHRASE_WORD_MAX :: 10

@(private = "file")
SEPARATOR_PRESETS := [4]string{"-", "_", " ", "."}
@(private = "file")
SEPARATOR_LABELS := [4]string{"-", "_", "space", "."}

Passphrase_State :: struct {
	word_count:      int,
	separator_index: int,
	capitalize:      bool,
	output:          string, // owned; "" when nothing generated yet
}

passphrase_state_init :: proc() -> Passphrase_State {
	return Passphrase_State{word_count = 4, separator_index = 0, capitalize = false, output = ""}
}

passphrase_state_destroy :: proc(state: ^Passphrase_State) {
	if state.output != "" {
		delete(state.output)
	}
}

passphrase_screen :: proc(state: ^Passphrase_State) {
	if clay.UI(clay.ID("PassphraseScreen"))(
	{
		layout = {
			sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(SPACE_XL),
			childGap = SPACE_LG,
		},
	},
	) {
		clay.Text("PASSPHRASE GENERATOR", {fontId = FONT_HEADING, fontSize = FONT_SIZE_TITLE, textColor = NORD_SNOW_2, letterSpacing = TRACKING_EYEBROW})

		// Word count stepper
		if clay.UI(clay.ID("WordCountRow"))({layout = {childGap = SPACE_MD, childAlignment = {y = .Center}}}) {
			clay.Text("Words", {fontId = FONT_BODY, fontSize = FONT_SIZE_BODY, textColor = NORD_SNOW_0})
			if button("-", .Secondary, 0) && state.word_count > PASSPHRASE_WORD_MIN {
				state.word_count -= 1
			}
			count_label := fmt.tprintf("%d", state.word_count)
			clay.Text(count_label, {fontId = FONT_MONO, fontSize = FONT_SIZE_BODY, textColor = NORD_SNOW_2})
			if button("+", .Secondary, 0) && state.word_count < PASSPHRASE_WORD_MAX {
				state.word_count += 1
			}
		}

		// Separator presets
		if clay.UI(clay.ID("SeparatorRow"))({layout = {childGap = SPACE_SM, childAlignment = {y = .Center}}}) {
			clay.Text("Separator", {fontId = FONT_BODY, fontSize = FONT_SIZE_BODY, textColor = NORD_SNOW_0})
			for label, i in SEPARATOR_LABELS {
				if toggle_button(label, state.separator_index == i, u32(i)) {
					state.separator_index = i
				}
			}
		}

		// Capitalize toggle
		if clay.UI(clay.ID("CapitalizeRow"))({layout = {childGap = SPACE_MD, childAlignment = {y = .Center}}}) {
			clay.Text("Capitalize", {fontId = FONT_BODY, fontSize = FONT_SIZE_BODY, textColor = NORD_SNOW_0})
			if toggle_button(capitalize_label(state.capitalize), state.capitalize, 0) {
				state.capitalize = !state.capitalize
			}
		}

		// Actions
		if clay.UI(clay.ID("ActionsRow"))({layout = {childGap = SPACE_MD}}) {
			if button("GENERATE", .Primary, 0) {
				regenerate_passphrase(state)
			}
			if state.output != "" && button("COPY", .Secondary, 1) {
				rl.SetClipboardText(strings.clone_to_cstring(state.output, context.temp_allocator))
			}
		}

		// Output
		if clay.UI(clay.ID("OutputPanel"))(
		{
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(56)}, padding = clay.PaddingAll(SPACE_MD), childAlignment = {y = .Center}},
			backgroundColor = NORD_POLAR_1,
			cornerRadius = clay.CornerRadiusAll(RADIUS_MD),
			border = {width = {1, 1, 1, 1, 0}, color = NORD_POLAR_3},
		},
		) {
			display_text := state.output if state.output != "" else "click generate..."
			display_color := NORD_SNOW_2 if state.output != "" else NORD_SNOW_0
			clay.Text(display_text, {fontId = FONT_MONO, fontSize = FONT_SIZE_MONO, textColor = display_color})
		}
	}
}

@(private = "file")
regenerate_passphrase :: proc(state: ^Passphrase_State) {
	options := password.Options{
		word_count = state.word_count,
		separator  = SEPARATOR_PRESETS[state.separator_index],
		capitalize = state.capitalize,
	}

	phrase, err := password.generate(options)
	if err != .None {
		return
	}

	if state.output != "" {
		delete(state.output)
	}
	state.output = phrase
}

@(private = "file")
capitalize_label :: proc(on: bool) -> string {
	return "on" if on else "off"
}
