#include "cordic.h"
#include "print.h"
#include "util.h"

volatile int cordic_job_done = 0;

void cordic_job_start(uint32_t *src, uint32_t *dst, uint32_t len) {
    CORDIC_SRC_ADDR = (uint32_t)src;
    CORDIC_DST_ADDR = (uint32_t)dst;
    CORDIC_LENGTH   = len;
    CORDIC_CTRL     = (1 << CORDIC_CTRL_START_BIT) | (1 << CORDIC_CTRL_IRQ_EN_BIT);
}

void cordic_job(uint32_t *src, uint32_t *dst, uint32_t len) {
    cordic_job_done = 0;
    cordic_job_start(src, dst, len);
    while (!cordic_job_done) {
        wfi();
    }
}
