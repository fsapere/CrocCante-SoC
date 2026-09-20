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

__attribute__((section(".cordic_data"))) static uint32_t src_buffer[32];
__attribute__((section(".cordic_data"))) static uint32_t dst_buffer[32];

void croc_interrupt_handler(uint32_t cause)
{
    if (cause == CORDIC_IRQ_FAST)
    {
        uint32_t status = cordic_read_status(); // clear DONE
        cordic_job_done = 1;
    }
}

static void fill_buf(uint32_t *buf, uint32_t n, uint32_t val) {
    for (uint32_t i = 0; i < n; i++) {
        buf[i] = val;
    }
}

static int check_buf_not_equal(uint32_t *buf, uint32_t n, uint32_t forbidden) {
    for (uint32_t i = 0; i < n; i++) {
        if (buf[i] == forbidden) return 0;
    }
    return 1;
}

static inline int report_packed_compare(uint32_t expected, uint32_t actual) {
    int16_t expected_cos = expected & 0xFFFF;
    int16_t expected_sin = (expected >> 16) & 0xFFFF;
    int16_t actual_cos = actual & 0xFFFF;
    int16_t actual_sin = (actual >> 16) & 0xFFFF;
    
    int16_t err_cos = actual_cos - expected_cos;
    int16_t err_sin = actual_sin - expected_sin;

    // Allow a small precision margin
    int pass = (err_cos >= -10 && err_cos <= 10) && (err_sin >= -10 && err_sin <= 10);
    return pass;
}

static int run_burst_test(int n) {
    for (int i = 0; i < n; i++) {
        src_buffer[i] = test_vectors[i % 32].angle_fixed;
    }
    fill_buf(dst_buffer, n, 0xDEADBEEF);

    cordic_job(src_buffer, dst_buffer, n);

    int pass = 1;
    if (!check_buf_not_equal(dst_buffer, n, 0xDEADBEEF)) {
        printf("Fail_D n=%x\n", n);
        pass = 0;
    } else {
        for (int i = 0; i < n; i++) {
            uint32_t exp = test_vectors[i % 32].expected_packed;
            if (!report_packed_compare(exp, dst_buffer[i])) {
                pass = 0;
            }
        }
    }
    printf("B%x:%s\n", n, pass ? "P" : "F");
    return pass;
}

int main()
{
    uart_init();

    // Wait for reset to fully propagate (several clock cycles)
    for (volatile int i = 0; i < 100; i++);

    int overall_pass = 1;

    set_global_irq_enable(1);
    set_interrupt_enable(1, CORDIC_IRQ_FAST);

    const int num_tests = (int)(sizeof(test_vectors) / sizeof(test_vectors[0]));

    for (int i = 0; i < num_tests; i++)
    {
        fill_buf(src_buffer, 1, test_vectors[i].angle_fixed);
        fill_buf(dst_buffer, 1, 0xDEADBEEF);

        cordic_job(src_buffer, dst_buffer, 1);
        
        int pass = 1;
        if (!check_buf_not_equal(dst_buffer, 1, 0xDEADBEEF)) {
            printf("Fail_D S%x\n", i);
            pass = 0;
        } else {
            pass = report_packed_compare(test_vectors[i].expected_packed, dst_buffer[0]);
        }
        
        overall_pass &= pass;
        printf("S%x:%s\n", i, pass ? "P" : "F");
    }

    // Run burst tests
    overall_pass &= run_burst_test(5);
    overall_pass &= run_burst_test(19);  // CORDIC_LATENCY is 19
    overall_pass &= run_burst_test(32);  // FIFO_DEPTH is 32

    set_global_irq_enable(0);
    set_interrupt_enable(0, CORDIC_IRQ_FAST);
    CORDIC_CTRL = 0;

    printf("[SUMMARY] Bench Func: %s\n", overall_pass ? "PASS" : "FAIL");

    uart_write_flush();
    return overall_pass ? 0 : 1;
}
