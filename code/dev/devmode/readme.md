Developer Mode (Standalone)
===

This is a dedicated standalone app for the feature Developer Mode that's built into VEXTREME's menu.

It allows you to enable Developer Mode from your application, and this app is completely silent (no start-up tune)

To use this app, you can place it in the root of VEXTREME/devmode.bin

and launch it with an RPC ID 11 call with argument 0

```
loadapp
        lda     #0          ; Load system app (hard coded to 0 for now: dev mode)
        sta     $7ffe       ; |
        lda     #11         ; rpc call to load a system rom
        ldx     #$f000      ; load x with return jmp address
        jmp     rpcfn2      ; Goodbye, we won't see you again hopefully!
```

NOTE: There is one teeny tiny problem though... this is all nice to document for posterity but it won't actually work.  Sure the app will launch, but Developer Mode can't function properly when the mode is loaded in cartData[] ... it needs to be in menuData[], womp womp.  There are special addresses that the mode looks at that the STM32 code updates, and this app won't ever see those get updated because they are happening over in menuData[] and this app is running from cartData[].

Anyhoo it's the thought that counts... if you come up with a solution let's hear about it in the Discord server ;-)
