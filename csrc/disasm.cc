#include <bfd.h>
#include <dis-asm.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

static int p_sprintf(char** p, const char* fmt, ...)
{
  va_list vl;
  va_start(vl, fmt);
  int n = vsprintf(*p, fmt, vl);
  *p += strlen(*p);
  va_end(vl);
  return n;
}

void riscv_do_disasm(uint32_t insn, char* str)
{
  bfd_vma pc = 0; // XXX
  disassemble_info info;
  char* p = str;

  INIT_DISASSEMBLE_INFO(info, &p, p_sprintf);
  info.flavour = bfd_target_unknown_flavour;
  info.arch = bfd_arch_mips;
  info.mach = 101; // XXX bfd_mach_mips_riscv requires modified bfd.h
  info.endian = BFD_ENDIAN_LITTLE;
  info.buffer = (bfd_byte*)&insn;
  info.buffer_length = sizeof(insn);
  info.buffer_vma = pc;

  print_insn_little_mips(pc, &info);

  for(int i=0; i<strlen(str); i++)
    if (str[i] == '\t') str[i] = ' ';
}
