# 🚀 Cue – Technical Documentation

**Version:** `1.0.0+14`  
**Last Updated:** `February 12, 2026`

Cue is a voice-first, socially-powered reminder system built with Flutter and Firebase.  
This document provides a complete technical overview of the system architecture, core components, and engineering decisions behind Cue.

---

## 📑 Table of Contents

1. [Tech Stack Overview](#-tech-stack-overview)
2. [System Architecture](#-system-architecture)
3. [Firebase Integration](#-firebase-integration)
4. [Notification System](#-notification-system)
5. [RevenueCat Integration](#-revenuecat-integration)
6. [Voice & Transcription](#-voice--transcription)
7. [Data Models](#-data-models)
8. [Security & Permissions](#-security--permissions)
9. [Performance Optimization](#-performance-optimization)
10. [Testing & Debugging](#-testing--debugging)
11. [Production Deployment](#-production-deployment)
12. [Links & Resources](#-links--resources)

---

## 🧱 Tech Stack Overview

### Frontend (Mobile)
- **Framework:** Flutter 3.10.7 (Dart)
- **State Management:** Provider + ChangeNotifiers
- **UI:** Material (Android) + Cupertino (iOS)
- **Responsive Layouts:** `flutter_screenutil`

### Backend & Cloud
- **Auth:** Firebase Authentication  
- **Database:** Cloud Firestore (NoSQL)  
- **Functions:** Firebase Cloud Functions (Node.js + TypeScript)  
- **Storage:** Firebase Storage  
- **Push Notifications:** Firebase Cloud Messaging (FCM)

### Key Dependencies

```yaml
firebase_core: ^2.24.2
firebase_auth: ^4.16.0
cloud_firestore: ^4.14.0
cloud_functions: ^4.5.12
firebase_storage: ^11.5.6
firebase_messaging: ^14.7.10

flutter_local_notifications: ^16.3.0
timezone: ^0.9.2
permission_handler: ^11.1.0

flutter_sound:
http:

purchases_flutter: ^9.10.8
flutter_screenutil:
url_launcher: