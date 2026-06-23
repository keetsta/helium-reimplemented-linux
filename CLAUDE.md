# Helium Reimplemented — Linux packaging (рабочий брифинг)

Это **личный форк** (владелец — keetsta). Репо отвечает за **Linux-упаковку**: тянет
кросс-платформенный core (`helium-chromium`, submodule), качает Chromium, накладывает
патчи и собирает `tar.xz` + `AppImage` (опц. `.deb`). Core и фичи описаны в
`helium-chromium/CLAUDE.md` — здесь только Linux-специфика.

## Два способа собрать

1. **Docker** (как задумано upstream, для не-Debian хостов): `scripts/docker-build.sh`
   собирает образ `chromium-builder:trixie-slim` из `docker/build.Dockerfile` и гоняет
   `scripts/build.sh` внутри с bind-mount репо как `/repo`.
2. **Нативно** (если хост — Debian trixie): `sudo ./fork-install-deps.sh` ставит ровно то,
   что ставит Dockerfile (Node 22 + dev-пакеты + sccache), затем `fork-*` скрипты гоняют
   `scripts/build.sh` напрямую — без Docker, без bind-mount. Так быстрее итерации.

`fork-*` скрипты рассчитаны на **нативный** путь.

## Раскладка

Никакого contained-toolchain (в отличие от macOS-репо): используются системные тулзы,
тулчейн Chromium (clang/rust) на x64 скачивается prebuilt в `build/src`.

```
helium-reimplemented-linux/      ← этот репо, fork-* и flags.linux.gn в корне
  helium-chromium/               ← core submodule (keetsta/helium-reimplemented, detached)
  scripts/                       ← build.sh, shared.sh, package.sh, docker-build.sh, dev.sh
  patches/                       ← платформенные патчи + series
  build/                         ← src, download_cache, release/, logs/  (git-ignored)
    src/out/Default/             ← args.gn + объекты (per-platform, НЕ переносимы между ОС)
    release/                     ← tar.xz + AppImage
    .fork-sync-marker            ← core+platform SHA, под которые накатано build/src
```

**Важно (WSL):** репо обязано лежать в нативной ext4, не на `/mnt/*` (9p медленный +
ломает case-sensitivity на ~400k файлов Chromium). `out/` **не переносится между ОС**
(ELF vs COFF vs Mach-O, разные тулчейны) — первый Linux-билд всегда с нуля по компиляции;
ускоряет только sccache (Linux↔Linux).

## Скрипты (все в корне репо)

- **`fork-install-deps.sh`** — разовая нативная установка зависимостей из
  `docker/build.Dockerfile` (Node 22 nodesource, dev-пакеты, sccache). Нужен root. На x64
  пропускает `cmake/clang/lld` (Chromium тянет prebuilt clang).
- **`fork-build [args]`** — полная чистая RELEASE-сборка (download → patches → gn → ninja
  `chrome chromedriver` → `package.sh`). Часы, 100+ ГБ. `flags.linux.gn` уже
  `is_official_build=true`. Аргументы форвардятся в `scripts/build.sh`:
  - `./fork-build` — tarball-путь (быстрее стартовать);
  - `./fork-build -c` — через source-clone;
  - `./fork-build -c --pgo` — PGO release (только x64).
  Кросс-арч: `ARCH=arm64 ./fork-build`. **Пишет маркер** `build/.fork-sync-marker` после
  успешной сборки — единственный честный источник маркера.
- **`fork-rebuild`** — инкрементально: `gn gen` + `ninja chrome chromedriver` +
  `package.sh`. Минуты. НЕ перекачивает и НЕ вайпает `out/`. Требует готовое `build/src`.
- **`fork-sync.sh [-r|--rebuild] [-n|--dry-run] [--no-pull]`** — pull core/platform и занос
  **только дельты патчей** в `build/src` (реверс старого патча → форвард нового). `-r` —
  затем `fork-rebuild`. `-n` — превью через read-only `git fetch` (дерево не трогает). При
  небезопасной дельте (рискованные не-патчевые изменения: `deps.ini`, `*.list`, `*.gn`,
  ресурсы, `patches/series`; либо патч не лёг чисто) — отказ с советом `fork-build`. Дерево
  никогда не остаётся полупропатченным (бэкап + restore). Ручного «проставить маркер» НЕТ —
  честный маркер только из чистого `fork-build`.

Цикл: один раз `sudo ./fork-install-deps.sh` → `./fork-build`; после пуша core с другой
машины — `./fork-sync.sh -r`; правки своих патчей — `./fork-rebuild`.

## Артефакты

`scripts/package.sh` (вызывается из `fork-build`/`fork-rebuild`) кладёт в `build/release/`:
`helium-<version>-<arch>.tar.xz` **и** `.AppImage` (+ `.AppImage.zsync`). `.deb` — только при
`MAKE_DEB=1`. Версия и `target_cpu` берутся из `helium_version.py` и `out/Default/args.gn`.

## sccache

`scripts/shared.sh:write_gn_args` дописывает `cc_wrapper="sccache"`, **если** `sccache` в
PATH **и** задана любая `SCCACHE_*` переменная. Persistent-кэш настраивается через
`SCCACHE_DIR`/`SCCACHE_CACHE_SIZE` в окружении. Кэш per-platform → ускоряет только
Linux-пересборки, не кросс-ОС.

## Двухуровневый git

Core — submodule `helium-chromium` (форк `keetsta/helium-reimplemented`, detached HEAD на
запиненном коммите). Правки патчей core коммить в submodule на `main` и пушить, затем здесь
`git add helium-chromium` (бамп указателя) + коммит + пуш. Платформенные патчи — в
`patches/` этого репо.

> Личный форк, не для upstream.
