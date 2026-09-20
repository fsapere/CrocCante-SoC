#ifndef CORDIC_H
#define CORDIC_H

#include <stdint.h>

// CORDIC base address in user_domain
#define CORDIC_BASE 0x20001000

// Register offsets
#define CORDIC_REG_SRC_ADDR  0x00
#define CORDIC_REG_DST_ADDR  0x04
#define CORDIC_REG_LENGTH    0x08
#define CORDIC_REG_CTRL      0x0C
#define CORDIC_REG_STATUS    0x10

// Register pointers
#define CORDIC_SRC_ADDR  (*(volatile uint32_t *)(CORDIC_BASE + CORDIC_REG_SRC_ADDR))
#define CORDIC_DST_ADDR  (*(volatile uint32_t *)(CORDIC_BASE + CORDIC_REG_DST_ADDR))
#define CORDIC_LENGTH    (*(volatile uint32_t *)(CORDIC_BASE + CORDIC_REG_LENGTH))
#define CORDIC_CTRL      (*(volatile uint32_t *)(CORDIC_BASE + CORDIC_REG_CTRL))
#define CORDIC_STATUS    (*(volatile uint32_t *)(CORDIC_BASE + CORDIC_REG_STATUS))

#define CORDIC_CTRL_START_BIT  0
#define CORDIC_CTRL_IRQ_EN_BIT 1
#define CORDIC_STATUS_BUSY_BIT 0
#define CORDIC_STATUS_DONE_BIT 1
#define CORDIC_STATUS_ERR_BIT  2

extern volatile int cordic_job_done;

// IRQ-based job launch (blocking)
void cordic_job(uint32_t *src, uint32_t *dst, uint32_t len);

// Async job launch
void cordic_job_start(uint32_t *src, uint32_t *dst, uint32_t len);

// Status helpers
static inline uint32_t cordic_read_status(void) {
    return CORDIC_STATUS;
}

static inline int cordic_is_busy(void) {
    return (CORDIC_STATUS >> CORDIC_STATUS_BUSY_BIT) & 1;
}

static inline int cordic_is_done(void) {
    return (CORDIC_STATUS >> CORDIC_STATUS_DONE_BIT) & 1;
}

static inline int cordic_has_err(void) {
    return (CORDIC_STATUS >> CORDIC_STATUS_ERR_BIT) & 1;
}

#endif // CORDIC_H
