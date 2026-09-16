---
id: date-picker
title: Date Picker
---

# Date Picker

A month calendar with one selected day and keyboard navigation. It stores only the selected date, so it needs no allocator.

## Usage

```zig
var picker = try tui.DatePicker.init(.{ .year = 2026, .month = 9, .day = 16 });
picker.header_style = .{ .modifier = .{ .bold = true } };
picker.weekday_style = .{ .fg = .dark_gray };
picker.selected_style = .{ .fg = .black, .bg = .cyan };

// In the event loop
if (event == .key) {
    _ = picker.handleKey(event.key);
}

// In the render function
picker.render(area, buf);

const date = picker.selected; // date.year, date.month, date.day
```

`init` returns `error.InvalidDate` for a date that doesn't exist, such as February 30.

## Layout

The title is centered on the first row, weekday names fill the second, and weeks start on Sunday:

```text
   September 2026
Su Mo Tu We Th Fr Sa
       1  2  3  4  5
 6  7  8  9 10 11 12
13 14 15 16 17 18 19
20 21 22 23 24 25 26
27 28 29 30
```

Give it an area 20 columns wide and 8 rows tall so that any month fits: a title row, a weekday row, and up to six weeks. A smaller area cuts off the rows and columns that don't fit.

## Keys

| Key | Moves the selection |
| --- | --- |
| Left / Right | One day |
| Up / Down | One week |
| Page Up / Page Down | One month. If the new month is shorter, the day moves to its last day |
| Home / End | The first or last day of the month |

Moves cross into the previous or next month and year. `handleKey` returns `true` when it used the key and `false` otherwise, so you can pass unused keys on to other widgets. It ignores key releases.

## Moving from code

```zig
picker.moveDays(-7);   // back one week
picker.moveMonths(12); // forward one year
```

Both take an `i8`. The selection never moves before January of year 1.

## Fields

| Field | Type | Description |
| --- | --- | --- |
| `selected` | `Date` | The selected day |
| `style` | `Style` | Base style. Fills the whole area |
| `header_style` | `Style` | The month and year title |
| `weekday_style` | `Style` | The row of weekday names |
| `selected_style` | `Style` | The selected day |

## `Date`

`tui.Date` has `year: u16`, `month: u8` from 1 to 12, and `day: u8`. `date.isValid()` checks that the day exists in that month. `tui.widgets.date_picker.daysInMonth(year, month)` and `tui.widgets.date_picker.isLeapYear(year)` are available for your own date math.
