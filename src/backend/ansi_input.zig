const std = @import("std");
const events = @import("../events/mod.zig");

pub const ParseResult = union(enum) {
    complete: Complete,
    incomplete,
    invalid: usize,
};

pub const Complete = struct {
    event: events.Event,
    consumed: usize,
};

pub fn parse(input: []const u8) ParseResult {
    if (input.len == 0) return .incomplete;

    if (input[0] != 0x1b) {
        return parseUtf8(input);
    }

    // A lone ESC is either the Esc key or the first byte of a sequence whose
    // rest has not been read yet. Only waiting tells them apart, which is left
    // to the caller; see `parseStale`.
    if (input.len == 1) return .incomplete;

    switch (input[1]) {
        '[' => return parseCsi(input),
        'O' => return parseSs3(input),
        else => return parseAlt(input),
    }
}

/// Parse input that no more bytes are coming for, because the escape timeout
/// passed without the terminal sending any. A lone ESC is then the Esc key, ESC
/// plus one byte is that key with Alt held, and a longer sequence was cut short,
/// so its ESC stands alone. Never returns `.incomplete` for non-empty input.
pub fn parseStale(input: []const u8) ParseResult {
    const result = parse(input);
    if (result != .incomplete or input.len == 0) return result;

    // A truncated UTF-8 sequence.
    if (input[0] != 0x1b) return .{ .invalid = 1 };

    if (input.len == 2) {
        return .{ .complete = .{ .event = .{ .key = .{ .code = .{ .char = input[1] }, .modifiers = .{ .alt = true } } }, .consumed = 2 } };
    }
    return .{ .complete = .{ .event = .{ .key = .{ .code = .esc } }, .consumed = 1 } };
}

fn parseUtf8(input: []const u8) ParseResult {
    const first = input[0];
    if (first < 0x80) {
        return .{ .complete = .{ .event = parseAsciiControl(first), .consumed = 1 } };
    }

    const len = std.unicode.utf8ByteSequenceLength(first) catch {
        return .{ .invalid = 1 };
    };

    if (input.len < len) return .incomplete;

    const cp = std.unicode.utf8Decode(input[0..len]) catch {
        return .{ .invalid = len };
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = .{ .char = cp } } }, .consumed = len } };
}

fn parseAsciiControl(byte: u8) events.Event {
    return switch (byte) {
        '\r' => .{ .key = .{ .code = .enter } },
        // LF（Ctrl+J）：作为换行字符交给应用处理，而不是当成回车
        '\n' => .{ .key = .{ .code = .{ .char = '\n' } } },
        '\t' => .{ .key = .{ .code = .tab } },
        8, 127 => .{ .key = .{ .code = .backspace } },
        1...7, 11...12, 14...26 => |ctrl| .{
            .key = .{
                .code = .{ .char = @as(u21, ctrl - 1 + 'a') },
                .modifiers = .{ .ctrl = true },
            },
        },
        else => .{ .key = .{ .code = .{ .char = byte } } },
    };
}

fn parseAlt(input: []const u8) ParseResult {
    if (input.len < 2) return .incomplete;

    const c = input[1];
    if (c >= 32 and c < 127) {
        return .{ .complete = .{ .event = .{ .key = .{ .code = .{ .char = c }, .modifiers = .{ .alt = true } } }, .consumed = 2 } };
    }

    return .{ .invalid = 1 };
}

fn parseSs3(input: []const u8) ParseResult {
    if (input.len < 3) return .incomplete;

    const code: events.KeyCode = switch (input[2]) {
        'P' => .{ .f = 1 },
        'Q' => .{ .f = 2 },
        'R' => .{ .f = 3 },
        'S' => .{ .f = 4 },
        'H' => .home,
        'F' => .end,
        'A' => .up,
        'B' => .down,
        'C' => .right,
        'D' => .left,
        else => return .{ .invalid = 3 },
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = code } }, .consumed = 3 } };
}

fn parseCsi(input: []const u8) ParseResult {
    var i: usize = 2;
    while (i < input.len) : (i += 1) {
        const b = input[i];
        if (b >= 0x40 and b <= 0x7e) break;
    }

    if (i >= input.len) return .incomplete;

    const final = input[i];
    const params = input[2..i];
    const consumed = i + 1;

    switch (final) {
        'A', 'B', 'C', 'D', 'H', 'F', 'Z', 'P', 'Q', 'R', 'S' => {
            return parseCsiLetter(params, final, consumed);
        },
        '~' => return parseCsiTilde(params, consumed),
        'u' => return parseCsiU(params, consumed),
        'M', 'm' => {
            // SGR mouse: CSI < Cb ; Cx ; Cy M/m  (press/release)
            if (params.len > 0 and params[0] == '<') {
                return parseSgrMouse(params[1..], final, consumed);
            }
            return .{ .complete = .{ .event = .none, .consumed = consumed } };
        },
        else => return .{ .complete = .{ .event = .none, .consumed = consumed } },
    }
}

fn parseCsiLetter(params: []const u8, final: u8, consumed: usize) ParseResult {
    const parsed = parseParams(params);
    const mods = decodeModifiers(parsed.modifiers);

    const code: events.KeyCode = switch (final) {
        'A' => .up,
        'B' => .down,
        'C' => .right,
        'D' => .left,
        'H' => .home,
        'F' => .end,
        'Z' => .back_tab,
        'P' => .{ .f = 1 },
        'Q' => .{ .f = 2 },
        'R' => .{ .f = 3 },
        'S' => .{ .f = 4 },
        else => return .{ .complete = .{ .event = .none, .consumed = consumed } },
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = code, .modifiers = mods } }, .consumed = consumed } };
}

fn parseCsiTilde(params: []const u8, consumed: usize) ParseResult {
    const parsed = parseParams(params);
    const mods = decodeModifiers(parsed.modifiers);

    const code: events.KeyCode = switch (parsed.primary) {
        1, 7 => .home,
        4, 8 => .end,
        2 => .insert,
        3 => .delete,
        5 => .page_up,
        6 => .page_down,
        11 => .{ .f = 1 },
        12 => .{ .f = 2 },
        13 => .{ .f = 3 },
        14 => .{ .f = 4 },
        15 => .{ .f = 5 },
        17 => .{ .f = 6 },
        18 => .{ .f = 7 },
        19 => .{ .f = 8 },
        20 => .{ .f = 9 },
        21 => .{ .f = 10 },
        23 => .{ .f = 11 },
        24 => .{ .f = 12 },
        29 => .menu,
        else => return .{ .complete = .{ .event = .none, .consumed = consumed } },
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = code, .modifiers = mods } }, .consumed = consumed } };
}

fn parseCsiU(params: []const u8, consumed: usize) ParseResult {
    var key_code: ?u32 = null;
    var modifiers_value: u32 = 1;
    var event_type_value: u32 = 1;

    var field_index: u8 = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= params.len) : (i += 1) {
        if (i == params.len or params[i] == ';') {
            const field = params[start..i];
            switch (field_index) {
                0 => {
                    key_code = parseFirstSubfield(field) orelse return .{ .invalid = consumed };
                },
                1 => {
                    const parsed = parseTwoSubfields(field);
                    if (parsed.first) |v| modifiers_value = v;
                    if (parsed.second) |v| event_type_value = v;
                },
                // Field 2 carries text-as-codepoints (associated text).
                // Not yet supported; silently discarded.
                else => {},
            }
            field_index += 1;
            start = i + 1;
        }
    }

    const code_value = key_code orelse return .{ .invalid = consumed };
    if (code_value == 0) {
        return .{ .complete = .{ .event = .none, .consumed = consumed } };
    }

    const key_code_mapped = mapKeyCode(code_value) orelse return .{ .complete = .{ .event = .none, .consumed = consumed } };
    const modifiers = decodeModifiers(modifiers_value);
    const kind = decodeEventType(event_type_value);

    return .{ .complete = .{ .event = .{ .key = .{ .code = key_code_mapped, .modifiers = modifiers, .kind = kind } }, .consumed = consumed } };
}

fn parseSgrMouse(params: []const u8, final: u8, consumed: usize) ParseResult {
    // params = "Cb;Cx;Cy", final = 'M' (press/motion) or 'm' (release)
    var fields: [3]u32 = .{ 0, 0, 0 };
    var field_index: usize = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= params.len) : (i += 1) {
        if (i == params.len or params[i] == ';') {
            if (field_index < 3) {
                fields[field_index] = parseNumber(params[start..i]) orelse 0;
            }
            field_index += 1;
            start = i + 1;
        }
    }
    if (field_index < 3) return .{ .complete = .{ .event = .none, .consumed = consumed } };

    const cb = fields[0];
    const cx = fields[1];
    const cy = fields[2];

    // Decode button and event kind from cb
    const button_bits = cb & 0b11;
    const is_motion = (cb & 32) != 0;
    const is_scroll = (cb & 64) != 0;

    var kind: events.MouseEventKind = undefined;
    var button: events.MouseButton = .left;

    if (is_scroll) {
        kind = if (button_bits == 0) .scroll_up else .scroll_down;
    } else if (final == 'm') {
        kind = .up;
        button = switch (button_bits) {
            0 => .left,
            1 => .middle,
            2 => .right,
            else => .left,
        };
    } else if (is_motion) {
        kind = .moved;
        button = switch (button_bits) {
            0 => .left,
            1 => .middle,
            2 => .right,
            else => .left,
        };
    } else {
        kind = .down;
        button = switch (button_bits) {
            0 => .left,
            1 => .middle,
            2 => .right,
            else => .left,
        };
    }

    const modifiers = events.KeyModifiers{
        .shift = (cb & 4) != 0,
        .alt = (cb & 8) != 0,
        .ctrl = (cb & 16) != 0,
    };

    // SGR coordinates are 1-based
    const x: u16 = if (cx > 0) @intCast(cx - 1) else 0;
    const y: u16 = if (cy > 0) @intCast(cy - 1) else 0;

    return .{ .complete = .{ .event = .{ .mouse = .{
        .kind = kind,
        .button = button,
        .x = x,
        .y = y,
        .modifiers = modifiers,
    } }, .consumed = consumed } };
}

fn parseParams(params: []const u8) struct { primary: u32, modifiers: u32 } {
    var primary: u32 = 0;
    var modifiers: u32 = 1;

    var field_index: u8 = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= params.len) : (i += 1) {
        if (i == params.len or params[i] == ';') {
            const field = params[start..i];
            if (field_index == 0) {
                primary = parseNumber(field) orelse 0;
            } else if (field_index == 1) {
                modifiers = parseNumber(field) orelse 1;
            }
            field_index += 1;
            start = i + 1;
        }
    }

    return .{ .primary = primary, .modifiers = modifiers };
}

fn parseFirstSubfield(field: []const u8) ?u32 {
    var i: usize = 0;
    while (i <= field.len) : (i += 1) {
        if (i == field.len or field[i] == ':') {
            return parseNumber(field[0..i]);
        }
    }
    return null;
}

fn parseTwoSubfields(field: []const u8) struct { first: ?u32, second: ?u32 } {
    var first: ?u32 = null;
    var second: ?u32 = null;

    var index: u8 = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= field.len) : (i += 1) {
        if (i == field.len or field[i] == ':') {
            const part = field[start..i];
            const value = parseNumber(part);
            if (index == 0) first = value else if (index == 1) second = value;
            index += 1;
            start = i + 1;
        }
    }

    return .{ .first = first, .second = second };
}

fn parseNumber(bytes: []const u8) ?u32 {
    if (bytes.len == 0 or bytes.len > 10) return null;
    var value: u32 = 0;
    for (bytes) |b| {
        if (b < '0' or b > '9') return null;
        value = std.math.mul(u32, value, 10) catch return null;
        value = std.math.add(u32, value, @as(u32, b - '0')) catch return null;
    }
    return value;
}

fn decodeModifiers(value: u32) events.KeyModifiers {
    if (value == 0) return .{};
    const mask: u32 = value - 1;

    return .{
        .shift = (mask & 0b0000_0001) != 0,
        .alt = (mask & 0b0000_0010) != 0,
        .ctrl = (mask & 0b0000_0100) != 0,
        .super = (mask & 0b0000_1000) != 0,
        .hyper = (mask & 0b0001_0000) != 0,
        .meta = (mask & 0b0010_0000) != 0,
        .caps_lock = (mask & 0b0100_0000) != 0,
        .num_lock = (mask & 0b1000_0000) != 0,
    };
}

fn decodeEventType(value: u32) events.KeyEventKind {
    return switch (value) {
        2 => .repeat,
        3 => .release,
        else => .press,
    };
}

fn mapKeyCode(code: u32) ?events.KeyCode {
    switch (code) {
        9 => return .tab,
        13 => return .enter,
        27 => return .esc,
        127 => return .backspace,
        // Navigation keys (PUA, used under report-all-keys mode)
        57348 => return .insert,
        57349 => return .delete,
        57350 => return .left,
        57351 => return .right,
        57352 => return .up,
        57353 => return .down,
        57354 => return .page_up,
        57355 => return .page_down,
        57356 => return .home,
        57357 => return .end,
        // Lock/misc keys
        57358 => return .caps_lock,
        57359 => return .scroll_lock,
        57360 => return .num_lock,
        57361 => return .print_screen,
        57362 => return .pause,
        57363 => return .menu,
        // F13-F35 (PUA)
        57376...57398 => return .{ .f = @intCast(code - 57376 + 13) },
        else => {},
    }

    if (code >= 57344 and code <= 63743) {
        return .{ .functional = code };
    }

    if (code <= 0x10FFFF and !std.unicode.isSurrogateCodepoint(@intCast(code))) {
        return .{ .char = @intCast(code) };
    }

    return null;
}

test "parse CSI u basic" {
    const input = "\x1b[97;6u";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    try std.testing.expectEqual(@as(usize, input.len), complete.consumed);
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode{ .char = 'a' }, key.code);
            try std.testing.expect(key.modifiers.ctrl);
            try std.testing.expect(key.modifiers.shift);
            try std.testing.expect(!key.modifiers.alt);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse CSI u repeat" {
    const input = "\x1b[97;1:2u";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode{ .char = 'a' }, key.code);
            try std.testing.expectEqual(events.KeyEventKind.repeat, key.kind);
            try std.testing.expect(!key.modifiers.ctrl);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse CSI modified arrow" {
    const input = "\x1b[1;5C";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode.right, key.code);
            try std.testing.expect(key.modifiers.ctrl);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse utf8 multibyte" {
    const input = "\xE2\x82\xAC";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode{ .char = 0x20AC }, key.code);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse incomplete CSI" {
    const input = "\x1b[1;5";
    const result = parse(input);
    try std.testing.expect(result == .incomplete);
}

test "parse SGR mouse left click" {
    const input = "\x1b[<0;10;20M";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    try std.testing.expectEqual(@as(usize, input.len), complete.consumed);
    switch (complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.down, mouse.kind);
            try std.testing.expectEqual(events.MouseButton.left, mouse.button);
            try std.testing.expectEqual(@as(u16, 9), mouse.x);
            try std.testing.expectEqual(@as(u16, 19), mouse.y);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse SGR mouse release" {
    const input = "\x1b[<0;5;3m";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    switch (result.complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.up, mouse.kind);
            try std.testing.expectEqual(events.MouseButton.left, mouse.button);
            try std.testing.expectEqual(@as(u16, 4), mouse.x);
            try std.testing.expectEqual(@as(u16, 2), mouse.y);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse SGR mouse scroll up" {
    const input = "\x1b[<64;1;1M";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    switch (result.complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.scroll_up, mouse.kind);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse SGR mouse right click with ctrl" {
    const input = "\x1b[<18;15;10M";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    switch (result.complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.down, mouse.kind);
            try std.testing.expectEqual(events.MouseButton.right, mouse.button);
            try std.testing.expect(mouse.modifiers.ctrl);
        },
        else => return error.TestExpectedEqual,
    }
}

fn expectKey(result: ParseResult, code: events.KeyCode, modifiers: events.KeyModifiers, consumed: usize) !void {
    try std.testing.expect(result == .complete);
    try std.testing.expectEqual(consumed, result.complete.consumed);
    switch (result.complete.event) {
        .key => |key| {
            try std.testing.expectEqual(code, key.code);
            try std.testing.expectEqual(modifiers, key.modifiers);
        },
        else => return error.TestExpectedEqual,
    }
}

test "lone ESC waits for the rest of a split sequence" {
    try std.testing.expect(parse("\x1b") == .incomplete);
    try expectKey(parse("\x1b[13;2u"), .enter, .{ .shift = true }, 7);
}

test "stale lone ESC is the Esc key" {
    try expectKey(parseStale("\x1b"), .esc, .{}, 1);
}

test "stale ESC and one byte is that key with Alt" {
    try expectKey(parseStale("\x1b["), .{ .char = '[' }, .{ .alt = true }, 2);
    try expectKey(parseStale("\x1bO"), .{ .char = 'O' }, .{ .alt = true }, 2);
}

test "stale sequence cut short keeps only its ESC" {
    try expectKey(parseStale("\x1b[1;5"), .esc, .{}, 1);
}

test "stale input that already parses is unchanged" {
    try expectKey(parseStale("\x1b[A"), .up, .{}, 3);
    try expectKey(parseStale("a"), .{ .char = 'a' }, .{}, 1);
    try std.testing.expect(parseStale("\xE2\x82") == .invalid);
}

// ── 有状态解析器：bracketed paste（DECSET 2004）支持 ──

const paste_start = "\x1b[200~";
const paste_end = "\x1b[201~";
const max_parser_buffer = 1 << 20; // 1 MiB

/// 流式输入解析器：累积字节并逐个产出事件。
/// 在 `parse()` 之上增加了 bracketed paste 的状态管理：
/// 终端以 `ESC[200~ ... ESC[201~` 包裹粘贴内容时，产出单个 `.paste` 事件，
/// 其中的换行不会退化成为 Enter 按键。
pub const Parser = struct {
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    paste_payload: std.ArrayListUnmanaged(u8) = .empty,
    in_paste: bool = false,

    pub fn deinit(self: *Parser, allocator: std.mem.Allocator) void {
        self.buffer.deinit(allocator);
        self.paste_payload.deinit(allocator);
    }

    /// 追加原始输入字节
    pub fn feed(self: *Parser, allocator: std.mem.Allocator, bytes: []const u8) !void {
        try self.buffer.appendSlice(allocator, bytes);
        if (self.buffer.items.len > max_parser_buffer) {
            // 防御：异常膨胀的未解析缓冲直接丢弃
            self.buffer.clearRetainingCapacity();
            self.in_paste = false;
            self.paste_payload.clearRetainingCapacity();
        }
    }

    /// 尝试解析下一个事件；null 表示需要更多数据。
    /// 返回 `.paste` 时，其切片在下次调用 next()/feed() 前有效。
    pub fn next(self: *Parser, allocator: std.mem.Allocator) ?events.Event {
        while (true) {
            if (self.in_paste) {
                if (std.mem.indexOf(u8, self.buffer.items, paste_end)) |pos| {
                    self.paste_payload.appendSlice(allocator, self.buffer.items[0..pos]) catch {
                        self.discardPaste();
                        return null;
                    };
                    self.consume(pos + paste_end.len);
                    self.in_paste = false;
                    return .{ .paste = normalizePasteLineEndings(self.paste_payload.items) };
                }
                // 未遇到结束标记：收集除"结束标记前缀"之外的字节
                const keep = paste_end.len - 1;
                if (self.buffer.items.len > keep) {
                    const take = self.buffer.items.len - keep;
                    self.paste_payload.appendSlice(allocator, self.buffer.items[0..take]) catch {
                        self.discardPaste();
                        return null;
                    };
                    self.consume(take);
                }
                if (self.paste_payload.items.len > max_parser_buffer) {
                    self.discardPaste();
                }
                return null;
            }

            if (std.mem.indexOf(u8, self.buffer.items, paste_start)) |pos| {
                if (pos == 0) {
                    self.consume(paste_start.len);
                    self.in_paste = true;
                    self.paste_payload.clearRetainingCapacity();
                    continue;
                }
                // 标记之前还有普通输入：先处理前缀
                switch (parse(self.buffer.items[0..pos])) {
                    .complete => |c| {
                        self.consume(c.consumed);
                        return c.event;
                    },
                    .invalid => |consumed| {
                        self.consume(@max(consumed, 1));
                        continue;
                    },
                    .incomplete => {
                        self.consume(1);
                        continue;
                    },
                }
            }

            switch (parse(self.buffer.items)) {
                .incomplete => return null,
                .invalid => |consumed| {
                    self.consume(@max(consumed, 1));
                    continue;
                },
                .complete => |c| {
                    self.consume(c.consumed);
                    return c.event;
                },
            }
        }
    }

    /// 读取超时（不再有新字节）时调用：把悬挂的 ESC/截断序列按最终含义结算，
    /// 与 ANSI 后端的 parseStale 路径一致；粘贴进行中不结算（分块到达是正常的）。
    pub fn nextStale(self: *Parser) ?events.Event {
        if (self.in_paste) return null;
        while (self.buffer.items.len > 0) {
            switch (parseStale(self.buffer.items)) {
                .complete => |c| {
                    self.consume(c.consumed);
                    return c.event;
                },
                .invalid => |consumed| {
                    self.consume(@max(consumed, 1));
                    continue;
                },
                .incomplete => return null,
            }
        }
        return null;
    }

    fn discardPaste(self: *Parser) void {
        self.in_paste = false;
        self.paste_payload.clearRetainingCapacity();
    }

    fn consume(self: *Parser, n: usize) void {
        const take = @min(n, self.buffer.items.len);
        if (take == 0) return;
        const rest = self.buffer.items.len - take;
        std.mem.copyForwards(u8, self.buffer.items[0..rest], self.buffer.items[take..]);
        self.buffer.shrinkRetainingCapacity(rest);
    }
};

/// 规范化粘贴内容的换行：CRLF 与孤立 CR 统一为 LF。
/// Windows 剪贴板行尾是 CRLF，而某些终端只把 CR 透传给应用。
fn normalizePasteLineEndings(payload: []u8) []u8 {
    var w: usize = 0;
    var i: usize = 0;
    while (i < payload.len) {
        if (payload[i] == '\r') {
            payload[w] = '\n';
            w += 1;
            i += 1;
            if (i < payload.len and payload[i] == '\n') i += 1; // 吞掉 CRLF 中的 LF
            continue;
        }
        payload[w] = payload[i];
        w += 1;
        i += 1;
    }
    return payload[0..w];
}

test "Parser: bracketed paste 输出单个 paste 事件" {
    var p = Parser{};
    defer p.deinit(std.testing.allocator);

    try p.feed(std.testing.allocator, "ab\x1b[200~line1\nline2\nline3\x1b[201~cd");

    // 先出 'a'
    switch (p.next(std.testing.allocator).?) {
        .key => |k| try std.testing.expectEqual(@as(u21, 'a'), k.code.char),
        else => return error.TestExpectedEqual,
    }
    // 再出 'b'
    switch (p.next(std.testing.allocator).?) {
        .key => |k| try std.testing.expectEqual(@as(u21, 'b'), k.code.char),
        else => return error.TestExpectedEqual,
    }
    // 然后是粘贴事件（内容原样保留换行）
    switch (p.next(std.testing.allocator).?) {
        .paste => |text| try std.testing.expectEqualStrings("line1\nline2\nline3", text),
        else => return error.TestExpectedEqual,
    }
    // 最后是 'c'
    switch (p.next(std.testing.allocator).?) {
        .key => |k| try std.testing.expectEqual(@as(u21, 'c'), k.code.char),
        else => return error.TestExpectedEqual,
    }
}

test "Parser: 粘贴分块到达也能正确拼接" {
    var p = Parser{};
    defer p.deinit(std.testing.allocator);

    try p.feed(std.testing.allocator, "\x1b[20");
    try std.testing.expect(p.next(std.testing.allocator) == null);
    try p.feed(std.testing.allocator, "0~hello\nwor");
    try std.testing.expect(p.next(std.testing.allocator) == null);
    try p.feed(std.testing.allocator, "ld\x1b[201");
    try std.testing.expect(p.next(std.testing.allocator) == null);
    try p.feed(std.testing.allocator, "~");

    switch (p.next(std.testing.allocator).?) {
        .paste => |text| try std.testing.expectEqualStrings("hello\nworld", text),
        else => return error.TestExpectedEqual,
    }
}

test "Parser: Ctrl+J(LF) 作为换行字符而非回车" {
    var p = Parser{};
    defer p.deinit(std.testing.allocator);

    try p.feed(std.testing.allocator, "\r\n");
    // Enter
    switch (p.next(std.testing.allocator).?) {
        .key => |k| try std.testing.expectEqual(events.KeyCode.enter, k.code),
        else => return error.TestExpectedEqual,
    }
    // LF → char '\n'
    switch (p.next(std.testing.allocator).?) {
        .key => |k| try std.testing.expectEqual(@as(u21, '\n'), k.code.char),
        else => return error.TestExpectedEqual,
    }
}

test "Parser: 粘贴内容中的 CRLF 与 CR 规范化为 LF" {
    var p = Parser{};
    defer p.deinit(std.testing.allocator);

    // 模拟 Windows 剪贴板 CRLF，以及某些终端只透传 CR 的情况
    try p.feed(std.testing.allocator, "\x1b[200~line1\r\nline2\rline3\x1b[201~");
    switch (p.next(std.testing.allocator).?) {
        .paste => |text| try std.testing.expectEqualStrings("line1\nline2\nline3", text),
        else => return error.TestExpectedEqual,
    }
}

test "Parser: 悬挂的 ESC 在超时后结算为 Esc" {
    var p = Parser{};
    defer p.deinit(std.testing.allocator);

    try p.feed(std.testing.allocator, "\x1b");
    try std.testing.expect(p.next(std.testing.allocator) == null);
    switch (p.nextStale().?) {
        .key => |k| try std.testing.expectEqual(events.KeyCode.esc, k.code),
        else => return error.TestExpectedEqual,
    }
    try std.testing.expect(p.nextStale() == null);

    // Alt+键 一次到达 → alt 修饰
    try p.feed(std.testing.allocator, "\x1bx");
    switch (p.next(std.testing.allocator).?) {
        .key => |k| {
            try std.testing.expectEqual(@as(u21, 'x'), k.code.char);
            try std.testing.expect(k.modifiers.alt);
        },
        else => return error.TestExpectedEqual,
    }
}

test "Parser: 粘贴进行中超时不清算" {
    var p = Parser{};
    defer p.deinit(std.testing.allocator);

    try p.feed(std.testing.allocator, "\x1b[200~partial");
    try std.testing.expect(p.next(std.testing.allocator) == null);
    try std.testing.expect(p.nextStale() == null);
    try p.feed(std.testing.allocator, "\x1b[201~");
    switch (p.next(std.testing.allocator).?) {
        .paste => |text| try std.testing.expectEqualStrings("partial", text),
        else => return error.TestExpectedEqual,
    }
}
