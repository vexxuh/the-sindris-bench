# **t**he-**s**indris-**b**ench

**t**he-**s**indris-**b**ench — a small, fast developer toolbox written in [Odin](https://odin-lang.org/),

```
--- /tmp/old.txt
+++ /tmp/new.txt
@@ -1,8 +1,8 @@
 a
 b
-c
+X
 d
 e
-f
+Y
 g
 h
```

## What's in the box

- **Diff engine** — three diff algorithms: Myers (default, exact shortest-edit-script), Patience, and Histogram. Output renders as a proper unified diff (`@@` hunks, context lines, hunk merging/splitting) that matches `diff -u` byte for byte.
- **JSON pretty-printer** — a JSON parser (full grammar: strings with escapes, numbers, nesting). Reports line/column on malformed input.
- **Passphrase generator** — `correct-horse-battery-staple`-style, drawing from a ~23,700-word filtered English dictionary baked into the binary, using the OS's cryptographic entropy source.
- **A native GUI** — in progress, built on [Clay](https://github.com/nicbarker/clay) + raylib, Nordic-themed. See [`gui/`](gui/).

The main app is the **native GUI** (Clay + raylib, Nordic-themed). The original CLI still lives on in [`cli/`](cli/) with its own build.

## Building & running the GUI

Requires the [Odin compiler](https://odin-lang.org/docs/install/).

```
./build.sh     # Linux/macOS -> ./tsb
build.bat      # Windows     -> tsb.exe
./tsb
```

Or just `odin run gui` for local iteration. Must be run from the repo root (fonts load from `gui/assets/fonts/` relative to the working directory).

## CLI

The CLI (`tsb-cli`) exposes the same diff/JSON/passphrase tools as flags, useful for scripting:

```
cli/build.sh     # Linux/macOS -> cli/tsb-cli
cli/build.bat    # Windows     -> cli\tsb-cli.exe
```

```
tsb-cli <old-file> <new-file> [--algorithm=myers|patience|histogram]
tsb-cli --pretty <file.json> [--indent=N]
tsb-cli --passphrase [--words=N] [--separator=SEP] [--capitalize]
```

**Diff two files:**

```
$ tsb-cli old.txt new.txt --algorithm=histogram
--- old.txt
+++ new.txt
@@ -1,8 +1,8 @@
 a
 b
-c
+X
 d
 e
-f
+Y
 g
 h
```

Exit code mirrors `diff`: `0` if identical, `1` if they differ.

**Pretty-print JSON:**

```
$ tsb-cli --pretty sample.json --indent=2
{
  "name": "sindri",
  "tags": [
    "diff",
    "json"
  ],
  "nested": {
    "ok": true,
    "count": 3.5,
    "nil": null
  },
  "empty_arr": [],
  "empty_obj": {}
}
```

**Generate a passphrase:**

```
$ tsb-cli --passphrase
heaven-albino-flavorer-couscous

$ tsb-cli --passphrase --words=6 --separator=_ --capitalize
Tranche_Clergy_Lief_Endive_Bevy_Normal
```

## Layout

```
gui/             native GUI (Clay + raylib), the main app
cli/             CLI (package main), same tools as flags
diff/engine/     diffing algorithms: Myers, Patience, Histogram, and a reference DP implementation
json/            hand-written JSON parser + pretty-printer
password/        passphrase generator + bundled wordlist
vendor/clay/     vendored Clay bindings (see below)
```

## Testing

Every package has its own test suite, including file-based integration tests that write fixtures to disk and read them back:

```
odin test diff/engine
odin test json
odin test password
odin test cli
```

All algorithms are checked against each other and against the reference DP implementation with property-based fuzz tests.

## License

`tsb`'s own code is [MIT-licensed](LICENSE).

`vendor/clay/` contains [Clay](https://github.com/nicbarker/clay), vendored under its own [zlib license](vendor/clay/LICENSE.md) (permissive, non-copyleft — see [`vendor/clay/NOTICE.md`](vendor/clay/NOTICE.md) for exactly what was taken and from where).
