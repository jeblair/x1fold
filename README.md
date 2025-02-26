# Ubuntu on Thinkpad X1 Fold

This is a guide to installing Ubuntu on the Thinkpad X1 Fold 16.

## What Works

### Touch Screen and Tablet

Both work out of the box with no configuration or adjustments.

### Screen Rotation

Works.

When used as a tablet, the system should automatically rotate between
portrait and landscape.  With the Gnome Shell under Xorg, this works
as expected.  Under Wayland, mutter/clutter looks for a switch to
determine if should operate in tablet mode.  Nothing exposes that
switch out of the box, but we can install a simple daemon to observe
the accelerometers and emulate it.  See below.

### On-Screen Keyboard

Works in Wayland.

This is tied to the tablet mode described in the previous section.  If
Gnome Shell is in tablet mode, then touching an input field will
automatically open the on-screen keyboard (OSK).

Under Xorg, there is a
[bug](https://gitlab.gnome.org/GNOME/mutter/-/issues/3484) that
prevents OSK keypresses from registering.  This bug has been open for
a while and it's not clear there is a lot of motivation for it to be
resolved.

### Bluetooth Keyboard

This works as expected after pairing (see below).

### Sleep

Fold it closed and it goes to sleep.

### Laptop Mode

This doesn't work as it should, but we can get an acceptable
approximation.

Ideally when the screen is folded up part-way and the keyboard placed
on the bottom part of the screen, the computer should enter "laptop
mode" where only the top half of the screen is used.  I have not been
able to find any information about the magnetic sensor that is used
for this, nor have I seen any sign of it in input devices or i2c
sensors.  Therefore I have made a Gnome Shell extension with a quick
setting to manually switch to laptop mode.

Additionally, under Wayland there is no ability to change the screen
geometry to only use the top half of the screen.  Therefore, the Gnome
Shell extension also adds a black panel to the bottom of the screen to
force Gnome to use only the top half.  This works for almost all
applications, with only an occasional dialog from Gnome itself
appearing in the center of the screen, half-obscured by the keyboard.

This works well enough in practice.

## Installation

### Ubuntu Version

Use Noble (24.04), this is the most recent that installs and works
reliably for me.

Oracular (24.10) installed but consistently crashed during boot after
installation.

The Plucky (25.04) installer segfaults as of 2025-02-14.  Hopefully
this will be fixed when the installer snap updates its embedded Gnome
environment.

### Xorg or Wayland

I recommend using Wayland due to the OSK bug.  Installing the
tablet-mode switch daemon is a simple fix for enabling tablet-mode,
which addresses the only downside of Wayland compared to Xorg (at
least as far as using the X1 Fold is concerned).  The OSK bug under
Xorg looks like a showstopper.

### Encryption

During installation, you can (and should!) choose to encrypt the disk,
however, you will need the keyboard plugged in at boot for the first
few boots until we configure the initrd with bluetooth support.

### Keyboard

During installation, keep the keyboard plugged in with the USB cable.
It will need to be paired later, but in the interim, it acts as a
normal USB keyboard when plugged in.

The keyboard is a Bluetooth Low Energy (BLE) device.  The Gnome panel
for Bluetooth pairing does not yet support BLE, so we need to pair it
from the command line.  After installation, run a scan to find the
device id (mac address):

```
$ bluetoothctl
scan le
```

Examine the output to find the MAC address.  My local environment was
quite busy and I found it helpful to use an app on my phone to
identify the keyboard.  Once you have the id (`12:34:56:78:9a:bc` in
this example) enter the following it bluetoothctl:

```
connect 12:34:56:78:9a:bc
```

You should see output like:
```
[CHG] Device 12:34:56:78:9A:BC Connected: yes
[ThinkPad Bl]# Connection successful
[ThinkPad Bl]# Request authorization
[agent] Accept pairing (yes/no): yes
[ThinkPad Bl]# [CHG] Device 12:34:56:78:9A:BC Bonded: yes
[ThinkPad Bl]# [CHG] Device 12:34:56:78:9A:BC Paired: yes
[ThinkPad Bl]# [CHG] Device 12:34:56:78:9A:BC Name: ThinkPad Bluetooth TrackPoint Keyboard
[ThinkPad Bl]# [CHG] Device 12:34:56:78:9A:BC Alias: ThinkPad Bluetooth TrackPoint Keyboard
[ThinkPad Bl]# [CHG] Device 12:34:56:78:9A:BC Modalias: usb:xxxxxxxxxxxxxxx
```

When complete, enter:

```
scan off
```

And exit.

### Installing tablet-mode

This is a simple daemon that watches the accelerometer and exposes a
software tablet-mode switch.  The Gnome Shell under Wayland expects
such a switch to enable auto-rotation and the OSK.

To install, run as root:

```
apt install python3-evdev
wget -O /etc/dbus-1/system.d/org.probos.TabletMode.conf https://github.com/jeblair/x1fold/dbus.conf
wget -O /usr/local/bin/tablet-mode https://github.com/jeblair/x1fold/tablet-mode
chmod a+x /usr/local/bin/tablet-mode
wget -O /etc/systemd/system/tablet-mode.service https://github.com/jeblair/x1fold/tablet-mode.service
systemctl enable tablet-mode
```

### Encryption at Boot

In order for the bluetooth keyboard to work early in the boot process
when prompted for a LUKS passphrase, we need dbus and bluetooth
running from the initrd.  Ubuntu typically uses update-initramfs to
build the initrd image, but that process has no ability to support
dbus and bluetooth.  Many other modern GNU/Linux systems use dracut,
and it can handle this.  Fortunately, Ubuntu appears to be moving
toward dracut, so we can use it today and expect it to be supported in
the future as well.

First, ensure that the keyboard is paired and working under the fully
booted system.

Second, make a backup of the initrd:

```
cp /boot/initrd.img /boot/initrt-back.img
```

Then install dracut and add some configuration options

```
apt install dracut
wget -O /etc/dracut.conf.d/myflags.conf https://github.com/jeblair/x1fold/dracut-flags.conf
mkdir /usr/lib/dracut/modules.d/99local
wget -O /usr/lib/dracut/modules.d/99local/module-setup.sh https://github.com/jeblair/x1fold/dracut-module-setup.sh
chmod a+x /usr/lib/dracut/modules.d/99local/module-setup.sh
```

This configuration tells dracut to use the bluetooth module and start
dbus early (before the prompt to enter the LUKS passphrase.  Dracut
will automatically include the bluetooth pairing configuration since
the keyboard is already paired.

Finally, run dracut and force it to overwrite the existing initrd:

```
dracut --force
```

If something goes wrong, you should be able to use grub to edit the
command line and use the backup initrd.

During boot, it may take a couple of seconds for the keyboard to
establish communication with the computer.  Happily, the keyboard will
buffer many keystrokes during that time, so you may be able to start
entering your LUKS passphrase during this process.
