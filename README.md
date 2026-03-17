# SafeTrack 🛡️

**SafeTrack** is a premium, high-security personal safety application designed to provide peace of mind during late-night travels or uncertain situations. Built with Flutter and integrated with powerful real-time services, SafeTrack ensures that you are never truly alone.

---

## 🔥 Core Features

### 🆘 SOS Emergency System
*   **One-Tap Trigger**: Initiate an emergency sequence instantly from the home screen.
*   **Direct Calling**: Automatically dials your primary trusted contact.
*   **Smart SMS Alerts**: Sends your live GPS location link to all trusted contacts.
*   **Local High-Intensity Alarm**: Plays a loud sound to alert nearby people or deter potential threats.

### 📍 Live Journey Tracking
*   **Smart Routing**: Plan your journey with road-locked navigation powered by **OpenRouteService**.
*   **Active Monitoring**: Shared live coordinates with guardians during your trip.
*   **Real-Time Status**: Visual indicators on a "Midnight" themed map showing progress and current risk levels.

### 👥 Guardian Ecosystem
*   **Trusted Contacts**: Add and manage key people who will receive your alerts.
*   **Guardian View**: A dedicated simulation view that allows contacts to track your journey in real-time on their own devices.
*   **Push Notifications (FCM)**: Immediate alerts sent to guardians when a journey starts or an SOS is triggered.

### 🌒 Premium "Midnight" UI
*   **Glassmorphism Status Headers**: Modern, semi-transparent overlays for high visual density.
*   **Capsule Action Buttons**: Sleek, tactile buttons with vibrant gradients.
*   **Dark Mode Optimization**: Designed for low-light environments to reduce eye strain and provide a stealthy, professional look.

---

## 🏗️ Technical Architecture

### 📱 Frontend
*   **Flutter (Dart)**: Multi-platform mobile application development.
*   **Google Maps SDK**: High-performance map rendering and interactive navigation.
*   **Custom Material 3**: Tailored UI system with glassmorphism and custom components.

### ☁️ Backend & Services
*   **Firebase Authentication**: Secure user login and signup lifecycle.
*   **Cloud Firestore**: Real-time database for live location synchronization and journey states.
*   **Firebase Cloud Messaging (FCM)**: Cross-platform push notifications.
*   **OpenRouteService API**: Professional-grade routing and pathfinding.

---

## 🛣️ User Workflow

1.  **Onboarding**: Secure login/signup via the **SafeTrack** portal.
2.  **Configuration**: Add trusted contacts who will receive emergency alerts.
3.  **Initiation**: 
    *   Tap the **SOS** button for immediate danger.
    *   Tap **Start Journey** to begin a monitored trip to a destination.
4.  **Monitoring**: During a journey, the app updates Firestore with live coordinates.
5.  **Guardian Alert**: Trusted contacts receive a notification and can tap "Track Now" to see the live progress.
6.  **Resolution**: End the journey safely or stop the emergency alarm.

---

## 🚀 Getting Started

1.  **Clone code**: `git clone <repo-url>`
2.  **Setup Assets**: Ensure `assets/logo.png` is present.
3.  **Firebase Config**: Add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS).
4.  **API Keys**: Add your Google Maps and OpenRouteService keys in `constants.dart` and `AndroidManifest.xml`.
5.  **Run**: `flutter run`

---
*Created with care by the SafeTrack Development Team.*
