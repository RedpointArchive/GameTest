# GameTest

GameTest is an framework for automated end-to-end testing of games.  It is intended to take an almost blank slate VM, and simulate a user installing a game through Steam, verifying that the game installs and launches correctly.  From here, the developer can specify an additional test script to run (i.e. to verify that controller support is working, etc.).

GameTest is currently under development, and supports:
- Testing games under Windows 7 SP1 guests, where the Hyper-V host is capable of providing GPU acceleration for DirectX.
- Restoring guest VMs to a snapshot on each test, to ensure a correct state.
- Automatically determining network configuration.
- Automatically installing games through the Steam UI, simulating user clicks and keyboard input for the most accurate representation of installation by users.

We intend to add support for other versions of Windows and other operating systems in the future.

## Usage

First you'll need to configure a Hyper-V host and a Windows 7 guest by following the guide: [Guest Installation Guide: Windows 7 Professional SP1](https://github.com/RedpointGames/GameTest/blob/master/GuestInstall/Windows7Pro.md)

Once this is setup, you need to create a credentials / configuration file on the Hyper-V host that specifies the app ID and how the game starts.  You should create a file like this, and name it something like `SteamCredentials.ps1`:

```powershell
$SteamUsername = "STEAM_ACCOUNT_NAME"
$SteamPassword = "STEAM_ACCOUNT_PASSWORD"
$SteamAppId = "APP_ID"
$SteamAppName = "APP_NAME_AS_IT_APPEARS_IN_STEAMAPPS_FOLDER"
$SteamTargetPath = "C:\Program Files (x86)\Steam\steamapps\common\APP_NAME\LOCATION_OF_MAIN_GAME_EXECUTABLE.exe"
$SteamAlivePath = "FULL_PATH_OF_A_FILE_OR_DIRECTORY_THAT_IS_CREATED_ON_GAME_LAUNCH"
$SteamAppChannel = "NOT_IMPLEMENTED_LEAVE_BLANK"
```

Open a PowerShell prompt and navigate to the `Library` directory in this repository.  Then run:

```
.\Guest-Windows7Pro.ps1 -GuestName VM_NAME -Target Test -CredentialsFile FULL_PATH_TO_STEAM_CREDENTIALS_PS1
```

## License

This project is licensed under the MIT license.  Contributions are welcome; please submit PRs!