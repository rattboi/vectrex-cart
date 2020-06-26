# Developer Mode (DM)

## Overview

This mode allows a single game to be flashed to VEXTREME via USB and immediately run.  To update the game, simply press reset, let the VEXTREME drive re-mount and you are ready to flash again.  Usually this connection time is impercievable since you reset VEXTREME, and then have to go press compile & flash.  This feature is already supported by Vide, as implemented for VecFever, but you may implement support easily in any development toolchain.  For this feature to work in Vide, you must copy [this README.TXT](https://www.dropbox.com/s/i8ykyks87n8ihxq/README.TXT?dl=1) to the root of your VEXTREME.

# Entering Developer Mode

- Press button 2 & 3 together at any time during the VEXTREME Menu to enter DM, or hold them down when starting the Menu.  NOTE: they must be pressed at the same time, not 2 then 3 or vice versa.
- The Developer Mode wait screen will prompt you to "PLUG IN USB" if you have USB unplugged. 
- After plugging it in, it will show "LOAD CART.BIN" prompting you to put a cart.bin file in the root of the drive e.g. VEXTREME/cart.bin.
- If the Vectrex is off, and USB plugged in, the USB drive will mount as usual.  You may add a cart.bin however you wish, and then if you Eject the drive it will detect the cart.bin and load it.  As soon as you turn your Vectrex on, it will boot the cart.bin ROM.  You may press reset to skip the cold boot sequence and warm reset the cart.bin (v0.3 HW only, or v0.2 with mods)
- DM is considered "active" when a cart.bin is present.
- If you reset the Vectrex while DM is active, it will automatically return to DM mode without needing to press buttons 2 & 3.  This is the preferred way to re-enter DM after running cart.bin, to get ready to flash another cart.bin.

# Developer Mode Menu

- The splash screen for DM will show one of 4 messages:
  - "PLUG IN USB" (pretty obvious you need to plug in USB)
  - "UNKNOWN USB" (you should never see this, but it's there for debugging weird issues)
  - "LOAD CART.BIN" (USB is plugged in and we are waiting for a cart.bin and the eject sequence.  Currently you must eject, not use safely remove hardware.  Windows users, go to File Explorer and Eject the drive. TODO: add a timeout for Windows users in the future that detects safe removal process)
  - "1: EXIT  4: RUN" (this just helps you remember what button to press to EXIT developer mode and delete cart.bin or RUN the cart.bin if present.  If no cart.bin present it will just return to the VEXTREME Menu. USB does not need to be connected to EXIT or RUN)
- The splash screen was specifically designed to be a bit less bright, and randomly move the text LEFT/RIGHT/UP/DOWN for even screen wear. Do not calibrate your screen brightness in this mode.
- If you accidentally press RESET after connecting USB, you might see Mine Storm load.  Just press RESET again and you should recover.

# Exiting Developer Mode

- DM can be "disabled" by removing cart.bin manually, or through the DM menu button 1: Exit.
- Pressing 4: RUN from the DM menu does not disable it.
- Powering off the Vectrex with cart.bin present does not disable Developer Mode.