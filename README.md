# tsb

**t**he-**s**indris-**b**ench — a small, fast toolbox written in [Odin](https://odin-lang.org/), built around one idea: diffing things well shouldn't need a runtime, a package manager, or a browser tab.

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

- **Diff engine** — three real algorithms, not one: Myers (default, exact shortest-edit-script), Patience, and Histogram, plus an O(n·m) reference implementation used to check the others against. Output renders as a proper unified diff (`@@` hunks, context lines, hunk merging/splitting) that matches `diff -u` byte for byte.
- **JSON pretty-printer** — a real hand-written recursive-descent JSON parser (full grammar: strings with escapes, numbers, nesting), not a whitespace hack. Reports line/column on malformed input.
- **Passphrase generator** — `correct-horse-battery-staple`-style, drawing from a ~23,700-word filtered English dictionary baked into the binary, using the OS's cryptographic entropy source (not a toy PRNG).
- **A native GUI** — in progress, built on [Clay](https://github.com/nicbarker/clay) + raylib, Nordic-themed. See [`gui/`](gui/).

## Usage

```
tsb <old-file> <new-file> [--algorithm=myers|patience|histogram]
tsb --pretty <file.json> [--indent=N]
tsb --passphrase [--words=N] [--separator=SEP] [--capitalize]
```

**Diff two files:**

```
$ tsb old.txt new.txt --algorithm=histogram
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
$ tsb --pretty sample.json --indent=2
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
$ tsb --passphrase
heaven-albino-flavorer-couscous

$ tsb --passphrase --words=6 --separator=_ --capitalize
Tranche_Clergy_Lief_Endive_Bevy_Normal
```

## Building

Requires the [Odin compiler](https://odin-lang.org/docs/install/).

```
./build.sh     # Linux/macOS -> ./tsb
build.bat      # Windows     -> tsb.exe
```

## Layout

```
main.odin, *_cmd.odin, tokenize.odin, unified_diff.odin   the CLI itself (package main)
diff/engine/     diffing algorithms: Myers, Patience, Histogram, and a reference DP implementation
json/            hand-written JSON parser + pretty-printer
password/        passphrase generator + bundled wordlist
gui/             native GUI (Clay + raylib), work in progress
vendor/clay/     vendored Clay bindings (see below)
```

## Testing

Every package has its own test suite, including file-based integration tests that write real fixtures to disk and read them back:

```
odin test diff/engine
odin test json
odin test password
odin test .
```

All algorithms are checked against each other and against the reference DP implementation (which is provably optimal) with property-based fuzz tests, not just hand-picked examples.

## License

`tsb`'s own code is [MIT-licensed](LICENSE).

`vendor/clay/` contains [Clay](https://github.com/nicbarker/clay), vendored under its own [zlib license](vendor/clay/LICENSE.md) (permissive, non-copyleft — see [`vendor/clay/NOTICE.md`](vendor/clay/NOTICE.md) for exactly what was taken and from where).
