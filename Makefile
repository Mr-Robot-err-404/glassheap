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

build-%:
	@$(MAKE) --no-print-directory all GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

adiff-%:
	@$(MAKE) --no-print-directory qemu GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)
	@$(MAKE) --no-print-directory trace GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1) 2>/dev/null > /tmp/mine.txt
	@grep -v '^--' /tmp/mine.txt > /tmp/mine_clean.txt
	@grep '$(ADDR)' $(BUILD)/$*/trace.txt | head -5
	@echo ---
	@grep '$(ADDR)' /tmp/mine_clean.txt | head -5

diff-%:
	@$(MAKE) --no-print-directory qemu GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)
	@$(MAKE) --no-print-directory trace GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1) 2>/dev/null | grep -o '^0x[0-9a-f]*' > /tmp/mine.pc
	@grep -o '^0x[0-9a-f]*' $(BUILD)/$*/trace.txt > /tmp/qemu.pc
	@diff /tmp/qemu.pc /tmp/mine.pc | head -20

trace-%:
	@$(MAKE) --no-print-directory trace GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

run-%:
	@$(MAKE) --no-print-directory run GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

guest-%:
	@$(MAKE) --no-print-directory guest GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

qemu-%:
	@$(MAKE) --no-print-directory qemu GUEST=guest/$*/$(shell ls guest/$* 2>/dev/null | head -1)

clean:
	rm -rf $(BUILD)

.PHONY: all run trace guest qemu clean
