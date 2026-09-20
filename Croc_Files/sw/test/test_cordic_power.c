#include <stdint.h>
#include "config.h"
#include "util.h"
#include "cordic.h"

#define BURST_LEN 32
#define ITERATIONS 5
#define CORDIC_IRQ_FAST 23

typedef struct {
    const char *label;
    uint32_t angle_fixed;
    uint32_t expected_packed;
} cordic_test_vector_t;

static const cordic_test_vector_t test_vectors[] = {
    {"0 deg",   0x00000000, 0x00007FFF},
    {"30 deg",  0x00002182, 0x40006EDA},
    {"45 deg",  0x00003244, 0x5A825A82},
    {"60 deg",  0x00004305, 0x6EDA4000},
    {"90 deg",  0x00006488, 0x7FFF0000},
};

void croc_interrupt_handler(uint32_t cause)
{
    if (cause == CORDIC_IRQ_FAST)
    {
        uint32_t status = cordic_read_status();
        cordic_job_done = 1;
    }
}

int main() {
    // Wait for reset to fully propagate
    for (volatile int i = 0; i < 100; i++);

    uint32_t burst_angles[BURST_LEN];
    uint32_t burst_results[BURST_LEN];

    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);

    // Populate the burst buffer cyclically
    for (int i = 0; i < BURST_LEN; i++) {
        burst_angles[i] = test_vectors[i % 5].angle_fixed;
    }

    // Generate sustained switching activity for VCD
    for (int iter = 0; iter < ITERATIONS; iter++) {
        // Run offloaded CORDIC job via memory path
        cordic_job(burst_angles, burst_results, BURST_LEN);
    }

    set_global_irq_enable(0);
    set_interrupt_enable(0, CORDIC_IRQ_FAST);

    return 0; // Silent PASS
}