# quickgreet

A [greetd](https://sr.ht/~kennylevinsen/greetd/) greeter built on
[Quickshell](https://quickshell.org), styled after Material 3.

Wallpaper background with configurable blur, per-user avatars, a session
picker, live keyboard layout and Caps Lock indicators, and power controls.
Colours are read from a Material You style scheme file, so the login screen
can match the desktop it leads into.

## Status

Working and in daily use, but young. The protocol layer is complete
(authentication, session selection, cancellation); expect rough edges
elsewhere. Issues and patches welcome.

## Requirements

- `greetd`
- `quickshell` — the git build; tagged releases are too old
- `python3` — for the protocol bridge and the session/user enumerators
- `Hyprland` — as the greeter's compositor (see [Why Hyprland](#why-hyprland))
- Fonts: **Rubik** and **Material Symbols Rounded**

On Arch:

```sh
pacman -S greetd hyprland python
yay -S quickshell-git ttf-material-symbols-variable ttf-rubik-vf
```

## Install

```sh
git clone https://github.com/USER/quickgreet
cd quickgreet
sudo ./install.sh
```

This installs the QML to `/usr/share/quickgreet`, the helper scripts to
`/usr/lib/quickgreet`, and an example configuration to `/etc/quickgreet`.
It does **not** switch your display manager — see below.

### Switching over

Point greetd at the greeter:

```toml
# /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "/usr/lib/quickgreet/run-greeter.sh"
user = "greeter"
```

Then swap display managers:

```sh
sudo systemctl disable --now sddm      # or gdm, plasmalogin, ...
sudo systemctl enable --now greetd
```

**Test before you commit to this.** A broken greeter means no graphical
login. Run greetd on a spare VT first, with your current display manager
still in charge:

```sh
sudo cp /etc/quickgreet/greetd-test.toml /tmp/
sudo greetd --config /tmp/greetd-test.toml   # binds vt 7
```

Switch to it with `Ctrl+Alt+F7` and log in for real. If that works, make it
permanent. Make sure your console keymap can type your password —
`KEYMAP=` in `/etc/vconsole.conf` — or recovery from a text console will be
impossible.

## Configuration

`/etc/quickgreet/config.json`, every key optional:

| Key | Default | Meaning |
|---|---|---|
| `locale` | `"en"` | `en`, `ru`, or `auto` to follow the system |
| `wallpaper` | `""` | Background image; empty means a solid colour |
| `blur` | `0.85` | Background blur, 0–1 |
| `dim` | `0.72` | Background dimming, 0–1 |
| `schemePath` | `/etc/quickgreet/scheme.json` | Colour scheme |
| `defaultSession` | `""` | Session id preselected, e.g. `hyprland` |
| `defaultUser` | `""` | Username preselected |
| `showPowerButtons` | `true` | Show suspend/reboot/shutdown |
| `timeFormat` | `"HH:mm"` | Qt time format |
| `dateFormat` | `"dddd, d MMMM"` | Qt date format |

### Colours

`scheme.json` uses the Material You shape:

```json
{
  "mode": "dark",
  "colours": {
    "background": "101418",
    "onSurface": "e0e2e8",
    "primary": "a3c9e9"
  }
}
```

Keys may be prefixed with `#` or not. Anything absent falls back to a
built-in neutral palette, so a partial file is fine.

`scripts/gen-scheme.py` builds one from an image, so the login screen can
be derived from its own wallpaper:

```sh
sudo /usr/lib/quickgreet/gen-scheme.py /etc/quickgreet/wallpaper.jpg \
     > /etc/quickgreet/scheme.json

gen-scheme.py --light --variant vibrant image.png   # other options
```

Variants: `tonalspot` (default), `vibrant`, `expressive`, `fidelity`,
`content`, `monochrome`, `neutral`, `rainbow`, `fruitsalad`. Needs
`python-materialyoucolor` and `python-pillow`; both are optional
dependencies, everything else works without them.

The format is the same shape
[caelestia](https://github.com/caelestia-dots/shell) generates, so its
schemes can be dropped in directly:

```sh
sudo cp ~/.local/state/caelestia/scheme.json /etc/quickgreet/scheme.json
```

Note that its seed colour selection differs from `gen-scheme.py`, so the
same wallpaper can yield noticeably different palettes. quickgreet is not
affiliated with that project and does not depend on it.

### Avatars

Looked up in order, first readable wins:

```
/var/lib/AccountsService/icons/$USER
/var/lib/kdm/faces/$USER.face.icon
~/.face
~/.face.icon
```

The greeter runs as an unprivileged user, so a file inside a home
directory may not be readable — the `/var/lib` paths are the reliable
ones. Without any of them, the account's initial is drawn instead.

## Development

```sh
./test.sh          # mock mode, password "test"
./test.sh -k       # stop it
```

Mock mode runs the full UI and the entire protocol state machine against a
simulated greetd, in an ordinary window inside your current session. No
authentication happens and nobody is logged in.

Drop a `config/config.dev.json` in the checkout to point at your own
wallpaper and scheme; it is gitignored and takes precedence over the
example.

### Why Hyprland

The keyboard layout belongs to the compositor and no Wayland client can
read or change it on its own. Under Hyprland the greeter subscribes to the
event socket for live layout updates and switches via `hyprctl`. Under a
plain kiosk compositor such as `cage` everything else works, but the layout
badge falls back to counting Alt+Shift itself and clicking it does nothing.

### Layout

```
qml/      shell.qml and components; this is the Quickshell config root
scripts/  greetd bridge, session and user enumerators, greeter launcher
config/   example config, greetd and Hyprland samples
contrib/  PKGBUILD, polkit rules
```

## Notes

**Power buttons** call `systemctl`. greetd's user usually has polkit
permission for this; if the buttons do nothing, install
`contrib/polkit/10-quickgreet-power.rules`.

**greetd framing** is a 4-byte native-endian length followed by JSON.
Quickshell's `Socket` splits on delimiters and cannot read that, which is
why `scripts/greetd-bridge.py` exists: line-delimited JSON on one side,
greetd's framing on the other.

**Two cursors**, one lagging behind the other, mean a cursor theme is
named but not installed — the compositor falls back to a built-in pointer
while clients keep drawing their own. `run-greeter.sh` picks a theme that
actually exists on the machine, which is why greetd runs it rather than
Hyprland directly. If you see this inside your *desktop* session, check
whatever sets `XCURSOR_THEME` there against `ls /usr/share/icons/*/cursors`.

**Testing while already logged in** has limits worth knowing before you
blame the greeter. The test VT must be genuinely free — `loginctl
list-sessions` shows which are taken — or logind refuses the login with
`VirtualTerminalAlreadyTaken` and greetd simply restarts the greeter,
which looks exactly like a rejected password. Starting a *second*
concurrent session for a user who is already logged in also fails with
session managers that use systemd user units, `uwsm` among them; pick the
plain compositor session from the dropdown for that test. Neither applies
at a real boot.

## Licence

MIT. See [LICENSE](LICENSE).
