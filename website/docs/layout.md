---
id: layout
title: Layout
---

# Layout

`Layout` divides a `Rect` into rows or columns. You describe each piece with a `Constraint`, and the solver turns the constraints into sizes that always fit inside the area.

## Splitting an area

```zig
const layout = tui.Layout{
    .direction = .vertical,
    .constraints = &.{ .{ .fixed = 3 }, .{ .fill = 1 }, .{ .fixed = 1 } },
};

var rows: [3]tui.Rect = undefined;
_ = layout.splitInto(buf.getArea(), &rows);

// rows[0] is the header, rows[1] the body, rows[2] the status bar
```

`splitInto` writes into storage you own and needs no allocator. The slice must hold exactly one `Rect` per constraint, and a layout can have at most `tui.layout.max_constraints` (64) constraints.

`split` allocates the result instead. Free it when you are done:

```zig
const rows = try layout.split(area, allocator);
defer allocator.free(rows);
```

## Constraints

| Constraint | Meaning |
| --- | --- |
| `.fixed` / `.length` | Exactly n cells |
| `.percentage` | A share of the full extent, from 0 to 100 |
| `.ratio` | A share of the full extent, as `.{ .numerator = 1, .denominator = 3 }` |
| `.min` | At least n cells. Absorbs leftover space when no `.fill` is present |
| `.max` | At most n cells. Gives space back first when space runs short |
| `.fill` | Takes leftover space, split by weight against the other `.fill`s |

Percentages and ratios are shares of the whole extent, not of what the other constraints leave over. Across 100 cells, `.{ .fixed = 10 }, .{ .percentage = 50 }` gives 10 and 50.

Shares that add up to the whole extent cover it exactly, with no cell lost to rounding. Two 50% columns across 101 cells get 51 and 50.

### Leftover space

When the constraints ask for less than the area holds:

- `.fill` constraints share the leftover by weight. Across 100 cells, `.{ .fixed = 10 }, .{ .fill = 1 }, .{ .fill = 2 }` gives 10, 30, and 60.
- With no `.fill`, `.min` constraints share it evenly. `.{ .min = 10 }, .{ .fixed = 5 }` gives 95 and 5.
- With neither, the leftover stays unallocated, and the last `Rect` ends before the edge of the area.

Use `.fill` for the pane that should take up the slack.

### When space runs short

When the constraints ask for more than the area holds, sizes shrink in this order: `.max` first, then `.ratio`, `.percentage`, `.fixed` and `.length`, and `.min` last. Within one kind, the cut is shared in proportion to size, so a pane shrinks instead of disappearing. `.{ .fixed = 10 }, .{ .fixed = 30 }` squeezed into 20 cells gives 7 and 13.

## Nesting layouts

Split a piece of one layout again to build a grid. This splits the screen into a title bar, a body, and a status bar, then splits the body into a sidebar and a main pane:

```zig
var rows: [3]tui.Rect = undefined;
_ = (tui.Layout{
    .direction = .vertical,
    .constraints = &.{ .{ .fixed = 1 }, .{ .fill = 1 }, .{ .fixed = 1 } },
}).splitInto(buf.getArea(), &rows);

var columns: [2]tui.Rect = undefined;
_ = (tui.Layout{
    .direction = .horizontal,
    .constraints = &.{ .{ .fixed = 24 }, .{ .fill = 1 } },
}).splitInto(rows[1], &columns);

const sidebar = columns[0];
const main_pane = columns[1];
```

## Margins

A margin shrinks the area before it is split:

```zig
const layout = tui.Layout{
    .direction = .horizontal,
    .constraints = &.{ .{ .percentage = 30 }, .{ .fill = 1 } },
    .margin = .{ .left = 2, .right = 2, .top = 1, .bottom = 1 },
};
```

`tui.layout.Margin` also has the constants `NONE`, `ALL_1`, and `ALL_2`. If the margin leaves no room, every resulting `Rect` is empty.

## Builder

`Layout.default()` returns a builder with the same options. Note that its `split` takes the allocator first, and that `margin` applies one value to all four sides:

```zig
const columns = try tui.Layout.default()
    .direction(.horizontal)
    .constraints(&.{ .{ .percentage = 30 }, .{ .fill = 1 } })
    .margin(1)
    .split(allocator, area);
defer allocator.free(columns);
```

## Rect helpers

Some splits don't need a full layout:

| Call | Result |
| --- | --- |
| `area.inner(1)` | The area shrunk by n cells on every side |
| `area.splitHorizontal(20)` | `.left` is the first 20 columns, `.right` is the rest |
| `area.splitVertical(3)` | `.top` is the first 3 rows, `.bottom` is the rest |
| `area.contains(x, y)` | Whether a cell is inside the area, for mouse hit testing |
| `block.inner(area)` | The content area inside a `Block`'s borders |
| `tui.centeredRectPct(area, 60, 40)` | A centered area, sized as percentages. See [Popup](./widgets/popup.md) |
| `tui.centeredRectFixed(area, 50, 10)` | A centered area of an exact size |
