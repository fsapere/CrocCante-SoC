/* Copyright (c) 2024 ETH Zurich and University of Bologna.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Authors:
 * - Paul Scheffler <paulsc@iis.ee.ethz.ch>
 * - Philippe Sauter <phsauter@iis.ee.ethz.ch> 
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
	/* Core SRAM (Bank 0) for core code and data */
	SRAM_CORE (rwxail) : ORIGIN = 0x10000000, LENGTH = 2K
	/* CORDIC SRAM (Bank 1) for CORDIC buffers */
	SRAM_CORDIC (rw)   : ORIGIN = 0x10000800, LENGTH = 2K
}

PHDRS
{
	text PT_LOAD FLAGS(5); /* tag as: Read + Execute */
	data PT_LOAD FLAGS(6); /* tag as: Read + Write */
	cordic PT_LOAD FLAGS(6);
}

SECTIONS
{
    /* Drop metadata/debug sections, not needed */
	/DISCARD/ :
	{
	*(.riscv.attributes)
	*(.comment)
	}

    /* Start placing following sections at the SRAM base address */
	. = ORIGIN(SRAM_CORE);

    /* Interrupt vector table */
	.vectors : ALIGN(4)
	{
	KEEP(*(.vectors))
	} > SRAM_CORE :text

    /* Startup entry (first instructions executed after bootrom) */
	.text._start : ALIGN(4)
	{
	KEEP(*(.text._start))
	} > SRAM_CORE :text

    /* Main code (text) and read-only data (rodata) */
	.text : ALIGN(4)
	{
	*(.text)
	*(.text.*)
	*(.rodata)
	*(.rodata.*)
	} > SRAM_CORE :text

    /* Writable data (what people colloquially call RAM) */
	.misc : ALIGN(4)
	{
	*(.sdata)
	*(.sdata.*)
	*(.data)
	*(.data.*)
	*(.sbss)
	*(.sbss.*)
	*(.bss)
	*(.bss.*)
	*(COMMON)
	} > SRAM_CORE :data

    /* Specific data for CORDIC in Bank 1 */
	.cordic_data (NOLOAD) : ALIGN(4)
	{
	*(.cordic_data)
	} > SRAM_CORDIC :cordic
}

/* Global absolute symbols */

/* Place GP near the middle for efficient GP-relative access */
PROVIDE(__global_pointer$ = ADDR(.misc) + SIZEOF(.misc) / 2);
/* Initial stack pointer at the end of SRAM_CORE */
PROVIDE(__stack_pointer$ = ORIGIN(SRAM_CORE) + LENGTH(SRAM_CORE));

/* Bootrom symbols (fixed addresses) */
PROVIDE(_eoc = 0x02000100);
PROVIDE(_trap_handler_wrapper = 0x02000200);
PROVIDE(_trap_exit = 0x02000300);

/* SoC register symbols */
PROVIDE(corestatus = 0x03000008);
