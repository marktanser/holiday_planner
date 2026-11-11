# Holiday Planner

Plan stays between fixed holiday dates, with travel between each stop. It runs in the browser, works offline once installed, and saves plans as `.json` files, for example to iCloud Drive.

## Put it on GitHub Pages

1. Sign in at github.com and create a new repository called `holiday-planner`. Make it **Public**: free GitHub Pages needs that. Only the app's code is public. Your plans stay on your devices and in your own files.
2. On the new repository's page, choose **uploading an existing file**. Add every file from this folder:
   `index.html`, `sw.js`, `manifest.webmanifest`, `icon-180.png`, `icon-192.png`, `icon-512.png`, `icon.svg`, `README.md`.
   Then press **Commit changes**.
3. Go to **Settings → Pages**. Under *Build and deployment*, set Source to **Deploy from a branch**, branch **main**, folder **/ (root)**, and press **Save**.
4. After a minute or two the app is at `https://YOUR-USERNAME.github.io/holiday-planner/`.

## Add it to an iPhone or iPad

1. Open the address above in **Safari**.
2. Tap **Share**, then **Add to Home Screen**, then **Add**.
3. Open it from the new **Holidays** icon. It opens full screen and works offline.

## Saving to iCloud Drive

- Tap **Save to Files**. In the share sheet choose **Save to Files**, pick a folder in **iCloud Drive**, and tap **Save**. If a file with the same name exists, choose **Replace** to update it.
- To load a plan, tap **Open plan…** and choose the file from iCloud Drive.
- On a computer, the same files open in the same app, so iCloud Drive moves plans between devices.

The app also keeps your latest plan on each device by itself. The iCloud file is your backup and the way to move a plan between devices.

## Exporting to Excel

Tap **Export to Excel** to make a spreadsheet of the whole trip: each stay and travel item in date order. Untick **Include costs** first for a version without prices or totals, for example to share with people you're travelling with. On iPhone and iPad the file opens in the share sheet, so you can save it to Files or send it on.

## Updating the app

Upload a new `index.html` over the old one. Devices pick it up the next time they open the app online. If you change the icons, also change `CACHE` at the top of `sw.js` (for example to `holiday-planner-v2`).
