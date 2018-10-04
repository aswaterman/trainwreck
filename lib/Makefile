all: disasm-modelsim.so mac_fedriver.so htif-modelsim.so libopcodes.a

RISCV_LIB_DIR := $(dir $(shell which riscv-gcc))/../$(shell scripts/config.guess)/riscv/lib
LIBOPCODES := libopcodes-2.19.51.20090720.so
LIBBFD := libbfd-2.19.51.20090720.so

libopcodes.a: $(RISCV_LIB_DIR)/libopcodes.a
	cp $< $@

$(LIBOPCODES): $(RISCV_LIB_DIR)/$(LIBOPCODES)
	cp $< $@

$(LIBBFD): $(RISCV_LIB_DIR)/$(LIBBFD)
	cp $< $@

disasm-modelsim.so: ../csrc/disasm-modelsim.cc ../csrc/disasm.cc ../csrc/disasm-modelsim.h $(LIBOPCODES) $(LIBBFD)
	$(CXX) -shared -o $@ $(CFLAGS) -I../csrc -I$(MTI_HOME)/include $^ -fPIC

mac_fedriver.so: ../csrc/mac_fedriver.c ../csrc/mac_fedriver.h
	$(CC) -shared -o $@ $(CFLAGS) -I../csrc -I$(MTI_HOME)/include -fPIC $<

htif-modelsim.so: ../csrc/htif-modelsim.cc ../csrc/htif-modelsim.h
	$(CXX) -shared -o $@ $(CFLAGS) -I../csrc -I$(MTI_HOME)/include -fPIC $<
