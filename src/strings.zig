const std = @import("std");
const Allocator = std.mem.Allocator;

const print = std.debug.print;

pub fn concat(allocator: Allocator, strA: []const u8, strB: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, strA.len + strB.len);
    @memcpy(result[0..strA.len], strA);
    @memcpy(result[strA.len..], strB);
    return result;
}
