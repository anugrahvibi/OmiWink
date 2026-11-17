# OmaPeek

OmaPeek is a tiny Omarchy bar face with eyes that follow your cursor. It blinks and makes occasional idle glances, too.

## Install

OmaPeek requires Omarchy's Quattro shell, Hyprland, and Python 3. After the repository is public, install it with:

```sh
omarchy plugin add https://github.com/anugrahvibi/omapeek.git --enable
```

To remove it, disable and remove the plugin:

```sh
omarchy plugin disable anugrahvibi.omapeek
omarchy plugin remove anugrahvibi.omapeek
```

OmaPeek adds no services, packages, or privileged commands. Removing the plugin removes its files.

## How it works

The bar widget runs one small Python process on the primary display. It reads cursor coordinates from the current Hyprland session's local IPC socket and sends them to the QML face. It samples at 8 Hz while idle and up to 60 Hz briefly after pointer movement. Omarchy's idle monitor pauses the reader when the session is idle. The plugin does not send data over the network or store cursor history.

Omarchy plugins run with your user permissions and are not sandboxed. OmaPeek uses the Omarchy shell APIs and the current user's Hyprland IPC socket. It does not request elevated privileges.

## Validate

Run these commands from the repository root on Omarchy:

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml
```
