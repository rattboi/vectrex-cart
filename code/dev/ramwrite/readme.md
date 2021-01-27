RAM Write
===

Just a little app to help test writes to RAM.

To use this app, you can place it in VEXTREME/roms/DEV/ramwrite.bin

and launch it with an RPC ID 13 call with address specified as follows:

$7ff0 - Start Address High Byte
$7ff1 - Start Address Low  Byte
$7ff2 -   End Address High Byte
$7ff3 -   End Address Low  Byte

```
ram_dump
        lda     #$20        ; Dump RAM $2000 ~ $27ff to TX output
        sta     $7ff0       ; |
        lda     #$00        ; |
        sta     $7ff1       ; |
        lda     #$27        ; |
        sta     $7ff2       ; |
        lda     #$ff        ; |
        sta     $7ff3       ; |
        lda     #13         ; |
        ldx     #main_loop  ; load x with return jmp address to main_loop
        jmp     rpcfn1      ; Y'all come back now, ya hear?
```

