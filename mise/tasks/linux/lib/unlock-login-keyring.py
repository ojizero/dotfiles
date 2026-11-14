#!/usr/bin/env python3
"""Unlock the GNOME login keyring in the running gnome-keyring-daemon.

Remote helper for linux:unlock. On this host the login keyring password is
the LUKS disk passphrase. GDM autologin unlocks the keyring only while
systemd-cryptsetup still caches that passphrase in the kernel keyring. When
the cache has expired, the keyring stays locked.

This script uses gnome-keyring's own D-Bus method UnlockWithMasterPassword,
so no unlock prompt opens in GNOME. The passphrase is read from the terminal
and goes only to the daemon on the user's session bus. It is never put in
argv, in the environment, or in a file.

Do not use `gnome-keyring-daemon --unlock` for this. It unlocks only a daemon
that it starts itself, and it can start a second daemon.

Exit status: 0 when the login keyring is unlocked, 1 when it is locked.
"""
import getpass
import sys

from gi.repository import Gio, GLib

BUS_NAME = 'org.freedesktop.secrets'
SERVICE = '/org/freedesktop/secrets'
LOGIN = '/org/freedesktop/secrets/collection/login'
ATTEMPTS = 3

bus = Gio.bus_get_sync(Gio.BusType.SESSION)


def call(path, interface, method, args=None, reply=None):
    return bus.call_sync(BUS_NAME, path, interface, method, args,
                         GLib.VariantType(reply) if reply else None,
                         Gio.DBusCallFlags.NONE, -1, None)


def locked():
    args = GLib.Variant('(ss)', ('org.freedesktop.Secret.Collection', 'Locked'))
    return call(LOGIN, 'org.freedesktop.DBus.Properties', 'Get', args, '(v)').unpack()[0]


def unlock(password):
    # The daemon finds the session by the caller's connection, so the session
    # and the unlock call must use the same connection (this process).
    _, session = call(SERVICE, 'org.freedesktop.Secret.Service', 'OpenSession',
                      GLib.Variant('(sv)', ('plain', GLib.Variant('s', ''))), '(vo)').unpack()
    try:
        call(SERVICE, 'org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface',
             'UnlockWithMasterPassword',
             GLib.Variant('(o(oayays))', (LOGIN, (session, b'', password, 'text/plain'))))
    except GLib.Error as error:
        print(f'gnome-keyring: {error.message}', file=sys.stderr)
    finally:
        call(session, 'org.freedesktop.Secret.Session', 'Close')


def main():
    if not locked():
        return 0
    print('The login keyring is locked. Its password is the LUKS disk passphrase.')
    for _ in range(ATTEMPTS):
        unlock(getpass.getpass('LUKS disk passphrase: ').encode())
        if not locked():
            return 0
        print('That passphrase did not unlock the login keyring.', file=sys.stderr)
    return 1


try:
    sys.exit(main())
except GLib.Error as error:
    sys.exit(f'Cannot read or unlock the login keyring: {error.message}')
