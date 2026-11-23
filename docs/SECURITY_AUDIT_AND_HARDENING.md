# Yaalu Dating App - Security Architecture & Threat Defense Report

## 1. Executive Summary & Zero-Trust Posture
**Yaalu** is engineered with a **Defense-in-Depth, Zero-Trust Architecture**. Dating applications handle exceptionally sensitive PII (Personally Identifiable Information), biometric facial scans, private chats, geolocation coordinates, and financial billing. 

Every tier of the system (Mobile Client, API Gateway, Real-Time WebSockets, Database Engine) operates under the assumption that the network is hostile and client inputs are untrusted.

---

## 2. Threat Vector Mitigation Matrix

| Threat / Vulnerability | OWASP Category | Defense Implementation in Yaalu |
| :--- | :--- | :--- |
| **SQL & NoSQL Injection** | OWASP Top 10 A03:2021 | 100% Parameterized queries; Zod schema runtime validation; NoSQL operator stripping (`$gt`, `$where`, `$regex`); Strict regex on phone numbers and IDs. |
| **Cross-Site Scripting (XSS)** | OWASP Top 10 A03:2021 | Deep input sanitizer recursively stripping script tags, null bytes `\0`, and encoding HTML entities; Content Security Policy (CSP) headers enabled via Helmet. |
| **Insecure Direct Object Reference (IDOR)** | OWASP Top 10 A01:2021 | Strict tenant isolation. Chat messages, match histories, swipe stacks, and media blur toggles verify ownership at the query level before execution. |
| **Brute Force & SMS Bombing** | OWASP Top 10 A07:2021 | Multi-tier sliding window rate limiters: max 10 auth requests per 15 min; max 3 OTP attempts before invalidation; max 30 swipes/min. |
| **Information Disclosure & CWE-532** | OWASP Top 10 A05:2021 | Structured logger automatically redacts passwords, JWT tokens, OTPs, CVVs, and credit card numbers; Stack traces hidden in production. |
| **HTTP Parameter Pollution (HPP)** | OWASP API3:2023 | Express `hpp()` middleware active to eliminate array pollution attacks on query parameters. |
| **Timing Attacks on Signatures** | Cryptographic Weakness | Constant-time comparisons using `crypto.timingSafeEqual` for PayHere IPN hash verification and HMAC checks. |
| **EXIF Location Leakage** | Privacy Violation | Images uploaded are re-encoded to strip GPS coordinates and camera hardware metadata, protecting user physical locations. |
| **Hardware Screen Scraping / Spyware** | Mobile Security | Android `FLAG_SECURE` hardware flag active on `MainActivity.kt`. Blocks OS screenshots, screen recording, and casting. |
| **Cleartext Transmission** | Network Security | Enforced TLS 1.3 / HTTPS via Android `network_security_config.xml` and HSTS header (`max-age=31536000`). |

---

## 3. Deep Dive: Zero-Injection Architecture

### 3.1 Eliminating SQL / NoSQL Injection
In Yaalu, no user input is ever concatenated into raw query strings.
- **DTO Validation:** Every route executes through `validateSchema(zodSchema)`. If a malicious actor sends `phone: "' OR '1'='1' --"`, Zod immediately rejects the payload with HTTP 422 before any database or business logic is reached.
- **Recursive Sanitizer:** The `inputSanitizer` middleware traverses request bodies, query strings, and route parameters to strip object keys starting with `$` (preventing MongoDB operator injection) and prototype keys (`__proto__`, `constructor`).

```typescript
// Example from src/middlewares/security.ts:
if (k === '__proto__' || k === 'constructor' || k === 'prototype') continue;
if (k.startsWith('$')) continue; // Blocks NoSQL injection
```

### 3.2 Authentication & Session Hardening
- **Access Tokens:** Signed with HMAC-SHA256 (`HS256`) or asymmetric `RS256`, with a 15-minute expiration time.
- **Refresh Tokens:** Cryptographically long tokens (7-day validity) stored securely in `FlutterSecureStorage` (backed by Android Keystore and iOS Keychain).
- **Session Revocation:** On logout or account deletion, the refresh token is immediately blacklisted, and all active Socket.io connections for that `userId` are severed.

---

## 4. Mobile Client Security (Flutter)

### 4.1 Android `FLAG_SECURE`
Located in `mobile/android/app/src/main/kotlin/com/yaalu/dating/MainActivity.kt`:
```kotlin
window.setFlags(
    WindowManager.LayoutParams.FLAG_SECURE,
    WindowManager.LayoutParams.FLAG_SECURE
)
```
**Impact:**
1. When a user tries to screenshot a profile or chat, Android displays: *"Couldn't save screenshot. Taking screenshots isn't allowed by the app or your organization."*
2. In the recent apps switcher, the screen renders as a blank black preview, preventing background snooping.

### 4.2 Secure Storage
Tokens are never stored in standard unencrypted `SharedPreferences` or `UserDefaults`. They are written via `flutter_secure_storage`:
- Android: Encrypted using AES encryption with hardware master key stored in Android Keystore.
- iOS: Protected by Apple Keychain with `kSecAttrAccessibleAfterFirstUnlock`.

---

## 5. PayHere Sri Lanka Payment Gateway Security

### 5.1 Signature Verification (MD5 / SHA256)
When PayHere calls `/api/v1/payments/payhere/notify`, attackers might try to spoof successful payment webhooks.
Yaalu validates the webhook signature:
```typescript
const hashedSecret = crypto.createHash('md5').update(merchantSecret).digest('hex').toUpperCase();
const expectedHashString = `${merchant_id}${order_id}${payhere_amount}${payhere_currency}${status_code}${hashedSecret}`;
const expectedSig = crypto.createHash('md5').update(expectedHashString).digest('hex').toUpperCase();

// Constant-time comparison prevents side-channel timing attacks:
const isValid = crypto.timingSafeEqual(Buffer.from(expectedSig), Buffer.from(md5sig));
```
If the signature does not match, the transaction is rejected and a security alert is logged.
