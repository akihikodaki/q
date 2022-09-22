# Q

Q is a quick playground for QEMU instances with a network bridge.

## Linux Test Project

The LTP is designed to test the kernel, but it can also reveal bugs in network
device implementations of QEMU by utilizing several network features like
ICMP, TCP, UDP, multicast, etc, and by stressing the device with real-world
applications like FTP, HTTP, SSH, etc.

## Setting up

1. Set up GNU/Linux.

2. Install slirp4netns and build dependencies of QEMU.

3. Run:

```sh
git clone https://github.com/akihikodaki/q.git
cd q
mkdir var
curl -LO https://download.fedoraproject.org/pub/fedora/linux/releases/36/Silverblue/aarch64/iso/Fedora-Silverblue-ostree-aarch64-36-1.5.iso
git clone -b akihikodaki/igb_sriov_rebase https://github.com/daynix/qemu.git var/qemu
make -C var/qemu
var/qemu/build/qemu-img create root.img 64G
./d
```

The last `./d` runs the server program that provides a network environment.

4. Open another terminal and run:

```sh
cd q
./x virtio-net -cdrom Fedora-Silverblue-ostree-aarch64-36-1.5.iso
```

Continue installing Fedora.

5. On the guest, run:

```sh
rpm-ostree upgrade
rpm-ostree install -r automake bind dhcp-server expect ftp gcc iproute-tc make net-tools rusers rusers-server tcpdump telnet telnet-server traceroute vsftpd
```

This reboots the guest.

6. On the guest, run:

```sh
git clone https://github.com/akihikodaki/ltp.git -b aki
cd ltp
./build.sh -i
sudo nmcli modify 'Ethernet 1' ipv6.addr-gen-mode 0
sudo passwd --stdin root <<< password
sudo mkdir /root/.ssh
sudo tee /root/.ssh/config <<< 'StrictHostKeyChecking no'
sudo tee /root/.ssh/id_ed25519.pub <<< 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXBrKSRDUiHhTAzGdqcWlny2XiPXEXA7U1WxsZWCZiI'
sudo cp /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys
sudo cp /usr/lib/systemd/system/telnet.socket /etc/systemd/system/telnet-i.socket
sudo cp /usr/lib/systemd/system/telnet@.service /etc/systemd/system/telnet-i@.service
systemctl enable httpd rstatd rusersd sshd telnet-i.socket vsftpd
```

7. Append ` -i` to `ExecStart` in `/etc/systemd/system/telnet-i@.service`.

telnet hangs when connecting from remote without this change.

8. On the guest, comment out `listen=NO` and `listen_ipv6=YES` in
   `/etc/vsftpd/vsftpd.conf`.

FTP hangs when logging in from remote without this change.

9. On the guest, comment out `root` in `/etc/vsftpd/ftpusers`.

10. On the guest, comment out `root` in `/etc/vsftpd/user_list`.

11. On the host, open another terminal, run:

```
cd q
./e scp etc/ssh/id_ed25519 10.0.2.15:.ssh
```

11. On the guest, run:

```
sudo chmod -R go-rwx /root/.ssh
systemctl poweroff
```

## Running

1. Open two terminals and run the following for each:

```
cd q
./x virtio-net -snapshot
```

2. On the first guest, run:

```
cd ltp-install/testscripts
sudo IPV4_LHOST=10.0.2.15/24 IPV4_RHOST=10.0.2.16/24 IPV6_LHOST=fd00::ff:fe00:0/64 IPV6_RHOST=fd00::ff:fe00:1/64 LHOST_IFACES=enp0s1 PASSWD=password RHOST=10.0.2.16 RHOST_IFACES=enp0s1 ./network.sh -6mrta
```
