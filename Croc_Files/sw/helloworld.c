#include "uart.h"
#include "print.h"
#include "config.h"

int main()
{
    uart_init();
    printf("Hello World from Croc!\n");

    volatile unsigned int *user_id = (volatile unsigned int *)0x20000000; // Start of user_rom
    unsigned int buffer[16];                                              // Array of unsigned int to ensure 32-bit (4 byte) alignment

    // Read memory in 32-bit words
    for (int i = 0; i < 16; i++)
    {
        buffer[i] = user_id[i];
    }

    // Print the buffer (cast to char*)
    printf("%s\n", (char *)buffer);

    uart_write_flush();
    return 0;
}
