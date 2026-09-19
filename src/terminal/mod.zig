const std = @import("std");
const backend = @import("../backend/mod.zig");
const render = @import("../render/mod.zig");
const width_mod = @import("../render/width.zig");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;
const Backend = backend.Backend;
const KeyboardProtocolOptions = backend.KeyboardProtocolOptions;
const Buffer = render.Buffer;

pub const Error = backend.Error;
pub const restore = @import("restore.zig");

/// 终端对「模糊宽度」字符（①←≤…等）实际推进的列数。
/// 1 = 只推进 1 列（Windows Terminal + 默认字体实测）：flush 会显式补写续格空格，
/// 把终端光标强制对齐到"2 列"坐标系；
/// 2 = 按全角推进 2 列（终端使用 CJK 等宽字体等）：与普通宽字符一样处理、无需补格。
/// 仅当 width.ambiguous_width == .wide 时生效；pub 供宿主按终端能力覆盖。
pub var ambiguous_advance: u2 = 1;

/// Turning autowrap off keeps a glyph in the last column from scrolling the
/// screen, which would otherwise desynchronize every tracked cursor position.
const enter_sequence = "\x1b[?7l";
const exit_sequence = "\x1b[?7h";

/// Terminals that understand this hold the frame back until it is complete;
/// the rest ignore the private mode. Either way the frame is never torn.
const sync_begin = "\x1b[?2026h";
const sync_end = "\x1b[?2026l";

pub const Terminal = struct {
    backend_impl: Backend,
    current_buffer: Buffer,
    next_buffer: Buffer,
    output: std.ArrayListUnmanaged(u8) = .empty,
    hidden_cursor: bool = false,
    /// 帧尾要定位到的终端光标（0 基列、行；null = 不改变）。
    /// 由宿主在 render 回调内设置：作为帧的**最后一条指令**随同步块一起写出，
    /// 保证终端每帧只渲染一次且渲染时光标已在正确位置。
    /// （独立走 Win32 SetConsoleCursorPosition 会与帧字节流形成两条通道，时序不可控，
    /// IME 组合串/候选窗会在"最后写入格子"与目标位置间闪烁）
    pending_cursor: ?[2]u16 = null,
    /// 上一帧已定位的光标（用于判断是否需要单纯因光标移动而输出）
    last_cursor: ?[2]u16 = null,

    pub fn init(allocator: Allocator, backend_impl: Backend) !Terminal {
        const size = try backend_impl.getSize();

        var current = try Buffer.init(allocator, size.width, size.height);
        errdefer current.deinit();

        var next = try Buffer.init(allocator, size.width, size.height);
        errdefer next.deinit();

        try backend_impl.enterRawMode();
        errdefer backend_impl.exitRawMode() catch {};

        try backend_impl.enableAlternateScreen();
        errdefer backend_impl.disableAlternateScreen() catch {};

        try backend_impl.clearScreen();
        try backend_impl.write(enter_sequence);
        try backend_impl.flush();

        return Terminal{
            .backend_impl = backend_impl,
            .current_buffer = current,
            .next_buffer = next,
        };
    }

    pub fn deinit(self: *Terminal) void {
        if (self.hidden_cursor) {
            self.backend_impl.showCursor() catch {};
        }
        self.backend_impl.write(exit_sequence) catch {};
        self.backend_impl.flush() catch {};
        self.backend_impl.disableAlternateScreen() catch {};
        self.backend_impl.exitRawMode() catch {};
        self.output.deinit(self.current_buffer.allocator);
        self.current_buffer.deinit();
        self.next_buffer.deinit();
    }

    pub fn draw(self: *Terminal, ctx: anytype, renderFn: fn (@TypeOf(ctx), *Buffer) anyerror!void) !void {
        self.next_buffer.clear();
        try renderFn(ctx, &self.next_buffer);
        try self.flush();
    }

    pub fn flush(self: *Terminal) !void {
        const alloc = self.current_buffer.allocator;
        const next = &self.next_buffer;

        const full_redraw = self.current_buffer.width != next.width or
            self.current_buffer.height != next.height;
        if (full_redraw) try self.current_buffer.resize(next.width, next.height);

        self.output.clearRetainingCapacity();

        var last_fg: style.Color = .reset;
        var last_bg: style.Color = .reset;
        var last_modifier: style.Modifier = .{};
        var style_known = false;
        var last_x: u16 = std.math.maxInt(u16);
        var last_y: u16 = std.math.maxInt(u16);

        var y: u16 = 0;
        while (y < next.height) : (y += 1) {
            var x: u16 = 0;
            while (x < next.width) {
                const cell = next.cells[@as(usize, y) * @as(usize, next.width) + @as(usize, x)];
                const advance: u16 = @max(cell.width, 1);

                if (cell.isContinuation()) {
                    x += 1;
                    continue;
                }
                if (!full_redraw and cell.eql(self.current_buffer.cells[@as(usize, y) * @as(usize, next.width) + @as(usize, x)])) {
                    x += advance;
                    continue;
                }

                if (x != last_x or y != last_y) {
                    var cursor_buf: [24]u8 = undefined;
                    const cursor_cmd = std.fmt.bufPrint(&cursor_buf, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch unreachable;
                    try self.output.appendSlice(alloc, cursor_cmd);
                }

                if (!style_known or
                    !cell.fg.eql(last_fg) or
                    !cell.bg.eql(last_bg) or
                    !cell.modifier.eql(last_modifier))
                {
                    try appendSgr(&self.output, alloc, cell.fg, cell.bg, cell.modifier);
                    last_fg = cell.fg;
                    last_bg = cell.bg;
                    last_modifier = cell.modifier;
                    style_known = true;
                }

                try appendChar(&self.output, alloc, cell.char);

                // 缓冲记账 2 列、但终端实际只推进 1 列（模糊宽度字符、或被 wide
                // 覆盖名单提宽的窄字符）：显式在续格写一个空格，把终端光标对齐到
                // 2 列坐标系。否则后续内容会整体左移一列，重绘时错位、留下残影。
                if (advance == 2 and width_mod.terminalAdvance(cell.char, ambiguous_advance == 2) == 1) {
                    var cont_buf: [24]u8 = undefined;
                    const cont_cmd = std.fmt.bufPrint(&cont_buf, "\x1b[{d};{d}H", .{ y + 1, x + 2 }) catch unreachable;
                    try self.output.appendSlice(alloc, cont_cmd);
                    try self.output.append(alloc, ' ');
                }

                last_x = x + advance;
                last_y = y;
                x += advance;
            }
        }

        // 终端光标定位：并入帧尾（同步块内最后一条指令）。
        // pending_cursor 与上一帧不同时，即使无格子变化也需输出（否则光标停留旧位置）。
        const cursor_changed = if (self.pending_cursor) |p|
            (self.last_cursor == null or !std.meta.eql(p, self.last_cursor.?))
        else
            false;
        if (self.output.items.len == 0 and !cursor_changed) return;

        try self.output.appendSlice(alloc, "\x1b[0m");
        if (self.pending_cursor) |p| {
            var cur_buf: [24]u8 = undefined;
            const cur_cmd = std.fmt.bufPrint(&cur_buf, "\x1b[{d};{d}H", .{ p[1] + 1, p[0] + 1 }) catch unreachable;
            try self.output.appendSlice(alloc, cur_cmd);
        }
        try self.backend_impl.write(sync_begin);
        try self.backend_impl.write(self.output.items);
        try self.backend_impl.write(sync_end);
        try self.backend_impl.flush();
        self.last_cursor = self.pending_cursor;

        @memcpy(self.current_buffer.cells, next.cells);
    }

    fn appendSgr(
        output: *std.ArrayListUnmanaged(u8),
        alloc: Allocator,
        fg: style.Color,
        bg: style.Color,
        mod: style.Modifier,
    ) !void {
        var buf: [96]u8 = undefined;
        var n: usize = 0;

        const prefix = "\x1b[0";
        @memcpy(buf[0..prefix.len], prefix);
        n = prefix.len;

        n += appendColorParams(buf[n..], fg, 0);
        n += appendColorParams(buf[n..], bg, 10);

        var codes: [9]u8 = undefined;
        for (mod.ansiParams(&codes)) |code| {
            n += (std.fmt.bufPrint(buf[n..], ";{d}", .{code}) catch unreachable).len;
        }

        buf[n] = 'm';
        n += 1;

        try output.appendSlice(alloc, buf[0..n]);
    }

    fn appendColorParams(buf: []u8, color: style.Color, offset: u8) usize {
        return switch (color) {
            .rgb => |rgb| (std.fmt.bufPrint(buf, ";{d};2;{d};{d};{d}", .{ 38 + offset, rgb.r, rgb.g, rgb.b }) catch unreachable).len,
            .indexed => |idx| (std.fmt.bufPrint(buf, ";{d};5;{d}", .{ 38 + offset, idx }) catch unreachable).len,
            .reset => 0,
            else => (std.fmt.bufPrint(buf, ";{d}", .{color.ansiBase().? + offset}) catch unreachable).len,
        };
    }

    fn appendChar(output: *std.ArrayListUnmanaged(u8), alloc: Allocator, char: u21) !void {
        if (char < 128) {
            try output.append(alloc, @intCast(char));
            return;
        }
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &buf) catch {
            try output.append(alloc, '?');
            return;
        };
        try output.appendSlice(alloc, buf[0..len]);
    }

    pub fn clear(self: *Terminal) !void {
        self.current_buffer.clear();
        self.next_buffer.clear();
        try self.backend_impl.clearScreen();
    }

    pub fn hideCursor(self: *Terminal) !void {
        try self.backend_impl.hideCursor();
        self.hidden_cursor = true;
    }

    pub fn showCursor(self: *Terminal) !void {
        try self.backend_impl.showCursor();
        self.hidden_cursor = false;
    }

    pub fn setCursor(self: *Terminal, x: u16, y: u16) !void {
        try self.backend_impl.setCursor(x, y);
    }

    pub fn enableKeyboardProtocol(self: *Terminal, options: KeyboardProtocolOptions) !void {
        try self.backend_impl.enableKeyboardProtocol(options);
    }

    pub fn disableKeyboardProtocol(self: *Terminal) !void {
        try self.backend_impl.disableKeyboardProtocol();
    }

    pub fn enableMouse(self: *Terminal) !void {
        try self.backend_impl.enableMouse();
    }

    pub fn disableMouse(self: *Terminal) !void {
        try self.backend_impl.disableMouse();
    }

    pub fn getSize(self: *Terminal) !render.Size {
        return try self.backend_impl.getSize();
    }

    pub fn resize(self: *Terminal, size: render.Size) !void {
        try self.current_buffer.resize(size.width, size.height);
        try self.next_buffer.resize(size.width, size.height);
        self.invalidate();
    }

    /// Forget what is believed to be on screen, so the next flush repaints every
    /// cell. Needed after a resize, since the terminal reflows on its own.
    pub fn invalidate(self: *Terminal) void {
        @memset(self.current_buffer.cells, .{ .char = 0 });
    }
};

// ── 测试：帧尾光标定位（含 mock backend） ──

const testing = std.testing;

const MockBackend = struct {
    written: std.ArrayListUnmanaged(u8) = .{ .items = &.{}, .capacity = 0 },

    fn enterRawMode(_: *anyopaque) Error!void {}
    fn exitRawMode(_: *anyopaque) Error!void {}
    fn enableAlternateScreen(_: *anyopaque) Error!void {}
    fn disableAlternateScreen(_: *anyopaque) Error!void {}
    fn clearScreen(ptr: *anyopaque) Error!void {
        _ = ptr;
    }
    fn write(ptr: *anyopaque, data: []const u8) Error!void {
        const self: *MockBackend = @ptrCast(@alignCast(ptr));
        self.written.appendSlice(testing.allocator, data) catch return Error.OutOfMemory;
    }
    fn flush(_: *anyopaque) Error!void {}
    fn getSize(_: *anyopaque) Error!render.Size {
        return .{ .width = 20, .height = 5 };
    }
    fn pollEvent(_: *anyopaque, _: u32) Error!@import("../events/mod.zig").Event {
        return .none;
    }
    fn hideCursor(_: *anyopaque) Error!void {}
    fn showCursor(_: *anyopaque) Error!void {}
    fn setCursor(_: *anyopaque, _: u16, _: u16) Error!void {}
    fn enableKeyboardProtocol(_: *anyopaque, _: KeyboardProtocolOptions) Error!void {}
    fn disableKeyboardProtocol(_: *anyopaque) Error!void {}
    fn enableMouse(_: *anyopaque) Error!void {}
    fn disableMouse(_: *anyopaque) Error!void {}

    const vtable = Backend.VTable{
        .enter_raw_mode = enterRawMode,
        .exit_raw_mode = exitRawMode,
        .enable_alternate_screen = enableAlternateScreen,
        .disable_alternate_screen = disableAlternateScreen,
        .clear_screen = clearScreen,
        .write = write,
        .flush = flush,
        .get_size = getSize,
        .poll_event = pollEvent,
        .hide_cursor = hideCursor,
        .show_cursor = showCursor,
        .set_cursor = setCursor,
        .enable_keyboard_protocol = enableKeyboardProtocol,
        .disable_keyboard_protocol = disableKeyboardProtocol,
        .enable_mouse = enableMouse,
        .disable_mouse = disableMouse,
    };
};

test "flush emits pending cursor as the last instruction inside the sync block" {
    var mock = MockBackend{};
    defer mock.written.deinit(testing.allocator);

    const be = Backend{ .ptr = &mock, .vtable = &MockBackend.vtable };
    var term = try Terminal.init(testing.allocator, be);
    defer term.deinit();

    // 第一帧：写内容 + 光标定位
    mock.written.clearRetainingCapacity();
    const Ctx = struct { term: *Terminal };
    try term.draw(Ctx{ .term = &term }, struct {
        fn render(ctx: Ctx, buf: *Buffer) !void {
            buf.setString(0, 0, "hi", .{});
            ctx.term.pending_cursor = .{ 3, 2 }; // 0 基坐标 (3,2) → 序列应为 CSI 3;4 H
        }
    }.render);
    const out1 = mock.written.items;
    const cursor_seq = "\x1b[3;4H";
    const pos_cursor = std.mem.indexOf(u8, out1, cursor_seq) orelse
        return error.TestExpectedCursorSequence;
    const pos_sync_end = std.mem.lastIndexOf(u8, out1, sync_end) orelse
        return error.TestExpectedSyncEnd;
    const pos_sync_begin = std.mem.lastIndexOf(u8, out1, sync_begin) orelse
        return error.TestExpectedSyncBegin;
    // 定位在同步块内、且是块内最后一条指令（sync_begin < cursor < sync_end）
    try testing.expect(pos_sync_begin < pos_cursor);
    try testing.expect(pos_cursor < pos_sync_end);
    // 帧内容与定位同处一个同步块（渲染一次完成，不与独立通道交错）
    try testing.expect(std.mem.indexOf(u8, out1[0..pos_sync_end], "hi") != null);

    // 第二帧：无格子差异、仅光标移动 → 仍需输出定位
    mock.written.clearRetainingCapacity();
    try term.draw(Ctx{ .term = &term }, struct {
        fn render(ctx: Ctx, buf: *Buffer) !void {
            // 重画同样的 "hi"，无差异
            buf.setString(0, 0, "hi", .{});
            ctx.term.pending_cursor = .{ 5, 1 };
        }
    }.render);
    try testing.expect(std.mem.indexOf(u8, mock.written.items, "\x1b[2;6H") != null);

    // 第三帧：光标与格子都不变 → 不输出
    mock.written.clearRetainingCapacity();
    try term.draw(Ctx{ .term = &term }, struct {
        fn render(ctx: Ctx, buf: *Buffer) !void {
            buf.setString(0, 0, "hi", .{});
            ctx.term.pending_cursor = .{ 5, 1 };
        }
    }.render);
    try testing.expectEqual(@as(usize, 0), mock.written.items.len);

    // 第四帧：不再定位（pending_cursor = null）→ 只输出格子差异，无定位序列
    mock.written.clearRetainingCapacity();
    try term.draw(Ctx{ .term = &term }, struct {
        fn render(ctx: Ctx, buf: *Buffer) !void {
            buf.setString(0, 0, "yo", .{});
            ctx.term.pending_cursor = null;
        }
    }.render);
    try testing.expect(std.mem.indexOf(u8, mock.written.items, "yo") != null);
    try testing.expect(std.mem.indexOf(u8, mock.written.items, "\x1b[2;6H") == null);
}
