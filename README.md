# afkick

Fix webcams whose autofocus never engages until vendor software pokes them.

## TL;DR

Some external UVC webcams, notably the 4K camera built into the **Dell
U3223QZ** video-conferencing monitor, report autofocus as *enabled* but never
actually run a focus scan when Zoom, Teams, Chime, or a browser opens the
stream. The image stays blurry until Dell's own app (DDPM / Dell Peripheral
Manager) touches the camera. `afkick` removes that dependency: it watches for
the camera to start streaming and toggles the UVC auto-focus control to wake
the lens, automatically.

```
without afkick:                        with afkick:

Zoom opens camera                      Zoom opens camera
      |                                      |
      v                                      v
firmware: AF "on" but idle             afkick sees stream start
image stays blurry                           |
      |                                      v
      v                                toggles UVC auto-focus off/on
you open Dell's app by hand                  |
image snaps into focus                       v
                                       image snaps into focus (~2s)
```

## Why this happens

The camera's focus logic idles until it receives a UVC
`CT_FOCUS_AUTO_CONTROL` write. Dell's desktop software re-applies camera
settings whenever the device changes state, which is what "fixes" it: the
camera platform effectively outsources its autofocus wake-up to host
software. On a Mac without DDPM running (or when DDPM doesn't notice the
stream), nothing sends that write, so the lens sits at its parked position.
No Dell monitor firmware to date (through M2T107, Apr 2025) changes this
behavior. `afkick` sends the same wake-up write the vendor app would.

## Install

```sh
git clone https://github.com/lzongren/afkick.git
cd afkick
swift build -c release
sudo cp .build/release/afkick /usr/local/bin/
```

Requires macOS 13+ and Swift 6 (Xcode or Command Line Tools).

## Usage

```sh
# see your cameras and their streaming state
afkick list

# kick autofocus once, right now
afkick kick --camera Dell

# watch in the foreground (Ctrl-C to stop)
afkick watch --camera Dell

# install as a login agent, runs in the background from now on
afkick install --camera Dell

# remove the agent
afkick uninstall
```

`--camera` is a case-insensitive substring match against the camera name, so
`--camera Dell`, `--camera U3223QZ`, and `--camera "Dell U3223QZ Webcam"` all
work. Default is `Dell`.

Tuning knobs on `watch`:

| Flag | Default | Meaning |
|---|---|---|
| `--delay` | 1.5 | seconds after stream start before kicking (lets exposure settle) |
| `--debounce` | 3.0 | minimum seconds between kicks (avoids focus hunting when apps flap the device) |

Logs go to `~/Library/Logs/afkick.log` when installed as an agent.

## How it works

```
CoreMediaIO                          UVC (USB Video Class)
kCMIODevicePropertyDeviceIsRunningSomewhere
      |                                    |
      v                                    v
afkick watch -- stream started -->  toggle CT_FOCUS_AUTO_CONTROL
                (delay, debounce)     off, 300ms, on
                                           |
                                           v
                                   firmware restarts AF scan
```

Two details worth knowing if you're building something similar:

- **AVFoundation's `isInUseByAnotherApplication` does not fire KVO for
  external UVC cameras.** CoreMediaIO's `DeviceIsRunningSomewhere` property
  listener is the one that works.
- The UVC control plumbing (`Sources/UVCKit`) is vendored from
  [jtfrey/uvc-util](https://github.com/jtfrey/uvc-util) (MIT), lightly
  reorganized into an SPM target.

## Will this work for my non-Dell camera?

If your camera goes sharp the moment you open the vendor's tuning app but is
blurry in every meeting app, it very likely has the same
firmware-waits-for-a-poke behavior. Try `afkick kick --camera <name>` while
streaming and see if it snaps into focus. If it does, `afkick install` and
forget about it.

## Development

```sh
swift test        # unit tests (policy state machine, matching, plist rendering)
swift build       # debug build
```

The core logic (`AFKickCore`) is hardware-free and fully unit-tested; the
executable target wraps it with CoreMediaIO and UVC I/O.

## License

MIT. Vendored `UVCKit` sources are MIT (c) 2016 Jeffrey Frey (see
`Sources/UVCKit/LICENSE-uvc-util`).
