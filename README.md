# helium-linux

Linux packaging for [Helium Reimplemented](https://github.com/keetsta/helium-reimplemented),
a personal fork of [Helium](https://github.com/imputnet/helium).

## Credits

This repo is based on
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux)
and on [Helium's Linux packaging](https://github.com/imputnet/helium-linux). Thanks to
everyone behind ungoogled-chromium, who made working with Chromium far easier.

## License
All code, patches, modified portions of imported code or patches, and
any other content that is unique to Helium and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).

## Building
To build the binary, run `scripts/docker-build.sh` from the repo root.

The `scripts/docker-build.sh` script will:
1. Create a Docker image of a Debian-based building environment with all
   required packages (llvm, nodejs and distro packages) included.
2. Run `scripts/build.sh` inside the Docker image to build Helium.

Running `scripts/build.sh` directly will not work unless you're running a
Debian-based distro and have all necessary dependencies installed. This repo is
designed to avoid having to configure the building environment on your Linux
installation.

### Native build (Debian host)

If your host already is a Debian trixie system, you can skip Docker entirely.
Run once:

```sh
sudo ./fork-install-deps.sh
```

It installs exactly what `docker/build.Dockerfile` installs (Node 22, the distro
`-dev` packages and sccache), then the `fork-*` scripts below run
`scripts/build.sh` natively. On WSL2, keep the checkout on the native ext4
filesystem (not under `/mnt/*`) — the 9p mount is slow and breaks
case-sensitivity on the Chromium source tree.

### Packaging
After building, run `scripts/package.sh`. Alternatively, you can run
`package/docker-package.sh` to build inside a Docker image. Either of these
scripts will create `tar.xz` and `AppImage` files under `build/`.

If you would like to also generate a .deb file, you can set `MAKE_DEB=1` when
running the release script.

### Development
By default, the build script uses tarball. If you need to use a source tree
clone, you can run `scripts/docker-build.sh -c` instead. This may be useful if
a tarball for a release isn't available yet.

## Fork workflow scripts

For native (non-Docker) development there are convenience wrappers in the repo
root. They keep everything inside `build/` and log to `build/logs/latest.log`.

| Script | What it does |
| --- | --- |
| `sudo ./fork-install-deps.sh` | One-time native install of the Dockerfile's deps (Node 22, `-dev` packages, sccache). |
| `./fork-build [args]` | Full clean **release** build (download → patches → gn → ninja → package). Hours, 100+ GB. Args are forwarded to `scripts/build.sh` (`-c` clone, `--pgo`). Writes `build/.fork-sync-marker`. |
| `./fork-rebuild` | Fast **incremental** rebuild: `gn gen` + `ninja chrome chromedriver` + repackage. Reuses `build/src` and `out/`; does not re-download. |
| `./fork-sync.sh [-r] [-n] [--no-pull]` | Pull new core/platform commits and apply **only the patch delta** to `build/src`, so a quick `fork-rebuild` picks them up. `-r` rebuilds on success; `-n` previews via a read-only fetch. Refuses unsafe deltas (non-patch build-affecting changes, or patches that don't apply cleanly) and tells you to run a full `fork-build`. |

Typical loop: `sudo ./fork-install-deps.sh` → `./fork-build` once; after pushing
core changes from another machine `./fork-sync.sh -r`; for your own patch edits
`./fork-rebuild`.

`fork-build` produces a release build because `flags.linux.gn` already sets
`is_official_build=true`. For a PGO release run `./fork-build -c --pgo` (x86_64
only). Build output (`out/`) is platform-specific and is **not** shareable
across operating systems — the first Linux build always compiles from scratch;
a persistent [sccache](https://github.com/mozilla/sccache) (set `SCCACHE_DIR`
and `SCCACHE_CACHE_SIZE`) is what speeds up later clean rebuilds.

### Artifacts
`fork-build`/`fork-rebuild` call `scripts/package.sh`, which writes
`helium-<version>-<arch>.tar.xz` and a matching `.AppImage` (plus
`.AppImage.zsync`) to `build/release/`. Set `MAKE_DEB=1` to also produce a
`.deb`.
