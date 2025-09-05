# Rumi Talk

A Flutter application integrated with Firebase services including Authentication and Cloud Firestore.

## Features

- ✅ Firebase Core integration
- ✅ Firebase Authentication
- ✅ Cloud Firestore database
- ✅ Cross-platform support (iOS & Android)

## Prerequisites

- Flutter SDK (latest stable version)
- Firebase CLI
- Xcode (for iOS development)
- Android Studio/VS Code

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/highshore/rumi_talk.git
cd rumi_talk
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration

The app is already configured with Firebase. The configuration files are:

- `lib/firebase_options.dart` - Firebase configuration
- `android/app/google-services.json` - Android configuration (auto-generated)
- `ios/Runner/GoogleService-Info.plist` - iOS configuration (auto-generated)

### 4. Run the App

```bash
# For debug mode
flutter run

# For release mode
flutter run --release
```

## Firebase Services

### Authentication
Firebase Authentication is set up and ready to use. You can implement sign-in methods like:
- Email/Password
- Google Sign-In
- Apple Sign-In
- Anonymous authentication

### Cloud Firestore
Cloud Firestore is configured for real-time database functionality. Features include:
- Real-time data synchronization
- Offline support
- Scalable NoSQL database

## Development

### Adding New Firebase Services

To add more Firebase services:

1. Install the required Flutter package:
```bash
flutter pub add firebase_service_name
```

2. Update Firebase configuration if needed:
```bash
flutterfire configure
```

### Security Rules

Firestore security rules are defined in:
- `firestore.rules` - Database security rules
- `firestore.indexes.json` - Database indexes

Deploy rules with:
```bash
firebase deploy --only firestore:rules
```

## Build & Deploy

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Resources

- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
- [FlutterFire Plugins](https://firebase.flutter.dev/)
- [Flutter Documentation](https://docs.flutter.dev/)

## License

This project is open source and available under the [MIT License](LICENSE).
