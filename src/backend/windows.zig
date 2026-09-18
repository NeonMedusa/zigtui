const std = @import("std");
const builtin = @import("builtin");
const Backend = @import("mod.zig").Backend;
const KeyboardProtocolOptions = @import("mod.zig").KeyboardProtocolOptions;
const Error = @import("mod.zig").Error;
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const ansi_input = @import("ansi_input.zig");
const restore = @import("../terminal/restore.zig");
const Allocator = std.mem.Allocator;

const is_windows = builtin.os.tag == .windows;

const windows = if (is_windows) std.os.windows else void;
const HANDLE = if (is_windows) windows.HANDLE else void;
const DWORD = if (is_windows) windows.DWORD else u32;
const WORD = if (is_windows) windows.WORD else u16;
const BOOL = if (is_windows) windows.BOOL else i32;
const UINT = if (is_windows) windows.UINT else u32;
const SHORT = if (is_windows) windows.SHORT else i16;
const COORD = if (is_windows) windows.COORD else void;

const SMALL_RECT = extern struct {
    Left: SHORT,
    Top: SHORT,
    Right: SHORT,
    Bottom: SHORT,
};

const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
    dwSize: COORD,
    dwCursorPosition: COORD,
    wAttributes: WORD,
    srWindow: SMALL_RECT,
    dwMaximumWindowSize: COORD,
};

extern "kernel32" fn GetStdHandle(nStdHandle: DWORD) callconv(.winapi) HANDLE;
extern "kernel32" fn GetConsoleMode(hConsoleHandle: HANDLE, lpMode: *DWORD) callconv(.winapi) BOOL;
extern "kernel32" fn SetConsoleMode(hConsoleHandle: HANDLE, dwMode: DWORD) callconv(.winapi) BOOL;
extern "kernel32" fn GetConsoleScreenBufferInfo(
    hConsoleOutput: HANDLE,
    lpConsoleScreenBufferInfo: *CONSOLE_SCREEN_BUFFER_INFO,
) callconv(.winapi) BOOL;
extern "kernel32" fn SetConsoleCursorPosition(hConsoleOutput: HANDLE, dwCursorPosition: COORD) callconv(.winapi) BOOL;
extern "kernel32" fn SetConsoleTextAttribute(hConsoleOutput: HANDLE, wAttributes: WORD) callconv(.winapi) BOOL;
extern "kernel32" fn FillConsoleOutputCharacterW(
    hConsoleOutput: HANDLE,
    cCharacter: u16,
    nLength: DWORD,
    dwWriteCoord: COORD,
    lpNumberOfCharsWritten: *DWORD,
) callconv(.winapi) BOOL;
extern "kernel32" fn FillConsoleOutputAttribute(
    hConsoleOutput: HANDLE,
    wAttribute: WORD,
    nLength: DWORD,
    dwWriteCoord: COORD,
    lpNumberOfAttrsWritten: *DWORD,
) callconv(.winapi) BOOL;

// Console input/output mode flags
const ENABLE_ECHO_INPUT: DWORD = 0x0004;
const ENABLE_LINE_INPUT: DWORD = 0x0002;
const ENABLE_PROCESSED_INPUT: DWORD = 0x0001;
const ENABLE_WINDOW_INPUT: DWORD = 0x0008;
const ENABLE_MOUSE_INPUT: DWORD = 0x0010;
const ENABLE_VIRTUAL_TERMINAL_PROCESSING: DWORD = 0x0004;
const ENABLE_VIRTUAL_TERMINAL_INPUT: DWORD = 0x0200;

// Standard handles
const STD_INPUT_HANDLE: DWORD = @bitCast(@as(i32, -10));
const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));

// Console cursor info structure
const CONSOLE_CURSOR_INFO = extern struct {
    dwSize: DWORD,
    bVisible: BOOL,
};

// External Windows API functions not in std.os.windows.kernel32
extern "kernel32" fn GetConsoleCursorInfo(
    hConsoleOutput: HANDLE,
    lpConsoleCursorInfo: *CONSOLE_CURSOR_INFO,
) callconv(.winapi) BOOL;

extern "kernel32" fn SetConsoleCursorInfo(
    hConsoleOutput: HANDLE,
    lpConsoleCursorInfo: *const CONSOLE_CURSOR_INFO,
) callconv(.winapi) BOOL;

extern "kernel32" fn WriteConsoleA(
    hConsoleOutput: HANDLE,
    lpBuffer: [*]const u8,
    nNumberOfCharsToWrite: DWORD,
    lpNumberOfCharsWritten: ?*DWORD,
    lpReserved: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: DWORD,
    lpNumberOfEventsRead: *DWORD,
) callconv(.winapi) BOOL;

extern "kernel32" fn GetNumberOfConsoleInputEvents(
    hConsoleInput: HANDLE,
    lpcNumberOfEvents: *DWORD,
) callconv(.winapi) BOOL;

extern "kernel32" fn WaitForSingleObject(
    hHandle: HANDLE,
    dwMilliseconds: DWORD,
) callconv(.winapi) DWORD;

extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) UINT;

extern "kernel32" fn SetConsoleOutputCP(
    codepage: UINT,
) callconv(.winapi) BOOL;

// Input record structures for reading console input
// Note: Windows INPUT_RECORD has 2 bytes of padding after EventType
// to align the Event union to a 4-byte boundary
const INPUT_RECORD = extern struct {
    EventType: WORD,
    _padding: u16 = 0, // Explicit padding for proper alignment
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent: MENU_EVENT_RECORD,
        FocusEvent: FOCUS_EVENT_RECORD,
    },
};

const KEY_EVENT_RECORD = extern struct {
    bKeyDown: BOOL,
    wRepeatCount: WORD,
    wVirtualKeyCode: WORD,
    wVirtualScanCode: WORD,
    uChar: extern union {
        UnicodeChar: u16,
        AsciiChar: u8,
    },
    dwControlKeyState: DWORD,
};

const MOUSE_EVENT_RECORD = extern struct {
    dwMousePosition: COORD,
    dwButtonState: DWORD,
    dwControlKeyState: DWORD,
    dwEventFlags: DWORD,
};

// Mouse button state / event flags
const FROM_LEFT_1ST_BUTTON_PRESSED: DWORD = 0x0001;
const RIGHTMOST_BUTTON_PRESSED: DWORD = 0x0002;
const FROM_LEFT_2ND_BUTTON_PRESSED: DWORD = 0x0004;
const MOUSE_MOVED: DWORD = 0x0001;
const MOUSE_WHEELED: DWORD = 0x0004;

const WINDOW_BUFFER_SIZE_RECORD = extern struct {
    dwSize: COORD,
};

const MENU_EVENT_RECORD = extern struct {
    dwCommandId: UINT,
};

const FOCUS_EVENT_RECORD = extern struct {
    bSetFocus: BOOL,
};

// Event types
const KEY_EVENT: WORD = 0x0001;
const MOUSE_EVENT: WORD = 0x0002;
const WINDOW_BUFFER_SIZE_EVENT: WORD = 0x0004;
const FOCUS_EVENT: WORD = 0x0010;

// Virtual key codes
const VK_RETURN: WORD = 0x0D;
const VK_ESCAPE: WORD = 0x1B;
const VK_BACK: WORD = 0x08;
const VK_TAB: WORD = 0x09;
const VK_LEFT: WORD = 0x25;
const VK_UP: WORD = 0x26;
const VK_RIGHT: WORD = 0x27;
const VK_DOWN: WORD = 0x28;
const VK_DELETE: WORD = 0x2E;
const VK_HOME: WORD = 0x24;
const VK_END: WORD = 0x23;
const VK_PRIOR: WORD = 0x21; // Page Up
const VK_NEXT: WORD = 0x22; // Page Down
const VK_INSERT: WORD = 0x2D;
const VK_F1: WORD = 0x70;

// Control key state
const LEFT_CTRL_PRESSED: DWORD = 0x0008;
const RIGHT_CTRL_PRESSED: DWORD = 0x0004;
const LEFT_ALT_PRESSED: DWORD = 0x0002;
const RIGHT_ALT_PRESSED: DWORD = 0x0001;
const SHIFT_PRESSED: DWORD = 0x0010;

// Wait result
const WAIT_OBJECT_0: DWORD = 0x00000000;
const WAIT_TIMEOUT: DWORD = 0x00000102;

const UTF8_CODE_PAGE: UINT = 65001;

/// Combines a UTF-16 surrogate pair into a code point. Returns null when
/// either half is outside its surrogate range.
fn combineSurrogates(hi: u16, lo: u16) ?u21 {
    if (hi < 0xD800 or hi > 0xDBFF) return null;
    if (lo < 0xDC00 or lo > 0xDFFF) return null;
    return @intCast(0x10000 + ((@as(u21, hi) - 0xD800) << 10) + (@as(u21, lo) - 0xDC00));
}

/// 把一条 KEY_EVENT 的 `UnicodeChar`（UTF-16 码元）转换为应喂给输入解析器的
/// UTF-8 字节，写入 `out` 并返回字节数（0 = 该记录被吞掉，如未配对的前导代理）。
///
/// 背景（ConPTY 实测）：conhost 的 VtInputThread 会先把收到的字节流按 UTF-8
/// 解码为 UTF-16 再写入输入记录，因此记录**携带的永远是 UTF-16 码元**：
/// - ASCII（≤ 0x7F）：码元值与字节相同，直接透传（控制序列/鼠标上报依赖此路径）；
/// - BMP 非 ASCII（含中文）：UTF-8 编码后喂入；
/// - 非 BMP（emoji 等）：以**前导+后继两条记录**到达，`pending_high` 缓存前导，
///   与后继合并成完整码点后再编码（与微软 terminalInput.cpp 的 _leadingSurrogate
///   逻辑一致）。代理码元单独编码会失败并被静默丢弃 → 输入/粘贴 emoji 无效；
/// - U+0080–U+00FF（é、ü 等 Latin-1 补充）：若被当作"原始字节"透传，
///   单字节不构成合法 UTF-8 序列，会静默丢弃该字符甚至吞掉后续字符；故统一编码。
fn codeUnitToUtf8(pending_high: *u16, unit: u16, out: *[4]u8) usize {
    if (unit == 0) return 0;
    if (unit >= 0xD800 and unit <= 0xDBFF) {
        pending_high.* = unit;
        return 0;
    }
    var cp: u21 = unit;
    if (pending_high.* != 0) {
        const hi = pending_high.*;
        pending_high.* = 0;
        if (combineSurrogates(hi, unit)) |full| cp = full;
    }
    if (cp <= 0x7F) {
        out[0] = @intCast(cp);
        return 1;
    }
    return std.unicode.utf8Encode(cp, out) catch 0;
}

pub const WindowsBackend = struct {
    allocator: Allocator,
    stdin_handle: HANDLE,
    stdout_handle: HANDLE,
    original_stdin_mode: DWORD = 0,
    original_stdout_mode: DWORD = 0,
    in_raw_mode: bool = false,
    in_alternate_screen: bool = false,
    mouse_enabled: bool = false,
    write_buffer: std.ArrayListUnmanaged(u8) = .empty,
    /// VT 输入字节流解析器（支持 bracketed paste）
    input: ansi_input.Parser = .{},
    /// 未配对的 UTF-16 前导代理（emoji 等非 BMP 字符分两条记录到达，
    /// 需缓存前导再与后继合并；0 = 无）
    pending_high_surrogate: u16 = 0,
    original_console_info: CONSOLE_SCREEN_BUFFER_INFO = undefined,
    original_codepage: UINT = undefined,

    /// `io` is accepted to match the ANSI backend's signature; console output
    /// goes through WriteConsoleW rather than the Io interface.
    pub fn init(allocator: Allocator, io: std.Io) !WindowsBackend {
        _ = io;
        if (!is_windows) {
            return error.UnsupportedTerminal; // Use ansi.zig backend instead
        }

        //get current codepage and set to utf8 if not set already
        const original_codepage = GetConsoleOutputCP();
        if (original_codepage != UTF8_CODE_PAGE) {
            _ = SetConsoleOutputCP(UTF8_CODE_PAGE);
        }

        // Get standard handles using GetStdHandle
        const stdin_handle = GetStdHandle(STD_INPUT_HANDLE);
        const stdout_handle = GetStdHandle(STD_OUTPUT_HANDLE);
        if (stdin_handle == windows.INVALID_HANDLE_VALUE or stdout_handle == windows.INVALID_HANDLE_VALUE) {
            return error.IOError;
        }

        // Get original console modes
        var original_stdin_mode: DWORD = 0;
        var original_stdout_mode: DWORD = 0;
        _ = GetConsoleMode(stdin_handle, &original_stdin_mode);
        _ = GetConsoleMode(stdout_handle, &original_stdout_mode);

        // Get original console info
        var original_console_info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        _ = GetConsoleScreenBufferInfo(stdout_handle, &original_console_info);

        return WindowsBackend{
            .allocator = allocator,
            .stdin_handle = stdin_handle,
            .stdout_handle = stdout_handle,
            .original_stdin_mode = original_stdin_mode,
            .original_stdout_mode = original_stdout_mode,
            .original_console_info = original_console_info,
            .original_codepage = original_codepage,
        };
    }

    pub fn deinit(self: *WindowsBackend) void {
        if (self.in_alternate_screen) {
            disableAlternateScreen(self) catch {};
        }
        if (self.in_raw_mode) {
            exitRawMode(self) catch {};
        }

        // Restore original console settings
        _ = SetConsoleTextAttribute(self.stdout_handle, self.original_console_info.wAttributes);
        _ = SetConsoleCursorPosition(self.stdout_handle, self.original_console_info.dwCursorPosition);

        // Restore original codepage
        if (self.original_codepage > 0 and self.original_codepage != UTF8_CODE_PAGE) {
            _ = SetConsoleOutputCP(self.original_codepage);
        }

        self.write_buffer.deinit(self.allocator);
        self.input.deinit(self.allocator);
    }

    pub fn interface(self: *WindowsBackend) Backend {
        return Backend{
            .ptr = self,
            .vtable = &.{
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
            },
        };
    }

    fn enterRawMode(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (self.in_raw_mode) return;

        if (!is_windows) return;

        // Disable line input, echo input, processed input for stdin
        var stdin_mode: DWORD = self.original_stdin_mode;
        stdin_mode &= ~ENABLE_LINE_INPUT;
        stdin_mode &= ~ENABLE_ECHO_INPUT;
        stdin_mode &= ~ENABLE_PROCESSED_INPUT;
        stdin_mode |= ENABLE_WINDOW_INPUT;
        // 启用 VT 输入：按键与粘贴以 ANSI 字节流到达，
        // 从而支持 bracketed paste（含多行粘贴不会被拆成回车）
        stdin_mode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
        _ = SetConsoleMode(self.stdin_handle, stdin_mode);

        // Enable virtual terminal processing for stdout (ANSI escape sequences)
        var stdout_mode: DWORD = self.original_stdout_mode;
        stdout_mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        _ = SetConsoleMode(self.stdout_handle, stdout_mode);

        // 启用 bracketed paste：终端将粘贴内容用 ESC[200~..ESC[201~ 包裹，
        // 同时 Windows Terminal 不再弹出多行粘贴警告
        try writeDirectToConsole(self, "\x1b[?2004h");

        // Hand the console to `restore` so a panic or abnormal exit cannot
        // leave it in raw mode with mouse reporting on and the cursor hidden.
        restore.arm(self.stdin_handle, self.stdout_handle, .{
            .stdin = self.original_stdin_mode,
            .stdout = self.original_stdout_mode,
        });

        self.in_raw_mode = true;
    }

    fn exitRawMode(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_raw_mode) return;

        if (!is_windows) return;

        // 关闭 bracketed paste
        writeDirectToConsole(self, "\x1b[?2004l") catch {};

        restore.disarm();

        // Restore original modes
        _ = SetConsoleMode(self.stdin_handle, self.original_stdin_mode);
        _ = SetConsoleMode(self.stdout_handle, self.original_stdout_mode);
        self.in_raw_mode = false;
    }

    fn enableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (self.in_alternate_screen) return;

        if (!is_windows) return;

        // Use ANSI escape sequence for alternate screen buffer (works with VT mode enabled)
        try writeDirectToConsole(self, "\x1b[?1049h");
        try clearScreen(ptr);
        self.in_alternate_screen = true;
    }

    fn disableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_alternate_screen) return;

        if (!is_windows) return;

        // Use ANSI escape sequence to restore main screen buffer
        try writeDirectToConsole(self, "\x1b[?1049l");
        self.in_alternate_screen = false;
    }

    fn clearScreen(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (!GetConsoleScreenBufferInfo(self.stdout_handle, &info).toBool()) {
            return Error.IOError;
        }

        const coord: COORD = .{ .X = 0, .Y = 0 };
        const attrs = info.wAttributes;
        const buffer_size = @as(DWORD, @intCast(info.dwSize.X)) * @as(DWORD, @intCast(info.dwSize.Y));

        var written: DWORD = undefined;
        // Use wide character version
        if (!FillConsoleOutputCharacterW(self.stdout_handle, ' ', buffer_size, coord, &written).toBool()) {
            return Error.IOError;
        }
        if (!FillConsoleOutputAttribute(self.stdout_handle, attrs, buffer_size, coord, &written).toBool()) {
            return Error.IOError;
        }
        if (!SetConsoleCursorPosition(self.stdout_handle, coord).toBool()) {
            return Error.IOError;
        }
    }

    fn write(ptr: *anyopaque, data: []const u8) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        self.write_buffer.appendSlice(self.allocator, data) catch return Error.IOError;
    }

    fn flush(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        if (self.write_buffer.items.len > 0) {
            try writeDirectToConsole(self, self.write_buffer.items);
            self.write_buffer.clearRetainingCapacity();
        }
    }

    fn writeDirectToConsole(self: *WindowsBackend, data: []const u8) Error!void {
        if (!is_windows) return;

        var written: DWORD = undefined;
        const result = WriteConsoleA(
            self.stdout_handle,
            data.ptr,
            @intCast(data.len),
            &written,
            null,
        );

        if (!result.toBool()) {
            return Error.IOError;
        }
    }

    fn getSize(ptr: *anyopaque) Error!render.Size {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) {
            return .{ .width = 80, .height = 24 };
        }

        var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (!GetConsoleScreenBufferInfo(self.stdout_handle, &info).toBool()) {
            return .{ .width = 80, .height = 24 }; // Default fallback
        }

        // Use the window size, not buffer size
        const width: u16 = @intCast(info.srWindow.Right - info.srWindow.Left + 1);
        const height: u16 = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1);

        return .{
            .width = if (width > 0) width else 80,
            .height = if (height > 0) height else 24,
        };
    }

    fn pollEvent(ptr: *anyopaque, timeout_ms: u32) Error!events.Event {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) {
            return events.Event.none;
        }

        // 1. 先尝试从已缓冲的输入字节流解析事件
        if (self.input.next(self.allocator)) |event| {
            return event;
        }

        // Wait for input with timeout
        const wait_result = WaitForSingleObject(self.stdin_handle, timeout_ms);
        if (wait_result == WAIT_TIMEOUT) {
            // 超时不再有新字节：结算悬挂的 ESC 序列（单独 Esc / 被截断的序列），
            // 与 ANSI 后端的 parseStale 超时路径保持一致
            if (self.input.nextStale()) |event| return event;
            return events.Event.none;
        }
        if (wait_result != WAIT_OBJECT_0) {
            return events.Event.none;
        }

        // 2. 批量读取控制台记录，把按键/粘贴字节喂给解析器。
        //    VT 输入模式下按键以 ANSI 字节流到达（如方向键 = ESC [ A），
        //    粘贴则被 ESC[200~..ESC[201~ 包裹。一次读空队列可以避免
        //    大段粘贴分多帧处理。
        var resize_size: ?struct { width: u16, height: u16 } = null;
        var read_count: usize = 0;
        while (read_count < 65536) : (read_count += 1) {
            var num_events: DWORD = 0;
            if (!GetNumberOfConsoleInputEvents(self.stdin_handle, &num_events).toBool()) break;
            if (num_events == 0) break;

            var input_record: [1]INPUT_RECORD = undefined;
            var events_read: DWORD = 0;
            if (!ReadConsoleInputW(self.stdin_handle, &input_record, 1, &events_read).toBool()) break;
            if (events_read == 0) break;

            const record = input_record[0];
            switch (record.EventType) {
                KEY_EVENT => {
                    const key_event = record.Event.KeyEvent;
                    if (!key_event.bKeyDown.toBool()) continue; // 忽略抬起事件
                    var utf8_buf: [4]u8 = undefined;
                    const n = codeUnitToUtf8(&self.pending_high_surrogate, key_event.uChar.UnicodeChar, &utf8_buf);
                    if (n == 0) continue; // 吞掉（未配对的前导代理 / 空码元）
                    self.input.feed(self.allocator, utf8_buf[0..n]) catch return Error.IOError;
                },
                WINDOW_BUFFER_SIZE_EVENT => {
                    const size_event = record.Event.WindowBufferSizeEvent;
                    resize_size = .{
                        .width = @intCast(size_event.dwSize.X),
                        .height = @intCast(size_event.dwSize.Y),
                    };
                },
                FOCUS_EVENT => {
                    const focus_event = record.Event.FocusEvent;
                    const ev: events.Event = if (focus_event.bSetFocus.toBool())
                        events.Event.focus_gained
                    else
                        events.Event.focus_lost;
                    // 先解析已缓冲的按键事件，焦点事件留到下次轮询
                    if (self.input.next(self.allocator)) |event| return event;
                    return ev;
                },
                else => {},
            }
        }

        // 3. 从解析器取出事件
        if (self.input.next(self.allocator)) |event| {
            return event;
        }
        if (resize_size) |s| {
            return events.Event{ .resize = .{ .width = s.width, .height = s.height } };
        }
        return events.Event.none;
    }

    fn hideCursor(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        var info: CONSOLE_CURSOR_INFO = undefined;
        if (!GetConsoleCursorInfo(self.stdout_handle, &info).toBool()) {
            return Error.IOError;
        }

        info.bVisible = .FALSE;
        if (!SetConsoleCursorInfo(self.stdout_handle, &info).toBool()) {
            return Error.IOError;
        }
    }

    fn showCursor(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        var info: CONSOLE_CURSOR_INFO = undefined;
        if (!GetConsoleCursorInfo(self.stdout_handle, &info).toBool()) {
            return Error.IOError;
        }

        info.bVisible = .TRUE;
        if (!SetConsoleCursorInfo(self.stdout_handle, &info).toBool()) {
            return Error.IOError;
        }
    }

    fn setCursor(ptr: *anyopaque, x: u16, y: u16) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        const coord: COORD = .{ .X = @intCast(x), .Y = @intCast(y) };
        if (!SetConsoleCursorPosition(self.stdout_handle, coord).toBool()) {
            return Error.IOError;
        }
    }

    fn enableKeyboardProtocol(ptr: *anyopaque, _: KeyboardProtocolOptions) Error!void {
        _ = ptr;
        if (!is_windows) return;
        return Error.UnsupportedTerminal;
    }

    fn disableKeyboardProtocol(ptr: *anyopaque) Error!void {
        _ = ptr;
        // Nothing to disable -- enable always fails on Windows.
    }

    fn enableMouse(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (self.mouse_enabled) return;
        if (!is_windows) return;
        // VT 输入模式下通过转义序列开启鼠标上报（SGR 扩展编码 + 按住拖动跟踪），
        // 滚轮/点击/拖动会以 CSI < ... M/m 序列到达解析器
        try writeDirectToConsole(self, "\x1b[?1002h\x1b[?1006h");
        self.mouse_enabled = true;
    }

    fn disableMouse(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (!self.mouse_enabled) return;
        if (!is_windows) return;
        writeDirectToConsole(self, "\x1b[?1006l\x1b[?1000l") catch {};
        self.mouse_enabled = false;
    }
};

test "combineSurrogates: valid pairs and boundaries" {
    // 😀 U+1F600 = D83D DE00
    try std.testing.expectEqual(@as(?u21, 0x1F600), combineSurrogates(0xD83D, 0xDE00));
    // Boundary: U+10000 = D800 DC00, U+10FFFF = DBFF DFFF
    try std.testing.expectEqual(@as(?u21, 0x10000), combineSurrogates(0xD800, 0xDC00));
    try std.testing.expectEqual(@as(?u21, 0x10FFFF), combineSurrogates(0xDBFF, 0xDFFF));
    // Non-surrogate halves are rejected
    try std.testing.expectEqual(@as(?u21, null), combineSurrogates(0x0041, 0xDE00));
    try std.testing.expectEqual(@as(?u21, null), combineSurrogates(0xD83D, 0x0041));
    try std.testing.expectEqual(@as(?u21, null), combineSurrogates(0xDC00, 0xDC00));
}

test "codeUnitToUtf8: ASCII 透传 / BMP 编码 / Latin-1 修复" {
    var pending: u16 = 0;
    var buf: [4]u8 = undefined;

    // ASCII：单字节透传（控制序列/鼠标上报依赖此路径）
    try std.testing.expectEqual(@as(usize, 1), codeUnitToUtf8(&pending, 0x1B, &buf));
    try std.testing.expectEqual(@as(u8, 0x1B), buf[0]);
    try std.testing.expectEqual(@as(usize, 1), codeUnitToUtf8(&pending, 'a', &buf));
    try std.testing.expectEqual(@as(u8, 'a'), buf[0]);

    // 中文（BMP 非 ASCII）：UTF-8 编码
    try std.testing.expectEqual(@as(usize, 3), codeUnitToUtf8(&pending, 0x4E2D, &buf));
    try std.testing.expectEqualSlices(u8, "中", buf[0..3]);

    // Latin-1 补充（é U+00E9）：若按原始字节透传会丢字符，应编码为 C3 A9
    try std.testing.expectEqual(@as(usize, 2), codeUnitToUtf8(&pending, 0x00E9, &buf));
    try std.testing.expectEqualSlices(u8, "é", buf[0..2]);

    // 空码元：吞掉
    try std.testing.expectEqual(@as(usize, 0), codeUnitToUtf8(&pending, 0, &buf));
}

test "codeUnitToUtf8: 代理对（emoji）跨记录合并 / 孤立前导清理" {
    var pending: u16 = 0;
    var buf: [4]u8 = undefined;

    // 😀 U+1F600：前导记录被吞掉并缓存，后继记录合并为完整编码
    try std.testing.expectEqual(@as(usize, 0), codeUnitToUtf8(&pending, 0xD83D, &buf));
    try std.testing.expectEqual(@as(u16, 0xD83D), pending);
    try std.testing.expectEqual(@as(usize, 4), codeUnitToUtf8(&pending, 0xDE00, &buf));
    try std.testing.expectEqualSlices(u8, "😀", buf[0..4]);
    try std.testing.expectEqual(@as(u16, 0), pending);

    // 孤立前导 + 普通字符：前导被清理，字符正常处理
    try std.testing.expectEqual(@as(usize, 0), codeUnitToUtf8(&pending, 0xD83D, &buf));
    try std.testing.expectEqual(@as(usize, 1), codeUnitToUtf8(&pending, 'x', &buf));
    try std.testing.expectEqual(@as(u8, 'x'), buf[0]);
    try std.testing.expectEqual(@as(u16, 0), pending);

    // 孤立后继（无前导）：编码失败被吞、无残留状态
    try std.testing.expectEqual(@as(usize, 0), codeUnitToUtf8(&pending, 0xDE00, &buf));
    try std.testing.expectEqual(@as(u16, 0), pending);

    // 连续两个 emoji：状态正确复位
    _ = codeUnitToUtf8(&pending, 0xD83D, &buf);
    try std.testing.expectEqual(@as(usize, 4), codeUnitToUtf8(&pending, 0xDE80, &buf));
    try std.testing.expectEqualSlices(u8, "🚀", buf[0..4]);
    _ = codeUnitToUtf8(&pending, 0xD83D, &buf);
    try std.testing.expectEqual(@as(usize, 4), codeUnitToUtf8(&pending, 0xDE00, &buf));
    try std.testing.expectEqualSlices(u8, "😀", buf[0..4]);
}
