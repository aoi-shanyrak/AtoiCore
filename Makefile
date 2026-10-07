# =============================================================================
# Configuration

IMAGE         = boot.img
BOOT_ASM      = boot.asm
BOOT_OBJ      = boot.o
KERNEL_ZIG    = kernel.zig
KERNEL_OBJ    = kernel.o
LINKER        = link.ld
OS_ELF        = os.elf
PAYLOAD       = os.bin
SECTOR_SIZE   = 512
KERNEL_OFFSET = 0x7E00
SECTOR_COUNT  = 40


# =============================================================================
# Phony

.PHONY: all run debug clean

all: run


# =============================================================================
# Build

$(BOOT_OBJ): $(BOOT_ASM)
	nasm -f elf32 -D SECTOR_COUNT=$(SECTOR_COUNT) $< -o $@

$(KERNEL_OBJ): $(KERNEL_ZIG)
	zig build-obj \
	    -target x86-freestanding-none \
	    -O ReleaseSmall \
	    -femit-bin=$(KERNEL_OBJ) \
	    $(KERNEL_ZIG)

$(OS_ELF): $(BOOT_OBJ) $(KERNEL_OBJ) $(LINKER)
	i686-elf-ld -m elf_i386 -T $(LINKER) $(BOOT_OBJ) $(KERNEL_OBJ) -o $@

$(PAYLOAD): $(OS_ELF)
	i686-elf-objcopy -I elf32-i386 -O binary $(OS_ELF) $(PAYLOAD)

$(IMAGE): $(PAYLOAD)
	dd if=/dev/zero of=$(IMAGE) bs=$(SECTOR_SIZE) count=2880
	dd if=$(PAYLOAD) of=$(IMAGE) conv=notrunc


# =============================================================================
# Run

run: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g -fda $(IMAGE) -monitor stdio -device VGA

debug: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g -fda $(IMAGE) -monitor stdio -device VGA -s -S &
	lldb -o "gdb-remote 1234" -o "breakpoint set -a 0x7C00"

clean:
	rm -f $(BOOT_OBJ) $(KERNEL_OBJ) $(OS_ELF) $(PAYLOAD) $(IMAGE)
	rm -rf .zig-cache zig-out
