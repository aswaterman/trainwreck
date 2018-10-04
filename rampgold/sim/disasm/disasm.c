//------------------------------------------------------------------------------   
// File:        disasm.c
// Author:      Zhangxi Tan
// Description: Use libopcode to disassemble SPARC instruction. Implemented as a
//		DPI library called from SV simulation
//		requires cross compiled binutil-dev
//		1) configure binutil with options: 
//		 --target=sparc-linux 
//		 --prefix=$HOME/sparc-linux-binutil
//		 --enable-shared
//		2) make all install
//		3) bfd/ make install_libbfd, opcodes/ make install_libopcodes
//------------------------------------------------------------------------------

#include "disasm.h"
#include <stdio.h>
#include <bfd.h>
#include <dis-asm.h>

disassembler_ftype disassemble_fn;
disassemble_info info;

//initialize libopcodes/
DPI_LINK_DECL DPI_DLLESPEC
void init_disasm() {
	INIT_DISASSEMBLE_INFO(info, stdout, fprintf);

	/* set up SPARC target */
	info.flavour = bfd_target_unknown_flavour;
	info.arch = bfd_arch_sparc;		
//	info.mach = bfd_mach_sparc_sparclite_le;
	info.mach = bfd_mach_sparc;
	info.endian = BFD_ENDIAN_LITTLE;	//little endian
	disassemble_fn = print_insn_sparc;	
}


DPI_LINK_DECL DPI_DLLESPEC
void sparc_disasm(const disasm_info_type* dis) {
	bfd_byte *buffer = (unsigned char*)&dis->inst;
	bfd_size_type size =  sizeof(dis->inst);
	int vma = 0;
	int bytes;	

	info.buffer = buffer;
	info.buffer_length = size;
	info.buffer_vma = vma;

	bytes = 0;
	while (bytes < size) {
		fprintf(stdout, "@Time %lu, PID %2d Thread %2d: %X: [%08X] ", dis->ctime, dis->pid, dis->tid, dis->pc * 4, dis->inst);
		bytes += (*disassemble_fn)(vma + bytes, &info);

		
		if (dis->replay)	//replay
			printf(" [replay] ");
		else if (dis->annul)	//annuled inst in the branch delay slot
			printf(" [annuled] ");
			
		if (dis->uc_mode) 
			printf(" UC(%d) ", dis->upc);
		
		if (dis->dma_mode)
			printf(" DMA ");
		
		printf("\n");
			
	}	

}

