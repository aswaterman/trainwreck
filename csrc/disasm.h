#ifndef _DISASM_H
#define _DISASM_H

#include <stdint.h>

void riscv_do_disasm(uint32_t insn, char* str);

#endif
