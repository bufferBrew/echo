# Stable local signing for Echo

## Why this is needed

Echo's quick-paste injects a synthetic ⌘V via `CGEvent.post(tap: .cghidEventTap)`. macOS discards
that event unless the app holds **Accessibility** permission — silently, with no error.

Ad-hoc signing (`codesign --sign -`) gives the app a designated requirement that is a bare hash of
the binary:

```
# designated => cdhash H"55d613efa167f97f1f853e9d8440d276437d7744"
```

TCC stores the Accessibility grant against that requirement. Change the code, and the cdhash
changes, and the grant no longer matches. System Settings still *lists* Echo with its toggle on —
that list is keyed by path, not by hash — so the UI claims the permission is granted while
`AXIsProcessTrusted()` returns false and the app re-prompts on every launch.

A self-signed certificate changes the requirement to:

```
# designated => identifier "com.kartikjain.echo" and certificate leaf = H"<cert hash>"
```

The bundle ID and the certificate both stay constant across rebuilds, so the grant sticks
permanently. No paid Apple Developer account is required.

---

## Step 1 — Create the certificate

1. Open **Keychain Access** (`/Applications/Utilities/Keychain Access.app`, or Spotlight it).
2. Menu bar: **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Fill in the sheet:
   - **Name:** `Echo Local Signing` — must match exactly, `build.sh` looks for this string
   - **Identity Type:** `Self Signed Root`
   - **Certificate Type:** `Code Signing`
   - **Check "Let me override defaults"** — do check this; the default certificate expires in
     365 days, and once it expires you can no longer sign with it
4. Click **Continue**. It warns that this is a self-signed certificate — that is expected, click
   **Continue** again.
5. **Serial Number:** leave as is. **Validity Period (days):** change `365` to `3650` (10 years).
   Continue.
6. The next several screens (email/name, key pair info, key usage, extended key usage, subject
   alternate name) can all be left at their defaults — keep clicking **Continue**.
7. **Specify a Location For The Certificate:** make sure Keychain is set to **login**. Click
   **Create**, then **Done**.

## Step 2 — Trust it for code signing

Certificate Assistant sometimes marks the certificate trusted automatically. Check first:

```bash
security find-identity -v -p codesigning
```

If you see a line containing `Echo Local Signing` and the output ends with `1 valid identities
found`, **skip to Step 3**.

If it still says `0 valid identities found`:

1. In Keychain Access, select the **login** keychain, then the **Certificates** category.
2. Double-click **Echo Local Signing**.
3. Expand the **Trust** triangle.
4. Set **Code Signing** to **Always Trust**. (Prefer this over setting "When using this
   certificate: Always Trust", which grants blanket trust for every purpose — you only need
   code signing.)
5. Close the window. Enter your Mac login password when prompted.
6. Re-run the `security find-identity` command above to confirm it now reports a valid identity.

## Step 3 — Rebuild with the new identity

```bash
./build.sh
```

It auto-detects the identity. You should see `Signing with identity: Echo Local Signing` instead
of the ad-hoc message, followed by `Signed with a stable identity`.

If macOS shows a dialog saying *"codesign wants to sign using key … in your keychain"*, click
**Always Allow** so future builds don't prompt.

Confirm the designated requirement is now certificate-based rather than a bare cdhash:

```bash
codesign -d -r- /Applications/Echo.app
```

You want the last line to read `identifier "com.kartikjain.echo" and certificate leaf = H"..."`.
If it still shows `cdhash H"..."`, the identity wasn't picked up — go back to Step 2.

## Step 4 — Clear the stale grant and re-grant, once

The old ad-hoc grant is still in the TCC database and will shadow the new one. Wipe it:

```bash
tccutil reset Accessibility com.kartikjain.echo
```

Then quit Echo from the menu bar icon and:

1. **System Settings → Privacy & Security → Accessibility**
2. Click **+**, choose `/Applications/Echo.app`, and make sure its toggle is **on**
3. Relaunch:

```bash
open /Applications/Echo.app
```

## Step 5 — Verify

Copy a couple of things, open the history popup with your shortcut, arrow down to an entry, press
**Return**. It should paste into whatever app you were in.

From here on, code changes plus `./build.sh` will not disturb the permission.

---

## Notes and gotchas

- **Using a different certificate name:** export `ECHO_SIGN_IDENTITY` to whatever you named it —
  `ECHO_SIGN_IDENTITY="My Cert" ./build.sh`.
- **The certificate is local only.** It is not trusted on any other Mac, so this makes the app
  stable for you, not distributable. Gatekeeper will still warn other users.
- **Don't delete or regenerate the certificate.** A new certificate has a new leaf hash, which is
  a new designated requirement, which means re-granting Accessibility again.
- **Changing `CFBundleIdentifier` also breaks the grant**, since the identifier is half the
  requirement.
- **Certificate expiry:** with 3650 days you are set until ~2036. An expired certificate blocks
  new signing; already-signed apps keep working.
- **Backing up:** the certificate lives in your login keychain. If you migrate Macs without the
  keychain, recreate it and re-grant permission once.

## Build without installing

Use `./build.sh --no-install` to assemble a local app without replacing an installed copy.
`ECHO_SIGN_IDENTITY` overrides the signing identity.

## Navigation checks

On a Command Line Tools installation without XCTest, run:

```bash
swiftc Sources/Echo/ClipboardItem.swift Sources/Echo/HistoryViewModel.swift Tests/main.swift -o /tmp/echo-navigation-tests
/tmp/echo-navigation-tests
```
