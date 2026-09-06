PAYLOAD    ?= aoi.txt
BOOT_ASM    = boot.asm
BOOT_BIN    = boot.bin
IMAGE       = boot.img
SECTOR_SIZE = 512

PAYLOAD_SECTOR_COUNT_DEFAULT = 40


PAYLOAD_EXISTS = $(wildcard $(PAYLOAD))
ifeq ($(PAYLOAD_EXISTS),)
    SECTOR_COUNT = $(PAYLOAD_SECTOR_COUNT_DEFAULT)
else
    PAYLOAD_SIZE = $(shell stat -c%s $(PAYLOAD) 2>/dev/null || echo 0)
    ifeq ($(PAYLOAD_SIZE),0)
        SECTOR_COUNT = $(PAYLOAD_SECTOR_COUNT_DEFAULT)
    else
        SECTOR_COUNT = $(shell echo $$(( ($(PAYLOAD_SIZE) + $(SECTOR_SIZE) - 1) / $(SECTOR_SIZE) )))
    endif
endif


all: run

$(PAYLOAD):
	python3 generate_payload.py $(PAYLOAD) $(PAYLOAD_SECTOR_COUNT_DEFAULT)

$(BOOT_BIN): $(BOOT_ASM)
	nasm -fbin -D SECTOR_COUNT=$(SECTOR_COUNT) $< -o $@
	
$(IMAGE): $(BOOT_BIN) $(PAYLOAD)
	dd if=/dev/zero of=$(IMAGE) bs=$(SECTOR_SIZE) count=2880
	dd if=$(BOOT_BIN) of=$(IMAGE) conv=notrunc
	dd if=$(PAYLOAD) of=$(IMAGE) conv=notrunc seek=1

run: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g -fda $(IMAGE) -monitor stdio -device VGA

debug: $(IMAGE)
	qemu-system-i386 -cpu pentium2 -m 1g -fda $(IMAGE) -monitor stdio -device VGA -s -S &
	lldb -o "gdb-remote 1234" -o "breakpoint set -a 0x7C00"

check:
	@echo "type: make"
	@echo "then: pmemsave 0x7E00 $$(( $(SECTOR_COUNT) * $(SECTOR_SIZE) )) bar"
	@echo "and:  cmp bar $(PAYLOAD)"

clean:
	rm -f $(BOOT_BIN) $(IMAGE) bar

.PHONY: all run clean check debug
