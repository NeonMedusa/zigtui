---
id: unicode
title: Unicode and Text Width
---

# Unicode and Text Width

Not every character takes one terminal column. CJK characters and most emoji take two, and combining marks take none. The buffer measures text in columns, so wide characters line up and never spill past the width you give them.

## Measuring text

```zig
tui.codepointWidth('a');        // 1
tui.codepointWidth('日');       // 2
tui.codepointWidth(0x0301);     // 0, a combining accent

tui.stringWidth("日本語ab");     // 8
tui.truncateToWidth("日本", 3); // "日", never half of a wide character
```

| Function | Returns |
| --- | --- |
| `codepointWidth(cp: u21) u2` | The columns one codepoint takes: 0, 1, or 2 |
| `stringWidth(text: []const u8) usize` | The columns a UTF-8 string takes |
| `truncateToWidth(text: []const u8, max_columns: usize) []const u8` | The longest start of the string that fits, as a slice of it |

Control characters take 0 columns. Box-drawing, block, and Braille characters such as `─`, `╭`, `█`, and `⣿` take 1.

Use `stringWidth`, not `.len`, to center or right-align text. `.len` counts bytes: `"é".len` is 2 and `"日".len` is 3.

```zig
const label = "設定";
const width: u16 = @intCast(@min(tui.stringWidth(label), area.width));
buf.setString(area.x + (area.width - width) / 2, area.y, label, .{});
```

## Writing text

| Method | Behavior |
| --- | --- |
| `buf.setChar(x, y, cp, style)` | Writes one codepoint. A wide one also takes the next column |
| `buf.setString(x, y, text, style)` | Writes until the right edge of the buffer |
| `buf.putString(x, y, text, max_width, style)` | Writes at most `max_width` columns and returns how many it wrote |
| `buf.setStringTruncated(x, y, text, max_width, style)` | Like `putString`, but ends with `…` when the text doesn't fit |

`putString` and `setStringTruncated` stop before a wide character that would cross `max_width`. For example, `"日本語"` truncated to 5 columns becomes `日本…`.

The return value of `putString` tells you where the next piece of text starts:

```zig
var x = area.x;
x += buf.putString(x, area.y, "Status: ", area.width, .{ .fg = .cyan });
_ = buf.putString(x, area.y, "運行中", area.x + area.width - x, .{ .fg = .green });
```

## How cells store wide characters

A wide character takes two cells. The first holds the codepoint and has `width` 2. The second is a continuation cell with `width` 0, which `cell.isContinuation()` detects. Skip continuation cells when you read the buffer yourself, for example in tests.

The buffer never leaves half a wide character on screen:

- Writing over either half of a wide character blanks the other half.
- `setChar` replaces a wide character that would cross the right edge of the buffer with a space.

## Limitations

- **Combining marks are dropped.** Each cell holds one codepoint, so a combining mark can't attach to the character before it. `"e\u{0301}"` renders as `e`. The precomposed `é` (U+00E9) renders correctly.
- **Emoji sequences are measured one codepoint at a time.** Flags, skin tones, and sequences joined with U+200D can measure wider than the single glyph a terminal draws.
- **Ambiguous-width characters are narrow.** Characters such as `→`, `★`, and `α` take 1 column, which can disagree with terminals set to treat them as wide in CJK locales.
