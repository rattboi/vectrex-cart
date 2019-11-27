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
//Main rom emulation code

romemu:
//	mov r0,#'R'
//	ldr r1,=0x40011004
//	str r0,[r1]

	ldr r1,=0x40020800	//gpioc idr offset
	ldr r0,=romData		//ROM data array
	ldr r2,[r0]
	ldr r3,=0x40020000	//gpioa bsrr offset
	ldr r4,=0x40020400	//gpiob idr offset
	ldr r8,=0			//cycle count since last event
wloop:
//wait for NCART to become active
	ldr r0,[r4, 0x10]
	lsls r0,#(31-15)		//shift bit 15 into sign flag
	bmi wloop				//bit 15 set? Loop if so
//Check for a write
	ldr r0,[r4, 0x10]
	lsls r0,#(31-1)			//shift bit 1 into sign flag
	bpl write				//bit 1 clear? Is write!

	//Handle read: load address, get byte, send to Vectrex
	ldr r0,[r1, 0x10]		//load addr pins
	eor r0, r0, #0x8000		//invert software-controlled line: it is high per default

	ldrb r5,[r0, r2]		//load corresponding byte in rom
	orr.w r5,r5,#0xff0000	//set shit
	str r5,[r3, 0x18]		//output

//	b dbg

	add r8,#1				//increase read count

	cmp r0,#4				//is this a read of the copyright?
	bne wloop

	//According to my emu, the ROM reads a random header about 19296 times. Seems like
	//Vectrexes with a GCE logo read it more often than my MB-branded one... hope this
	//number holds up then.
	// Note: this was resetting prematurely on GCE vectri with #0x10000
	cmp r8,#0x40000
	blo wloop

	//Header read when the game has been running for a while. Hmm, cart probably is reset...
	//Exchange the rom and menu data
	ldr r0,=romData
	ldr r2,=menuData
	str r2,[r0]

	mov r8,#0
	b wloop


write:
	//The Vec writes to the cart. Seemingly, we need to do something
	ldr r6,[r3, 0]			//load input/output defs of portA
	mov r7,r6				//Save old values
	lsr r6,#16				//Nuke bottom 16 bits...
	lsl r6,#16				//...by shifting them out and zeroes back.
	str r6,[r3, 0]			//Set bottom 8 pins of gpioa to input
	ldr r0,[r1, 0x10]				//load addr word from gpioc
	ubfx r0,r0,#0,#15		//and with 0x7fff

	//We need to delay a while because the written data is only stable
	//in the 2nd half of the cycle.
	mov r6,#10
waitdataloop:
	subs r6,#1
	bne waitdataloop

	ldr r5,[r3, 0x10]		//load data
	and r5,#0xff
	str r7,[r3, 0]			//restore bottom half of gpioa to output

//From here on:
//r0 is addr
//r5 is data

	//addr 0 = serial port addr
	cmp r0,#0
	beq outserial

	//See if it is a write to xxFF
	and r0,#0xff
	cmp r0,#0xff
	beq handleevent
	//Nope, it is probably a parameter.
	ldr r7,=parmRam
	strb r5,[r7, r0]
	b wrdone

outserial:
	//output byte to ser port
	ldr r0,=0x40011004
	str r5,[r0]


	//Wait till the /wr line goes high again.
wrdone:
	ldr r0,[r4, 0x10]	//Load inputs
	lsls r0,#(31-1)		//shift bit 1 into sign flag
	bmi wloop			//bit 1 set? Return if so
	b wrdone			//Wr still is low.


dbg:
	mov r1,r5
	ldr r2,=doDbgHook
	blx r2
	b romemu

handleevent:
	mov r0,r5
	ldr r1,=doHandleEvent
	blx r1
	b romemu

