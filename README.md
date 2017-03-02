# GameTest

GameTest is an framework for automated end-to-end testing of games.  It is intended to take an almost blank slate VM, and simulate a user installing a game through Steam, verifying that the game installs and launches correctly.  From here, the developer can specify an additional test script to run (i.e. to verify that controller support is working, etc.).

GameTest is currently under development, and supports:
- Testing games under Windows 7 SP1 guests, where the Hyper-V host is capable of providing GPU acceleration for DirectX.
- Restoring guest VMs to a snapshot on each test, to ensure a correct state.
- Automatically determining network configuration.
- Automatically installing games through the Steam UI, simulating user clicks and keyboard input for the most accurate representation of installation by users.

We intend to add support for other versions of Windows and other operating systems in the future.