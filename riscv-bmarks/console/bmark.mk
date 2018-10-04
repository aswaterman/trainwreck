#=======================================================================
# UCB CS250 Makefile fragment for benchmarks
#-----------------------------------------------------------------------
#
# Each benchmark directory should have its own fragment which
# essentially lists what the source files are and how to link them
# into an riscv and/or host executable. All variables should include
# the benchmark name as a prefix so that they are unique.
#

console_c_src = \
	console_main.c \

console_riscv_src = \

console_c_objs     = $(patsubst %.c, %.o, $(console_c_src))
console_riscv_objs = $(patsubst %.S, %.o, $(console_riscv_src))

console_host_bin = console.host
$(console_host_bin) : $(console_c_src)
	$(HOST_COMP) $^ -o $(console_host_bin)

console_riscv_bin = console.riscv
$(console_riscv_bin) : $(console_c_objs) $(console_riscv_objs)
	$(RISCV_LINK) $(console_c_objs) $(console_riscv_objs) -o $(console_riscv_bin)

junk += $(console_c_objs) $(console_riscv_objs) \
        $(console_host_bin) $(console_riscv_bin)
