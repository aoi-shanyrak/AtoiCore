# =============================================================================
# Configuration

SRC_DIR       = src
BUILD_DIR     = build

BOOT_ASM      = $(SRC_DIR)/boot.asm
KERNEL_ZIG    = $(SRC_DIR)/kernel.zig
LINKER        = $(SRC_DIR)/link.ld

BOOT_OBJ      = $(BUILD_DIR)/boot.o
KERNEL_OBJ    = $(BUILD_DIR)/kernel.o
OS_ELF        = $(BUILD_DIR)/os.elf
PAYLOAD       = $(BUILD_DIR)/os.bin
IMAGE         = $(BUILD_DIR)/boot.img

SECTOR_SIZE   = 512
SECTOR_COUNT  = 40


# =============================================================================
# Phony

.PHONY: all run debug clean

all: run


# =============================================================================
# Build

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BOOT_OBJ): $(BOOT_ASM) | $(BUILD_DIR)
	nasm -f elf32 -D SECTOR_COUNT=$(SECTOR_COUNT) $< -o $@

$(KERNEL_OBJ): $(KERNEL_ZIG) | $(BUILD_DIR)
	zig build-obj \
	    -target x86-freestanding-none \
	    -O ReleaseSmall \
	    -femit-bin=$@ \
	    $<

$(OS_ELF): $(BOOT_OBJ) $(KERNEL_OBJ) $(LINKER)
	i686-elf-ld -m elf_i386 -T $(LINKER) $(BOOT_OBJ) $(KERNEL_OBJ) -o $@

$(PAYLOAD): $(OS_ELF)
	i686-elf-objcopy -I elf32-i386 -O binary $(OS_ELF) $@

$(IMAGE): $(PAYLOAD)
	dd if=/dev/zero of=$@ bs=$(SECTOR_SIZE) count=2880
	dd if=$(PAYLOAD) of=$@ conv=notrunc


# =============================================================================
# Run

run: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g -drive file=$(IMAGE),format=raw,if=floppy -monitor stdio -device VGA

debug: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g -drive file=$(IMAGE),format=raw,if=floppy -monitor stdio -device VGA -s -S &
	lldb -o "gdb-remote 1234" -o "breakpoint set -a 0x7C00"

clean:
	rm -rf $(BUILD_DIR) .zig-cache zig-out
	