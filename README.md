# Q

Q is a quick playground for QEMU instances with a network bridge.

## Linux Test Project and DPDK Test Suite

The LTP is designed to test the kernel, but it can also reveal bugs in network
device implementations of QEMU by utilizing several network features like
ICMP, TCP, UDP, multicast, etc, and by stressing the device with real-world
applications like FTP, HTTP, SSH, etc.

DPDK Test Suite tests DPDK. As DPDK exercises many hardware features, it can
cover wide features.

### Setting up

1. Set up GNU/Linux.

2. Install mkosi and build dependencies of QEMU.

3. Run:

```sh
git clone https://github.com/akihikodaki/q.git
cd q
mkdir -p var/results
cd var
git clone -b v8.2.1 https://gitlab.com/qemu-project/qemu.git
cd qemu
./configure
make
cd ..
git clone https://gitlab.freedesktop.org/akihiko.odaki/fontconfig
meson setup fontconfig-build fontconfig
meson compile -C fontconfig-build
```

### Running

Run `./t igb`

### Notes on t

#### Not running RPC tests

RPC tests are excluded because it was found they are not working properly. See:
https://github.com/linux-test-project/ltp/issues/621

### clockdiff error with igb loopback

It is likely to be a bug of clockdiff fixed with:
https://github.com/iputils/iputils/pull/380
