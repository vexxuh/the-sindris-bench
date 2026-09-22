package main

import clay "../vendor/clay/clay-odin"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_TITLE :: "tsb"
INITIAL_WIDTH :: 1000
INITIAL_HEIGHT :: 700

error_handler :: proc "c" (error_data: clay.ErrorData) {
	context = {}
	fmt.eprintln("clay error:", error_data.errorType, string(error_data.errorText.chars[:error_data.errorText.length]))
}

main :: proc() {
	min_memory_size := clay.MinMemorySize()
	arena_backing := make([]u8, min_memory_size)
	defer delete(arena_backing)

	arena := clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), raw_data(arena_backing))
	clay.Initialize(arena, {INITIAL_WIDTH, INITIAL_HEIGHT}, {handler = error_handler})
	clay.SetMeasureTextFunction(measure_text, nil)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(INITIAL_WIDTH, INITIAL_HEIGHT, WINDOW_TITLE)
	defer rl.CloseWindow()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))

	load_font(FONT_HEADING, FONT_SIZE_DISPLAY, "gui/assets/fonts/SpaceGrotesk.ttf")
	load_font(FONT_BODY, FONT_SIZE_BODY, "gui/assets/fonts/Inter.ttf")
	load_font(FONT_MONO, FONT_SIZE_MONO, "gui/assets/fonts/JetBrainsMono.ttf")

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		clay.SetPointerState(rl.GetMousePosition(), rl.IsMouseButtonDown(.LEFT))
		clay.UpdateScrollContainers(false, rl.GetMouseWheelMoveV(), rl.GetFrameTime())
		clay.SetLayoutDimensions({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())})

		clay.BeginLayout()
		build_frame()
		render_commands := clay.EndLayout(rl.GetFrameTime())

		rl.BeginDrawing()
		rl.ClearBackground(clay_color_to_rl_color(NORD_POLAR_0))
		clay_raylib_render(&render_commands)
		rl.EndDrawing()
	}
}

build_frame :: proc() {
	if clay.UI(clay.ID("App"))(
	{
		layout = {sizing = {clay.SizingGrow({}), clay.SizingGrow({})}, layoutDirection = .TopToBottom},
		backgroundColor = NORD_POLAR_0,
	},
	) {
		if clay.UI(clay.ID("Header"))(
		{
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(64)}, padding = {left = SPACE_LG, right = SPACE_LG}, childAlignment = {y = .Center}},
			backgroundColor = NORD_POLAR_1,
			border = {width = {bottom = 1}, color = NORD_POLAR_3},
		},
		) {
			clay.Text("tsb", {fontId = FONT_HEADING, fontSize = FONT_SIZE_DISPLAY, textColor = NORD_SNOW_2})
		}
	}
}
