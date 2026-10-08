IMAGE   = build/boot.img
PAYLOAD = zig-out/bin/os.bin
SECTOR_SIZE = 512

.PHONY: all run debug clean

all: run

$(PAYLOAD): build.zig $(wildcard src/*)
	@zig build

$(IMAGE): $(PAYLOAD)
	@mkdir -p build
	dd if=/dev/zero of=$@ bs=$(SECTOR_SIZE) count=2880
	dd if=$(PAYLOAD) of=$@ conv=notrunc

run: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g \
	    -drive file=$(IMAGE),format=raw,if=floppy \
	    -monitor stdio -device VGA

debug: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g \
	    -drive file=$(IMAGE),format=raw,if=floppy \
	    -monitor stdio -device VGA -s -S &
	lldb -o "gdb-remote 1234" -o "breakpoint set -a 0x7C00"

clean:
	rm -rf build zig-out .zig-cache
	