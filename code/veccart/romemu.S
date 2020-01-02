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
// DEBUG code to show on serial TX when romemu starts
//  mov   r0,#'R'
//  ldr   r1,=0x40011004
//  str   r0,[r1]

    // Initialization
    ldr   r1,=0x40020800        // GPIOC idr offset
    ldr   r0,=romData           // ROM data array
    ldr   r2,[r0]
    ldr   r3,=0x40020000        // GPIOA bsrr offset
    ldr   r4,=0x40020400        // GPIOB idr offset
    ldr   r8,=0                 // Cycle count since last event

wloop:
    // Wait for NCART to become active
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

//  b     dbg

    add   r8,#1                 // Increase read count

    cmp   r0,#4                 // Is this a read of the copyright?
    bne   wloop

    // According to my emu, the ROM reads a random header about 19296 times. Seems like
    // Vectrexes with a GCE logo read it more often than my MB-branded one... hope this
    //   number holds up then.
    // Note: this was resetting prematurely on GCE vectri with #0x10000 to 0x40000.
    //       Later doubled from 0x40000 to 0x80000 due to long tune on Fortress of Narzod
    cmp   r8,#0x80000
    blo   wloop

    // Header read when the game has been running for a while. Hmm, cart probably is reset...
    // Exchange the rom and menu data
    ldr   r0,=romData
    ldr   r2,=menuData
    str   r2,[r0]

    mov   r8,#0
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
    // Is it a write to addr #$0000 = serial port addr (TODO: avoid addr 0 because Polar Rescue writes there!)
    cmp   r0,#0
    beq   outserial

    // See if it is a write to xxFF
    and   r0,#0xff
    cmp   r0,#0xff
    beq   handleevent

    // Nope, it is probably a parameter
    ldr   r7,=parmRam
    strb  r5,[r7, r0]
    b     wrdone

// TODO: Move this sub-routine after wrdone, and let the parameter write fall through to wrdone
//       to save a few instructions on average and force more cycles to be wasted only when using serial
outserial:
    // Output byte to serial port (TX pin on debugging header)
    ldr   r0,=0x40011004
    str   r5,[r0]

    // Wait until the /wr line goes high again
wrdone:
    ldr   r0,[r4, 0x10]         // Load inputs
    lsls  r0,#(31-1)            // Shift bit 1 into sign flag
    bmi   wloop                 // bit 1 set? Return if so
    b     wrdone                // Wr still is low

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
