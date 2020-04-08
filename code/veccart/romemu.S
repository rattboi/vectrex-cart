.code 16
.syntax unified

.global menuData
.global cartData
.global romData
.global parmRam
.global doHandleEvent
.global doDbgHook
.global readcnt

.section .data

.global romemu
// Main rom emulation code

romemu:
    // Initialization
    ldr   r1,=0x40020800        // GPIOC idr offset
    ldr   r0,=romData           // Load ROM data array addr in scratch r0
    ldr   r2,[r0]
    ldr   r3,=0x40020000        // GPIOA bsrr offset
    ldr   r4,=0x40020400        // GPIOB idr offset
                                // r5 is another scratch register for data
                                // r6 is another scratch register for data manipulation
    ldr   r7,=0xfffe            // reset vector constant
    ldr   r8,=0                 // Cycle count since last event
    ldr   r9,=0x40011004        // USART1_DR for quick addr pointer to Serial Debugging TX
                                // USART1_SR = 0x40011000

wloop:
    // Check for 6809 reset vector (0xFFFE)
    // FIXME: Currently on v0.2, we are not reading A15 for MSB, but rather PB6.
    //        This works though, because PB6 stays HIGH, but it might break down
    //        with games that toggle PB6.  Not sure what PB6 will do if LOW, when
    //        the Vectrex is reset.  Change this for v0.3 hardware so A15 is on PC15,
    //        unless something like Bad Apple or Voom uses PB6, although in testing
    //        it doesn't seem like it.  Bad Apple can be reset now with this method.
    ldr   r0,[r1, 0x10]         // Load addr pins
    cmp   r0,r7                 // Compare to 6809 reset vector
    bne   clearcount

    add   r8,#1                 // Increase reset vector count
    cmp   r8,#0x700000          // 8 cycles * 0x170000 is about 100ms (FIXME: use HW timer)
                                //   0x700000 is is more like 700ms (quick tap resets game, long tap back to menu)
                                //   Found that no-buzz Vectrex has a min 300ms reset pulse, so 700ms is about right.
    blo   resetexit             // Keep the increased count, but exit without returning to menu

    // Reset vector detected for more than 100ms, exchange the rom and menu data
    ldr   r0,=romData
    ldr   r2,=menuData
    str   r2,[r0]
//  mov   r0,#'R'               // Debug code, to know when we've detected RESET
//  str   r0,[r9]               //  |
waitreset:
    ldr   r0,[r1, 0x10]         // Load addr pins
    cmp   r0,r7                 // Compare to 6809 reset vector
    beq   waitreset             // Wait for reset vector to clear
                                // Fall through clear count to reset counter
clearcount:
    and   r8,#0
resetexit:

    // Wait for /CE (A15) to become active
    ldr   r0,[r4, 0x10]
    lsls  r0,#(31-15)           // Shift bit 15 into sign flag
    bmi   wloop                 // Bit 15 set? Loop if so

    // Check for a write
    ldr   r0,[r4, 0x10]
    lsls  r0,#(31-1)            // Shift bit 1 into sign flag
    bpl   write                 // Bit 1 clear? Is write!

    // Handle read: load address, get byte, send to Vectrex
    ldr   r0,[r1, 0x10]         // Load addr pins
    eor   r0, r0, #0x8000       // Invert software-controlled line: it is high per default

    ldrb  r5,[r0, r2]           // Load corresponding byte in rom
    orr.w r5,r5,#0xff0000       // Set shit
    str   r5,[r3, 0x18]         // Output

    b     wloop

write:
    // The Vec writes to the cart. Seemingly, we need to do something
    ldr   r6,[r3, 0]            // Load input/output defs of portA
    mov   r7,r6                 // Save old values
    lsr   r6,#16                // Nuke bottom 16 bits...
    lsl   r6,#16                // ...by shifting them out and zeroes back.
    str   r6,[r3, 0]            // Set bottom 8 pins of gpioa to input
    ldr   r0,[r1, 0x10]         // Load addr word from gpioc
    ubfx  r0,r0,#0,#15          // and with 0x7fff

    // We need to delay a while because the written data is only stable
    // in the 2nd half of the cycle.
    mov   r6,#10                // <- Oscillator frequency dependent magic number here!!
waitdataloop:
    subs  r6,#1
    bne   waitdataloop

    ldr   r5,[r3, 0x10]         // Load data
    and   r5,#0xff
    str   r7,[r3, 0]            // Restore bottom half of gpioa to output

    // From here on:
    // r0 is addr
    // r5 is data
    // Writes to 0x7f00-0x7ffe are to set parameter values for a future event (rpc function ID)
    // Writes to 0x7fff are the rpc function ID's and kick off the function
    // Writes to 0x0000 will have the data byte immediately forwarded to the serial TX pin for debugging
    // ------------------------------------------------------------------------
    // Is it a write to addr #$0000 = serial port addr
    // TODO: avoid addr 0 because Polar Rescue writes there occassionally
    //       avoid addr 1 because the Bad Apple player writes there a lot!
    cmp   r0,#0
    beq   outserial

    // See if it is a write to 7Fxx (this is extra insurance against odd Polar Rescue writes)
    lsr   r9,r0,#8
    cmp   r9,#0x7f
    bne   wrdone                // If not, bail out.  TODO: jump to write RAM instead

    // See if it is a write to xxFF
    and   r0,#0xff
    cmp   r0,#0xff
    beq   handleevent

    // Nope, it is probably a parameter
    ldr   r7,=parmRam
    strb  r5,[r7, r0]

    // Wait until the /wr line goes high again
wrdone:
    ldr   r0,[r4, 0x10]         // Load inputs
    lsls  r0,#(31-1)            // Shift bit 1 into sign flag
    bmi   romemu                // bit 1 set? Return if so (was jumping back to wloop, but seemed
                                //  to not return to menu unless registers re-init with romemu jump
                                //  when playing Polar Rescue, after sub launches and Write to cart occur)
    b     wrdone                // Wr still is low

// This sub-routine is after wrdone, and lets the parameter write fall through to wrdone
// to save a few instructions on average and force more cycles to be wasted only when using serial
outserial:
    // Output byte to serial port (TX pin on debugging header)
    ldr   r0,=0x40011004
    str   r5,[r0]
    b     wrdone

dbg:
    mov   r1,r5
    ldr   r2,=doDbgHook
    blx   r2
    b     romemu

handleevent:
    mov   r0,r5
    ldr   r1,=doHandleEvent
    blx   r1
    b     romemu
