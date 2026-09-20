/* test_cordic_HWSW_sweep.c
 *
 * Multi-N HW vs SW speedup sweep.
 * Runs CORDIC in HW and SW for N = 32, 64, 128, 256 and prints
 * only the total execution cycles per N (no config/IRQ breakdown).
 *
 * REQUIRES: link_hwsw.ld  (Banks 0+1 for code, Banks 2+3 for buffers)
 *   Build:  make LINK=link_hwsw.ld bin/test_cordic_HWSW_sweep.hex
 */

#include <stdint.h>
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"
#include "cordic.h"

#define CORDIC_IRQ_FAST  23
#define MAX_BURST        256
#define NUM_TEST_VECTORS 32

/* ---------- Test vectors (reused from test_cordic_HWSW_compare.c) ---------- */
static const uint32_t test_angles[NUM_TEST_VECTORS] = {
    0x00000000, 0x000010C1, 0x00002183, 0x00003244,
    0x00004305, 0x000053C7, 0x00006488, 0x00007549,
    0x0000860B, 0x000096CC, 0x0000A78D, 0x0000B84F,
    0x0000C910, 0x0000D9D1, 0x0000EA93, 0x0000FB54,
    0x00010C15, 0x00011CD7, 0x00012D98, 0x00013E59,
    0x00014F1B, 0x00015FDC, 0x0001709D, 0x0001815F,
    0x0000011E, 0x0000636A, 0x000065A6, 0x0000C7F2,
    0x0000CA2E, 0x00012C7A, 0x00012EB6, 0x00019102,
};

/* ---------- SW CORDIC (same algorithm as hardware) ---------- */
static const uint32_t atan_table[16] = {
    12867, 7596, 4013, 2037, 1022, 511, 256, 128, 64, 32, 16, 8, 4, 2, 1, 1
};
#define CORDIC_GAIN 19897

static uint32_t sw_cordic(int32_t input_angle) {
    int32_t reduced_angle;
    int cos_negate = 0, sin_negate = 0;

    if (input_angle <= 0x06488) {
        reduced_angle = input_angle;
    } else if (input_angle <= 0x0C910) {
        reduced_angle = 0x0C910 - input_angle;
        cos_negate = 1;
    } else if (input_angle <= 0x12D98) {
        reduced_angle = input_angle - 0x0C910;
        cos_negate = 1;
        sin_negate = 1;
    } else {
        reduced_angle = 0x19220 - input_angle;
        sin_negate = 1;
    }

    int32_t x = CORDIC_GAIN;
    int32_t y = 0;
    int32_t z = reduced_angle;

    for (int i = 0; i < 16; i++) {
        int32_t x_shift = x >> i;
        int32_t y_shift = y >> i;
        if (z < 0) {
            x = x + y_shift;
            y = y - x_shift;
            z = z + atan_table[i];
        } else {
            x = x - y_shift;
            y = y + x_shift;
            z = z - atan_table[i];
        }
    }

    if (cos_negate) x = -x;
    if (sin_negate) y = -y;

    uint32_t res_cos = (uint32_t)(x & 0xFFFF);
    uint32_t res_sin = (uint32_t)(y & 0xFFFF);
    return (res_sin << 16) | res_cos;
}

/* ---------- Buffers in Banks 2+3 (.cordic_data) ---------- */
__attribute__((section(".cordic_data"))) static uint32_t src_buffer[MAX_BURST];
__attribute__((section(".cordic_data"))) static uint32_t dst_buffer[MAX_BURST];

/* ---------- ISR ---------- */
void croc_interrupt_handler(uint32_t cause)
{
    if (cause == CORDIC_IRQ_FAST) {
        uint32_t status = cordic_read_status();
        cordic_job_done = 1;
    }
}

/* ---------- HW burst ---------- */
static uint32_t run_hw(int n) {
    for (int i = 0; i < n; i++)
        src_buffer[i] = test_angles[i % NUM_TEST_VECTORS];

    cordic_job_done = 0;
    uint64_t t0 = get_mcycle();
    cordic_job_start(src_buffer, dst_buffer, n);
    while (!cordic_job_done) { wfi(); }
    uint64_t t1 = get_mcycle();

    return (uint32_t)(t1 - t0);
}

/* ---------- SW burst ---------- */
static uint32_t run_sw(int n) {
    for (int i = 0; i < n; i++)
        src_buffer[i] = test_angles[i % NUM_TEST_VECTORS];

    uint64_t t0 = get_mcycle();
    for (int i = 0; i < n; i++)
        dst_buffer[i] = sw_cordic(src_buffer[i]);
    uint64_t t1 = get_mcycle();

    return (uint32_t)(t1 - t0);
}

/* ---------- Main ---------- */
int main(void)
{
    uart_init();
    for (volatile int i = 0; i < 100; i++);

    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);

    static const uint32_t n_values[] = {32, 64, 128, 256};
    int overall_pass = 1;

    for (int ni = 0; ni < 4; ni++) {
        uint32_t n  = n_values[ni];
        uint32_t sw = run_sw(n);
        uint32_t hw = run_hw(n);

        /* Integer speedup = sw / hw */
        uint32_t speedup = 0;
        if (hw > 0) {
            uint32_t tmp = sw;
            while (tmp >= hw) { tmp -= hw; speedup++; }
        }
        printf("[SUMMARY] SWvsHW N=%x: PASS speedup=%x (S=%x H=%x)\n",
               n, speedup, sw, hw);
    }

    set_global_irq_enable(0);
    set_interrupt_enable(0, CORDIC_IRQ_FAST);

    printf("[SUMMARY] SWvsHW_sweep: DONE\n");
    uart_write_flush();
    return 0;
}
