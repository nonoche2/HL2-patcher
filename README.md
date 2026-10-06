# HL2-patcher
a script to compile Half Life 2 for Apple Silicon and Intel 64 bit

This script will create an Apple Silicon or Intel 64 bit version of Half Life 2 for macOS.

[![Ko-fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/nonoche)

It is adapted from [this guide](https://jxhug.notion.site/Guide-to-Installing-Half-Life-2-Using-Source-Engine-on-macOS-9fa5ffc910f5454ab0f0e5da2a9e5b9f) from 2023 which had these issues:
- compiler commands were outdated with the latest updates to Clang
- Valve updated the Source Engine and files with Half Life 2's anniversary edition which have rendering issues with the older version of the Source Engine used for this port
- the guide had you painstakingly copy and paste each command in the terminal

This script aims to fix all these issues and create an application bundle with minimal user interaction. The script will match the game's localization to your system language settings. Note: you must own Half Life 2 on your Steam account for this to work.

## How to use:

- to the right of this window, click "releases", expand "assets" if necessary and click on "hl2.Patcher.zip" to download it
- unzip the file if necessary
- Double click hl2.command. You will have a Gatekeeper alert preventing the script from running, go to system settings > security and privacy, scroll down and click "open anyway".

The script will open the terminal, it will make sure you have all the required dependencies, download/update them if necessary, and prompt you for your Steam login so that it can download the older version of Half Life 2

- type your Steam login and hit enter

you will then be prompted for your Steam password (the terminal won't display anything when you type it, that's normal)
- type your Steam password and hit enter

if necessary, you will then be asked for your Steam guard code. Type it and hit enter.

the script will then download the older version of Half Life 2, download the Source Engine, compile the files and create a Mac version of Half Life 2 in the same location as the script. Depending on your machine, the whole operation can take up to about 15 minutes. The terminal will output a bunch of stuff, and if successfull the last thing you'll see will be "--- Build and Processing Cycle Complete! ---".

## Updating the Steam version

If you don't want the game to run as an independant Application Bundle and want to have it work from Steam:

- after following the instructions above, right-click Half Life 2.app and select "display contents"
- navigate to Contents/Resources/, select all the files inside and copy them
- in Steam, select your installed version of Half Life 2 in the library, click the gear icon and select Manage > browse local files, it'll open a Finder window where the Half Life 2 files are installed
- delete everything except hl2.sh
- paste the files you copied

you can now launch Half Life 2 from Steam

A similar script is available for [Portal](https://github.com/nonoche2/Portal-patcher/tree/main)
