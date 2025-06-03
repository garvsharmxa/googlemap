![Simulator Screenshot - iPhone 16 Plus - 2025-06-03 at 17 30 57](https://github.com/user-attachments/assets/1192b250-b0ce-4276-94f6-a14208351c9f)# 🚖 Enhanced Google Maps Flutter App

A beautiful, modern Flutter app for **exploring places**, **searching locations**, viewing detailed info, and **planning routes** between two points—**inspired by top cab apps** like Uber and Ola. Enjoy a uniquely animated, glassmorphic, and dark-mode ready user experience.

---

![Google Maps Flutter Demo](https://user-images.githubusercontent.com/your-screenshot.png)

---

## ✨ Features

- **🌎 Interactive Google Map**
    - Gorgeous custom map styles for day & night, with smooth animated transitions.
- **🔎 Powerful Place Search**
    - Google Places Autocomplete for smart suggestions.
    - Tap to view details, or **long-press** to set as Pickup (A) or Drop (B).
- **🏙 Place Details**
    - Beautiful detail sheets with images, reviews, ratings, address, website, and opening hours—all in a frosted 3D glass panel.
- **📍 Custom Location Selection**
    - Tap anywhere on the map to set Location A (Pickup) or B (Drop).
    - **Drag** markers for pinpoint accuracy.
- **🚗 Route Planning**
    - Draws the driving route (via Google Directions API), with distance shown in kilometers.
- **🌗 Dark & Light Mode**
    - Instantly toggle between elegant day and night themes—UI and map included!
- **💎 Eye-Catching Animated UI**
    - 3D glassmorphic search bar, animated gradients, and floating glass buttons.
    - Smooth transitions and delightful touches throughout.

---

## 🖼️ Screenshots

![Simulator Screenshot - iPhone 16 Plus - 2025-06-03 at 17 30 57](https://github.com/user-attachments/assets/8ece2215-0acc-4f11-b451-7dd06f007903)

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Google Cloud API Key](https://console.cloud.google.com/apis/credentials)
    - Enable **Maps SDK for Android/iOS**, **Places API**, and **Directions API**.

---

### ⚡ Setup

#### 1. Clone the repository

```sh
git clone https://github.com/yourusername/enhanced-google-maps-flutter.git
cd enhanced-google-maps-flutter
```

#### 2. Update your API Key

Open the Dart file and replace:

```dart
static const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
```

with your API key.

#### 3. Add dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_maps_flutter: ^2.5.0
  http: ^1.1.0
  url_launcher: ^6.2.5
```

Then run:

```sh
flutter pub get
```

#### 4. Run the app

```sh
flutter run
```

---

### 📱 Android/iOS Setup

- Follow the [google_maps_flutter documentation](https://pub.dev/packages/google_maps_flutter) for platform-specific setup:
    - Add your API key to `AndroidManifest.xml` (Android)
    - Add your API key to `AppDelegate.swift` (iOS)

---

## 🕹 How to Use

- **Search** for any place using the top bar.
- **Long-press** a search result to set as Pickup (A) or Drop (B).
- **Tap** "Loc A"/"Loc B" widgets, then tap the map to pick manually.
- **Drag** markers to fine-tune location.
- **Tap the route icon** to draw the route and see distance.
- **Clear** locations and routes with the clear icon.
- **Switch themes** using the sun/moon icon.

---

## 🎨 Customization

- Change initial location by editing `initialPosition` in the Dart file.
- Tweak UI colors, gradients, and map styles for your own branding.
- Expand with more features: cab booking simulation, multi-stop routes, fare calculation, or real-time cab tracking.

---

## 📄 License

Licensed under the [MIT License](LICENSE).

---

<p align="center">
  <b>Made with ♥ using Flutter & Google Maps</b>
</p>
