const std = @import("std");
const render = @import("../render/mod.zig");
const codepointWidth = render.codepointWidth;
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

pub fn TextInput(comptime max_bytes: usize) type {
    return struct {
        const Self = @This();

        buf: [max_bytes]u8 = undefined,
        /// Number of valid bytes currently stored.
        len: usize = 0,
        /// Byte offset of the cursor (always on a codepoint boundary).
        cursor: usize = 0,
        focused: bool = true,
        style: Style = .{},
        cursor_style: Style = .{},
        placeholder: []const u8 = "",
        placeholder_style: Style = .{},
        /// 是否绘制应用层方块光标。宿主用真实终端光标时置 false
        /// （否则会出现两个光标；坐标用 cursorScreenPos 计算）
        draw_fake_cursor: bool = true,
        /// 选区字节范围 [lo, hi)（由外部设置；null 表示无选区）。
        /// 与 TextArea.sel_range 同语义，用于 Ctrl+A 全选 / 剪切 / 拖选高亮。
        sel_range: ?[2]usize = null,

        /// Return the current text as a slice.
        pub fn value(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }

        /// Clear all content and reset cursor.
        pub fn clear(self: *Self) void {
            self.len = 0;
            self.cursor = 0;
            self.sel_range = null;
        }

        /// 选中全部文本（光标置尾，与 TextArea 语义一致）
        pub fn selectAll(self: *Self) void {
            if (self.len == 0) {
                self.sel_range = null;
                return;
            }
            self.sel_range = .{ 0, self.len };
            self.cursor = self.len;
        }

        /// 删除 [lo, hi) 区间（光标落在 lo）；无选区时无操作
        pub fn deleteRange(self: *Self, lo: usize, hi: usize) void {
            const a = @min(lo, self.len);
            const b = @min(hi, self.len);
            if (b <= a) return;
            std.mem.copyForwards(u8, self.buf[a .. self.len - (b - a)], self.buf[b..self.len]);
            self.len -= b - a;
            self.cursor = a;
            self.sel_range = null;
        }

        /// 当前选区字节范围（两端排序、越界裁剪）；无有效选区返回 null
        pub fn selectionRange(self: *const Self) ?[2]usize {
            const r = self.sel_range orelse return null;
            const a = @min(r[0], self.len);
            const b = @min(r[1], self.len);
            const lo = @min(a, b);
            const hi = @max(a, b);
            if (hi <= lo) return null;
            return .{ lo, hi };
        }

        /// 删除当前选区（无选区时无操作）
        pub fn deleteSelection(self: *Self) void {
            if (self.selectionRange()) |r| self.deleteRange(r[0], r[1]);
        }

        /// 方向键折叠选区（主流编辑器语义）：左/上折叠到左边缘、右/下折叠到右边缘。
        /// 清除选区并把光标移到边缘，返回 true 表示存在有效选区并已折叠
        /// （调用方不要再移动光标）。无选区/空选区返回 false。
        pub fn collapseSelection(self: *Self, to_right: bool) bool {
            const r = self.selectionRange() orelse {
                self.sel_range = null;
                return false;
            };
            self.sel_range = null;
            self.cursor = if (to_right) r[1] else r[0];
            return true;
        }

        fn isSelected(self: *const Self, off: usize) bool {
            const r = self.sel_range orelse return false;
            return off >= r[0] and off < r[1];
        }

        /// Insert a Unicode codepoint at the cursor position.
        pub fn insertCodepoint(self: *Self, cp: u21) void {
            var enc: [4]u8 = undefined;
            const cp_len = std.unicode.utf8Encode(cp, &enc) catch return;
            self.insertBytes(enc[0..cp_len]);
        }

        /// Insert raw bytes (must be valid UTF-8) at the cursor.
        pub fn insertBytes(self: *Self, bytes: []const u8) void {
            // 有选区：插入即替换选中内容（与 TextArea 的输入替换语义一致）
            if (self.selectionRange()) |r| self.deleteRange(r[0], r[1]);
            if (self.len + bytes.len > max_bytes) return;
            // Shift existing content right to make room
            if (self.cursor < self.len) {
                std.mem.copyBackwards(
                    u8,
                    self.buf[self.cursor + bytes.len .. self.len + bytes.len],
                    self.buf[self.cursor..self.len],
                );
            }
            @memcpy(self.buf[self.cursor .. self.cursor + bytes.len], bytes);
            self.len += bytes.len;
            self.cursor += bytes.len;
        }

        /// Delete the codepoint immediately before the cursor (backspace).
        pub fn deleteBackward(self: *Self) void {
            if (self.selectionRange()) |r| {
                self.deleteRange(r[0], r[1]);
                return;
            }
            if (self.cursor == 0) return;
            const cp_len = self.prevCodepointLen();
            const new_cursor = self.cursor - cp_len;
            std.mem.copyForwards(u8, self.buf[new_cursor .. self.len - cp_len], self.buf[self.cursor..self.len]);
            self.len -= cp_len;
            self.cursor = new_cursor;
        }

        /// Delete the codepoint immediately after the cursor (delete key).
        pub fn deleteForward(self: *Self) void {
            if (self.selectionRange()) |r| {
                self.deleteRange(r[0], r[1]);
                return;
            }
            if (self.cursor >= self.len) return;
            const cp_len = self.nextCodepointLen();
            std.mem.copyForwards(u8, self.buf[self.cursor .. self.len - cp_len], self.buf[self.cursor + cp_len .. self.len]);
            self.len -= cp_len;
        }

        pub fn moveCursorLeft(self: *Self) void {
            self.sel_range = null;
            if (self.cursor == 0) return;
            self.cursor -= self.prevCodepointLen();
        }

        pub fn moveCursorRight(self: *Self) void {
            self.sel_range = null;
            if (self.cursor >= self.len) return;
            self.cursor += self.nextCodepointLen();
        }

        pub fn moveCursorHome(self: *Self) void {
            self.sel_range = null;
            self.cursor = 0;
        }

        pub fn moveCursorEnd(self: *Self) void {
            self.sel_range = null;
            self.cursor = self.len;
        }

        /// 把光标设到指定字节偏移（自动裁剪到合法范围并对齐码点边界）
        pub fn setCursor(self: *Self, off: usize) void {
            self.sel_range = null;
            var o = @min(off, self.len);
            // 回退到码点起始字节（不能停在 UTF-8 连续字节上）
            while (o > 0 and o < self.len and (self.buf[o] & 0xC0) == 0x80) o -= 1;
            self.cursor = o;
        }

        pub fn render(self: *const Self, area: Rect, buf: *Buffer) void {
            if (area.width == 0 or area.height == 0) return;

            const text = self.value();

            if (text.len == 0 and self.placeholder.len > 0 and !self.focused) {
                buf.setStringTruncated(area.x, area.y, self.placeholder, area.width, self.placeholder_style);
                return;
            }

            // Layout is column-based: CJK and emoji occupy two terminal
            // columns, so advancing one column per code point would overwrite
            // the trailing cell of a wide character with the next glyph.
            // Columns occupied by the text before the cursor.
            const cursor_col: usize = blk: {
                var cols: usize = 0;
                var i: usize = 0;
                while (i < self.cursor and i < text.len) {
                    const d = decodeAt(text, i);
                    cols += codepointWidth(d.cp);
                    i += d.len;
                }
                break :blk cols;
            };

            // Scroll so the cursor column stays visible.
            const width: usize = area.width;
            const scroll: usize = if (cursor_col >= width) cursor_col - width + 1 else 0;

            // Draw the visible window; `skip` counts columns scrolled off.
            var x: u16 = area.x;
            var col: usize = 0;
            var cursor_drawn = false;
            var i: usize = 0;
            while (i < text.len) {
                const d = decodeAt(text, i);
                const w: usize = codepointWidth(d.cp);
                const col_end = col + w;
                // Characters fully scrolled off, or the cursor cell itself, are
                // not painted as text (the cursor is drawn below).
                if (col_end <= scroll) {
                    col = col_end;
                    i += d.len;
                    continue;
                }
                if (x + @as(u16, @intCast(w)) > area.x + area.width) break;

                const is_cursor = self.draw_fake_cursor and self.focused and col == cursor_col;
                const selected = self.isSelected(i);
                if (is_cursor) {
                    buf.setChar(x, area.y, d.cp, self.style.merge(self.cursor_style));
                    cursor_drawn = true;
                } else if (selected) {
                    // 选区高亮（与 TextArea 同风格：反色）
                    buf.setChar(x, area.y, d.cp, self.style.merge(.{ .modifier = .{ .reversed = true } }));
                } else {
                    buf.setChar(x, area.y, d.cp, self.style);
                }
                x += @intCast(w);
                col = col_end;
                i += d.len;
            }

            // Cursor at end-of-text (or on a scrolled-into-view column).
            if (self.draw_fake_cursor and self.focused and !cursor_drawn and x < area.x + area.width) {
                buf.setChar(x, area.y, ' ', self.style.merge(self.cursor_style));
                x += 1;
            }

            // Fill remainder with background style
            while (x < area.x + area.width) : (x += 1) {
                buf.setChar(x, area.y, ' ', self.style);
            }
        }

        /// 光标在渲染区内的屏幕坐标（供宿主定位真实终端光标；参数与 render 一致）。
        /// 与 render 的滚动逻辑保持一致：光标列超出宽度时向左滚动（cursor_col - width + 1）。
        /// 需将 draw_fake_cursor 置 false，否则会出现两个光标。
        pub fn cursorScreenPos(self: *const Self, area: Rect) ?[2]u16 {
            if (area.width == 0 or area.height == 0) return null;
            const text = self.value();
            var cursor_col: usize = 0;
            var i: usize = 0;
            while (i < self.cursor and i < text.len) {
                const d = decodeAt(text, i);
                cursor_col += codepointWidth(d.cp);
                i += d.len;
            }
            const width: usize = area.width;
            const scroll: usize = if (cursor_col >= width) cursor_col - width + 1 else 0;
            const col = cursor_col - scroll;
            return .{ area.x +| @as(u16, @intCast(@min(col, 0xFFFF))), area.y };
        }

        // ── Private helpers ───────────────────────────────────────────────────

        /// Decodes the code point at `bytes[index]` and its byte length.
        /// Malformed input yields U+FFFD with length 1 (advance one byte).
        fn decodeAt(bytes: []const u8, index: usize) struct { cp: u21, len: usize } {
            const seq = std.unicode.utf8ByteSequenceLength(bytes[index]) catch return .{ .cp = 0xFFFD, .len = 1 };
            if (index + seq > bytes.len) return .{ .cp = 0xFFFD, .len = 1 };
            const cp = std.unicode.utf8Decode(bytes[index .. index + seq]) catch return .{ .cp = 0xFFFD, .len = 1 };
            return .{ .cp = cp, .len = seq };
        }

        fn prevCodepointLen(self: *const Self) usize {
            // Walk backwards to find the start of the previous codepoint.
            var i = self.cursor;
            while (i > 0) {
                i -= 1;
                if (self.buf[i] & 0xC0 != 0x80) break; // not a continuation byte
            }
            return self.cursor - i;
        }

        fn nextCodepointLen(self: *const Self) usize {
            if (self.cursor >= self.len) return 0;
            const seq_len = std.unicode.utf8ByteSequenceLength(self.buf[self.cursor]) catch return 1;
            return @min(seq_len, self.len - self.cursor);
        }
    };
}

test "TextInput selection: collapse to edge on arrow keys" {
    var input = TextInput(64){};
    input.insertBytes("hello world");

    // 左折：光标到左边缘
    input.cursor = 5;
    input.sel_range = .{ 2, 8 };
    try std.testing.expect(input.collapseSelection(false));
    try std.testing.expectEqual(@as(usize, 2), input.cursor);
    try std.testing.expect(input.sel_range == null);

    // 右折：光标到右边缘
    input.sel_range = .{ 2, 8 };
    try std.testing.expect(input.collapseSelection(true));
    try std.testing.expectEqual(@as(usize, 8), input.cursor);
    try std.testing.expect(input.sel_range == null);

    // 反向区间：按数值边缘
    input.sel_range = .{ 8, 2 };
    try std.testing.expect(input.collapseSelection(false));
    try std.testing.expectEqual(@as(usize, 2), input.cursor);

    // 无选区：返回 false
    try std.testing.expect(!input.collapseSelection(true));
}

test "TextInput cursorScreenPos follows cursor and scroll" {
    var input = TextInput(64){};
    input.insertBytes("hello");
    // 光标在末尾（列 5）：x = 2 + 5 = 7
    var pos = input.cursorScreenPos(.{ .x = 2, .y = 3, .width = 10, .height = 1 }).?;
    try std.testing.expectEqual(@as(u16, 7), pos[0]);
    try std.testing.expectEqual(@as(u16, 3), pos[1]);

    // 光标移到行首：x = 2
    input.moveCursorHome();
    pos = input.cursorScreenPos(.{ .x = 2, .y = 3, .width = 10, .height = 1 }).?;
    try std.testing.expectEqual(@as(u16, 2), pos[0]);

    // 宽度 4、光标列 5：scroll = 2 → col 3 → x = 3
    input.moveCursorEnd();
    pos = input.cursorScreenPos(.{ .x = 0, .y = 0, .width = 4, .height = 1 }).?;
    try std.testing.expectEqual(@as(u16, 3), pos[0]);
}

test "TextInput insert and delete" {
    var input = TextInput(64){};
    input.insertCodepoint('H');
    input.insertCodepoint('i');
    try std.testing.expectEqualStrings("Hi", input.value());

    input.deleteBackward();
    try std.testing.expectEqualStrings("H", input.value());
}

test "TextInput cursor movement" {
    var input = TextInput(64){};
    input.insertCodepoint('A');
    input.insertCodepoint('B');
    input.insertCodepoint('C');
    input.moveCursorHome();
    try std.testing.expectEqual(@as(usize, 0), input.cursor);
    input.moveCursorEnd();
    try std.testing.expectEqual(@as(usize, 3), input.cursor);
    input.moveCursorLeft();
    try std.testing.expectEqual(@as(usize, 2), input.cursor);
}

test "TextInput insert in middle" {
    var input = TextInput(64){};
    input.insertCodepoint('A');
    input.insertCodepoint('C');
    input.moveCursorLeft();
    input.insertCodepoint('B');
    try std.testing.expectEqualStrings("ABC", input.value());
}

test "TextInput selection: selectAll / deleteSelection / insert replaces" {
    var input = TextInput(64){};
    input.insertBytes("sk-abc123");
    input.selectAll();
    try std.testing.expectEqual(@as(usize, 9), input.selectionRange().?[1]);
    input.deleteSelection();
    try std.testing.expectEqualStrings("", input.value());
    try std.testing.expectEqual(@as(usize, 0), input.cursor);

    // 插入替换选区
    input.insertBytes("old");
    input.selectAll();
    input.insertBytes("new");
    try std.testing.expectEqualStrings("new", input.value());

    // backspace 删除选区
    input.selectAll();
    input.deleteBackward();
    try std.testing.expectEqualStrings("", input.value());
}

test "TextInput selection: deleteRange clamps and clears sel" {
    var input = TextInput(64){};
    input.insertBytes("abcdef");
    input.sel_range = .{ 2, 4 };
    input.deleteRange(2, 4);
    try std.testing.expectEqualStrings("abef", input.value());
    try std.testing.expectEqual(@as(usize, 2), input.cursor);
    try std.testing.expect(input.sel_range == null);
    // 越界裁剪
    input.sel_range = .{ 1, 999 };
    input.deleteSelection();
    try std.testing.expectEqualStrings("a", input.value());
}

test "TextInput renders wide characters at correct columns" {
    var input = TextInput(64){};
    input.insertBytes("hi,你好");
    input.insertCodepoint(0x1F60A); // 😊 emoji, 2 columns

    var buf = try render.Buffer.init(std.testing.allocator, 20, 1);
    defer buf.deinit();
    input.render(.{ .x = 0, .y = 0, .width = 20, .height = 1 }, &buf);

    // Expected layout: h i , 你 好 😊
    // Columns:        0 1 2 3 4 5 6 7 8
    var cells: [20]u21 = undefined;
    var widths: [20]u2 = undefined;
    for (0..20) |i| {
        const c = buf.get(@intCast(i), 0).?;
        cells[i] = c.char;
        widths[i] = c.width;
    }

    try std.testing.expectEqual(@as(u21, 'h'), cells[0]);
    try std.testing.expectEqual(@as(u21, 'i'), cells[1]);
    try std.testing.expectEqual(@as(u21, ','), cells[2]);
    try std.testing.expectEqual(@as(u21, 0x4F60), cells[3]); // 你
    try std.testing.expectEqual(@as(u2, 2), widths[3]);
    try std.testing.expectEqual(@as(u2, 0), widths[4]); // continuation cell
    try std.testing.expectEqual(@as(u21, 0x597D), cells[5]); // 好
    try std.testing.expectEqual(@as(u2, 2), widths[5]);
    try std.testing.expectEqual(@as(u2, 0), widths[6]); // continuation cell
    try std.testing.expectEqual(@as(u21, 0x1F60A), cells[7]); // 😊
    try std.testing.expectEqual(@as(u2, 2), widths[7]);
    try std.testing.expectEqual(@as(u2, 0), widths[8]); // continuation cell
    // The glyph right after a wide character must not have clobbered its pair.
    try std.testing.expectEqual(@as(u2, 1), widths[9]);
}

test "TextInput cursor column accounts for wide characters" {
    var input = TextInput(64){};
    input.insertBytes("a");
    input.insertCodepoint(0x5F00); // 开, 2 columns
    input.insertBytes("b");
    // cursor at end (after 'b'): display column should be 1 + 2 + 1 = 4
    var buf = try render.Buffer.init(std.testing.allocator, 12, 1);
    defer buf.deinit();
    input.render(.{ .x = 0, .y = 0, .width = 12, .height = 1 }, &buf);
    // cursor cell (space with cursor style) should sit at column 4
    const c = buf.get(4, 0).?;
    try std.testing.expectEqual(@as(u21, ' '), c.char);
}

test "TextInput cursor on a wide character keeps it intact" {
    var input = TextInput(64){};
    input.insertCodepoint(0x5F00); // 开 (2 columns)
    input.insertCodepoint(0x5FC3); // 心 (2 columns)
    input.moveCursorHome(); // cursor before 开
    input.moveCursorRight(); // cursor before 心

    var buf = try render.Buffer.init(std.testing.allocator, 8, 1);
    defer buf.deinit();
    input.render(.{ .x = 0, .y = 0, .width = 8, .height = 1 }, &buf);

    // 开 at columns 0-1 (not covered by the cursor), 心 at columns 2-3 (cursor).
    try std.testing.expectEqual(@as(u21, 0x5F00), buf.get(0, 0).?.char);
    try std.testing.expectEqual(@as(u2, 2), buf.get(0, 0).?.width);
    try std.testing.expectEqual(@as(u21, 0x5FC3), buf.get(2, 0).?.char);
    try std.testing.expectEqual(@as(u2, 2), buf.get(2, 0).?.width);
    try std.testing.expectEqual(@as(u2, 0), buf.get(3, 0).?.width); // continuation
}

test "TextInput scroll window is column-based" {
    var input = TextInput(128){};
    // 6 wide characters (12 columns) then "ab"; area is 6 columns wide.
    var n: usize = 0;
    while (n < 6) : (n += 1) input.insertCodepoint(0x5F00); // 开 ×6
    input.insertBytes("ab");
    input.moveCursorEnd();

    var buf = try render.Buffer.init(std.testing.allocator, 6, 1);
    defer buf.deinit();
    input.render(.{ .x = 0, .y = 0, .width = 6, .height = 1 }, &buf);

    // Cursor column = 14, width 6 -> scroll = 9. Visible columns 9..14:
    // 开 #5 occupies columns 8-9 (column 8 scrolled off, partially visible
    // columns start at 9), then 'a' at 10, 'b' at 11, cursor at 12.
    // The important invariant: 'a' and 'b' must be present, at columns 10/11.
    var seen_a = false;
    var seen_b = false;
    for (0..6) |i| {
        const c = buf.get(@intCast(i), 0).?.char;
        if (c == 'a') seen_a = true;
        if (c == 'b') seen_b = true;
    }
    try std.testing.expect(seen_a and seen_b);
}

test "TextInput placeholder is width-clamped" {
    var input = TextInput(64){};
    input.focused = false;
    input.placeholder = "开开心心开心";
    var buf = try render.Buffer.init(std.testing.allocator, 5, 1);
    defer buf.deinit();
    input.render(.{ .x = 0, .y = 0, .width = 5, .height = 1 }, &buf);
    // setStringTruncated must not leave a broken wide pair at the edge.
    var col: u16 = 0;
    while (col < 5) : (col += 1) {
        const c = buf.get(col, 0).?;
        if (c.width == 0) {
            // continuation cell must follow a wide lead
            try std.testing.expect(col > 0 and buf.get(col - 1, 0).?.width == 2);
        }
    }
}
