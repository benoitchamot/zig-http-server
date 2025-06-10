const std = @import("std");
const strings = @import("strings.zig");
const net = std.net;
const posix = std.posix;

// Some shortcuts as I feel I'm gonna need this a lot...
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// Some errors
const RequestError = error {
    Unsupported,
};


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
        
        // Allocator used by the server
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();


        // Infinite loop with a blocking listener
        while (true) {
            var client_address: net.Address = undefined;
            var client_address_len: posix.socklen_t = @sizeOf(net.Address);

            const socket = posix.accept(listener,
                                        &client_address.any,
                                        &client_address_len,
                                        0) catch |err| {
                print("Error access: {}\n", .{err});
                continue;
            };
            defer posix.close(socket);

            print("{} connected\n", .{client_address});

            // Prepare some code to read requests
            // The read data are in buf[0..read]
            const buf = try allocator.alloc(u8, 500_000);
            const read = posix.read(socket, buf) catch |err| {
                print("Error reading: {}\n", .{err});
                continue;
            };
            if (read == 0) {
                continue;
            }

            // Parse the request
            const pageName = parseRequest(buf[0..read]);
            if (pageName) |value| {
                // Construct a simple message with some HTML
                //const pageName = "index.html";
                print("{s}\n", .{value.?});
                const simple_message = try respondWithHtml(allocator, value orelse "index.html");

                // Handle request
                write(socket, simple_message) catch |err| {
                    // Handle a client disconnecting
                    print("Error writing: {}\n", .{err});
                };
            }
            else |err| switch (err) {
                RequestError.Unsupported => print("Unsupported request.", .{}),
                else => unreachable
            }
        }
    }

    fn parseRequest(request: []const u8) RequestError!?[]const u8 {
        // Get the first line of the request
        // var firstLine = try allocator.alloc(u8, 1000);
        var eolIndex: usize = undefined;
        if (std.mem.indexOf(u8, request, "\r\n")) |index| {
            //firstLine = request[0..index];
            eolIndex = index;
        }
        else {
            unreachable;
        }

        // Split the first line based on spaces
        var firstLineArray = std.mem.splitSequence(u8, request[0..eolIndex], " ");

        // Make sure it's a GET and if it is, return the page
        if (std.mem.eql(u8, firstLineArray.first(), "GET")) {
            if (std.mem.eql(u8, firstLineArray.peek().?, "/")) {
                return "index.html";
            }
            else if (std.mem.indexOf(u8, firstLineArray.peek().?, ".html")) |_| {
                // Drop the leading /
                return firstLineArray.next().?[1..];
            }
            else {
                return RequestError.Unsupported;
            }
        }
        else {
            return RequestError.Unsupported;
        }
    }


    fn readHtmlFile(allocator: Allocator, folder: []const u8, filename: []const u8) ![]u8 {
        const maxSize = 2_000_000; // That seems like a reasonable max size...

        // Get the the folder and open the file
        const cwd = std.fs.cwd();

        var siteDirectory = try cwd.openDir(folder, .{});
        const file = try siteDirectory.openFile(filename, .{});
        defer file.close();

        // Read from the file
        const htmlPage = try file.readToEndAlloc(allocator, maxSize);
        return htmlPage;
    }

    fn respondWithHtml(allocator: Allocator, filename: []const u8) ![]const u8 {
        // This works only at comptime
        // TODO: look into dynamic alloc: https://gencmurat.com/en/posts/zig-strings/
        const responseLine = "HTTP/1.1 200 OK";
        const headers = "Content-type: text/html";
        //const breakLine = "\r\n";
        //const htmlBody = "<h1>Dummy Server v0.1 Alpha</h1>\n<p>You're doing it you bastard</p>";

        // Retrieve HTML content
        // Would it be wise to declare another allocator so it get cleared here?
        const folder = "www";
        const htmlContent = try readHtmlFile(allocator, folder, filename); 

        // Response line + CRLF
        var response = try strings.concat(allocator, responseLine, "\r\n");
        
        // Add headers
        response = try strings.concat(allocator, response, headers);

        // Add breakline
        response = try strings.concat(allocator, response, "\r\n\r\n");

        // Add HTML
        response = try strings.concat(allocator, response, htmlContent);

        return response;
        // return responseLine ++ "\r\n" ++ headers ++ "\r\n" ++ breakLine ++ htmlBody;
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

    // Run server
    print("Welcome to my Server\n", .{});
    const server = HTTPServer.init(address);
    try server.start();
}
