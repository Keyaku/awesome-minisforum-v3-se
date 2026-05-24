# Linux — Camera

## Facial Recognition

The IR camera works with [howdy](https://github.com/boltgolt/howdy). Fedora-based distros can install [howdy-beta](https://copr.fedorainfracloud.org/coprs/principis/howdy-beta/) via Copr.

Set `device_path` in `/etc/howdy/config.ini` to `/dev/video3`.

> [!NOTE]
> Some units expose the IR sensor as `/dev/video2` instead. Check `v4l2-ctl --list-devices` if `/dev/video3` is not the IR stream.

_Credits to Tsuki4735._
