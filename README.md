# ascii-rotator

Reads an 24x80 ascii-encoded text file called "image.txt" and spins it around.

Written in AArch64 assembly.

## Build and run

```sh
aarch64-linux-gnu-gcc -o main main.s -lm
qemu-aarch64 -L /usr/aarch64-linux-gnu/ ./main
```
