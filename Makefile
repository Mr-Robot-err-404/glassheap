LLVM  := /opt/homebrew/opt/llvm/bin
BUILD := build
GUEST ?= guest/hi/main.odin

NAME  := $(notdir $(patsubst %/,%,$(dir $(GUEST))))
OUT   := $(BUILD)/$(NAME)
ELF   := $(OUT)/glassheap.elf

all: $(ELF)

$(OUT):
	mkdir -p $(OUT)

$(BUILD):
	mkdir -p $(BUILD)

$(ELF): $(GUEST) $(BUILD)/boot.o | $(OUT)
	odin build $(GUEST) -file \
		-target:freestanding_riscv64 \
		-build-mode:obj \
		-no-crt \
		-no-entry-point \
		-default-to-nil-allocator \
		-out:$(OUT)/main
	/opt/homebrew/bin/ld.lld -T link.ld $(OUT)/main-*.o $(BUILD)/boot.o -o $(ELF) --defsym __tls_get_addr=0x80000000

$(BUILD)/boot.o: boot.s | $(BUILD)
	$(LLVM)/clang -target riscv64 -march=rv64imfd -mabi=lp64d -c boot.s -o $(BUILD)/boot.o

run: $(ELF)
	qemu-system-riscv64 -machine virt -nographic -bios none -kernel $(ELF)

trace: $(ELF)
	odin run . -- $(ELF) 2>/dev/null

guest: $(ELF)
	odin run . -- $(ELF) 2>&1 >/dev/null

qemu: $(ELF)
	qemu-system-riscv64 -machine virt -nographic -bios none -kernel $(ELF) -d in_asm 2> $(OUT)/trace.txt

qemu-regs: $(ELF)
	-qemu-system-riscv64 -machine virt -nographic -bios none -kernel $(ELF) -d in_asm,cpu -accel tcg,one-insn-per-tb=on 2> $(OUT)/trace-regs.txt

build-%:
	@$(MAKE) --no-print-directory all GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

rdiff-%:
	@echo "=== QEMU ==="
	@grep -E '^ pc |^ x' $(BUILD)/$*/trace-regs.txt | grep -A8 "pc            00000000$(ADDR:0x%=%)" | grep '^ x' | head -8
	@echo "=== MINE ==="
	@odin run . -- $(BUILD)/$*/glassheap.elf --regs 2>/dev/null | grep -A8 '^$(ADDR):' | grep '^ x' | head -8

adiff-%:
	@echo "=== QEMU ==="
	@grep '$(ADDR):' $(BUILD)/$*/trace-regs.txt | head -1
	@echo "executions: `grep -c 'pc            00000000$(ADDR:0x%=%)' $(BUILD)/$*/trace-regs.txt`"
	@echo "=== MINE ==="
	@$(MAKE) --no-print-directory trace GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1) 2>/dev/null | grep '^$(ADDR):' > /tmp/mine.txt
	@head -1 /tmp/mine.txt
	@echo "executions: `wc -l < /tmp/mine.txt | tr -d ' '`"

diff-%:
	@$(MAKE) --no-print-directory qemu-regs GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)
	@$(MAKE) --no-print-directory trace GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1) 2>/dev/null | grep -o '^0x[0-9a-f]*' > /tmp/mine.pc
	@grep '^ pc  ' $(BUILD)/$*/trace-regs.txt | awk '{print "0x" substr($$2, 9)}' | grep '^0x8' > /tmp/qemu.pc
	@diff /tmp/qemu.pc /tmp/mine.pc | head -20

trace-%:
	@$(MAKE) --no-print-directory trace GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

run-%:
	@$(MAKE) --no-print-directory run GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

guest-%:
	@$(MAKE) --no-print-directory guest GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

qemu-%:
	@$(MAKE) --no-print-directory qemu GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

regs-%:
	@$(MAKE) --no-print-directory qemu-regs GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)
	@grep -E '^0x|^ pc |^ x' $(BUILD)/$*/trace-regs.txt > $(BUILD)/$*/trace-regs-clean.txt

clean:
	rm -rf $(BUILD)

.PHONY: all run trace guest qemu clean
