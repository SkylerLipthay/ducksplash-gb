BUILD_DIR := build
RES_DIR := res
SRC_DIR := src

OUTPUT := $(BUILD_DIR)/ducksplash.gb
ASM_FILES := $(wildcard $(SRC_DIR)/*.asm)
OBJ_FILES := $(addprefix $(BUILD_DIR)/,$(notdir $(ASM_FILES:.asm=.o)))
RES_FILES := $(wildcard $(RES_DIR)/*)

all: $(OUTPUT)

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm $(RES_FILES) | $(BUILD_DIR)
	rgbasm -L -o $@ $<

$(OUTPUT): $(OBJ_FILES)
	rgblink -o $@ $^
	rm $^
	rgbfix -v -p 0xFF $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
