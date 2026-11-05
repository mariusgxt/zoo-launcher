<p align="center">
  <img src="docs/media/banner.svg" alt="zoo: Minecraft: Java Edition, rewritten in Goose" width="100%">
</p>

<p align="center">
  <a href="https://github.com/mariusgxt/zoo-launcher/actions/workflows/ci.yml"><img src="https://github.com/mariusgxt/zoo-launcher/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Goose-v2026.3-E2A84A" alt="Goose v2026.3">
  <img src="https://img.shields.io/badge/Minecraft-Java%2026.3-5D9C3F" alt="Minecraft Java 26.3">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-2A2470" alt="Windows, Linux and macOS">
  <img src="https://img.shields.io/badge/specimen-Panthera%20leo-7A3F1C" alt="Current specimen: Panthera leo">
</p>

<p align="center">
  <a href="#download"><b>Download</b></a> ·
  <a href="#what-works-today"><b>What works today</b></a> ·
  <a href="#roadmap"><b>Roadmap</b></a> ·
  <a href="#build-from-source"><b>Build from source</b></a> ·
  <a href="#versioning-the-specimen-label"><b>Versioning</b></a> ·
  <a href="#modding"><b>Modding</b></a>
</p>

# zoo

zoo is Minecraft: Java Edition rebuilt in [Goose](https://aardappel.github.io/goose/), a memory-safe systems language with no heap allocator and no garbage collector. It follows the path [Horizon](https://github.com/horizon-rust/horizon) took in Rust: a native game that reads the same worlds and plays by the same rules, started through a small launcher that prepares the game's files from your own copy of Minecraft.

This repository holds both. The launcher works today. The zoo client is being built in stages, starting with a world viewer.

> Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft. zoo contains no Minecraft code, assets or data: you need your own legally obtained copy of Minecraft: Java Edition.

<p align="center">
  <img src="docs/media/launcher.png" alt="The zoo launcher: the version list on the left, the selected version and its preparation on the right" width="80%">
</p>

## Download

Builds for Windows x64 and Linux x86-64 are attached to each [release](https://github.com/mariusgxt/zoo-launcher/releases). Unpack the archive and start `zoo-launcher` (`zoo-launcher.exe` on Windows). Nothing else needs to be installed.

**You need** a copy of Minecraft: Java Edition. If the official launcher has already installed a version, zoo uses that jar directly. Otherwise zoo downloads the client jar from Mojang and checks its SHA-1 before using it.

## What works today

- **Version list:** Mojang's version manifest, merged with the versions in your `.minecraft` folder. The list is cached, so it still fills offline.
- **Preparation:** zoo takes the textures, models, block states, atlases, fonts and English names out of the client jar and stores them in its collection folder (`%APPDATA%\zoo` on Windows, `~/.local/share/zoo` on Linux, `~/Library/Application Support/zoo` on macOS). A prepared version is skipped on the next start until its jar changes.
- **Written in Goose:** SHA-1, DEFLATE and zip reading are plain Goose, with no zlib or OpenSSL behind them. The only C is the network door (WinHTTP on Windows, libcurl elsewhere) and a platform probe.
- **A window that stays responsive:** downloads and unpacking run on a worker thread and report back through Goose's typed queues.

## Roadmap

| Stage | Goal | State |
|---|---|---|
| 1 | Launcher with a GUI: versions, download, checks, resource preparation | working |
| 2 | Zoo client, first look: open a singleplayer world (Anvil, NBT) and render its chunks with the real textures, free camera | next |
| 3 | Playable: player physics and collision, breaking and placing blocks, saving, HUD | planned |
| 4 | The long road, in Horizon's order: world generation, mobs, redstone, multiplayer protocol, comparison tests against vanilla | planned |
| - | Microsoft account sign-in, several instances, a mod and pack browser | planned |

## Build from source

You need the Goose compiler built with its graphics packages, CMake and a C compiler (MSVC 2022 or clang on Windows, gcc or clang elsewhere). On Linux, libcurl's development files and SDL's X11 or Wayland packages are needed too.

```sh
git clone --branch v2026.3 https://github.com/aardappel/goose
cmake -S goose -B goose/build -DCMAKE_BUILD_TYPE=Release -DGOOSE_BUILTIN_LIBS=all
cmake --build goose/build --config Release

goose build zoo.goose        # builds ./zoo-launcher
goose tests.goose            # runs the tests
```

The tests use fixtures in `test/data` (a stand-in jar with no Mojang content, made by `test/make_fixtures.py`). The download tests need a local server and skip themselves without one:

```sh
(cd test/data && python3 -m http.server 8765) &
goose tests.goose
```

`ZOO_HOME` moves the collection folder and `ZOO_MANIFEST_URL` points the version list at a mirror. `zoo-launcher --frames 30 --select 26.3 --prepare` runs without input and saves the last frame as `zoo.png`, which is how the screenshot above was taken.

### Layout

```
zoo.goose              the launcher's entry point
zoo/app/               window, theme, version catalogue, worker thread
zoo/collection.goose   finding, downloading, checking and preparing one version
zoo/mojang/            Mojang's manifest and version files
zoo/minecraft/         the official launcher's folder
zoo/archive/           zip and DEFLATE
zoo/hash/              SHA-1
zoo/net/               HTTP, backed by native/
zoo/specimen.goose     the release catalogue
native/                the C behind extern fn: WinHTTP, libcurl, platform probe
tests.goose            the test runner
```

## Versioning: the specimen label

Each release carries a SemVer number for machines and a museum data tag for people, after the way natural history collections label their specimens with binomial nomenclature:

```
$ zoo-launcher --version
zoo 0.1.0 "Panthera leo" (Lion)
  Panthera leo Linnaeus, 1758
  Accession  ZOO-2026-0001
  Locality   windows
  Collected  2026-11-05
  Prep.      mariusgxt
```

The accession number counts up with every release, the locality is the system the copy runs on, and the collection date is the release date. The catalogue is kept in `zoo/specimen.goose`, where each new release adds a tag and leaves the old ones as they were.

## Modding

Making your own client should be as direct as it was with the Mod Coder Pack. Because the zoo client is readable Goose source, there is nothing to decompile or deobfuscate. The planned workflow:

1. `setup` fetches the source and prepares the resources from your Minecraft jar.
2. You change the code, or add a mod folder.
3. `recompile` and `startclient` build and start your client.

Goose compiles a whole program at once and has no function pointers, so mods join the build instead of being loaded at run time. A mod sees the same types and functions as the game itself.

## Contributing

Issues and pull requests are welcome. Run `goose tests.goose` before sending a change. Code comments are in English and explain why something is done the way it is.

## Licence

Not chosen yet. Third-party parts are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Author

zoo is made by [mariusgxt](https://github.com/mariusgxt).
