# Running CleanYourTV from Termux (Android phone)

Everything in `tools/` is Python and shell, so the **debloat half runs in Termux as it is**. The launcher
half needs one change: gradle and the Android SDK do not run on a phone, so the APK is built in GitHub's
cloud (or on a computer) and Termux only installs it.

Your phone and the TV must be on the same Wi-Fi. On the TV: Settings → Device Preferences → About → press OK
on **Build** seven times → Developer options → **USB debugging** on (and Network/ADB debugging if offered).

## 1. Set up the tools (once)

Install Termux from [F-Droid](https://f-droid.org/packages/com.termux/) (the Play Store build is outdated), then:

```
pkg install git -y
git clone https://github.com/<you>/cleanyourtv      # your fork, or Gathin23/cleanyourtv
cd cleanyourtv
bash tools/termux-setup.sh
termux-setup-storage                                # lets Termux read your Downloads folder
```

`tools/termux-setup.sh` installs `python` and `python-cryptography` from Termux's own repository and builds
`tools/venv` with `--system-site-packages`. Plain `pip install -r tools/requirements.txt` would try to compile
`cryptography` with Rust, which is slow and often fails on a phone.

## 2. Check the connection

```
export TV_HOST=192.168.1.50                          # your TV's IP address
tools/venv/bin/python -I tools/tv.py --probe
```

Accept "Allow USB debugging?" on the TV (tick "Always allow").

## 3. Debloat

```
bash tools/disable.sh examples/<your tv>/debloat.txt
bash tools/restore.sh examples/<your tv>/debloat.txt   # undo
```

Use `bash` in front of the scripts; it also works when the file has no execute bit. A list that disables the
stock launcher is applied in two passes: the guard in `disable.sh` skips the app that owns Home until another
launcher is installed (step 5), then run the list again.

## 4. Build the launcher APK in the cloud

1. Fork the repository on GitHub (from the phone's browser is fine).
2. In your fork open **Actions** → **Build launcher APK** → **Run workflow** (press **Enable** first if Actions is off).
   The workflow is `.github/workflows/build-launcher.yml`.
3. After 3–5 minutes open the finished run and download the artifact **cleanyourtv-launcher-apk**. It is a zip
   holding `app-release.apk`; leave it in Downloads, no need to unpack it.

## 5. Install the launcher and make it Home

```
export TV_HOST=192.168.1.50
bash launcher/install-apk.sh          # picks the newest APK or artifact zip in Downloads
# or name it:  bash launcher/install-apk.sh ~/storage/downloads/cleanyourtv-launcher-apk.zip
```

`install-apk.sh` calls `launcher/build-and-install.sh` with `APK_FILE` set, so it skips the JDK, SDK and gradle
steps and keeps everything else: the minSdk check, pushing the APK, installing it, finding and disabling the
stock launcher, and rolling back if Home does not land on the new launcher. The same options apply:

```
INPUT_KEY_SERVICE=1 HOME_KEY_SERVICE=1 bash launcher/install-apk.sh
STOCK_LAUNCHER=none bash launcher/install-apk.sh      # leave the stock launcher enabled
```

Then run the debloat list once more (step 3) if it contains the old launcher.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `no launcher APK found` | Run `termux-setup-storage`, or pass the file path as the argument. |
| `ModuleNotFoundError: cryptography` | Re-run `bash tools/termux-setup.sh`; it needs the `python-cryptography` package. |
| `--probe` times out | Same Wi-Fi? Network/ADB debugging on? The TV must be awake. Some TVs list the IP under Settings → Network. |
| Prompt never appears on the TV | Toggle USB debugging off and on, then run `--probe` again. |
| Termux is killed during a long run | Keep the screen on, or run `termux-wake-lock` first. |

Close ADB when you are done (Developer options → debugging off); see the README's security question.

## Add-ons (Sleep Timer, Weather, Prayer Times)

Add-ons are separate apps in `addons/`; their own install scripts build with gradle, so from a phone use the
cloud build here too.

1. In your fork: **Actions** → **Build add-on APKs** → **Run workflow**. Leave the add-on list as it is, or
   name some (`sleep-timer`, `weather`, `prayer-times`). The Prayer Times fields (city name, latitude, longitude
   and the Aladhan method number, e.g. 20 for Kemenag Indonesia) are baked in at build time; run it again to
   change them.
2. Download the artifact **cleanyourtv-addons** into Downloads.
3. Install:
   ```
   export TV_HOST=192.168.1.50
   bash addons/install-apk.sh sleep-timer weather prayer-times
   ```
   `SRC=<zip>` names the file if it is not the newest `cleanyourtv-addons*.zip` in Downloads. Sleep Timer also
   gets its accessibility service and app-ops (including TCL's auto-start) from its own script.
4. Press Home and answer **Show card** for each. Weather asks for the city on the TV with the remote's keyboard.
