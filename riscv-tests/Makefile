#=======================================================================
# UCB VLSI FLOW: Makefile for riscv-tests
#-----------------------------------------------------------------------
# Yunsup Lee (yunsup@cs.berkeley.edu)
#

default: all

instname    = riscv-tests
instbasedir = $(UCB_VLSI_HOME)/install

#--------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------

asm_tests = \
	riscv_example.S \
	riscv_coreid.S \
	riscv_mul.S \
	riscv_mulw.S \
	riscv_mulh.S \
	riscv_mulhu.S \
	riscv_mulhsu.S \
	riscv_div.S \
	riscv_divw.S \
	riscv_divu.S \
	riscv_divuw.S \
	riscv_rem.S \
	riscv_remw.S \
	riscv_remu.S \
	riscv_remuw.S \
	riscv_fp_ldst.S \
	riscv_fsgnj.S \
	riscv_fadd.S \
	riscv_fmin.S \
	riscv_fmadd.S \
	riscv_fcvt_w.S \
	riscv_fcvt.S \
	riscv_fcmp.S \
	riscv_amoadd_w.S \
	riscv_amoadd_d.S \
	riscv_amoswap_w.S \
	riscv_amoswap_d.S \
	riscv_amoand_w.S \
	riscv_amoand_d.S \
	riscv_amoor_w.S \
	riscv_amoor_d.S \
	riscv_amomin_w.S \
	riscv_amomin_d.S \
	riscv_amomax_w.S \
	riscv_amomax_d.S \
	riscv_amominu_w.S \
	riscv_amominu_d.S \
	riscv_amomaxu_w.S \
	riscv_amomaxu_d.S \
	riscv_addi.S \
	riscv_add.S \
	riscv_addiw.S \
	riscv_addw.S \
	riscv_and.S \
	riscv_andi.S \
	riscv_beq.S \
	riscv_bge.S \
	riscv_bgeu.S \
	riscv_blt.S \
	riscv_bltu.S \
	riscv_bne.S \
	riscv_j.S \
	riscv_jal.S \
	riscv_jalr.S \
	riscv_jalr_r.S \
	riscv_jalr_j.S \
	riscv_lui.S \
	riscv_lb.S \
	riscv_lbu.S \
	riscv_lh.S \
	riscv_lhu.S \
	riscv_lw.S \
	riscv_lwu.S \
	riscv_ld.S \
	riscv_or.S \
	riscv_ori.S \
	riscv_rdnpc.S \
	riscv_simple.S \
	riscv_slt.S \
	riscv_sltu.S \
	riscv_slti.S \
	riscv_sltiu.S \
	riscv_slli.S \
	riscv_sll.S \
	riscv_slliw.S \
	riscv_sllw.S \
	riscv_srai.S \
	riscv_sra.S \
	riscv_sraiw.S \
	riscv_sraw.S \
	riscv_srli.S \
	riscv_srl.S \
	riscv_srliw.S \
	riscv_srlw.S \
	riscv_sub.S \
	riscv_subw.S \
	riscv_sb.S \
	riscv_sh.S \
	riscv_sw.S \
	riscv_sd.S \
	riscv_xor.S \
	riscv_xori.S \
	riscv_fp_move.S \
	riscv_fp_structural.S \
	riscv_vvcfgivl.S \
	riscv_vsetvl.S \
	riscv_vec_wakeup.S \
	riscv_vec_fence.S \
	riscv_vec_vvadd_w.S \
	riscv_vec_vvadd_d.S \
	riscv_vec_vvadd_fw.S \
	riscv_vec_vvadd_fd.S \
	riscv_vec_vvmul_d.S \
	riscv_vec_fcvt-d-l.S \
	riscv_vec_utidx.S \
	riscv_vec_vmvv.S \
	riscv_vec_vmsv.S \
	riscv_vec_vfmvv.S \
	riscv_vec_movz.S \
	riscv_vec_movn.S \
	riscv_vec_fmovz.S \
	riscv_vec_fmovn.S \
	riscv_vec_ld.S \
	riscv_vec_lw.S \
	riscv_vec_lwu.S \
	riscv_vec_lh.S \
	riscv_vec_lhu.S \
	riscv_vec_lb.S \
	riscv_vec_lbu.S \
	riscv_vec_sd.S \
	riscv_vec_sw.S \
	riscv_vec_sh.S \
	riscv_vec_sb.S \
	riscv_vec_fld.S \
	riscv_vec_flw.S \
	riscv_vec_fsd.S \
	riscv_vec_fsw.S \
	riscv_vec_amoadd_d.S \
	riscv_vec_amoswap_d.S \
	riscv_vec_amoand_d.S \
	riscv_vec_amoor_d.S \
	riscv_vec_amomin_d.S \
	riscv_vec_amominu_d.S \
	riscv_vec_amomax_d.S \
	riscv_vec_amomaxu_d.S \
	riscv_vec_amoadd_w.S \
	riscv_vec_amoswap_w.S \
	riscv_vec_amoand_w.S \
	riscv_vec_amoor_w.S \
	riscv_vec_amomin_w.S \
	riscv_vec_amominu_w.S \
	riscv_vec_amomax_w.S \
	riscv_vec_amomaxu_w.S \
	riscv_vec_imul.S \
	riscv_vec_fma.S \

asm_vec_tests = \
	riscv_mul.S \
	riscv_mulw.S \
	riscv_mulh.S \
	riscv_mulhu.S \
	riscv_mulhsu.S \
	riscv_addi.S \
	riscv_add.S \
	riscv_addiw.S \
	riscv_addw.S \
	riscv_and.S \
	riscv_andi.S \
	riscv_lui.S \
	riscv_or.S \
	riscv_ori.S \
	riscv_slt.S \
	riscv_sltu.S \
	riscv_slti.S \
	riscv_sltiu.S \
	riscv_slli.S \
	riscv_sll.S \
	riscv_slliw.S \
	riscv_sllw.S \
	riscv_srai.S \
	riscv_sra.S \
	riscv_sraiw.S \
	riscv_sraw.S \
	riscv_srli.S \
	riscv_srl.S \
	riscv_srliw.S \
	riscv_srlw.S \
	riscv_sub.S \
	riscv_subw.S \
	riscv_xor.S \
	riscv_xori.S \
	riscv_fadd.S \
	riscv_fsgnj.S \
	riscv_fmin.S \
	riscv_fmadd.S \
	riscv_fcvt_w.S \
	riscv_fcvt.S \
	riscv_fcmp.S \

extra_files = \
	test_macros.h \

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

MAVEN_GCC = riscv-gcc
MAVEN_GCC_OPTS = -DENABLE_STATS -O2 -nostdlib -nostartfiles -T test.ld
MAVEN_OBJDUMP = riscv-objdump --disassemble-all --disassemble-zeroes --section=.text --section=.data
MAVEN_SIM = fesvr -testrun

#------------------------------------------------------------
# Build assembly tests

asm_tests_bin  = $(patsubst %.S, %, $(asm_tests))
asm_tests_dump = $(addsuffix .dump, $(asm_tests_bin))
asm_tests_out  = $(addsuffix .out,  $(asm_tests_bin))

$(asm_tests_dump): %.dump: %
	$(MAVEN_OBJDUMP) $< > $@

$(asm_tests_bin): %: %.S
	$(MAVEN_GCC) $(MAVEN_GCC_OPTS) $< -o $@

$(asm_tests_out): %.out: %
	$(MAVEN_SIM) $< > $@

asm_vec_tests_bin  = $(patsubst %.S, %_vec, $(asm_vec_tests))
asm_vec_tests_dump = $(addsuffix .dump, $(asm_vec_tests_bin))
asm_vec_tests_out  = $(addsuffix .out,  $(asm_vec_tests_bin))

$(asm_vec_tests_dump): %.dump: %
	$(MAVEN_OBJDUMP) $< > $@

$(asm_vec_tests_bin): %_vec: %.S
	$(MAVEN_GCC) $(MAVEN_GCC_OPTS) -D__VEC_MACROS $< -o $@

$(asm_vec_tests_out): %.out: %
	$(MAVEN_SIM) $< > $@

riscv-: $(asm_tests_dump) $(asm_vec_tests_dump)
run: $(asm_tests_out) $(asm_vec_tests_out)
	echo; perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
	       $(asm_tests_out) $(asm_vec_tests_out); echo;

junk += $(asm_tests_bin) $(asm_tests_dump) $(asm_tests_out) $(asm_vec_tests_bin) $(asm_vec_tests_dump) $(asm_vec_tests_out)

#------------------------------------------------------------
# Default

all: riscv-

#------------------------------------------------------------
# Install

date_suffix = $(shell date +%Y-%m-%d_%H-%M)
install_dir = $(instbasedir)/$(instname)-$(date_suffix)
latest_install = $(shell ls -1 -d $(instbasedir)/$(instname)* | tail -n 1)

install:
	mkdir $(install_dir)
	cp $(asm_tests_bin) $(asm_tests_dump) $(install_dir)

install-link:
	rm -rf $(instbasedir)/$(instname)
	ln -s $(latest_install) $(instbasedir)/$(instname)

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(junk)
