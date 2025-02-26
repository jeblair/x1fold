#!/bin/bash

install() {
    sed -i -Ee \
        's/^Wants=sysinit.*/Wants=local-fs.target/' \
        "$initdir$systemdsystemunitdir/dbus.service"
    sed -i -Ee \
        's/^After=sysinit.*/After=local-fs.target/' \
        "$initdir$systemdsystemunitdir/dbus.service"
    sed -i -Ee \
        's/^Wants=sysinit.*/Wants=local-fs.target/' \
        "$initdir$systemdsystemunitdir/dbus.socket"
    sed -i -Ee \
        's/^After=sysinit.*/After=local-fs.target/' \
        "$initdir$systemdsystemunitdir/dbus.socket"
}
