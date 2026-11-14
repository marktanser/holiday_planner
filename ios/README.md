# Holidays: the iPhone and iPad app

A native SwiftUI version of the Holiday Planner. Plans are documents: you keep them in iCloud Drive (or on the device) and open them from the app's file browser, the same way as Pages. The files are the same `.json` plans the web app saves, so a plan made in either opens in the other.

What it does:

- Fixed arrive and leave dates. Changing one stay moves nights to or from the others.
- A timeline bar with dividers you drag to move nights between neighbouring stays.
- Any number of travel items between stays, and for getting there and home.
- Costs per night and per travel item, with totals.
- Export menu: PDF document, Excel spreadsheet (both with or without costs) and Copy itinerary.

Needs **Xcode 16 or later** on a Mac, and an iPhone or iPad on **iOS 17 or later**.

## Install it on your iPhone or iPad (free Apple ID)

1. **Install Xcode** from the Mac App Store, open it once, and let it finish installing its components.
2. **Sign in:** Xcode → Settings → Accounts → **+** → Apple ID. A free Apple ID gives you a "Personal Team".
3. **Get the project:** on github.com/marktanser/holiday_planner choose **Code → Download ZIP** and unzip it (or clone the repository). Open `ios/HolidayPlanner.xcodeproj`.
4. **Choose your team:** click **HolidayPlanner** at the top of the left sidebar, then the **HolidayPlanner** target → **Signing & Capabilities**. Tick **Automatically manage signing** and pick your Personal Team. If Xcode says the bundle identifier isn't available, change `com.marktanser.HolidayPlanner` to something unique, for example `com.marktanser.holidays2`.
5. **Connect your iPhone** with a cable, unlock it and tap **Trust**. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** and restart when asked.
6. **Run it:** pick your iPhone in the device menu at the top of Xcode and press **Run** (⌘R).
7. **Trust the app the first time:** on the iPhone go to **Settings → General → VPN & Device Management**, tap your Apple ID and tap **Trust**. Then open **Holidays** from the Home Screen.

Do the same for an iPad.

### The 7-day limit

Apps installed with a free Apple ID stop opening after 7 days. Your plans are safe in their files. To carry on, connect the device and press **Run** in Xcode again. A paid Apple Developer membership extends this to a year. A free Apple ID can also have at most three of these apps on a device at once.

## Using it

- The app opens on a file browser. Choose **iCloud Drive** in Browse, pick a folder, and tap **Create Document** (or **+**) for a new plan. To open a plan saved by the web app, tap the file.
- Changes save automatically. Rename a plan by tapping its name in the title bar.
- **Export** (top right) has the **Include costs** switch, **PDF document**, **Excel spreadsheet** and **Copy itinerary**. Exports open the share sheet, where you can save to Files, print, or send them.

## If Xcode reports an error

This project was written without access to a Mac, so it hasn't been built yet. If Xcode shows a red error, copy the message (and the file and line it names) and ask Claude to fix it.
