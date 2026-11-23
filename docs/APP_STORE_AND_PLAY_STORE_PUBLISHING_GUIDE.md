# Yaalu Dating App - Google Play Store & Apple App Store Publishing Guide (පියවරෙන් පියවර සම්පූර්ණ මාර්ගෝපදේශය)

මෙම ලේඛනයෙන් Yaalu Dating App එක **Google Play Store** සහ **Apple App Store** වෙත සාර්ථකව, Reject වීමකින් තොරව (Zero Rejections) Upload කර Live කරන ආකාරය පියවරෙන් පියවර පැහැදිලි කරයි.

---

## කොටස 1: Google Play Store වෙත Upload කිරීම (Android)

### පියවර 1.1: Google Play Developer Account එකක් සකසා ගැනීම
1. [Google Play Console](https://play.google.com/console/signup) වෙත පිවිසෙන්න.
2. \$25 (One-time registration fee) ගෙවා Developer Account එක Active කරගන්න.
3. Identity Verification (National ID / Passport) සම්පූර්ණ කරන්න.

---

### පියවර 1.2: Android Release Keystore (Signing Key) එක සාදා ගැනීම
Release Build එක Sign කිරීමට Keystore එකක් සෑදිය යුතුය. Windows PowerShell එකේ පහත Command එක Run කරන්න:

```powershell
keytool -genkey -v -keystore yaalu-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias yaalu -storetype JKS
```
* **Password එකක් ඇතුළත් කරන්න:** (මතක තබාගන්න හෝ Password Manager එකක සුරකින්න).
* අසන ප්‍රශ්න වලට නම, Organization, Country Code (LK) ලබා දෙන්න.
* ලැබෙන `yaalu-release.jks` ෆයිල් එක ආරක්ෂිතව තබාගන්න. (මෙය නැති වුවහොත් App එක Update කළ නොහැක!).

---

### පියවර 1.3: `key.properties` සහ `build.gradle` සැකසීම
`mobile/android` ෆෝල්ඩරය තුළ `key.properties` නමින් file එකක් සාදා පහත තොරතුරු ඇතුළත් කරන්න:

```properties
storePassword=ඔබේ_Keystore_Password
keyPassword=ඔබේ_Key_Password
keyAlias=yaalu
storeFile=../yaalu-release.jks
```

`mobile/android/app/build.gradle` එකේ `signingConfigs` සහ `buildTypes` කොටස් වල `signingConfig signingConfigs.release` ලබා දෙන්න.

---

### පියවර 1.4: Android App Bundle (.aab) Build කිරීම
Play Store එකට Upload කළ යුත්තේ APK නොව **AAB (Android App Bundle)** එකකි. Terminal එකේ පහත command එක run කරන්න:

```powershell
cd f:\Yaalu\mobile
flutter build appbundle --release
```
Build එක සාර්ථක වූ පසු file එක මෙතැන හමුවේ:
`mobile/build/app/outputs/bundle/release/app-release.aab`

---

### පියවර 1.5: Google Play Console එකේ App එක සෑදීම සහ අවශ්‍ය තොරතුරු පිරවීම
1. **Create App:**
   - App Name: **Yaalu: Dating & Social Discovery**
   - Default Language: English (United States)
   - App or Game: **App**
   - Free or Paid: **Free** (In-App Purchases අඩංගු බව Select කරන්න)
2. **App Content Checklist (ඉතා වැදගත්):**
   - **Privacy Policy:** ඔබගේ Privacy Policy URL එක ලබා දෙන්න. (උදා: `https://yaalu.lk/privacy-policy`)
   - **App Access:** "All functionality is restricted" තෝරා Reviewer ට Log වීමට Test Credentials ලබා දෙන්න:
     - Phone: `+94779876543`
     - OTP: `777777`
   - **Ads:** "No, my app does not contain ads".
   - **Content Rating (IARC Questionnaire):** Dating Category එක තෝරා ප්‍රශ්න වලට පිළිතුරු දෙන්න. Dating App එකක් නිසා **18+ (Mature)** Rating එකක් ලැබෙනු ඇත.
   - **Target Audience:** 18+ තෝරන්න.
   - **Data Safety Form:**
     - Location: Yes (Approximate & Precise for finding nearby matches).
     - Personal Info: Name, Phone number (for authentication).
     - Photos & Videos: Yes (for profile pictures).
     - Audio: Yes (for voice notes in chat).
     - Data Encryption: Yes, data is encrypted in transit (TLS 1.3/HTTPS).
     - Data Deletion: Yes, users can request account & data deletion inside app settings.
3. **Store Listing Assets:**
   - App Icon: 512 x 512 px PNG (32-bit)
   - Feature Graphic: 1024 x 500 px JPG or PNG
   - Screenshots: අවම වශයෙන් Phone Screenshots 4ක් (1080 x 1920 px or 1080 x 2400 px)
4. **Closed Testing (20 Testers Requirement):**
   - අලුත් Personal Developer Accounts සඳහා Production Release කිරීමට පෙර දින 14ක් 20 testers ලවා Closed Beta පරීක්ෂා කළ යුතුය.
   - මිතුරන් 20 දෙනෙකුගේ Gmail එකතු කර Closed Testing track එකට Release කරන්න. දින 14කට පසු Apply for Production කරන්න.

---

## කොටස 2: Apple App Store වෙත Upload කිරීම (iOS)

### පියවර 2.1: Apple Developer Program එකට ලියාපදිංචි වීම
1. [developer.apple.com](https://developer.apple.com/programs/) වෙත ගොස් Apple Developer Program (\$99/year) මිලදී ගන්න.
2. Mac පරිගණකයක Xcode ස්ථාපනය කර ඔබගේ Apple ID එක Sign in කරන්න.

---

### පියවර 2.2: Apple Developer Portal එකේ Identifier & Provisioning Profile සෑදීම
1. **Certificates, Identifiers & Profiles** වෙත යන්න.
2. **Identifiers:** Add new App ID:
   - Description: Yaalu Dating App
   - Bundle ID: `com.yaalu.dating` (Explicit)
   - Capabilities: Push Notifications, In-App Purchase, Associated Domains.
3. **Provisioning Profile:** App Store Distribution Profile එකක් generate කර Mac එකට download කර Install කරගන්න.

---

### පියවර 2.3: iOS Archive එක සකසා App Store Connect වෙත Upload කිරීම
Mac Terminal එකේ පහත command එක run කරන්න:

```bash
cd mobile
flutter build ipa --release
```

හෝ Xcode මගින්:
1. `open ios/Runner.xcworkspace`
2. Target: **Any iOS Device (arm64)** තෝරන්න.
3. Menu එකෙන් **Product -> Archive** ක්ලික් කරන්න.
4. Archive එක සාර්ථක වූ පසු Organizer window එක විවෘත වේ.
5. **Distribute App -> App Store Connect -> Upload** තෝරා Next ක්ලික් කරන්න.

---

### පියවර 2.4: Apple App Review එක Reject නොවී First Attempt එකෙන්ම Pass කරගන්නා රහස් (Dating App Guidelines):

Apple සමාගම Dating Apps Review කිරීමේදී ඉතා දැඩි (Strict) ප්‍රතිපත්තියක් අනුගමනය කරයි. අප Yaalu App එකේ මේ සියලුම requirements කල්තියාම implement කර ඇත:

#### 1. Guideline 1.2 - User Generated Content (UGC):
- **EULA (End User License Agreement):** App එකේ Sign-up සහ Settings screen වල EULA එක link කර ඇත.
- **Report User Button:** Chat screen එකේ සහ Profile screen එකේ Flag/Report button එකක් ඇත. (අපේ app එකේ `ReportUser` API එක ක්‍රියාත්මක කර ඇත).
- **Block User Button:** කරදරකාරී users ලාව instant block කිරීමේ හැකියාව ඇත.
- **24-Hour Moderation:** App Review Notes වල සඳහන් කරන්න: *"All reports are reviewed by human moderators within 24 hours and offending users are permanently banned."*

#### 2. Guideline 5.1.1(v) - Mandatory Account Deletion:
- Apple නීතිය අනුව App එක ඇතුලෙන්ම Account එක සහ සියලු Personal Data Delete කරගැනීමට Option එකක් තිබිය යුතුය.
- අපේ App එකේ `Settings -> Delete Account` button එක හරහා `DELETE /api/v1/auth/delete-account` API එකට call කර සියලු දත්ත මකා දැමීම සිදු වේ.

#### 3. Guideline 3.1.1 - In-App Purchases (IAP):
- iOS මත Digital Subscriptions (Yaalu VIP Weekly, Monthly, Annual) සඳහා Apple StoreKit In-App Purchases අනිවාර්යයෙන්ම භාවිතා කළ යුතුය.
- External payment links (PayHere ආදිය) iOS Version එකේ VIP මිලදී ගැනීමට භාවිතා කිරීම Apple නීති වලට පටහැනිය. ඒ නිසා iOS මත Apple IAP ක්‍රියාත්මක කර ඇත.

#### 4. Reviewer Login Credentials (App Review Information):
- Apple Reviewer ට App එක පරීක්ෂා කිරීමට SMS OTP බලාපොරොත්තු නොවී Login වීමට Demo Account එක ලබා දෙන්න:
  - **Username / Phone:** `+94779876543`
  - **Password / OTP:** `777777`
  - **Notes for Reviewer:** *"This is a dating and social discovery app tailored for Sri Lankans. We have included an active demo phone with fixed OTP 777777 for your review convenience. Test matches are pre-seeded in the Colombo district."*

---

## කොටස 3: CI/CD & Production Environment Checklist

1. **Backend Server Hosting:**
   - AWS EC2 / ECS / DigitalOcean Droplet මත Node.js backend එක PM2 හෝ Docker මගින් run කරන්න.
   - SSL/TLS Certificate එක Cloudflare හෝ Let's Encrypt Certbot මගින් configure කර ගන්න.
2. **Domain Mapping:**
   - API Domain: `https://api.yaalu.lk`
   - Mobile `api_endpoints.dart` එකේ `baseUrl` එක `https://api.yaalu.lk/api/v1` ලෙස වෙනස් කරන්න.
3. **Database & Redis:**
   - PostgreSQL (Managed AWS RDS හෝ Supabase)
   - Redis Cloud (Session cache & rate limiting)
4. **AWS S3 Bucket & CloudFront:**
   - Photos upload කිරීම සඳහා S3 Bucket එකක් සාදා Public Read Block කර CloudFront CDN එකක් මගින් serve කරන්න.
