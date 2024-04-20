# Escape From Heat Island

![store_cover_merged_itch](https://github.com/nmfisher/escape_from_heat_island/assets/7238578/856c0526-8aaa-4d0c-97c6-65353d7c9d2a)

A cross-platform, 3D game for the Flutter Global Gamers Challenge.

Save the neighbourhood from increasing temperatures by planting trees to increase shade!

## Getting Started

The game has been built using the [flutter_filament](https://github.com/nmfisher/flutter_filament) Flutter package I developed. This is still highly experimental, so the package installation/build process is a bit more complex than normal.

```
flutter channel master
flutter upgrade
mkdir ~/escape_from_heat_island
git clone git@github.com:nmfisher/escape_from_heat_island.git
git clone git@github.com:nmfisher/flutter_filament.git
cd flutter_filament && git lfs pull && git checkout develop
cd ../escape_from_heat_island
flutter run -d <your device>
```
