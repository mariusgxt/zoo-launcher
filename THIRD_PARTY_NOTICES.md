# Third-party notices

## Inter

`assets/fonts/Inter-*.otf` and `assets/fonts/InterDisplay-*.otf` are Inter,
Copyright 2016-2023 The Inter Project Authors, under the SIL Open Font
License 1.1 (`assets/fonts/OFL.txt`).

## JetBrains Mono

`assets/fonts/JetBrainsMono-Regular.ttf` is JetBrains Mono, Copyright 2020
The JetBrains Mono Project Authors, under the SIL Open Font License 1.1
(`assets/fonts/OFL.txt`).

All fonts are embedded into the launcher at compile time.

## Minecraft

zoo contains no Minecraft code, assets or data. The launcher reads them from
the player's own copy of Minecraft: Java Edition, or downloads that copy from
Mojang's servers, and keeps them on the player's machine. Not an official
Minecraft product. Not approved by or associated with Mojang or Microsoft.

## Launcher design

The launcher's layout follows three published launcher concepts. zoo redraws
everything in code, with its own colours, text and mark; no images, fonts or
files from any of them are used.

- **Gigacat prototype launcher** by ツMonkesha, Figma Community
  (https://www.figma.com/community/file/1593718159027974699), licensed under
  CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The frame comes
  from this one: the rail of icons down the left, the top bar with its clock,
  badge and bar, the wordmark over a lit ground, the pills under it, and the
  row of cards along the foot. The "Amethyst" theme uses colours sampled from
  it. The content, worlds, setup and label pages follow its mods, map,
  settings and account pages.
- **Minecraft Java Edition Launcher** by voidmax, Figma Community
  (https://www.figma.com/community/file/1622169498397413530), licensed under
  CC BY 4.0. The action bar that holds the version picker, the main button
  and the icon buttons together on one panel is from this one, as is the
  small state pill above the title.
- **HQLauncher**, a Figma community design
  (https://www.figma.com/design/A1ON5O3moAjptWHjsvQeGW). Its plainer table
  rules for long lists and its swatch row for choosing an accent colour
  shaped zoo's version list and theme picker.
