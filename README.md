# PDCmdMod by Perru (@perru_ on discord)

PDCmdMod is a UE4SS mod for Pacific Drive that adds many commands to the in-game console. (may be opened using F10)

**To get started, after installing UE4SS and this mod, open the command line in-game (F10, you will see a small black text box at the bottom) and run the command `pdcmdmod` to see the introduction message, which will explain how to use this mod.**

Generative AI was used during development. Learn more below.

See credits at the end of the readme.

This mod is under the [MIT License](https://choosealicense.com/licenses/mit/). See the LICENSE file for more details.

## Installation

This mod requires the latest experimental version of [Unreal Engine 4 Scripting System (UE4SS)](https://github.com/UE4SS-RE/RE-UE4SS/releases) to work. I cannot guarantee support for previous versions. Follow installation instructions [here](https://github.com/UE4SS-RE/RE-UE4SS#basic-installation) (read carefully).

Once done installing UE4SS, you can install this mod by going in the [releases tab](https://github.com/MrPerruche/PDCmdMod/releases) (pick latest release, you should see a .zip file under the release's version and description in the Assets section). Unzip it in UE4SS' mods folder (`...\steamapps\common\Pacific Drive\PenDriverPro\Binaries\Win64\Mods` by default) (to reach this folder, right click game in steam, go to properties, press "browse local files" then navigate to `PenDriverPro\Binaries\Win64\Mods`). Unzip the mod such that the folder structure is `...\Mods\PDCmdMod\Scripts` and `...\Mods\PDCmdMod\dlls`.

## Warning

**This mod was built to break the game. As such, expect some features to be able to crash your game (or even brick your save) if you misuse them. I have added a few warnings in the help messages to help you not crash the game. This software is provided as-is, see the license.**

## Commands list

(Result of `pdcmdmod list --showall`)

```
Commands from PDCmdMod by Perru (@perru_ on discord):
  Help syntax: <mandatory> [optional]. Ellipsis means multiple/unknown subcommands/arguments
 
BOOKMARK ...
  Make and load bookmarks.

BORDERS ...
  Command to toggle invisible and instability walls.

DEBUG <COMMAND> [SUBCOMMANDS AND ARGUMENTS...]
  Debug commands from the PDCmdMod used for development.

DELETEHAND
  Deletes item in hand.

DLCGARAGE ...
  Toggle the DLC garage aesthetic permanently.

EVENT ...
  DEPRECATED. Manually trigger events. This command is unstable and can cause issues

EXPEDITION ...
  Expeditions related command(s).

FATIGUE ...
  Commands to manipulate the held part's fatigue.

GIVE ...
  Give items to player. GIVING YOURSELF DLC ITEMS WILL BRICK YOUR SAVE.

LOAD
  Open the load game menu (does not pause the game)

PDCMDMOD ...
  Show this message

PHOTO ...
  Go past the photomode border and edit camera speed.

SAVE
  Open the save game menu (does not pause the game)

SCANNER ...
  Read and modify the Zone Scanner's reveal charges.

SPAWN <ASSET_PATH>
  Spawn an actor at the player's location.

TP <CAR|PLAYER|CAM> [X Y Z]  FLAGS: --RELATIVE-TO=<SELF|CAR|PLAYER|CAM>
  Teleport the player, car or camera.

UNLOCKLOGS ...
  Unlock logbook entries.

WIDGET ...
  Open any widgets. There are very useful widgets regarding custom artifacts, zone conditions, game events, and much more.
```

## Notice on usage of Generative AI

Generative AI was heavily relied on to create this mod.

Note I made this mod to provide useful features to players and look for secrets hidden in game files. I am fully aware and understand the debate around Generative AI, and do not support its current agenda. However, I cannot care to learn UE4SS (as of making this mod) because I am too busy with exams and would like not to waste entire nights trying to figure out its quirks. It is not like anyone could've got a paycheck but was replaced by AI. I did not give big AI 20 bucks.

You are free to not install this mod and even make your own AI-less copy if you're not fine with this. 


## (Technical) Building the "C++ side"

This mod has a "Lua side" (in the Scripts folder) and a "C++ side" (in the dlls folder). A compiled DLL of `dllmain.cpp` is provided. You are free to analyze the code and build the DLL yourself if you do not trust it. It should be buildable from the [UE4SS C++ template](https://github.com/UE4SS-RE/UE4SSCPPTemplate), no other requirements. Feel free to reach out if you have any questions.

## Suggestions, bug reports and contributing

You may submit suggestions and bug reports by creating an issue on the GitHub repository. You can also contribute, though I do not really expect any contributions here.

## Credits

**Thanks to Shruc for allowing me to include their code to edit expedition level.**

## Reaching out

You can reach out to me on Discord (@perru_). I am still maintaining this mod and clarify in the readme when I will stop doing so.
