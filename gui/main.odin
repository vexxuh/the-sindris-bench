package main

import "core:fmt"
import clay "../vendor/clay/clay-odin"

main :: proc() {
	min_memory_size := clay.MinMemorySize()
	arena_backing := make([]u8, min_memory_size)
	defer delete(arena_backing)

	arena := clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), raw_data(arena_backing))
	clay.Initialize(arena, {800, 600}, {})

	clay.BeginLayout()
	if clay.UI(clay.ID("Root"))({layout = {sizing = {clay.SizingGrow({}), clay.SizingGrow({})}}}) {}
	commands := clay.EndLayout(0)

	fmt.printfln("clay linked OK: arena=%d bytes, render commands=%d", min_memory_size, commands.length)
}
