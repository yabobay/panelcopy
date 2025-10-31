All: panelcopy.o
	zig build-exe panelcopy.o -femit-bin=panelcopy -lc $(shell pkgconf --libs MagickWand)

panelcopy.o: main.zig
	zig build-obj main.zig -femit-bin=tmp.o -lc $(shell pkgconf --cflags-only-I MagickWand)
	mv tmp.o panelcopy.o
