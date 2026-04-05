# OACP Integration Guide — Live Darbar

How OACP (Open App Capability Protocol) v0.3 was added to Live Darbar, a Flutter app that streams live Gurbani Kirtan from Sri Darbar Sahib. This serves as a reference for adding OACP to any Flutter app.

## What OACP Enables

After this integration, the Hark voice assistant can:
- Discover Live Darbar's capabilities via ContentProvider
- Dispatch voice commands like "play kirtan", "play mukbaug", "show hukumnama"
- The on-device EmbeddingGemma model resolves fuzzy/misspelled input to the correct action

## Prerequisites

- OACP Android SDK (`oacp-android-release.aar`) — available from the [OACP repo](https://github.com/0xharkirat/oacp)
- Flutter app with Android support
- Basic understanding of Android intents and Flutter MethodChannels

---

## Step-by-Step Integration

### Step 1: Add the SDK

Copy `oacp-android-release.aar` into `android/app/libs/`.

Add the dependency in `android/app/build.gradle`:

```gradle
dependencies {
    implementation files("libs/oacp-android-release.aar")
    implementation "androidx.annotation:annotation:1.7.1"
}
```

The SDK auto-registers a ContentProvider at `${applicationId}.oacp` via manifest merger. No manual provider code needed.

### Step 2: Create `oacp.json` (Capability Manifest)

> **IMPORTANT — Flutter Asset Path Gotcha:**
> Place this file at `android/app/src/main/assets/oacp.json`, **NOT** in Flutter's `assets/` directory.
>
> **Why?** Flutter bundles pubspec assets at `flutter_assets/assets/oacp.json` inside the APK.
> The SDK's ContentProvider reads from the Android asset root (`oacp.json`).
> These are two different locations. Putting the file in Flutter's `assets/` will cause
> `FileNotFoundException: oacp.json` when Hark tries to discover the app.

Create `android/app/src/main/assets/oacp.json`:

```json
{
  "oacpVersion": "0.3",
  "appId": "__APPLICATION_ID__",
  "displayName": "Your App Name",
  "appDomains": ["your", "domains"],
  "appKeywords": ["keywords", "for", "discovery"],
  "appAliases": ["alternate app names"],
  "capabilities": [
    {
      "id": "your_action",
      "description": "What this action does in plain English.",
      "aliases": ["alternate phrasings", "other ways to say it"],
      "examples": ["example user utterances"],
      "keywords": ["matching", "keywords"],
      "disambiguationHints": ["When to use this vs similar actions"],
      "parameters": [],
      "confirmation": "never",
      "visibility": "public",
      "requiresForeground": true,
      "completionMode": "foreground_handoff",
      "invoke": {
        "android": {
          "type": "activity",
          "action": "__APPLICATION_ID__.oacp.ACTION_YOUR_ACTION"
        }
      }
    }
  ]
}
```

Key points:
- `__APPLICATION_ID__` is replaced with the real package name at runtime by the SDK
- Use `"type": "activity"` for actions that open the app (most Flutter actions)
- Use `"type": "broadcast"` for background-only actions (no UI needed)
- Rich `aliases`, `examples`, and `keywords` improve voice matching accuracy
- `action.endsWith(".oacp.ACTION_X")` pattern handles debug/release build variants

### Step 3: Create `OACP.md` (Semantic Context)

Place at `android/app/src/main/assets/OACP.md`:

```markdown
# Your App — OACP Context

## What this app does
[Plain English description]

## Vocabulary
[Domain-specific terms the LLM should understand]

## Capabilities
- action_id: [what it does]

## Disambiguation
- "user phrase" → action_id
```

This file helps future BYOK cloud models with larger context windows. The local EmbeddingGemma model uses `oacp.json` metadata only.

### Step 4: Update AndroidManifest.xml

Add intent filters to your `<activity>` for each foreground OACP action:

```xml
<activity android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop" ...>

    <!-- Existing intent filters -->

    <!-- OACP foreground actions -->
    <intent-filter>
        <action android:name="${applicationId}.oacp.ACTION_YOUR_ACTION" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>
```

If you have background actions, add a receiver:

```xml
<receiver android:name=".oacp.OacpActionReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="${applicationId}.oacp.ACTION_BACKGROUND_ACTION" />
    </intent-filter>
</receiver>
```

### Step 5: Handle OACP Intents in MainActivity (Kotlin)

Update `MainActivity.kt` to bridge OACP intents to Flutter via MethodChannel:

```kotlin
class MainActivity : FlutterActivity() {
    companion object {
        private const val OACP_CHANNEL = "com.your.app/oacp"
        private const val METHOD_HANDLE_OACP_COMMAND = "handleOacpCommand"
        private const val TAG = "YourApp"
    }

    private var oacpChannel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())
    private var pendingOacpPayload: HashMap<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        oacpChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OACP_CHANNEL
        )

        // Drain any command queued before channel was ready
        pendingOacpPayload?.let { payload ->
            pendingOacpPayload = null
            sendOacpCommandWithRetry(payload, retriesLeft = 40)
        }

        dispatchOacpIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchOacpIntent(intent)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null) // Prevent Activity leak
        super.onDestroy()
    }

    private fun dispatchOacpIntent(intent: Intent?) {
        val payload = buildOacpPayload(intent) ?: return
        intent?.action = null // Clear consumed action

        handler.removeCallbacksAndMessages(null) // Cancel previous retry chain

        val channel = oacpChannel
        if (channel == null) {
            pendingOacpPayload = payload // Queue for configureFlutterEngine
            return
        }

        sendOacpCommandWithRetry(payload, retriesLeft = 40)
    }

    private fun buildOacpPayload(intent: Intent?): HashMap<String, Any>? {
        val action = intent?.action ?: return null
        val payload = hashMapOf<String, Any>(
            "requestId" to UUID.randomUUID().toString()
        )

        when {
            action.endsWith(".oacp.ACTION_YOUR_ACTION") -> {
                payload["command"] = "your_action"
            }
            else -> return null
        }

        return payload
    }

    private fun sendOacpCommandWithRetry(payload: HashMap<String, Any>, retriesLeft: Int) {
        val channel = oacpChannel ?: return

        channel.invokeMethod(METHOD_HANDLE_OACP_COMMAND, payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(TAG, "OACP delivered: ${payload["command"]}")
                }
                override fun error(code: String, msg: String?, details: Any?) {
                    retryOrFail(payload, retriesLeft, msg)
                }
                override fun notImplemented() {
                    retryOrFail(payload, retriesLeft, "not implemented")
                }
            })
    }

    private fun retryOrFail(payload: HashMap<String, Any>, retriesLeft: Int, msg: String?) {
        if (retriesLeft > 0) {
            handler.postDelayed({ sendOacpCommandWithRetry(payload, retriesLeft - 1) }, 250)
        } else {
            Log.e(TAG, "OACP failed after retries: $msg")
        }
    }
}
```

Key patterns:
- **Retry logic**: Dart may not be ready when the intent arrives (cold start). 40 retries x 250ms = 10s window.
- **Pending queue**: If the MethodChannel isn't set up yet, the command is queued and drained when `configureFlutterEngine` runs.
- **Cleanup in onDestroy**: Prevents the retry chain from leaking the Activity.
- **`endsWith()` matching**: Handles debug/release build variants where `applicationId` differs.

### Step 6: Handle OACP Commands in Flutter (Dart)

In your main widget's `initState`, register the MethodChannel handler:

```dart
static const MethodChannel _oacpChannel =
    MethodChannel('com.your.app/oacp');
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

@override
void initState() {
  super.initState();
  _oacpChannel.setMethodCallHandler(_handleOacpCommand);
}

@override
void dispose() {
  _oacpChannel.setMethodCallHandler(null);
  super.dispose();
}

Future<void> _handleOacpCommand(MethodCall call) async {
  if (call.method != 'handleOacpCommand') return;
  if (!mounted) return; // Guard against disposed ref
  final dynamic raw = call.arguments;
  if (raw is! Map) return; // Safe cast
  final command = raw['command'] as String?;

  switch (command) {
    case 'your_action':
      // Do your thing — play audio, navigate, etc.
      break;
    case 'navigate_somewhere':
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const SomePage()),
      );
      break;
  }
}
```

If your OACP commands need to push routes, pass `navigatorKey` to your app widget:

```dart
return MaterialApp(  // or ShadApp, etc.
  navigatorKey: _navigatorKey,
  // ...
);
```

**Why `GlobalKey<NavigatorState>`?** The MethodChannel handler runs in the context of your root widget, which is *above* the Navigator in the widget tree. `Navigator.of(context)` would throw "context that does not include a Navigator". The GlobalKey gives direct access.

### Step 7: Create OacpActionReceiver (Optional)

For background actions that don't need UI, create `android/app/src/main/kotlin/.../oacp/OacpActionReceiver.kt`:

```kotlin
class OacpActionReceiver : OacpReceiver() {
    override fun onAction(
        context: Context,
        action: String,
        params: OacpParams,
        requestId: String?
    ): OacpResult? {
        return when {
            action.endsWith(".oacp.ACTION_BACKGROUND_THING") -> {
                // Do work without opening the app
                OacpResult.success("Done!")
            }
            else -> null
        }
    }
}
```

---

## Testing

### Verify ContentProvider

```bash
# Should print your oacp.json with real package name
adb shell content read --uri content://com.your.app.oacp/manifest

# Should print your OACP.md
adb shell content read --uri content://com.your.app.oacp/context
```

### Test Actions via adb

```bash
# Launch app first
adb shell am start -n com.your.app/.MainActivity

# Test a foreground action
adb shell am start \
  -a com.your.app.oacp.ACTION_YOUR_ACTION \
  -p com.your.app

# Check logs
adb logcat -d | grep "YourTag"
```

### Test with Hark

Install Hark on the same device. Say your voice command. Check logcat for the full resolution trace:
- `HarkNlu: resolve_ranked` — shows the EmbeddingGemma shortlist with scores
- `HarkNlu: resolve_success` — shows the winning action
- `IntentDispatcher` — shows the dispatched intent

---

## Gotchas & Lessons Learned

### 1. Flutter Asset Path (Critical)

| Location | APK Path | SDK Reads From |
|----------|----------|----------------|
| `assets/oacp.json` (pubspec) | `flutter_assets/assets/oacp.json` | - |
| `android/app/src/main/assets/oacp.json` | `oacp.json` (root) | **Here** |

**Always use `android/app/src/main/assets/` for OACP files in Flutter apps.**

If you see `FileNotFoundException: oacp.json` from the ContentProvider, this is the cause.

### 2. Navigator Context

`Navigator.of(context)` from a root widget's MethodChannel handler will throw because the context is above the Navigator. Use `GlobalKey<NavigatorState>` instead.

### 3. Build Variant Safety

Always use `action.endsWith(".oacp.ACTION_X")` in Kotlin, not exact string matching. Debug builds append `.debug` to the applicationId, so `com.your.app.debug.oacp.ACTION_X` won't match `com.your.app.oacp.ACTION_X`.

### 4. Retry Logic is Essential

Flutter's Dart VM may not be ready when the OACP intent arrives (especially on cold start). Without retry logic, the MethodChannel call will get `notImplemented` and the command is silently lost.

### 5. Rich Metadata = Better Matching

The EmbeddingGemma model matches based on `aliases`, `examples`, and `keywords` in `oacp.json`. In testing, "play mukbaug" (misspelled) correctly resolved to `play_mukhwak` because the aliases included phonetic variations like "play muk wak", "play mukh wak".

---

## Live Darbar Capabilities

| ID | Type | What It Does |
|----|------|-------------|
| `play_live_kirtan` | activity | Starts live kirtan stream from Darbar Sahib |
| `play_mukhwak` | activity | Plays today's Hukumnama audio |
| `play_katha` | activity | Plays Mukhwak Katha discourse |
| `view_mukhwak_pdf` | activity | Opens daily Hukumnama PDF viewer |

## File Overview

```
live_darbar/
├── android/app/
│   ├── libs/oacp-android-release.aar          # OACP SDK
│   ├── build.gradle                            # SDK dependency added
│   └── src/main/
│       ├── assets/
│       │   ├── oacp.json                       # Capability manifest
│       │   └── OACP.md                         # Semantic context
│       ├── AndroidManifest.xml                 # Intent filters added
│       └── kotlin/.../
│           ├── MainActivity.kt                 # OACP MethodChannel bridge
│           └── oacp/OacpActionReceiver.kt      # Background receiver
└── lib/main.dart                               # OACP command handler
```
