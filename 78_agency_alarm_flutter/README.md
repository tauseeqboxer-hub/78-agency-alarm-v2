# 78 Agency Alarm — Native Android & iOS Phone App

Yeh aapki **78 Agency Alarm** native mobile app ka complete project hai — jismein lock-screen alarm, **"Tun Tun" + Voice Announcement ("Kaam ka time ho gaya hai!")**, client-wise tracking, aur live Roman Urdu / English performance remarks shamil hain.

---

## Sab Se Aasan Tarika: Bina Coding Free APK Banayein (GitHub se)

Aapko apne computer par Flutter ya Android Studio install karne ki zaroorat nahi hai! Bas yeh 4 steps karein:

1. **GitHub par free account banayein** (github.com) aur upar `+` se **New Repository** banayein (naam rakhein `78-agency-alarm`).
2. Is ZIP file ko **unzip (extract)** karein aur andar ki saari files (including `.github` folder) GitHub repository mein upload karke **Commit** kar dein.
3. GitHub par upar **Actions** tab kholein — **"Build 78 Agency Alarm APK"** workflow khud chal padega (ya **"Run workflow"** button daba dein).
4. 3–4 minute mein green tick (✓) aa jayega. Us run par click karein, neeche **Artifacts** section mein **`78-Agency-Alarm-APK`** par click karke download karein — uske andar `app-release.apk` hogi! Isko apne Android phone mein install kar lein.

---

## Laptop Par Local Build Karne Ka Tarika (Optional)
1. Flutter SDK & Android Studio install karein.
2. Folder mein terminal khol kar chalayein:
   ```bash
   flutter create . --platforms=android
   flutter pub get
   flutter build apk --release
   ```
3. `android_config` folder ki permissions `android/app/src/main/AndroidManifest.xml` aur `android/app/build.gradle` mein add karein.
