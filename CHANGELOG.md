# Changelog

## v0.2

- Replaced USB-B-mini with USB-C and centered USB on cart
- Extended the PCB by 1.7 mm to get the USB-C connector as close to the case exterior as possible.
- Widened the PCB to 48.0 mm so that there’s less side to side play in the cartridge slot.
- Moved outer mounting holes into the proper locations
- Reversed D3 and R4 order to get D3 closer to edge of the PCB, but it turned out we added something else there!
- Added 10 APA102-2020 addressable RGB LED lights (max. draw 245mA) … qualify with USB-IN (PA9) for 100% brightness, else 50%
- Added 47uF cap for peak currents required for RGB LEDs.
- Added V-IRQ connection to PB9 for 128KB bank-switching
- Grounded unused floating inputs on U3 to reduce current consumption
- Adjusted Y1 to use 12pF load crystal resonator with 18pF load caps (see equation)
- Lots of clean up and tweaking all over PCB
- Added revision to PCB
- Added “VEXTREME” to PCB
- Added a ground pour under the STM32
- Made the contacts on the edge connector thinner (1.52mm) and made sure they were spaced properly (2.54mm).
- Started moving footprints to the libs/veccart.pretty library so you know where they will be!

## v0.1

- Mostly unchanged from Sprite_tm's original HW/SW design
- Mostly unchanged from Rattboi's original PCB design
- fixes error opening PCB with latest KiCaD
- add gerbers for easy PCB ordering at many places
- update README.md and add LICENSE
- fixes premature automatic reset delay on GCE Vectrex
- fixes menu builder missing filename in path
- pretty up the menu by removing the .BIN file extension, and other cleanup
- let's call it the VEXTREME cart, for now. (original name was EXTREME)
