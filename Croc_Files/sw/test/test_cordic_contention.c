#include <stdint.h>
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"
#include "cordic.h"

#define MAX_N 200
#define CORDIC_IRQ_FAST 23

volatile uint64_t cordic_end_time;
extern volatile int cordic_job_done;

void croc_interrupt_handler(uint32_t cause)
{
    if (cause == CORDIC_IRQ_FAST)
    {
        // Capture exact cycle count the moment the hardware finishes
        cordic_end_time = get_mcycle();
        uint32_t status = cordic_read_status();
        cordic_job_done = 1;
    }
}

// Reusable function to run the contended job
// hammer_addr dictates which bank the CPU will constantly hit during the wait.
__attribute__((noinline))
static uint32_t run_contended_job(uint32_t *src, uint32_t *dst, uint32_t n, volatile uint32_t *hammer_addr) {
    cordic_job_done = 0;
    uint64_t t0 = get_mcycle();
    cordic_job_start(src, dst, n);
    
    // High contention standard pattern: unrolled assembly lw/sw
    // CPU will be stuck here hammering the bus until the interrupt fires!
    while (!cordic_job_done) {
        asm volatile (
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            "lw t0, 0(%0)\n" "sw t0, 0(%0)\n"
            : : "r"(hammer_addr) : "t0"
        );
    }
    return (uint32_t)(cordic_end_time - t0);
}

__attribute__((section(".cordic_data"))) uint32_t bank1_buf_src[MAX_N];
__attribute__((section(".cordic_data"))) uint32_t bank1_buf_dst[MAX_N];
__attribute__((section(".cordic_data"))) volatile uint32_t bank1_dummy = 0;

int main() {
    uart_init();
    for (volatile int i = 0; i < 100; i++);
    
    // Enable interrupts for precise timing!
    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);

    // Buffers in .cordic_data -> Guaranteed Bank 1
    // (We declare them globally above, so we just use them here)

    // Hammer addresses
    volatile uint32_t *hammer_bank1 = &bank1_dummy;
    volatile uint32_t *hammer_bank0 = (volatile uint32_t *)0x10000000;

    // Init data
    for (int i = 0; i < MAX_N; i++) {
        bank1_buf_src[i] = 0x00002182; // 30 deg
        bank1_buf_dst[i] = 0xDEADBEEF;
    }

    // Warmup
    run_contended_job(bank1_buf_src, bank1_buf_dst, 1, hammer_bank0);

    static const uint32_t n_values[] = {10, 50, 100, 150, 200};
    int pass = 1;

    for (int i = 0; i < 5; i++) {
        uint32_t n = n_values[i];

        // SPLIT: CORDIC uses Bank 1, CPU hammers Bank 0
        uint32_t t_split = run_contended_job(bank1_buf_src, bank1_buf_dst, n, hammer_bank0);
        
        // SAME: CORDIC uses Bank 1, CPU hammers Bank 1
        uint32_t t_same = run_contended_job(bank1_buf_src, bank1_buf_dst, n, hammer_bank1);

        int32_t delta = (int32_t)(t_same - t_split);
        int32_t dip_pct = (t_split > 0) ? ((delta * 100) / (int32_t)t_split) : 0;

        char sign_delta = (delta < 0) ? '-' : '+';
        char sign_dip = (dip_pct < 0) ? '-' : '+';
        uint32_t abs_delta = (delta < 0) ? -delta : delta;
        uint32_t abs_dip = (dip_pct < 0) ? -dip_pct : dip_pct;

        printf("[SUMMARY] BankSweep N=%x split=%x same=%x delta=%c%x dip=%c%x\n", 
               n, t_split, t_same, sign_delta, abs_delta, sign_dip, abs_dip);

        if (bank1_buf_dst[n - 1] == 0xDEADBEEF) {
            pass = 0;
        }
    }

    if (pass) {
        printf("[SUMMARY] BankSweep: PASS\n");
    } else {
        printf("[SUMMARY] BankSweep: FAIL\n");
    }

    uart_write_flush();
    return 0;
}
