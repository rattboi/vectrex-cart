LED Test v1.1
===

This app tests the LED controls between Vectrex games and the VEXTREME cart.

This application demonstrates how to control the addressable LEDs
by seeding $7ff0 through $7ff9 with the LED colors, then calling
RPC function ID 7 (updateMulti) which writes out the data to all LEDs

### LED Colors

0 = off
1 = red
2 = orange
3 = yellow
4 = green
5 = cyan
6 = blue
7 = pink
8 = magenta
9 = white (Try not to use this one... it kind of draws a lot of power!)

### HW and SW Version

Also demonstrates the Hardware and Software Version RPC function ID 9
Which reads HW version HI:LO into $7ffc:$7fffd
     ...and SW verison HI:LO into $7ffe:$7ffff
This can be used to know how many LEDs are expected on the VEXTREME PCB this
game is running on, or other info that might be useful in a programatic way.
This app converts the values to strings to display, but the comparison would
be much easier to check for different types of boards and software revisions.

Press up on the Analog Joystick to control the LEDs and sound output.
