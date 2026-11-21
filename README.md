# Noodle

Noodle is a native macOS desktop pet. He lives above your other windows, reacts to toys, performs tricks, and can use a photo as his avatar.

## Requirements

- macOS 13 or newer
- Swift 5.9 or newer
- A Mac that can build Swift AppKit applications
- An Apple-silicon Mac for the current build script

Noodle does not request Accessibility permission when he starts. The optional window-control actions ask only if you choose to use them.

## Installation

Noodle is currently installed by building the app from this repository. There is not a pre-built installer or signed `.dmg` yet.

### Option 1: Download the ZIP

1. Open the [Noodle GitHub repository](https://github.com/sasutterkids-ctrl/noodle-pet).
2. Click the green **Code** button.
3. Click **Download ZIP**.
4. Open the downloaded ZIP in Finder. macOS creates a `noodle-pet-main` folder.
5. Open **Terminal**. Type `cd ` with a space after it, drag the `noodle-pet-main` folder into the Terminal window, and press Return.
6. Build and open Noodle:

   ```sh
   zsh run-noodle.command
   ```

### Option 2: Clone with Git

If Git is installed, open Terminal and run:

```sh
git clone https://github.com/sasutterkids-ctrl/noodle-pet.git
cd noodle-pet
zsh run-noodle.command
```

The first run downloads/builds the Swift target locally, creates `Noodle.app`, and opens it. You only need to run the command again when you want to rebuild after updating the source.

### Install the Swift tools if needed

If Terminal says that `swift` or `git` cannot be found, install Apple’s Command Line Tools:

```sh
xcode-select --install
```

Finish the installer, close and reopen Terminal, then run `zsh run-noodle.command` again. You can check Swift with:

```sh
swift --version
```

## Build and launch

The easiest way to build and open Noodle is:

```sh
zsh run-noodle.command
```

To build the application without opening it:

```sh
zsh build-app.sh
open Noodle.app
```

The script creates `Noodle.app` from the Swift source and the resources in `AppBundle/Contents/Resources`.

### If macOS blocks the app

The app is a local development build and is not notarized. If macOS says that it cannot verify the developer, close the warning, open **System Settings → Privacy & Security**, and choose **Open Anyway** for Noodle. Only do this when you downloaded the source from the repository you trust. Then run `open Noodle.app` again from the project folder.

### Uninstall

Quit Noodle from his menu, then delete the project folder. Noodle also stores a small amount of local state in macOS preferences so first-launch and reset behavior can persist; deleting the project does not remove that preference. To start fresh, use **Care → Reset Noodle** inside the app.

## First launch

On the first launch only, Noodle goes off-screen for five seconds. A cardboard box drops down from the top of the screen. Click the box to open it. There is no speech bubble while Noodle is inside the box.

After opening the box, Noodle explains the basics with four speech bubbles. Later launches open normally. **Care → Reset Noodle** repeats the off-screen and box-drop sequence.

## Open Noodle’s menu

Click Noodle once. His menu contains Care, Avatar, Tricks, Play, Toys, Movement, and Quit.

Dragging Noodle moves him. Releasing him after a drag makes him bounce like a tennis ball. He becomes angry briefly, then returns to normal.

## Care

- **Pet Noodle** makes him wave.
- **Feed Noodle** creates a physical treat. Drag the treat and throw it to Noodle. He only gains hunger when he catches it.
- **Send Noodle to cage** / **Let Noodle out** controls the cage.
- **Reset Noodle** restores Noodle, clears toys and machines, resets hunger, and drops the box after five seconds.

Noodle’s Hunger bar is visible below him. Hunger drains very slowly during normal wandering; active tricks, dancing, jumping, spinning, rolling, and bouncing use extra hunger. If hunger reaches 0, Noodle dies. Use Reset Noodle to revive him.

During active play, Noodle has a chance to throw up a golden bone. Drag the golden bone to him and feed it to unlock `Hunger ∞`; hunger then stays full until Reset Noodle is used.

## Import a photo

1. Click Noodle.
2. Open **Avatar → Import pet photo**.
3. Choose an image file in the file picker.
4. Noodle immediately uses the photo as his clipped avatar.
5. Open **Avatar → Style as Noodle** to apply the warm, sharpened cartoon-like styling pass.

The styling pass is local. It does not require an API key or upload the photo to a service.

## Cosmetics

Open **Avatar → Cosmetics** to change Noodle’s look. Choose:

- None
- Crown
- Party hat
- Sunglasses
- Bow tie
- Flower collar

Cosmetics are drawn locally and can be changed whenever you want. Clones receive the same cosmetic look.

## Tricks

Open **Tricks** and choose:

- Wave
- Zoomies
- Nap
- Jump
- Roll over
- Beg
- Play dead
- Stretch
- Dance
- Spin until stopped

Choose **Teach a trick** to give Noodle a custom trick name. He performs it with a playful custom pose.

## Play

- **Tag** starts a game where Noodle chases your cursor. Choose Stop Tag to end it.
- **Make popcorn** sends Noodle off-screen for the popcorn machine. Choose a flavor, wait for it to cook, then click the dropped bucket to eat it.
- **Clone machine** opens the cloning machine.
- **Stat changer machine** opens the machine for changing Noodle’s physics, hunger, and size.

## Toys

- **Spawn treat** creates a treat you can drag and toss.
- **Set trap** creates a harmless trap. Drag it into place; when Noodle walks into it, it holds him for about three seconds and then releases him.
- **Fetch ball** creates a ball Noodle chases and brings back.
- **Toss yarn** creates yarn Noodle chases and returns.
- **Spawn robot** creates a robot. Click it and use W/A/S/D, or let it move automatically. Noodle follows the robot around.
- **Spawn boom box** creates a boom box. Click it to make Noodle and clones dance.

Only one toy is active at a time. Drag a toy and release it to throw or place it.

## Clone machine

1. Open **Play → Clone machine**.
2. Choose how many clones to make, from 1 to 7.
3. Spawn a treat and drag it into the machine.
4. Drag Noodle into the input chamber.
5. Press Start.
6. Clones appear in the output chamber and play independently.

Use the Terminate chamber to remove a clone. Close the machine with its Close button; closing extra windows does not close Noodle.

## Stat changer

1. Open **Play → Stat changer machine**.
2. Spawn a treat and drag it into the machine.
3. Drag Noodle into the chamber.
4. Adjust the live sliders:
   - **Bounciness** changes bounce strength for Noodle and thrown physics toys.
   - **Gravity** changes the pull on Noodle and thrown physics toys.
   - **Hunger level** sets hunger from 0% to 100%.
   - **Size** changes Noodle from 50% to 150%.
5. Click Close when finished.

## Movement

- **Follow my mouse** makes Noodle follow the cursor until stopped.
- Every 25 minutes, Noodle automatically follows the cursor for about 12 seconds.
- **Rest on a random window** places Noodle on top of an open window temporarily.
- **Pause wandering** / **Resume wandering** controls desktop wandering.
- **Nudge front window** and **Tidy open windows** are optional Accessibility features. macOS may ask for permission only when you use them.

## GitHub

The public repository is available at:

https://github.com/sasutterkids-ctrl/noodle-pet

The repository contains the Swift source, resources, build scripts, and the walking video. The generated `Noodle.app` bundle and large `.mov` source clip are excluded from GitHub because individual files over 100 MB are not accepted.
