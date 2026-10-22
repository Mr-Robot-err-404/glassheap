LLVM  := /opt/homebrew/opt/llvm/bin
BUILD := build

all: $(BUILD)/glassheap.elf

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/glassheap.elf: main.odin $(BUILD)/boot.o | $(BUILD)
	odin build main.odin -file \
		-target:freestanding_riscv64 \
		-build-mode:obj \
		-no-crt \
		-no-entry-point \
		-default-to-nil-allocator \
		-out:$(BUILD)/main
	/opt/homebrew/bin/ld.lld -T link.ld $(BUILD)/main-*.o $(BUILD)/boot.o -o $(BUILD)/glassheap.elf --defsym __tls_get_addr=0x80000000

$(BUILD)/boot.o: boot.s | $(BUILD)
	$(LLVM)/clang -target riscv64 -march=rv64imfd -mabi=lp64d -c boot.s -o $(BUILD)/boot.o

run: $(BUILD)/glassheap.elf
	qemu-system-riscv64 -machine virt -nographic -bios none -kernel $(BUILD)/glassheap.elf

clean:
	rm -rf $(BUILD)

.PHONY: all run clean
