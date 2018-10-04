#include "dumpreg.h"
#include <stdio.h>

#define NWINDOWS 3
int fix_notation(int regaddr)
{
    int newaddr;

    if (regaddr >= 8+16*NWINDOWS)
    {
        newaddr = regaddr-16*NWINDOWS;
    }
    else
    {
        newaddr = regaddr;
    }

    return newaddr;
}

DPI_LINK_DECL DPI_DLLESPEC
void dump(const regfile_dpi_type* regfile, const spr_dpi_type* spr)
{
    if (regfile->temp)
    {
        fprintf(stdout, "memr.ex_res=%08x\n", regfile->temp);
    }

    if (regfile->ph2_we)
    {
        if (8 <= regfile->ph2_addr && regfile->ph2_addr < 16)
        {
            fprintf(stdout, "%d=%08x\n", regfile->ph2_addr, regfile->ph2_data);
        }
        else
        {
            fprintf(stdout, ">>>%d=0x%08x\n", fix_notation(regfile->ph2_addr), regfile->ph2_data);
        }
    }
    if (regfile->ph1_we)
    {
        if (8 <= regfile->ph1_addr && regfile->ph1_addr < 16)
        {
            fprintf(stdout, "%d=%08x\n", regfile->ph1_addr, regfile->ph1_data);
        }
        else
        {
            fprintf(stdout, ">>>%d=0x%08x\n", fix_notation(regfile->ph1_addr), regfile->ph1_data);
        }
    }
    if (spr->we)
    {
        fprintf(stdout, ">>>psr=0x%08x\n", spr->psr);
        fprintf(stdout, ">>>wim=0x%08x\n", spr->wim);
        fprintf(stdout, ">>>y=0x%08x\n", spr->y);
    }
}
