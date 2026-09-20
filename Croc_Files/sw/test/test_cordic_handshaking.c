#include <stdint.h>
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"
#include "cordic.h"

static inline uint16_t cordic_status_remaining(uint32_t s) {
    return (uint16_t)((s >> 8) & 0xFFFF);
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

static void fill_buf(uint32_t *buf, uint32_t length, uint32_t value)
{
    for (uint32_t i = 0; i < length; i++)
    {
        buf[i] = value;
    }
}

static uint32_t src_buffer[35];
static uint32_t dst_buffer[35];

int main(void)
{
    uart_init();

    // Wait for reset to fully propagate
    for (volatile int i = 0; i < 100; i++);

    int pass = 1;

    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);



    // 1. Initial state
    if (cordic_is_busy() || cordic_is_done())
    {
        pass = 0;
    }

    // 2. Launch job and check busy
    fill_buf(src_buffer, 35, 0x0B50);
    fill_buf(dst_buffer, 35, 0xDEADBEEF);
    
    cordic_job_done = 0;
    cordic_job_start(src_buffer, dst_buffer, 35);
    
    // Test if it's busy right after start
    int busy_seen = 0;
    for (int i = 0; i < 10; i++) {
        if (cordic_is_busy()) {
            busy_seen = 1;
            break;
        }
        for (volatile int j = 0; j < 5; j++); // small delay
    }
    if (!busy_seen) {
        printf("Fail 2\n");
        pass = 0;
    }

    // Attempt to write config while busy
    CORDIC_LENGTH = 100; // Will stall the CPU due to gnt backpressure until job finishes

    while (!cordic_job_done) {
        wfi();
    }

    // 3. Verify length was overwritten AFTER the job finished (due to CPU stalling)
    if (CORDIC_LENGTH != 100) {
        printf("Fail 3: stall\n");
        pass = 0;
    }

    // 4. Verify dst_buffer was written by manager
    for (int i = 0; i < 35; i++) {
        if (dst_buffer[i] == 0xDEADBEEF) {
            printf("Fail 4\n");
            pass = 0;
            break;
        }
    }

    set_global_irq_enable(0); // Disable IRQ to avoid handler reading status
    cordic_job_start(src_buffer, dst_buffer, 1);
    while (cordic_is_busy()) {
        for (volatile int j = 0; j < 10; j++);
    }
    
    // Now done should be 1. We manually read status to ack done.
    uint32_t st = cordic_read_status(); 
    int done_cleared = 0;
    for (int i = 0; i < 5; i++) {
        if (!cordic_is_done()) {
            done_cleared = 1;
            break;
        }
    }
    if (!done_cleared) {
        printf("Fail C2.1\n");
        pass = 0;
    }

    // Second consecutive job without reset
    set_global_irq_enable(1); // Re-enable IRQ so handler runs
    cordic_job_done = 0;
    cordic_job_start(src_buffer, dst_buffer, 1);
    while (!cordic_job_done) {
        wfi();
    }
    if (!cordic_job_done) {
        printf("Fail C2.2\n");
        pass = 0;
    }
    // No need to ack explicitly, handler did it.

    cordic_job_done = 0;
    cordic_job_start(src_buffer, dst_buffer, 8);
    
    uint16_t last_rem = 8;
    int rem_valid = 0;
    int rem_jump = 0;
    
    while (cordic_is_busy()) {
        st = cordic_read_status();
        if (st & (1 << CORDIC_STATUS_BUSY_BIT)) {
            uint16_t rem = cordic_status_remaining(st);
            if (rem <= 8 && rem > 0) rem_valid = 1;
            
            // Check non-increasing (rem <= last_rem + 1)
            if (rem > last_rem + 1) {
                rem_jump = 1;
            }
            last_rem = rem;
            for (volatile int j = 0; j < 5; j++); // small delay to avoid excessive identical reads
        }
    }
    
    if (!rem_valid) {
        printf("Fail C3.1\n");
        pass = 0;
    }
    if (rem_jump) {
        printf("Fail C3.2\n");
        pass = 0;
    }
    
    // Ensure we wait for the IRQ to fire
    while (!cordic_job_done) { wfi(); }

    printf("[SUMMARY] Bench Edge: %s\n", pass ? "PASS" : "FAIL");

    set_global_irq_enable(0);
    set_interrupt_enable(0, CORDIC_IRQ_FAST);

    uart_write_flush();
    for (volatile int i = 0; i < 200000; i++);
    
    return pass ? 0 : 1;
}