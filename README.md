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
mkdir -p var/results
cd var
curl -LO https://download.fedoraproject.org/pub/fedora/linux/releases/36/Silverblue/x86_64/iso/Fedora-Silverblue-ostree-x86_64-36-1.5.iso
git clone -b akihikodaki/igb_sriov_rebase https://github.com/daynix/qemu.git
cd qemu
./configure
make
cd ..
qemu/build/qemu-img create root.img 64G
cd ..
./d
```

The last `./d` runs the server program that provides a network environment.

4. Open another terminal and run:

```sh
cd q
./x virtio-net -cdrom Fedora-Silverblue-ostree-aarch64-36-1.5.iso
```

Continue installing Fedora. Answer `person` if you asked for a username.

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
sudo nmcli modify 'Ethernet 1' connection.multi-connect 8
sudo passwd --stdin root <<< password
sudo mkdir /root/.ssh
sudo tee /root/.ssh/config <<< 'StrictHostKeyChecking no'
sudo tee /root/.ssh/id_ed25519.pub <<< 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXBrKSRDUiHhTAzGdqcWlny2XiPXEXA7U1WxsZWCZiI'
sudo cp /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys
sudo mkdir /etc/systemd/system/telnet@.service.d
sudo tee /etc/systemd/system/telnet@.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/sbin/in.telnetd -i
EOF
systemctl disable chronyd
systemctl enable httpd rstatd rusersd sshd telnet.socket vsftpd
```

7. On the guest, comment out `listen=NO` and `listen_ipv6=YES` in
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

The first guest will be the test subject.

2. Run `./t`
