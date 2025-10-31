All: panelcopy
	$(MAKE) ZFLAGS="-O ReleaseSmall" panelcopy

.PHONY: debug
debug: panelcopy

panelcopy: panelcopy.o
	zig build-exe panelcopy.o -femit-bin=panelcopy -lc $(shell pkgconf --libs MagickWand) $(ZFLAGS)

panelcopy.o: main.zig
	zig build-obj main.zig -femit-bin=tmp.o -lc $(shell pkgconf --cflags-only-I MagickWand) $(ZFLAGS)
	mv tmp.o panelcopy.o
