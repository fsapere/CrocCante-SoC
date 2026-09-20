// Copyright (c) 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>
#include "uart.h"
#include "print.h"
#include "config.h"
#include "cordic.h"

/*
 * Reads the RISC-V hardware cycle counter (mcycle) for benchmarking purposes.
 */
static inline uint32_t get_cycles() {
    uint32_t cycles;
    asm volatile ("csrr %0, mcycle" : "=r" (cycles));
    return cycles;
}

/*
 * Placeholder for a software sine implementation.
 * Used as a baseline to evaluate the hardware accelerator speedup.
 */
int16_t software_sin(int16_t angle) {
    volatile int16_t res = angle;
    // Simulate computation delay (e.g., Taylor series expansion)
    for(int i = 0; i < 50; i++) { 
        res = (res * 3) / 2; 
    } 
    return res;
}

#define CORDIC_IRQ_FAST 23

void croc_interrupt_handler(uint32_t cause)
{
    if (cause == CORDIC_IRQ_FAST)
    {
        uint32_t status = cordic_read_status();
        cordic_job_done = 1;
    }
}

static uint32_t src_buffer[1];
static uint32_t dst_buffer[1];

int main(void) {
    uint32_t start_time, end_time;
    uint32_t sw_cycles, hw_cycles;
    
    // Example angle value in the format expected by the CORDIC pipeline
    uint32_t test_angle = 0x0B50; 
    
    uart_init();
    printf("--- CORDIC Accelerator Benchmark ---\n");

    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);

    // --- SOFTWARE TEST ---
    start_time = get_cycles();
    int16_t sw_res = software_sin(test_angle);
    end_time = get_cycles();
    sw_cycles = end_time - start_time;

    // --- HARDWARE TEST ---
    start_time = get_cycles();
    
    src_buffer[0] = test_angle;
    dst_buffer[0] = 0xDEADBEEF;
    cordic_job(src_buffer, dst_buffer, 1);
    
    if (dst_buffer[0] == 0xDEADBEEF) {
        printf("Fail: dst not overwritten\n");
    }

    uint32_t hw_res = dst_buffer[0];   
    
    end_time = get_cycles();
    hw_cycles = end_time - start_time;

    // --- FUNCTIONAL VERIFICATION ---
    // Extract sin and cos from packed 32-bit format:
    int16_t hw_sin = (int16_t)(hw_res >> 16);
    int16_t hw_cos = (int16_t)(hw_res & 0xFFFF);

    printf("Input Angle (Hex): 0x%04X\n", test_angle);
    printf("Hardware Sine    : 0x%04X\n", (uint16_t)hw_sin);
    printf("Hardware Cosine  : 0x%04X\n", (uint16_t)hw_cos);
    printf("----------------------------------\n");

    // --- METRICS REPORT ---
    printf("Software Execution: %d cycles (Result: %d)\n", sw_cycles, sw_res);
    printf("Hardware Execution: %d cycles (Packed Result: %x)\n", hw_cycles, hw_res);
    printf("Hardware Speedup: %dx\n", sw_cycles / hw_cycles);

    set_global_irq_enable(0);
    set_interrupt_enable(0, CORDIC_IRQ_FAST);

    uart_write_flush();
    return 0;
}