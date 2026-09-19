const std = @import("std");

const Range = struct { lo: u21, hi: u21 };

const zero_width = [_]Range{
    .{ .lo = 0x0300, .hi = 0x036F },
    .{ .lo = 0x0483, .hi = 0x0489 },
    .{ .lo = 0x0591, .hi = 0x05BD },
    .{ .lo = 0x05BF, .hi = 0x05BF },
    .{ .lo = 0x05C1, .hi = 0x05C2 },
    .{ .lo = 0x05C4, .hi = 0x05C5 },
    .{ .lo = 0x05C7, .hi = 0x05C7 },
    .{ .lo = 0x0610, .hi = 0x061A },
    .{ .lo = 0x064B, .hi = 0x065F },
    .{ .lo = 0x0670, .hi = 0x0670 },
    .{ .lo = 0x06D6, .hi = 0x06DC },
    .{ .lo = 0x06DF, .hi = 0x06E4 },
    .{ .lo = 0x06E7, .hi = 0x06E8 },
    .{ .lo = 0x06EA, .hi = 0x06ED },
    .{ .lo = 0x0711, .hi = 0x0711 },
    .{ .lo = 0x0730, .hi = 0x074A },
    .{ .lo = 0x07A6, .hi = 0x07B0 },
    .{ .lo = 0x07EB, .hi = 0x07F3 },
    .{ .lo = 0x0816, .hi = 0x0819 },
    .{ .lo = 0x081B, .hi = 0x0823 },
    .{ .lo = 0x0825, .hi = 0x0827 },
    .{ .lo = 0x0829, .hi = 0x082D },
    .{ .lo = 0x0900, .hi = 0x0902 },
    .{ .lo = 0x093A, .hi = 0x093A },
    .{ .lo = 0x093C, .hi = 0x093C },
    .{ .lo = 0x0941, .hi = 0x0948 },
    .{ .lo = 0x094D, .hi = 0x094D },
    .{ .lo = 0x0951, .hi = 0x0957 },
    .{ .lo = 0x0962, .hi = 0x0963 },
    .{ .lo = 0x0981, .hi = 0x0981 },
    .{ .lo = 0x09BC, .hi = 0x09BC },
    .{ .lo = 0x09C1, .hi = 0x09C4 },
    .{ .lo = 0x09CD, .hi = 0x09CD },
    .{ .lo = 0x0A01, .hi = 0x0A02 },
    .{ .lo = 0x0A3C, .hi = 0x0A3C },
    .{ .lo = 0x0A41, .hi = 0x0A42 },
    .{ .lo = 0x0A47, .hi = 0x0A48 },
    .{ .lo = 0x0A4B, .hi = 0x0A4D },
    .{ .lo = 0x0A81, .hi = 0x0A82 },
    .{ .lo = 0x0ABC, .hi = 0x0ABC },
    .{ .lo = 0x0AC1, .hi = 0x0AC5 },
    .{ .lo = 0x0AC7, .hi = 0x0AC8 },
    .{ .lo = 0x0ACD, .hi = 0x0ACD },
    .{ .lo = 0x0B01, .hi = 0x0B01 },
    .{ .lo = 0x0B3C, .hi = 0x0B3C },
    .{ .lo = 0x0B3F, .hi = 0x0B3F },
    .{ .lo = 0x0B41, .hi = 0x0B44 },
    .{ .lo = 0x0B4D, .hi = 0x0B4D },
    .{ .lo = 0x0BC0, .hi = 0x0BC0 },
    .{ .lo = 0x0BCD, .hi = 0x0BCD },
    .{ .lo = 0x0C3E, .hi = 0x0C40 },
    .{ .lo = 0x0C46, .hi = 0x0C48 },
    .{ .lo = 0x0C4A, .hi = 0x0C4D },
    .{ .lo = 0x0CBC, .hi = 0x0CBC },
    .{ .lo = 0x0CCC, .hi = 0x0CCD },
    .{ .lo = 0x0D41, .hi = 0x0D44 },
    .{ .lo = 0x0D4D, .hi = 0x0D4D },
    .{ .lo = 0x0DCA, .hi = 0x0DCA },
    .{ .lo = 0x0E31, .hi = 0x0E31 },
    .{ .lo = 0x0E34, .hi = 0x0E3A },
    .{ .lo = 0x0E47, .hi = 0x0E4E },
    .{ .lo = 0x0EB1, .hi = 0x0EB1 },
    .{ .lo = 0x0EB4, .hi = 0x0EBC },
    .{ .lo = 0x0EC8, .hi = 0x0ECD },
    .{ .lo = 0x0F35, .hi = 0x0F35 },
    .{ .lo = 0x0F37, .hi = 0x0F37 },
    .{ .lo = 0x0F39, .hi = 0x0F39 },
    .{ .lo = 0x0F71, .hi = 0x0F7E },
    .{ .lo = 0x0F80, .hi = 0x0F84 },
    .{ .lo = 0x0F86, .hi = 0x0F87 },
    .{ .lo = 0x0FC6, .hi = 0x0FC6 },
    .{ .lo = 0x102D, .hi = 0x1030 },
    .{ .lo = 0x1032, .hi = 0x1037 },
    .{ .lo = 0x1039, .hi = 0x103A },
    .{ .lo = 0x1058, .hi = 0x1059 },
    .{ .lo = 0x135F, .hi = 0x135F },
    .{ .lo = 0x1712, .hi = 0x1714 },
    .{ .lo = 0x1732, .hi = 0x1734 },
    .{ .lo = 0x1752, .hi = 0x1753 },
    .{ .lo = 0x1772, .hi = 0x1773 },
    .{ .lo = 0x17B4, .hi = 0x17B5 },
    .{ .lo = 0x17B7, .hi = 0x17BD },
    .{ .lo = 0x17C6, .hi = 0x17C6 },
    .{ .lo = 0x17C9, .hi = 0x17D3 },
    .{ .lo = 0x17DD, .hi = 0x17DD },
    .{ .lo = 0x180B, .hi = 0x180E },
    .{ .lo = 0x18A9, .hi = 0x18A9 },
    .{ .lo = 0x1920, .hi = 0x1922 },
    .{ .lo = 0x1927, .hi = 0x1928 },
    .{ .lo = 0x1932, .hi = 0x1932 },
    .{ .lo = 0x1939, .hi = 0x193B },
    .{ .lo = 0x1A17, .hi = 0x1A18 },
    .{ .lo = 0x1AB0, .hi = 0x1AFF },
    .{ .lo = 0x1B00, .hi = 0x1B03 },
    .{ .lo = 0x1B34, .hi = 0x1B34 },
    .{ .lo = 0x1B36, .hi = 0x1B3A },
    .{ .lo = 0x1B3C, .hi = 0x1B3C },
    .{ .lo = 0x1B42, .hi = 0x1B42 },
    .{ .lo = 0x1B6B, .hi = 0x1B73 },
    .{ .lo = 0x1DC0, .hi = 0x1DFF },
    .{ .lo = 0x200B, .hi = 0x200F },
    .{ .lo = 0x202A, .hi = 0x202E },
    .{ .lo = 0x2060, .hi = 0x2064 },
    .{ .lo = 0x206A, .hi = 0x206F },
    .{ .lo = 0x20D0, .hi = 0x20F0 },
    .{ .lo = 0x2CEF, .hi = 0x2CF1 },
    .{ .lo = 0x302A, .hi = 0x302F },
    .{ .lo = 0x3099, .hi = 0x309A },
    .{ .lo = 0xA806, .hi = 0xA806 },
    .{ .lo = 0xA80B, .hi = 0xA80B },
    .{ .lo = 0xA825, .hi = 0xA826 },
    .{ .lo = 0xFB1E, .hi = 0xFB1E },
    .{ .lo = 0xFE00, .hi = 0xFE0F },
    .{ .lo = 0xFE20, .hi = 0xFE2F },
    .{ .lo = 0xFEFF, .hi = 0xFEFF },
    .{ .lo = 0xFFF9, .hi = 0xFFFB },
    .{ .lo = 0x101FD, .hi = 0x101FD },
    .{ .lo = 0x10A01, .hi = 0x10A03 },
    .{ .lo = 0x10A0F, .hi = 0x10A0F },
    .{ .lo = 0x10A38, .hi = 0x10A3A },
    .{ .lo = 0x10A3F, .hi = 0x10A3F },
    .{ .lo = 0x11080, .hi = 0x11081 },
    .{ .lo = 0x110B3, .hi = 0x110B6 },
    .{ .lo = 0x110B9, .hi = 0x110BA },
    .{ .lo = 0x1D167, .hi = 0x1D169 },
    .{ .lo = 0x1D17B, .hi = 0x1D182 },
    .{ .lo = 0x1D185, .hi = 0x1D18B },
    .{ .lo = 0x1D1AA, .hi = 0x1D1AD },
    .{ .lo = 0x1D242, .hi = 0x1D244 },
    .{ .lo = 0xE0001, .hi = 0xE0001 },
    .{ .lo = 0xE0020, .hi = 0xE007F },
    .{ .lo = 0xE0100, .hi = 0xE01EF },
};

const wide = [_]Range{
    .{ .lo = 0x1100, .hi = 0x115F },
    .{ .lo = 0x231A, .hi = 0x231B },
    .{ .lo = 0x2329, .hi = 0x232A },
    .{ .lo = 0x23E9, .hi = 0x23EC },
    .{ .lo = 0x23F0, .hi = 0x23F0 },
    .{ .lo = 0x23F3, .hi = 0x23F3 },
    .{ .lo = 0x25FD, .hi = 0x25FE },
    .{ .lo = 0x2614, .hi = 0x2615 },
    .{ .lo = 0x2648, .hi = 0x2653 },
    .{ .lo = 0x267F, .hi = 0x267F },
    .{ .lo = 0x2693, .hi = 0x2693 },
    .{ .lo = 0x26A1, .hi = 0x26A1 },
    .{ .lo = 0x26AA, .hi = 0x26AB },
    .{ .lo = 0x26BD, .hi = 0x26BE },
    .{ .lo = 0x26C4, .hi = 0x26C5 },
    .{ .lo = 0x26CE, .hi = 0x26CE },
    .{ .lo = 0x26D4, .hi = 0x26D4 },
    .{ .lo = 0x26EA, .hi = 0x26EA },
    .{ .lo = 0x26F2, .hi = 0x26F3 },
    .{ .lo = 0x26F5, .hi = 0x26F5 },
    .{ .lo = 0x26FA, .hi = 0x26FA },
    .{ .lo = 0x26FD, .hi = 0x26FD },
    .{ .lo = 0x2705, .hi = 0x2705 },
    .{ .lo = 0x270A, .hi = 0x270B },
    .{ .lo = 0x2728, .hi = 0x2728 },
    .{ .lo = 0x274C, .hi = 0x274C },
    .{ .lo = 0x274E, .hi = 0x274E },
    .{ .lo = 0x2753, .hi = 0x2755 },
    .{ .lo = 0x2757, .hi = 0x2757 },
    .{ .lo = 0x2795, .hi = 0x2797 },
    .{ .lo = 0x27B0, .hi = 0x27B0 },
    .{ .lo = 0x27BF, .hi = 0x27BF },
    .{ .lo = 0x2B1B, .hi = 0x2B1C },
    .{ .lo = 0x2B50, .hi = 0x2B50 },
    .{ .lo = 0x2B55, .hi = 0x2B55 },
    .{ .lo = 0x2E80, .hi = 0x2E99 },
    .{ .lo = 0x2E9B, .hi = 0x2EF3 },
    .{ .lo = 0x2F00, .hi = 0x2FD5 },
    .{ .lo = 0x2FF0, .hi = 0x2FFB },
    .{ .lo = 0x3000, .hi = 0x303E },
    .{ .lo = 0x3041, .hi = 0x3096 },
    .{ .lo = 0x3099, .hi = 0x30FF },
    .{ .lo = 0x3105, .hi = 0x312F },
    .{ .lo = 0x3131, .hi = 0x318E },
    .{ .lo = 0x3190, .hi = 0x31E5 },
    .{ .lo = 0x31EF, .hi = 0x321E },
    .{ .lo = 0x3220, .hi = 0x3247 },
    .{ .lo = 0x3250, .hi = 0xA48C },
    .{ .lo = 0xA490, .hi = 0xA4C6 },
    .{ .lo = 0xA960, .hi = 0xA97C },
    .{ .lo = 0xAC00, .hi = 0xD7A3 },
    .{ .lo = 0xF900, .hi = 0xFAFF },
    .{ .lo = 0xFE10, .hi = 0xFE19 },
    .{ .lo = 0xFE30, .hi = 0xFE52 },
    .{ .lo = 0xFE54, .hi = 0xFE66 },
    .{ .lo = 0xFE68, .hi = 0xFE6B },
    .{ .lo = 0xFF01, .hi = 0xFF60 },
    .{ .lo = 0xFFE0, .hi = 0xFFE6 },
    .{ .lo = 0x16FE0, .hi = 0x16FE4 },
    .{ .lo = 0x16FF0, .hi = 0x16FF1 },
    .{ .lo = 0x17000, .hi = 0x187F7 },
    .{ .lo = 0x18800, .hi = 0x18CD5 },
    .{ .lo = 0x18D00, .hi = 0x18D08 },
    .{ .lo = 0x1AFF0, .hi = 0x1AFFE },
    .{ .lo = 0x1B000, .hi = 0x1B152 },
    .{ .lo = 0x1B164, .hi = 0x1B167 },
    .{ .lo = 0x1B170, .hi = 0x1B2FB },
    .{ .lo = 0x1F004, .hi = 0x1F004 },
    .{ .lo = 0x1F0CF, .hi = 0x1F0CF },
    .{ .lo = 0x1F18E, .hi = 0x1F18E },
    .{ .lo = 0x1F191, .hi = 0x1F19A },
    .{ .lo = 0x1F200, .hi = 0x1F320 },
    .{ .lo = 0x1F32D, .hi = 0x1F335 },
    .{ .lo = 0x1F337, .hi = 0x1F37C },
    .{ .lo = 0x1F37E, .hi = 0x1F393 },
    .{ .lo = 0x1F3A0, .hi = 0x1F3CA },
    .{ .lo = 0x1F3CF, .hi = 0x1F3D3 },
    .{ .lo = 0x1F3E0, .hi = 0x1F3F0 },
    .{ .lo = 0x1F3F4, .hi = 0x1F3F4 },
    .{ .lo = 0x1F3F8, .hi = 0x1F43E },
    .{ .lo = 0x1F440, .hi = 0x1F440 },
    .{ .lo = 0x1F442, .hi = 0x1F4FC },
    .{ .lo = 0x1F4FF, .hi = 0x1F53D },
    .{ .lo = 0x1F54B, .hi = 0x1F54E },
    .{ .lo = 0x1F550, .hi = 0x1F567 },
    .{ .lo = 0x1F57A, .hi = 0x1F57A },
    .{ .lo = 0x1F595, .hi = 0x1F596 },
    .{ .lo = 0x1F5A4, .hi = 0x1F5A4 },
    .{ .lo = 0x1F5FB, .hi = 0x1F64F },
    .{ .lo = 0x1F680, .hi = 0x1F6C5 },
    .{ .lo = 0x1F6CC, .hi = 0x1F6CC },
    .{ .lo = 0x1F6D0, .hi = 0x1F6D2 },
    .{ .lo = 0x1F6D5, .hi = 0x1F6D7 },
    .{ .lo = 0x1F6EB, .hi = 0x1F6EC },
    .{ .lo = 0x1F6F4, .hi = 0x1F6FC },
    .{ .lo = 0x1F7E0, .hi = 0x1F7EB },
    .{ .lo = 0x1F90C, .hi = 0x1F93A },
    .{ .lo = 0x1F93C, .hi = 0x1F945 },
    .{ .lo = 0x1F947, .hi = 0x1F9FF },
    .{ .lo = 0x1FA70, .hi = 0x1FA74 },
    .{ .lo = 0x1FA78, .hi = 0x1FA7C },
    .{ .lo = 0x1FA80, .hi = 0x1FA86 },
    .{ .lo = 0x1FA90, .hi = 0x1FAAC },
    .{ .lo = 0x1FAB0, .hi = 0x1FABA },
    .{ .lo = 0x1FAC0, .hi = 0x1FAC5 },
    .{ .lo = 0x1FAD0, .hi = 0x1FAD9 },
    .{ .lo = 0x1FAE0, .hi = 0x1FAE7 },
    .{ .lo = 0x1FAF0, .hi = 0x1FAF6 },
    .{ .lo = 0x20000, .hi = 0x2FFFD },
    .{ .lo = 0x30000, .hi = 0x3FFFD },
};

/// East Asian Width = Ambiguous（模糊宽度）。宽度由终端/字体决定：
/// 实测 Windows Terminal + 默认字体下，终端对这些字符的“记账”是 1 列，
/// 但字形常按全角设计（比格子宽约 1px），相邻时圆圈互相挤压。
/// 这里统一按 2 列处理（CJK 传统语义），并由 Terminal.flush 显式补续格空格
/// 强制对齐光标（见 terminal/mod.zig 的 ambiguous_advance）。
/// 例外（保持 1 列）：盒绘线 0x2500-0x257F 与块元素 0x2580-0x259F——
/// 传统半角，且本 TUI 的边框/工具块直接依赖它们占 1 列。
/// 数据源：Unicode 18.0 EastAsianWidth.txt，剔除组合记号/格式/私用/未分配/FFFD。
const ambiguous = [_]Range{
    .{ .lo = 0xA1, .hi = 0xA1 },
    .{ .lo = 0xA4, .hi = 0xA4 },
    .{ .lo = 0xA7, .hi = 0xA8 },
    .{ .lo = 0xAA, .hi = 0xAA },
    .{ .lo = 0xAE, .hi = 0xAE },
    .{ .lo = 0xB0, .hi = 0xB4 },
    .{ .lo = 0xB6, .hi = 0xBA },
    .{ .lo = 0xBC, .hi = 0xBF },
    .{ .lo = 0xC6, .hi = 0xC6 },
    .{ .lo = 0xD0, .hi = 0xD0 },
    .{ .lo = 0xD7, .hi = 0xD8 },
    .{ .lo = 0xDE, .hi = 0xE1 },
    .{ .lo = 0xE6, .hi = 0xE6 },
    .{ .lo = 0xE8, .hi = 0xEA },
    .{ .lo = 0xEC, .hi = 0xED },
    .{ .lo = 0xF0, .hi = 0xF0 },
    .{ .lo = 0xF2, .hi = 0xF3 },
    .{ .lo = 0xF7, .hi = 0xFA },
    .{ .lo = 0xFC, .hi = 0xFC },
    .{ .lo = 0xFE, .hi = 0xFE },
    .{ .lo = 0x101, .hi = 0x101 },
    .{ .lo = 0x111, .hi = 0x111 },
    .{ .lo = 0x113, .hi = 0x113 },
    .{ .lo = 0x11B, .hi = 0x11B },
    .{ .lo = 0x126, .hi = 0x127 },
    .{ .lo = 0x12B, .hi = 0x12B },
    .{ .lo = 0x131, .hi = 0x133 },
    .{ .lo = 0x138, .hi = 0x138 },
    .{ .lo = 0x13F, .hi = 0x142 },
    .{ .lo = 0x144, .hi = 0x144 },
    .{ .lo = 0x148, .hi = 0x14B },
    .{ .lo = 0x14D, .hi = 0x14D },
    .{ .lo = 0x152, .hi = 0x153 },
    .{ .lo = 0x166, .hi = 0x167 },
    .{ .lo = 0x16B, .hi = 0x16B },
    .{ .lo = 0x1CE, .hi = 0x1CE },
    .{ .lo = 0x1D0, .hi = 0x1D0 },
    .{ .lo = 0x1D2, .hi = 0x1D2 },
    .{ .lo = 0x1D4, .hi = 0x1D4 },
    .{ .lo = 0x1D6, .hi = 0x1D6 },
    .{ .lo = 0x1D8, .hi = 0x1D8 },
    .{ .lo = 0x1DA, .hi = 0x1DA },
    .{ .lo = 0x1DC, .hi = 0x1DC },
    .{ .lo = 0x251, .hi = 0x251 },
    .{ .lo = 0x261, .hi = 0x261 },
    .{ .lo = 0x2C4, .hi = 0x2C4 },
    .{ .lo = 0x2C7, .hi = 0x2C7 },
    .{ .lo = 0x2C9, .hi = 0x2CB },
    .{ .lo = 0x2CD, .hi = 0x2CD },
    .{ .lo = 0x2D0, .hi = 0x2D0 },
    .{ .lo = 0x2D8, .hi = 0x2DB },
    .{ .lo = 0x2DD, .hi = 0x2DD },
    .{ .lo = 0x2DF, .hi = 0x2DF },
    .{ .lo = 0x391, .hi = 0x3A1 },
    .{ .lo = 0x3A3, .hi = 0x3A9 },
    .{ .lo = 0x3B1, .hi = 0x3C1 },
    .{ .lo = 0x3C3, .hi = 0x3C9 },
    .{ .lo = 0x401, .hi = 0x401 },
    .{ .lo = 0x410, .hi = 0x44F },
    .{ .lo = 0x451, .hi = 0x451 },
    .{ .lo = 0x2010, .hi = 0x2010 },
    .{ .lo = 0x2013, .hi = 0x2016 },
    .{ .lo = 0x2018, .hi = 0x2019 },
    .{ .lo = 0x201C, .hi = 0x201D },
    .{ .lo = 0x2020, .hi = 0x2022 },
    .{ .lo = 0x2024, .hi = 0x2027 },
    .{ .lo = 0x2030, .hi = 0x2030 },
    .{ .lo = 0x2032, .hi = 0x2033 },
    .{ .lo = 0x2035, .hi = 0x2035 },
    .{ .lo = 0x203B, .hi = 0x203B },
    .{ .lo = 0x203E, .hi = 0x203E },
    .{ .lo = 0x2074, .hi = 0x2074 },
    .{ .lo = 0x207F, .hi = 0x207F },
    .{ .lo = 0x2081, .hi = 0x2084 },
    .{ .lo = 0x20AC, .hi = 0x20AC },
    .{ .lo = 0x2103, .hi = 0x2103 },
    .{ .lo = 0x2105, .hi = 0x2105 },
    .{ .lo = 0x2109, .hi = 0x2109 },
    .{ .lo = 0x2113, .hi = 0x2113 },
    .{ .lo = 0x2116, .hi = 0x2116 },
    .{ .lo = 0x2121, .hi = 0x2122 },
    .{ .lo = 0x2126, .hi = 0x2126 },
    .{ .lo = 0x212B, .hi = 0x212B },
    .{ .lo = 0x2153, .hi = 0x2154 },
    .{ .lo = 0x215B, .hi = 0x215E },
    .{ .lo = 0x2160, .hi = 0x216B },
    .{ .lo = 0x2170, .hi = 0x2179 },
    .{ .lo = 0x2189, .hi = 0x2189 },
    .{ .lo = 0x2190, .hi = 0x2199 },
    .{ .lo = 0x21B8, .hi = 0x21B9 },
    .{ .lo = 0x21D2, .hi = 0x21D2 },
    .{ .lo = 0x21D4, .hi = 0x21D4 },
    .{ .lo = 0x21E7, .hi = 0x21E7 },
    .{ .lo = 0x2200, .hi = 0x2200 },
    .{ .lo = 0x2202, .hi = 0x2203 },
    .{ .lo = 0x2207, .hi = 0x2208 },
    .{ .lo = 0x220B, .hi = 0x220B },
    .{ .lo = 0x220F, .hi = 0x220F },
    .{ .lo = 0x2211, .hi = 0x2211 },
    .{ .lo = 0x2215, .hi = 0x2215 },
    .{ .lo = 0x221A, .hi = 0x221A },
    .{ .lo = 0x221D, .hi = 0x2220 },
    .{ .lo = 0x2223, .hi = 0x2223 },
    .{ .lo = 0x2225, .hi = 0x2225 },
    .{ .lo = 0x2227, .hi = 0x222C },
    .{ .lo = 0x222E, .hi = 0x222E },
    .{ .lo = 0x2234, .hi = 0x2237 },
    .{ .lo = 0x223C, .hi = 0x223D },
    .{ .lo = 0x2248, .hi = 0x2248 },
    .{ .lo = 0x224C, .hi = 0x224C },
    .{ .lo = 0x2252, .hi = 0x2252 },
    .{ .lo = 0x2260, .hi = 0x2261 },
    .{ .lo = 0x2264, .hi = 0x2267 },
    .{ .lo = 0x226A, .hi = 0x226B },
    .{ .lo = 0x226E, .hi = 0x226F },
    .{ .lo = 0x2282, .hi = 0x2283 },
    .{ .lo = 0x2286, .hi = 0x2287 },
    .{ .lo = 0x2295, .hi = 0x2295 },
    .{ .lo = 0x2299, .hi = 0x2299 },
    .{ .lo = 0x22A5, .hi = 0x22A5 },
    .{ .lo = 0x22BF, .hi = 0x22BF },
    .{ .lo = 0x2312, .hi = 0x2312 },
    .{ .lo = 0x2460, .hi = 0x24E9 },
    .{ .lo = 0x24EB, .hi = 0x24FF },
    .{ .lo = 0x25A0, .hi = 0x25A1 },
    .{ .lo = 0x25A3, .hi = 0x25A9 },
    .{ .lo = 0x25B2, .hi = 0x25B3 },
    .{ .lo = 0x25B6, .hi = 0x25B7 },
    .{ .lo = 0x25BC, .hi = 0x25BD },
    .{ .lo = 0x25C0, .hi = 0x25C1 },
    .{ .lo = 0x25C6, .hi = 0x25C8 },
    .{ .lo = 0x25CB, .hi = 0x25CB },
    .{ .lo = 0x25CE, .hi = 0x25D1 },
    .{ .lo = 0x25E2, .hi = 0x25E5 },
    .{ .lo = 0x25EF, .hi = 0x25EF },
    .{ .lo = 0x2605, .hi = 0x2606 },
    .{ .lo = 0x2609, .hi = 0x2609 },
    .{ .lo = 0x260E, .hi = 0x260F },
    .{ .lo = 0x261C, .hi = 0x261C },
    .{ .lo = 0x261E, .hi = 0x261E },
    .{ .lo = 0x2640, .hi = 0x2640 },
    .{ .lo = 0x2642, .hi = 0x2642 },
    .{ .lo = 0x2660, .hi = 0x2661 },
    .{ .lo = 0x2663, .hi = 0x2665 },
    .{ .lo = 0x2667, .hi = 0x266A },
    .{ .lo = 0x266C, .hi = 0x266D },
    .{ .lo = 0x266F, .hi = 0x266F },
    .{ .lo = 0x269E, .hi = 0x269F },
    .{ .lo = 0x26BF, .hi = 0x26BF },
    .{ .lo = 0x26C6, .hi = 0x26CD },
    .{ .lo = 0x26CF, .hi = 0x26D3 },
    .{ .lo = 0x26D5, .hi = 0x26E1 },
    .{ .lo = 0x26E3, .hi = 0x26E3 },
    .{ .lo = 0x26E8, .hi = 0x26E9 },
    .{ .lo = 0x26EB, .hi = 0x26F1 },
    .{ .lo = 0x26F4, .hi = 0x26F4 },
    .{ .lo = 0x26F6, .hi = 0x26F9 },
    .{ .lo = 0x26FB, .hi = 0x26FC },
    .{ .lo = 0x26FE, .hi = 0x26FF },
    .{ .lo = 0x273D, .hi = 0x273D },
    .{ .lo = 0x2776, .hi = 0x277F },
    .{ .lo = 0x2B56, .hi = 0x2B59 },
    .{ .lo = 0x3248, .hi = 0x324F },
    .{ .lo = 0x1F100, .hi = 0x1F10A },
    .{ .lo = 0x1F110, .hi = 0x1F12D },
    .{ .lo = 0x1F130, .hi = 0x1F169 },
    .{ .lo = 0x1F170, .hi = 0x1F18D },
    .{ .lo = 0x1F18F, .hi = 0x1F190 },
    .{ .lo = 0x1F19B, .hi = 0x1F1AC },
};

fn inRanges(ranges: []const Range, cp: u21) bool {
    var lo: usize = 0;
    var hi: usize = ranges.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const r = ranges[mid];
        if (cp < r.lo) {
            hi = mid;
        } else if (cp > r.hi) {
            lo = mid + 1;
        } else {
            return true;
        }
    }
    return false;
}

/// 「模糊宽度」策略：按 2 列（CJK 传统）还是 1 列（多数终端/其他库的默认，如
/// string-width 的 ambiguousIsNarrow、OpenTUI/opencode 的实现）处理。
/// 本 vendored fork 默认 .wide 保持既有行为；SkyNet 启动时按配置覆盖：
/// config.json 的 ambiguous_width（wide/narrow/auto）。
pub const AmbiguousWidth = enum { wide, narrow };
pub var ambiguous_width: AmbiguousWidth = .wide;

pub fn codepointWidth(cp: u21) u2 {
    if (cp < 0x20 or (cp >= 0x7F and cp < 0xA0)) return 0;
    // 用户覆盖优先于一切（含 ASCII 快速路径；无覆盖名单时零开销）
    if (wide_override_count > 0 and inSortedList(wide_overrides[0..wide_override_count], cp)) return 2;
    if (cp < 0xA0) return 1;
    if (inRanges(&zero_width, cp)) return 0;
    if (narrow_override_count > 0 and inSortedList(narrow_overrides[0..narrow_override_count], cp)) {
        // 真宽字符终端固定渲染 2 列：narrow 覆盖无法生效，保持 2 列与终端一致
        if (inRanges(&wide, cp)) return 2;
        return 1;
    }
    if (inRanges(&wide, cp)) return 2;
    if (inRanges(&ambiguous, cp)) return switch (ambiguous_width) {
        .wide => 2,
        .narrow => 1,
    };
    return 1;
}

/// One decoded code point and the number of bytes it consumed.
pub const DecodedChar = struct { cp: u21, len: usize };

/// Decodes the code point starting at `bytes[index]`; `index` must be in
/// bounds. Malformed input (invalid start byte, truncated or overlong
/// sequence) yields U+FFFD with `len = 1`, so callers advance a single byte
/// and never skip past a following valid code point.
pub fn decodeCharAt(bytes: []const u8, index: usize) DecodedChar {
    const len = std.unicode.utf8ByteSequenceLength(bytes[index]) catch return .{ .cp = 0xFFFD, .len = 1 };
    if (index + len > bytes.len) return .{ .cp = 0xFFFD, .len = 1 };
    const cp = std.unicode.utf8Decode(bytes[index .. index + len]) catch return .{ .cp = 0xFFFD, .len = 1 };
    return .{ .cp = cp, .len = len };
}

/// Display width of `bytes` in columns. Malformed UTF-8 counts as the
/// replacement character (one column), matching how it is rendered.

/// 是否属于「模糊宽度」字符类（与当前策略无关；策略见 ambiguous_width）。
pub fn isAmbiguous(cp: u21) bool {
    return inRanges(&ambiguous, cp);
}

/// 用户宽度覆盖名单：wide 强制 2 列、narrow 强制 1 列（真宽字符除外，见 codepointWidth）。
/// 由宿主（SkyNet）在启动时按 config.json 的 width_overrides 设置。
pub const max_width_overrides = 1024;

var wide_overrides: [max_width_overrides]u21 = [_]u21{0} ** max_width_overrides;
var wide_override_count: usize = 0;
var narrow_overrides: [max_width_overrides]u21 = [_]u21{0} ** max_width_overrides;
var narrow_override_count: usize = 0;

fn setOverrideList(dst: []u21, count: *usize, cps: []const u21) void {
    const n = @min(cps.len, dst.len);
    @memcpy(dst[0..n], cps[0..n]);
    std.mem.sort(u21, dst[0..n], {}, std.sort.asc(u21));
    count.* = n;
}

/// 设置宽度覆盖名单（内部排序以支持二分查找；超出上限部分忽略）
pub fn setWidthOverrides(wide_cps: []const u21, narrow_cps: []const u21) void {
    setOverrideList(&wide_overrides, &wide_override_count, wide_cps);
    setOverrideList(&narrow_overrides, &narrow_override_count, narrow_cps);
}

fn inSortedList(list: []const u21, cp: u21) bool {
    var lo: usize = 0;
    var hi: usize = list.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (list[mid] == cp) return true;
        if (list[mid] < cp) lo = mid + 1 else hi = mid;
    }
    return false;
}

/// 终端实际推进列数（与用户覆盖无关——终端不认识覆盖名单）：
/// 真宽字符恒 2；模糊宽度字符取决于终端（ambiguous_terminal_wide）；
/// 其余为 1。渲染层据此对「记账 2 列、终端推 1 列」的字符补续格空格
/// （见 terminal/mod.zig 的 flush）。
pub fn terminalAdvance(cp: u21, ambiguous_terminal_wide: bool) u2 {
    if (inRanges(&wide, cp)) return 2;
    if (inRanges(&ambiguous, cp)) return if (ambiguous_terminal_wide) 2 else 1;
    return 1;
}

/// 宽容处理非法 UTF-8 字节（按替换字符计 1 列）
pub fn stringWidth(bytes: []const u8) usize {
    var total: usize = 0;
    var i: usize = 0;
    while (i < bytes.len) {
        const d = decodeCharAt(bytes, i);
        total += codepointWidth(d.cp);
        i += d.len;
    }
    return total;
}

/// Longest prefix of `bytes` that fits within `max_columns`, without
/// splitting a code point. Malformed UTF-8 is handled like the replacement
/// character.
pub fn truncateToWidth(bytes: []const u8, max_columns: usize) []const u8 {
    var used: usize = 0;
    var end: usize = 0;
    var i: usize = 0;
    while (i < bytes.len) {
        const d = decodeCharAt(bytes, i);
        const w = codepointWidth(d.cp);
        if (used + w > max_columns) break;
        used += w;
        i += d.len;
        end = i;
    }
    return bytes[0..end];
}

test "ascii and control widths" {
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('a'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth(' '));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0x7F));
}

test "wide and zero width codepoints" {
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('日'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('한'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x1F600));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0x0301));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0xFE0F));
}

test "box drawing stays narrow" {
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('─'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('╭'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('█'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('▀'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('⣿'));
}

test "ambiguous width treated as wide(2)" {
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('①')); // U+2460
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x24EB)); // ⓫（注意 U+24EA ⓪ 官方为 Neutral，保持 1）
    try std.testing.expectEqual(@as(u2, 1), codepointWidth(0x24EA));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('←'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('≤'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('°'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('α'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('…'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('Ⅰ'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth(0xFFFD));

    try std.testing.expect(isAmbiguous('①'));
    try std.testing.expect(isAmbiguous('…'));
    try std.testing.expect(!isAmbiguous(0x2500));
    try std.testing.expect(!isAmbiguous('a'));
    try std.testing.expect(!isAmbiguous('中'));
}

test "ambiguous width policy: narrow(1) 切换与恢复" {
    const saved = ambiguous_width;
    defer ambiguous_width = saved;

    ambiguous_width = .narrow;
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('①'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('…'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('→'));
    // 真宽字符与盒绘线不受策略影响
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('中'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x1F600));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('─'));
    // stringWidth / truncateToWidth 跟随策略
    try std.testing.expectEqual(@as(usize, 3), stringWidth("①ab"));
    try std.testing.expectEqualStrings("①", truncateToWidth("①②", 1));

    ambiguous_width = .wide;
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('①'));
    try std.testing.expectEqual(@as(usize, 4), stringWidth("①ab"));
    try std.testing.expectEqualStrings("", truncateToWidth("①②", 1));
}

test "width overrides: 名单优先于策略，真宽字符不被 narrow 收缩" {
    const saved_policy = ambiguous_width;
    defer ambiguous_width = saved_policy;
    defer setWidthOverrides(&[_]u21{}, &[_]u21{});

    // 策略 wide：narrow 覆盖要把 — (U+2014) 压窄；wide 覆盖把 ④ (U+2463) 提宽
    ambiguous_width = .wide;
    setWidthOverrides(&[_]u21{0x2463}, &[_]u21{0x2014});
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x2463)); // 覆盖为宽
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x2460)); // 策略宽（未覆盖）
    try std.testing.expectEqual(@as(u2, 1), codepointWidth(0x2014)); // 覆盖为窄（策略本是宽）

    // 策略 narrow：wide 覆盖把 ① 提宽
    ambiguous_width = .narrow;
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x2463));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth(0x2460));

    // 真宽字符不受 narrow 覆盖影响（终端固定 2 列）
    setWidthOverrides(&[_]u21{}, &[_]u21{0x4E2D});
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('中'));

    // 全自由度：任何字符可覆盖为宽；stringWidth/truncateToWidth 跟随
    setWidthOverrides(&[_]u21{'A'}, &[_]u21{});
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('A'));
    try std.testing.expectEqual(@as(usize, 4), stringWidth("Aab"));
    try std.testing.expectEqualStrings("", truncateToWidth("A", 1));
}

test "terminalAdvance：真宽恒 2；模糊看终端；其余 1" {
    try std.testing.expectEqual(@as(u2, 2), terminalAdvance('中', false));
    try std.testing.expectEqual(@as(u2, 2), terminalAdvance('日', true));
    try std.testing.expectEqual(@as(u2, 1), terminalAdvance(0x2014, false));
    try std.testing.expectEqual(@as(u2, 2), terminalAdvance(0x2014, true));
    try std.testing.expectEqual(@as(u2, 1), terminalAdvance('a', false));
    try std.testing.expectEqual(@as(u2, 1), terminalAdvance('a', true));
}

test "string width" {
    try std.testing.expectEqual(@as(usize, 5), stringWidth("hello"));
    try std.testing.expectEqual(@as(usize, 8), stringWidth("日本語ab"));
    try std.testing.expectEqual(@as(usize, 1), stringWidth("e\u{0301}"));
}

test "malformed UTF-8 decodes as U+FFFD" {
    // Stray invalid byte.
    const stray = [_]u8{ 'a', 0xFF, 'b' };
    try std.testing.expectEqual(@as(usize, 3), stringWidth(&stray));
    try std.testing.expectEqual(@as(usize, 3), truncateToWidth(&stray, 10).len);
    try std.testing.expectEqual(@as(usize, 1), truncateToWidth(&stray, 1).len);

    // Truncated multi-byte sequence at the end of the input.
    const truncated = [_]u8{ 0xE4, 0xBD };
    try std.testing.expectEqual(@as(usize, 2), stringWidth(&truncated));

    // A malformed sequence must not swallow the following valid byte.
    const bad_prefix = [_]u8{ 0xE4, 0xBD, '.' };
    try std.testing.expectEqual(@as(usize, 3), stringWidth(&bad_prefix));
    try std.testing.expectEqualStrings("\xE4\xBD", truncateToWidth(&bad_prefix, 2));

    // Overlong encoding.
    const overlong = [_]u8{ 0xC0, 0xAF };
    try std.testing.expectEqual(@as(usize, 2), stringWidth(&overlong));
}

test "truncate to width never splits a wide codepoint" {
    try std.testing.expectEqualStrings("日", truncateToWidth("日本", 3));
    try std.testing.expectEqualStrings("日本", truncateToWidth("日本", 4));
    try std.testing.expectEqualStrings("", truncateToWidth("日本", 1));
}
