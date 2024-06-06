# sisp51

*sisp51* (System-Independent SST Programmer) is an AT89C51RB2-based programmer for SST39SF010/SST39SF020/SST39SF040 parallel flash memories.

---

**Features**
* doesn't require any special program on host side - only an RS-232 terminal
* writing in multiples of 1024 bytes
* dumping memory contents in hexadecimal
* erasing by sector
* in-system flashing of the microcontroller

**Planned features**
* reading memory contents as binary data
* automatic verification after writing
* a PCB design

---

## Usage
To use this circuit, put the Flash memory IC in the ZIF socket, connect the RS-232 port to an RS-232 terminal, which is set to 9600 baud, 8-bit characters and 1 stop bit and then supply power to the power connector. The terminal will display a command line with a greeting message and command list:
```
sisp51 v1.0
Commands:
E - erase sector
W - write memory
R - read memory
>
```
The commands are single letters - type a letter in the terminal to execute a command.

### Reading memory
The "R" command asks the user for an address to read from and how many bytes to read, then it prints the bytes in hexadecimal.

This command asks for a 20-bit address (5 hexadecimal digits), but the SST39 flash memories only go up to a 19-bit address bus - 1 to 3 most significant bits are ignored depending on the size of the memory in the socket. Addresses above 7FFFF (which are outside of the 19-bit address space) may not be handled correctly.

This command can read from 1 byte up to 256 bytes (00-FF). To read 256 bytes, input 00 when asked for the byte count.

### Writing memory
The "W" command asks for an address to write to and then writes exactly 1024 bytes sent over the serial port. This command **does not erase anything** - if a byte wasn't erased before, it will not be overwritten. Erasing sets the bytes to FF, so bytes which are FF are skipped. Writing only begins after answering a confirmation prompt.

### 64 KB boundaries
The "R" and "W" commands **cannot go past 64 KB boundaries** - for example, reading 3 bytes from 0FFFF will read from 0FFFF, 00000 and 00001 instead of 0FFFF, 10000 and 10001. To avoid this, starting writing at 1024 B boundaries is recommended.

### Erasing a sector
The "E" command asks for an address to erase a sector at. A sector is 4096 bytes, so 12 least significant bits of the address are ignored. After erasing a sector, all bytes in it can be written to again. Erasing only begins after answering a confirmation prompt.

---

## Resetting and in-system programming
The RESET push button can be used to reset the microcontroller in case something goes wrong. Pressing it while holding the PRGM button will boot the microcontroller in in-system programming mode, which allows flashing microcontroller software (not the flash memory) over the serial port.

## Compiling and flashing
The software for this programmer is written in 8051 assembly - to compile, type:
```
asem51 main.a51 sisp51.hex
```
with the [ASEM-51](https://www.plit.de/asem-51/) assembler installed.

After compiling, boot the circuit in in-system programming mode and use any AT89C51RB2 flashing software to flash the HEX file.

---

## FAQ

### Can I use a generic 8051?

No, as the code uses dual DPTR and 1024 bytes of internal XRAM. I might do a generic 8051 port in the future.

### How do I flash more than 1024 bytes?

Split the data you want to flash into 1024-byte binary files on the host computer. The ASEM-51 assembler includes a tool called hex2bin which can split HEX files into binary files. Flashing a lot of files can be automated with a script.

### How do I flash less than 1024 bytes?

The writing routine skips bytes which are 0xFF, so pad out the binary file with 0xFF.

