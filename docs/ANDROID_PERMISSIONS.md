# Android Permissions & Feature Justification

Every permission declared in [AndroidManifest.xml](../app/android/app/src/main/AndroidManifest.xml) and [play/AndroidManifest.xml](../app/android/app/src/play/AndroidManifest.xml) maps directly to a verified Tandem feature. No hidden, obfuscated, or unused permissions are declared.

| Permission | Flavor(s) | Feature & Justification |
|---|---|---|
| `INTERNET` | Both | Required for BEP TLS 1.3 sync (`22000/tcp`, `22000/udp`), local loopback API (`127.0.0.1:8385`), and optional relays. |
| `ACCESS_NETWORK_STATE` / `CHANGE_NETWORK_STATE` | Both | Detects Wi-Fi vs. metered cellular links and binds sockets to a no-internet hotspot `Network` (`NetworkManager.kt`). |
| `ACCESS_WIFI_STATE` / `CHANGE_WIFI_STATE` | Both | Reads local Wi-Fi link state and joins/creates Local-Only Hotspots for no-internet transfer (`HotspotHelper.kt`). |
| `CHANGE_WIFI_MULTICAST_STATE` | Both | Acquires `WifiManager.MulticastLock` while local discovery (`UDP 21027`) is active so the OS does not drop broadcast/multicast announcements. |
| `NEARBY_WIFI_DEVICES` (`neverForLocation`) | Both | Required on Android 13+ (API 33+) to start/join local Wi-Fi hotspots without requesting location access. |
| `ACCESS_FINE_LOCATION` (`maxSdkVersion=32`) | Both | Required by Android 8–12 only for Local-Only Hotspot APIs; scoped strictly to `<= API 32`. |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` | Both | Keeps `TandemService` alive with a persistent notification during active folder sync / Send transfers (`V6` in `DECISIONS.md`). |
| `POST_NOTIFICATIONS` | Both | Required on Android 13+ to show the foreground service notification and completion notices. |
| `WAKE_LOCK` | Both | Holds a bounded partial wake lock strictly during active block transfers (`TandemService.kt`). |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Both | Requested only with explicit user consent when the user enables "Always on" background sync (`D4`). |
| `MANAGE_EXTERNAL_STORAGE` | `sideload` only | All-files access for arbitrary folder sync and camera backup on direct/GitHub APK builds (`D5`). Stripped via `tools:node="remove"` in `play` flavor. |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`), `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=29`) | Both | Legacy scoped storage fallback on Android 8–12 only. |
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | Both | Photo and video selection for Send and Play-flavor media access on Android 13+. |

> **Note:** If Play Protect flags the `sideload` flavor due to `MANAGE_EXTERNAL_STORAGE`, ship the `play` flavor permissions for direct downloads as well and document the SAF-only limitation.
