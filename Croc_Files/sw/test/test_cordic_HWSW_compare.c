#include <stdint.h>
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"
#include "cordic.h"

// CORDIC is wired as fast interrupt 7, which maps to mcause 23.
#define CORDIC_IRQ_FAST       23

typedef struct
{
    uint32_t angle_fixed;
    uint32_t expected_packed;
} cordic_test_vector_t;

static const cordic_test_vector_t test_vectors[] = {
    {0x00000000, 0x00007FFF}, // 0 deg
    {0x000010C1, 0x21217BA2}, // 15 deg
    {0x00002183, 0x3FFF6ED9}, // 30 deg
    {0x00003244, 0x5A825A82}, // 45 deg
    {0x00004305, 0x6ED94000}, // 60 deg
    {0x000053C7, 0x7BA22121}, // 75 deg
    {0x00006488, 0x7FFF0000}, // 90 deg
    {0x00007549, 0x7BA2DEDF}, // 105 deg
    {0x0000860B, 0x6ED9C001}, // 120 deg
    {0x000096CC, 0x5A82A57E}, // 135 deg
    {0x0000A78D, 0x3FFF9127}, // 150 deg
    {0x0000B84F, 0x2121845E}, // 165 deg
    {0x0000C910, 0x00008001}, // 180 deg
    {0x0000D9D1, 0xDEDF845E}, // 195 deg
    {0x0000EA93, 0xC0009127}, // 210 deg
    {0x0000FB54, 0xA57EA57E}, // 225 deg
    {0x00010C15, 0x9127C000}, // 240 deg
    {0x00011CD7, 0x845EDEDF}, // 255 deg
    {0x00012D98, 0x80010000}, // 270 deg
    {0x00013E59, 0x845E2121}, // 285 deg
    {0x00014F1B, 0x91274000}, // 300 deg
    {0x00015FDC, 0xA57E5A82}, // 315 deg
    {0x0001709D, 0xC0006ED9}, // 330 deg
    {0x0001815F, 0xDEDF7BA2}, // 345 deg
    {0x0000011E, 0x023C7FFA}, // 1 deg
    {0x0000636A, 0x7FFA023C}, // 89 deg
    {0x000065A6, 0x7FFAFDC4}, // 91 deg
    {0x0000C7F2, 0x023C8006}, // 179 deg
    {0x0000CA2E, 0xFDC48006}, // 181 deg
    {0x00012C7A, 0x8006FDC4}, // 269 deg
    {0x00012EB6, 0x8006023C}, // 271 deg
    {0x00019102, 0xFDC47FFA}, // 359 deg
};

static const uint32_t atan_table[16] = {
    12867, 7596, 4013, 2037, 1022, 511, 256, 128, 64, 32, 16, 8, 4, 2, 1, 1
};

#define CORDIC_GAIN 19897 // 16'sh4DB9

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

volatile uint64_t t_isr = 0;

void croc_interrupt_handler(uint32_t cause)
{
    t_isr = get_mcycle();
    if (cause == CORDIC_IRQ_FAST)
    {
        uint32_t status = cordic_read_status();
        cordic_job_done = 1;
    }
}

static inline int report_packed_compare(uint32_t expected, uint32_t actual) {
    int16_t expected_cos = expected & 0xFFFF;
    int16_t expected_sin = (expected >> 16) & 0xFFFF;
    int16_t actual_cos = actual & 0xFFFF;
    int16_t actual_sin = (actual >> 16) & 0xFFFF;
    
    int16_t err_cos = actual_cos - expected_cos;
    int16_t err_sin = actual_sin - expected_sin;

    int pass = (err_cos >= -10 && err_cos <= 10) && (err_sin >= -10 && err_sin <= 10);
    return pass;
}

__attribute__((section(".cordic_data"))) static uint32_t src_buffer[32];
__attribute__((section(".cordic_data"))) static uint32_t dst_buffer[32];

static int run_burst_test(int n, uint32_t *cyc_out, uint32_t *cfg_out, uint32_t *crn_out, uint32_t *irq_out) {
    int pass = 1;
    for (int i = 0; i < n; i++) {
        src_buffer[i] = test_vectors[i % 32].angle_fixed;
    }


    cordic_job_done = 0;
    
    uint64_t t_start = get_mcycle();
    cordic_job_start(src_buffer, dst_buffer, n);
    uint64_t t_configured = get_mcycle();
    
    while (!cordic_job_done) {
        wfi();
    }
    uint64_t t_done = get_mcycle();
    
    if (cyc_out) *cyc_out = (uint32_t)(t_done - t_start);

    if (cfg_out) *cfg_out = (uint32_t)(t_configured - t_start);
    if (crn_out) *crn_out = (uint32_t)(t_isr - t_configured);
    if (irq_out) *irq_out = (uint32_t)(t_done - t_isr);

    for (int i = 0; i < n; i++) {
        uint32_t exp = test_vectors[i % 32].expected_packed;
        if (!report_packed_compare(exp, dst_buffer[i])) {
            if (pass) printf("HWF i=%x e=%x a=%x\n", i, exp, dst_buffer[i]);
            pass = 0;
        }
    }
    return pass;
}

static int run_burst_sw_test(int n, uint32_t *cyc_out) {
    int pass = 1;
    for (int i = 0; i < n; i++) {
        src_buffer[i] = test_vectors[i % 32].angle_fixed;
    }

    uint64_t t0 = get_mcycle();
    for (int i = 0; i < n; i++) {
        dst_buffer[i] = sw_cordic(src_buffer[i]);
    }
    uint64_t t1 = get_mcycle();

    if (cyc_out) *cyc_out = (uint32_t)(t1 - t0);

    for (int i = 0; i < n; i++) {
        uint32_t exp = test_vectors[i % 32].expected_packed;
        if (!report_packed_compare(exp, dst_buffer[i])) {
            pass = 0;
        }
    }
    return pass;
}

int main()
{
    uart_init();

    for (volatile int i = 0; i < 100; i++);

    int overall_pass = 1;

    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);

    uint32_t sw_cyc = 0;
    uint32_t hw_cyc = 0, hw_cfg = 0, hw_crn = 0, hw_irq = 0;
    int sw_pass = run_burst_sw_test(16, &sw_cyc);
    int hw_pass = run_burst_test(16, &hw_cyc, &hw_cfg, &hw_crn, &hw_irq);

    set_global_irq_enable(0);
    set_interrupt_enable(0, CORDIC_IRQ_FAST);

    if (hw_pass && sw_pass) {
        printf("[SUMMARY] S=%x H=%x cfg=%x crn=%x irq=%x\n", sw_cyc, hw_cyc, hw_cfg, hw_crn, hw_irq);
    } else {
        printf("[SUMMARY] FAIL\nsw:%x hw:%x\n", sw_pass, hw_pass);
    }

    uart_write_flush();
    return (hw_pass && sw_pass) ? 0 : 1;
}
