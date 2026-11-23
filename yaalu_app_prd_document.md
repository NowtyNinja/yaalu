# Product Requirements Document (PRD) & Technical Architecture
**Project Name:** Yaalu (Casual Dating & Social Discovery App)  
**Target Platform:** Cross-Platform (iOS & Android)  
**Target Audience:** Sri Lankan Youth & Professionals (Primary) + Global Sri Lankan Diaspora (Secondary)  
**Prepared By:** Product Management & Engineering Architecture Team  

---

## 1. Executive Summary & Business Architecture

### 1.1 Brand Identity & Vision
**Yaalu** leverages a warm, culturally resonant Sri Lankan identity while maintaining a sleek, modern international app experience. The platform prioritizes user safety, genuine connections, and seamless monetization tailored to both local and global markets.

### 1.2 User Segmentation
* **Local Market (Sri Lanka):** Gen Z & Millennials (18–34) seeking casual dating, friendship, or networking. High demand for photo security, localized matching algorithms, and Sri Lankan payment methods.
* **Global / Diaspora:** International users and Sri Lankans overseas using location spoofing (Passport Feature) to connect with people back home or in specific cities worldwide.

### 1.3 Monetization Engine (Freemium + Subscription Model)

#### **Free Tier**
* Basic profile creation & AI selfie verification.
* Daily swipe limit (15 swipes / 24 hours).
* Location-based discovery radius (up to 50 km).
* Standard text messaging upon mutual match.

#### **Paid Tier: Yaalu VIP / Gold**
* **Free Trial:** 3-Day or 7-Day trial activated upon adding payment details.
* **Subscription Billing Cycles:** Weekly, Monthly, 3-Month, and Annual options.
* **VIP Features:**
  * **Unlimited Swiping & Rewind:** Infinite daily swipes + undo accidental left swipes.
  * **See Who Liked You:** Instant grid view of profiles that swiped right on the user.
  * **Yaalu Passport:** Teleport GPS coordinates to any city or country globally.
  * **Stealth / Incognito Mode:** Profile visibility restricted only to users whom the subscriber has swiped right on.
  * **Profile Boost:** 1-hour stack boost to top visibility per week.
  * **Super Yaalu (Super Likes):** 5 Super Likes per week with optional short intro messages.

#### **Payment Gateway Architecture**
* **International Transactions:** Apple In-App Purchase (IAP) & Google Play Billing.
* **Sri Lanka Local Payments:** PayHere API / WEBXPAY SDK integration (Cards, eZ Cash, Frimi, Genie).

---

## 2. Technical & System Architecture

### 2.1 Recommended Tech Stack
* **Mobile App Framework:** **Flutter** (Single codebase targeting iOS & Android for high UI performance and reduced cost).
* **Backend Infrastructure:** **Node.js (NestJS)** or **Python (FastAPI)** for high concurrency API routing and socket handling.
* **Databases:**
  * **PostgreSQL / MongoDB:** Primary datastore for user profiles, preferences, match history, and payment ledgers.
  * **Redis:** High-speed in-memory cache for online user state, active swipe stacks, and session tokens.
* **Real-time Messaging:** **Socket.io** over WebSockets for instant chat and typing indicators.
* **Cloud & CDN:** **AWS** (EC2 / ECS, S3 for secure image storage, CloudFront CDN for global low-latency media delivery).
* **AI Security Services:** AWS Rekognition / OpenCV for face liveness checking during selfie onboarding.

### 2.2 Security & Anti-Fraud Mechanisms
1. **Screen Capture Protection:**
   * Android: `FLAG_SECURE` enabled on sensitive profile and message screens.
   * iOS: Automatic background blur and window hiding on screen record/screenshot events.
2. **Data Security:** End-to-end HTTPS/TLS 1.3 for network transport; AES-256 field-level encryption for sensitive PII (Phone numbers, auth tokens).
3. **Bot Prevention:** Mandatory SMS OTP registration via Twilio / Dialog SMS API + IP rate limiting.

---

## 3. UI/UX Design System & User Flows

### 3.1 UI Vibe & Aesthetic
* **Color Palette:** Warm Coral Accent (`#FF5A5F`), Midnight Navy Dark Mode Baseline (`#121824`), Pure White (`#FFFFFF`).
* **Typography:** Clean, sans-serif fonts (Inter / SF Pro) optimized for mobile reading.

### 3.2 High-Level Architecture Flow

```
[Onboarding & Auth] -> [AI Selfie Verification] -> [Profile Builder] -> [Swipe Engine Stack]
                                                                                |
             +-----------------------+------------------------------------------+-----------------------------------+
             |                       |                                          |                                   |
    [Swipe Left / Right]   [Match Overlay Modal]                    [Messaging Hub]                     [User Profile & Settings]
                                     |                                          |                                   |
                             [Initiate Chat]                    [Text / Voice / Media]              [Paywall & VIP Subscription]
```

### 3.3 Core Screen Checklist
1. **Onboarding & Auth:** Phone OTP, Apple/Google OAuth, interactive multi-step profile builder (Interests, Dating Intention: Casual, Coffee, Travel, etc.), and Liveness Verification UI.
2. **Discovery Card Stack:** Gestural card stack (Swipe Left/Right, Swipe Up for Super Like), multi-photo tap preview, expand profile detail drawer, floating control dock.
3. **Match & Chat Center:** Interactive list of mutual matches, grid of active likes, real-time message stream supporting text, voice notes, and image blur toggles.
4. **Profile & Monetization Hub:** VIP upgrade banner, payment modal, interactive filter drawer (Age, Distance radius, Incognito mode toggle).

---

## 4. Feature Implementation Matrix

| Feature ID | Module | Technical Description | Priority |
| :--- | :--- | :--- | :--- |
| **YA-01** | User Auth | Phone OTP, Google/Apple OAuth, Token Management | P0 (Must Have) |
| **YA-02** | Selfie Check | AI facial verification matching profile photo to live capture | P0 (Must Have) |
| **YA-03** | Geo Engine | Location calculation algorithms using Spatial Indexing (PostGIS/MongoDB Geospatial) | P0 (Must Have) |
| **YA-04** | Swipe Stack | Stack queueing system, match detection triggering mutual webhooks | P0 (Must Have) |
| **YA-05** | Real-Time Chat | WebSockets integration, media upload to AWS S3, delivery receipts | P0 (Must Have) |
| **YA-06** | Subscriptions | Dual integration of Mobile Store IAP + PayHere Local Gateway | P0 (Must Have) |
| **YA-07** | Yaalu Passport | Custom lat/lng override for location switching | P1 (High) |
| **YA-08** | Anti-Privacy | Screenshot restriction triggers, blur filters, report/block module | P0 (Must Have) |
| **YA-09** | Notifications | Firebase Cloud Messaging (FCM) & Apple Push Notification service (APNs) | P1 (High) |

---

## 5. Development Roadmap & Milestones

* **Sprint 1 (Weeks 1–2):** Architecture setup, Figma UI/UX design components, database schema definitions.
* **Sprint 2 (Weeks 3–6):** MVP Core build (Authentication, Swipe Logic, Socket Chat, Admin Portal).
* **Sprint 3 (Weeks 7–8):** Subscriptions (PayHere + IAP), Privacy/Security enforcement, AI verification integration.
* **Sprint 4 (Week 9):** Penetration testing, performance tuning, Closed Beta testing (50–100 testers).
* **Sprint 5 (Week 10):** Production deployment to Apple App Store & Google Play Store.