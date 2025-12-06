const std = @import("std");
const stdout = std.fs.File.stdout().deprecatedWriter();

const magick = @cImport({
    @cDefine("MAGICKCORE_HDRI_ENABLE", "0");
    @cInclude("MagickWand/MagickWand.h");
});

const popt = @cImport(@cInclude("popt.h"));

const PanelCopyError = error{ FileNotFound, MagickReadError, MagickWriteError, WeirdMagickError };

const Node = struct { data: [*:0]const u8, node: std.DoublyLinkedList.Node = .{} };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var ifiles: std.DoublyLinkedList = .{};
    var ofile: ?[*:0]const u8 = null;

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (ofile != null) return printHelp();
            ofile = args.next() orelse return printHelp();
            continue;
        }
        if (arg[0] == '-')
            return printHelp();
        var node = try alloc.alloc(Node, 1);
        node[0] = .{ .data = arg };
        ifiles.append(&node[0].node);
    }

    if (ofile == null or ifiles.first == null)
        return printHelp();

    magick.MagickWandGenesis();
    defer magick.MagickWandTerminus(); // TERMINUS!!!!

    var diagnostic: ?[*:0]const u8 = null;
    if (spliceImages(&ifiles, false, &diagnostic)) |result| {
        defer _ = magick.DestroyMagickWand(result);
        const status = magick.MagickWriteImage(result, ofile);
        if (status == magick.MagickFalse)
            return PanelCopyError.MagickWriteError;
    } else |err| {
        defer _ = magick.RelinquishMagickMemory(@constCast(diagnostic));
        switch (err) {
            PanelCopyError.FileNotFound => try stdout.print("Error: File \"{s}\" not found\n", .{diagnostic.?}),
            PanelCopyError.MagickReadError => try stdout.print("Error: File \"{s}\" isn't an image\n", .{diagnostic.?}),
            PanelCopyError.WeirdMagickError => try stdout.print("{s}\n", .{diagnostic.?}),
            else => |e| return e,
        }
    }
}

fn printHelp() !void {
    return stdout.writeAll("Usage: panelcopy IMAGES... -o OUTFILE\n");
}

fn spliceImages(filenames: *std.DoublyLinkedList, horizontal: bool, diagnostic: *?[*:0]const u8) !?*magick.MagickWand {
    var mwand = magick.NewMagickWand();
    defer mwand = magick.DestroyMagickWand(mwand);
    var it = filenames.first;
    while (it) |n| : (it = n.next) {
        const filename = @as(*Node, @fieldParentPtr("node", n)).data;
        const fd = std.c.fopen(filename, "r");
        if (fd == null) {
            diagnostic.* = filename;
            return PanelCopyError.FileNotFound;
        }
        defer _ = std.c.fclose(fd.?);
        _ = magick.MagickClearException(mwand);
        if (magick.MagickReadImageFile(mwand, @ptrCast(fd.?)) == magick.MagickFalse) {
            var severity: magick.ExceptionType = 0;
            diagnostic.* = magick.MagickGetException(mwand, &severity);
            if (severity == magick.MissingDelegateError) {
                diagnostic.* = filename;
                return PanelCopyError.MagickReadError;
            }
            return PanelCopyError.WeirdMagickError;
        }
    }
    magick.MagickResetIterator(mwand);
    return magick.MagickAppendImages(mwand, if (horizontal) magick.MagickFalse else magick.MagickTrue);
}
