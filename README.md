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
