#include <stdint.h>
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"

typedef struct
{
    uint32_t angle_fixed;
    uint32_t expected_packed;
} cordic_test_vector_t;

// A significantly reduced set of test vectors for power simulation
// to prevent out-of-memory errors with the resulting VCD file.
static const cordic_test_vector_t test_vectors[] = {
    {0x00000000, 0x00007FFF}, // 0 deg
    {0x00003244, 0x5A825A82}, // 45 deg
    {0x00006488, 0x7FFF0000}, // 90 deg
    {0x000096CC, 0x5A82A57E}, // 135 deg
    {0x0000C910, 0x00008001}, // 180 deg
    {0x0000FB54, 0xA57EA57E}, // 225 deg
    {0x00012D98, 0x80010000}, // 270 deg
    {0x00015FDC, 0xA57E5A82}, // 315 deg
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

static uint32_t src_buffer[8];
static uint32_t dst_buffer[8];

static int run_burst_sw_test(int n) {
    int pass = 1;
    for (int i = 0; i < n; i++) {
        src_buffer[i] = test_vectors[i % 8].angle_fixed;
    }

    // Workload simulation loop
    for (int i = 0; i < n; i++) {
        dst_buffer[i] = sw_cordic(src_buffer[i]);
    }
    
    // Quick verification
    for (int i = 0; i < n; i++) {
        uint32_t exp = test_vectors[i % 8].expected_packed;
        
        int16_t expected_cos = exp & 0xFFFF;
        int16_t expected_sin = (exp >> 16) & 0xFFFF;
        int16_t actual_cos = dst_buffer[i] & 0xFFFF;
        int16_t actual_sin = (dst_buffer[i] >> 16) & 0xFFFF;
        
        int16_t err_cos = actual_cos - expected_cos;
        int16_t err_sin = actual_sin - expected_sin;

        if (!(err_cos >= -10 && err_cos <= 10 && err_sin >= -10 && err_sin <= 10)) {
            pass = 0;
        }
    }
    return pass;
}

int main()
{
    uart_init();

    for (volatile int i = 0; i < 100; i++);

    printf("Starting Baseline Power Simulation Workload\n");

    int sw_pass = run_burst_sw_test(8);

    if (sw_pass) {
        printf("Baseline SW test PASS\n");
    } else {
        printf("Baseline SW test FAIL\n");
    }

    uart_write_flush();
    return sw_pass ? 0 : 1;
}
