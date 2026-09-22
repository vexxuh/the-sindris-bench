package main

// Translates Clay's render commands into raylib draw calls, and measures
// text for Clay's layout pass. Adapted from Clay's official Odin+raylib
// reference renderer (vendor/clay, commit e6cc36941ab2af5d81107617039d6f527a1c660b),
// trimmed to what this app needs (no custom-element rendering).

import clay "../vendor/clay/clay-odin"
import "base:runtime"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

Raylib_Font :: struct {
	font_id: u16,
	font:    rl.Font,
}

raylib_fonts: [dynamic]Raylib_Font

clay_color_to_rl_color :: proc(color: clay.Color) -> rl.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

load_font :: proc(font_id: u16, font_size: u16, path: cstring) {
	font := rl.LoadFontEx(path, i32(font_size) * 2, nil, 0)
	rl.SetTextureFilter(font.texture, rl.TextureFilter.TRILINEAR)
	assign_at(&raylib_fonts, font_id, Raylib_Font{font = font, font_id = font_id})
}

// UTF-8 aware: this app diffs/pretty-prints arbitrary user files, which
// routinely contain non-ASCII text, so the ASCII-only fast path Clay's
// example ships isn't safe to use here.
measure_text :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, userData: rawptr) -> clay.Dimensions {
	context = runtime.default_context()

	line_width: f32 = 0
	font := raylib_fonts[config.fontId].font
	text_str := string(text.chars[:text.length])
	grapheme_count, _, _ := utf8.grapheme_count(text_str)

	for letter in text_str {
		glyph_index := rl.GetGlyphIndex(font, letter)
		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(glyph.offsetX)
		}
	}

	scale_factor := f32(config.fontSize) / f32(font.baseSize)
	total_spacing := f32(grapheme_count) * f32(config.letterSpacing)

	return {width = line_width * scale_factor + total_spacing, height = f32(config.fontSize)}
}

clay_raylib_render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand), allocator := context.temp_allocator) {
	overlay_colors := make([dynamic]clay.Color, allocator)

	for i in 0 ..< render_commands.length {
		command := clay.RenderCommandArray_Get(render_commands, i)
		bounds := command.boundingBox

		switch command.commandType {
		case .None:
		// nothing to draw

		case .Text:
			config := command.renderData.text
			text := string(config.stringContents.chars[:config.stringContents.length])
			cstr_text := strings.clone_to_cstring(text, allocator)
			font := raylib_fonts[config.fontId].font
			rl.DrawTextEx(font, cstr_text, {bounds.x, bounds.y}, f32(config.fontSize), f32(config.letterSpacing), clay_color_to_rl_color(config.textColor))

		case .Image:
			config := command.renderData.image
			tint := clay.Color{255, 255, 255, 255}
			if len(overlay_colors) > 0 {
				tint = overlay_colors[len(overlay_colors) - 1]
			}
			texture := (^rl.Texture2D)(config.imageData)
			rl.DrawTextureEx(texture^, {bounds.x, bounds.y}, 0, bounds.width / f32(texture.width), clay_color_to_rl_color(tint))

		case .ScissorStart:
			rl.BeginScissorMode(i32(math.round(bounds.x)), i32(math.round(bounds.y)), i32(math.round(bounds.width)), i32(math.round(bounds.height)))

		case .ScissorEnd:
			rl.EndScissorMode()

		case .Rectangle:
			config := command.renderData.rectangle
			if config.cornerRadius.topLeft > 0 {
				radius := (config.cornerRadius.topLeft * 2) / min(bounds.width, bounds.height)
				draw_rect_rounded(bounds.x, bounds.y, bounds.width, bounds.height, radius, config.backgroundColor)
			} else {
				draw_rect(bounds.x, bounds.y, bounds.width, bounds.height, config.backgroundColor)
			}

		case .Border:
			draw_border(bounds, command.renderData.border)

		case .OverlayColorStart:
			append(&overlay_colors, command.renderData.overlayColor.color)

		case .OverlayColorEnd:
			pop(&overlay_colors)

		case .Custom:
		// no custom elements in this app
		}
	}
}

@(private = "file")
draw_border :: proc(bounds: clay.BoundingBox, config: clay.BorderRenderData) {
	if config.width.left > 0 {
		draw_rect(bounds.x, bounds.y + config.cornerRadius.topLeft, f32(config.width.left), bounds.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft, config.color)
	}
	if config.width.right > 0 {
		draw_rect(bounds.x + bounds.width - f32(config.width.right), bounds.y + config.cornerRadius.topRight, f32(config.width.right), bounds.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight, config.color)
	}
	if config.width.top > 0 {
		draw_rect(bounds.x + config.cornerRadius.topLeft, bounds.y, bounds.width - config.cornerRadius.topLeft - config.cornerRadius.topRight, f32(config.width.top), config.color)
	}
	if config.width.bottom > 0 {
		draw_rect(bounds.x + config.cornerRadius.bottomLeft, bounds.y + bounds.height - f32(config.width.bottom), bounds.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight, f32(config.width.bottom), config.color)
	}

	if config.cornerRadius.topLeft > 0 {
		draw_arc(bounds.x + config.cornerRadius.topLeft, bounds.y + config.cornerRadius.topLeft, config.cornerRadius.topLeft - f32(config.width.top), config.cornerRadius.topLeft, 180, 270, config.color)
	}
	if config.cornerRadius.topRight > 0 {
		draw_arc(bounds.x + bounds.width - config.cornerRadius.topRight, bounds.y + config.cornerRadius.topRight, config.cornerRadius.topRight - f32(config.width.top), config.cornerRadius.topRight, 270, 360, config.color)
	}
	if config.cornerRadius.bottomLeft > 0 {
		draw_arc(bounds.x + config.cornerRadius.bottomLeft, bounds.y + bounds.height - config.cornerRadius.bottomLeft, config.cornerRadius.bottomLeft - f32(config.width.top), config.cornerRadius.bottomLeft, 90, 180, config.color)
	}
	if config.cornerRadius.bottomRight > 0 {
		draw_arc(bounds.x + bounds.width - config.cornerRadius.bottomRight, bounds.y + bounds.height - config.cornerRadius.bottomRight, config.cornerRadius.bottomRight - f32(config.width.bottom), config.cornerRadius.bottomRight, 0.1, 90, config.color)
	}
}

@(private = "file")
draw_arc :: proc(x, y, inner_rad, outer_rad, start_angle, end_angle: f32, color: clay.Color) {
	rl.DrawRing({math.round(x), math.round(y)}, math.round(inner_rad), outer_rad, start_angle, end_angle, 10, clay_color_to_rl_color(color))
}

@(private = "file")
draw_rect :: proc(x, y, w, h: f32, color: clay.Color) {
	rl.DrawRectangle(i32(math.round(x)), i32(math.round(y)), i32(math.round(w)), i32(math.round(h)), clay_color_to_rl_color(color))
}

@(private = "file")
draw_rect_rounded :: proc(x, y, w, h, radius: f32, color: clay.Color) {
	rl.DrawRectangleRounded({x, y, w, h}, radius, 8, clay_color_to_rl_color(color))
}
