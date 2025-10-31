const std = @import("std");
const stdout = std.fs.File.stdout();
const alloc = std.heap.smp_allocator;

const magick = @cImport({
    @cDefine("MAGICKCORE_HDRI_ENABLE", "0");
    @cInclude("MagickWand/MagickWand.h");
});

const popt = @cImport(@cInclude("popt.h"));

const PanelCopyError = error{ MagickReadError, MagickWriteError };

const Node = struct { data: [*:0]const u8, node: std.DoublyLinkedList.Node = .{} };

pub fn main() !void {
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

    var result = try spliceImages(&ifiles, false);
    defer result = magick.DestroyMagickWand(result);
    const status = magick.MagickWriteImage(result, ofile);
    if (status == magick.MagickFalse)
        return PanelCopyError.MagickWriteError;
}

fn printHelp() !void {
    return std.fs.File.stdout().writeAll("Usage: panelcopy IMAGES... -o OUTFILE\n");
}

fn spliceImages(filenames: *std.DoublyLinkedList, horizontal: bool) !?*magick.MagickWand {
    var mwand = magick.NewMagickWand();
    defer mwand = magick.DestroyMagickWand(mwand);
    var it = filenames.first;
    while (it) |n| : (it = n.next) {
        const node: *Node = @as(*Node, @fieldParentPtr("node", n));
        const filename = node.data;
        if (magick.MagickReadImage(mwand, filename) == magick.MagickFalse)
            return PanelCopyError.MagickReadError;
    }
    magick.MagickResetIterator(mwand);
    return magick.MagickAppendImages(mwand, if (horizontal) magick.MagickFalse else magick.MagickTrue);
}
