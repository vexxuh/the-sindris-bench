package main

import clay "../vendor/clay/clay-odin"

// Nord (https://www.nordtheme.com), dark. Four named layers instead of a
// generic "grey scale": each step up is a real elevation level (canvas ->
// panel -> raised surface -> border), not an arbitrary shade.
NORD_POLAR_0 :: clay.Color{46, 52, 64, 255} // canvas background
NORD_POLAR_1 :: clay.Color{59, 66, 82, 255} // panels / cards
NORD_POLAR_2 :: clay.Color{67, 76, 94, 255} // raised surfaces, input fields
NORD_POLAR_3 :: clay.Color{76, 86, 106, 255} // borders / dividers

NORD_SNOW_0 :: clay.Color{216, 222, 233, 255} // muted / placeholder text
NORD_SNOW_1 :: clay.Color{229, 233, 240, 255} // secondary text
NORD_SNOW_2 :: clay.Color{236, 239, 244, 255} // primary text

NORD_FROST_TEAL :: clay.Color{143, 188, 187, 255} // sparing secondary tint
NORD_FROST_LIGHT :: clay.Color{136, 192, 208, 255} // the one dominant accent
NORD_FROST_MID :: clay.Color{129, 161, 193, 255}
NORD_FROST_DEEP :: clay.Color{94, 129, 172, 255} // pressed / deeper accent

// Aurora: semantic use only (diff +/-, warnings, rare highlight), never UI chrome.
NORD_AURORA_RED :: clay.Color{191, 97, 106, 255} // diff delete
NORD_AURORA_ORANGE :: clay.Color{208, 135, 112, 255}
NORD_AURORA_YELLOW :: clay.Color{235, 203, 139, 255} // warning
NORD_AURORA_GREEN :: clay.Color{163, 190, 140, 255} // diff insert
NORD_AURORA_PURPLE :: clay.Color{180, 142, 173, 255} // rare highlight

// Spacing scale, multiples of 4 like most Clay examples use.
SPACE_XS :: 4
SPACE_SM :: 8
SPACE_MD :: 16
SPACE_LG :: 24
SPACE_XL :: 32

RADIUS_SM :: 4
RADIUS_MD :: 8

// Font ids: Clay identifies fonts by a small integer handed to
// SetMeasureTextFunction / TextElementConfig, resolved to an actual raylib
// Font by the renderer (see renderer_raylib.odin).
FONT_HEADING :: 0 // Space Grotesk — headings, tracked-uppercase labels
FONT_BODY :: 1 // Inter — body/UI chrome
FONT_MONO :: 2 // JetBrains Mono — diff/JSON content, meta chrome

// Type scale. Hermes-style contrast: a couple of big display sizes against
// several small, precise UI sizes, rather than a smooth linear ramp.
FONT_SIZE_DISPLAY :: 32
FONT_SIZE_TITLE :: 20
FONT_SIZE_LABEL :: 13
FONT_SIZE_BODY :: 15
FONT_SIZE_MONO :: 14
FONT_SIZE_EYEBROW :: 11

// Letter-spacing for tracked uppercase labels/eyebrows (Hermes-style).
TRACKING_EYEBROW :: 2
