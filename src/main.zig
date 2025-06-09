const std = @import("std");
const net = std.net;
const posix = std.posix;

// Some shortcut as I feel I'm gonna need this a lot...
const print = std.debug.print;

const HTTPServer = struct {
    address: net.Address,

    pub fn init(addr: std.net.Address) HTTPServer {
        return HTTPServer {
            .address = addr,
        };
    }

    pub fn start(self: HTTPServer) !void {
        // Some hard-coding is OK for this demo...
        const sockType: u32 = posix.SOCK.STREAM;
        const sockProtocol = posix.IPPROTO.TCP;
        
        // By using .any.family, we infer the family from the address
        const listener = try posix.socket(self.address.any.family, sockType, sockProtocol);
        defer posix.close(listener);
    
        // Set up a listener and allow for the address to be reused
        try posix.setsockopt(listener,
                            posix.SOL.SOCKET,
                            posix.SO.REUSEADDR,
                            &std.mem.toBytes(@as(c_int, 1))
        );

        try posix.bind(listener, &self.address.any, self.address.getOsSockLen());
        try posix.listen(listener, 128);

        while (true) {
            var client_address: net.Address = undefined;
            var client_address_len: posix.socklen_t = @sizeOf(net.Address);

            const socket = posix.accept(listener,
                                        &client_address.any,
                                        &client_address_len,
                                        0) catch |err| {
                print("Error acces: {}\n", .{err});
                continue;
            };
            defer posix.close(socket);

            print("{} connected\n", .{client_address});

            // Now we have some HTTP!
            const simple_message = "HTTP/1.1 200 OK\r\nContent-type: text/html\r\n\r\n<h1>Dummy Server v1.1</h1>";

            write(socket, simple_message) catch |err| {
                // Handle a client disconnecting
                print("Error writing: {}\n", .{err});
            };
        }
    }

    fn write(socket: posix.socket_t, msg: []const u8) !void {
        var pos: usize = 0;
        while (pos < msg.len) {
            const written = try posix.write(socket, msg[pos..]);
            if (written == 0) {
                return error.Closed;
            }
            pos += written;
        }
    }
};


pub fn main() !void {
    // Some global constant stuff
    const address = try net.Address.parseIp("127.0.0.1", 8888);
    
    const server = HTTPServer.init(address);
    print("Welcome to my Server\n", .{});

    try server.start();

}
