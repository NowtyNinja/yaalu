# Yaalu (යාලු) - Casual Dating & Social Discovery App

Cross-Platform (iOS & Android) Dating App designed for Sri Lankan Youth & Global Diaspora.

## 📁 Repository Structure

```
Yaalu/
├── backend/                                  # High-Security Node.js / TypeScript API & WebSockets
│   ├── src/
│   │   ├── config/                           # Environment & Secret configs
│   │   ├── controllers/                      # Auth, Discovery, Swipes, Chat, Payments, Verification
│   │   ├── database/                         # Zero-injection data store & spatial engine
│   │   ├── middlewares/                      # Zod validation, RateLimiters, Security Headers, Auth
│   │   ├── models/                           # User, Profile, Match, Message, Payment types
│   │   ├── routes/                           # Modular API routes (/api/v1)
│   │   ├── sockets/                          # Real-time Socket.io chat server
│   │   ├── utils/                            # Geo calculation, Structured Logger, Response envelopes
│   │   ├── app.ts                            # Express application setup
│   │   └── server.ts                         # Server entry point
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
├── mobile/                                   # Cross-Platform Flutter Mobile Application
│   ├── lib/
│   │   ├── core/                             # Constants, Colors, Themes, Secure Storage, API Client
│   │   ├── models/                           # User, Profile, Match, Message, Plan models
│   │   ├── providers/                        # Auth, Discovery, Chat, VIP Providers
│   │   ├── screens/                          # Auth, Onboarding, Discovery Stack, Chat, VIP Paywall, Settings
│   │   └── main.dart                         # Flutter entry point
│   ├── android/                              # Hardware FLAG_SECURE & Network Security Config
│   ├── ios/                                  # App Store permissions & configuration
│   └── pubspec.yaml
└── docs/
    ├── SECURITY_AUDIT_AND_HARDENING.md       # Zero-Trust & Zero-Injection Architecture Report
    └── APP_STORE_AND_PLAY_STORE_PUBLISHING_GUIDE.md # Sinhala & English Step-by-Step Publishing Guide
```

## 🚀 Quick Start Guide

### 1. Run Backend Server
```bash
cd backend
npm install
npm run build
npm start
```
* API Server will start at `http://localhost:5000/api/v1`
* Health Check: `http://localhost:5000/api/v1/health`

### 2. Run Mobile Application
```bash
cd mobile
flutter pub get
flutter run
```

### 3. Demo Test Account for Reviewers & Developers
* **Phone:** `+94779876543`
* **SMS OTP:** `777777`
