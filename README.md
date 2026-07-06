# TalkRight

An Android-based interactive learning application developed with Flutter to help elementary school students improve their English pronunciation through structured lessons, speech recognition, and gamified learning activities.

TalkRight provides real-time pronunciation feedback using Speech-to-Text technology, allowing learners to practice independently while tracking their learning progress through achievements, assessments, and lesson completion. The application is designed to work entirely offline, making it suitable for schools and learners with limited internet connectivity.

---

## ✨ Features

- 📖 Interactive pronunciation lessons
- 🎙️ Speech recognition with real-time pronunciation feedback
- 🔊 Text-to-Speech pronunciation guidance
- 🎮 Gamified learning experience
- 🏆 Achievement and badge system
- 📈 Progress tracking
- 📝 Interactive assessments and quizzes
- 🔔 Local notification reminders
- 💾 Offline functionality using local storage
- 👦 Child-friendly user interface

---

## 📱 Screenshots

> Screenshots will be added soon.

---

## 🛠️ Tech Stack

### Framework
- Flutter

### Programming Language
- Dart

### Local Storage
- SharedPreferences

### Speech & Audio
- speech_to_text
- flutter_tts
- audioplayers

### Notifications
- flutter_local_notifications

---

## 📦 Packages Used

| Package | Purpose |
|---------|---------|
| `speech_to_text` | Converts spoken words into text for pronunciation assessment. |
| `flutter_tts` | Reads words and sentences aloud to guide pronunciation. |
| `shared_preferences` | Stores learner progress, achievements, unlocked lessons, and application settings locally. |
| `audioplayers` | Plays lesson audio and sound effects. |
| `flutter_local_notifications` | Schedules reminder notifications for learners. |
| `qr_flutter` | Generates QR codes used within the application. |
| `timezone` | Supports accurate scheduling of local notifications. |

---

## 📂 Project Structure

```text
lib/
├── models/
├── screens/
├── services/
├── widgets/
├── utils/
└── main.dart
```

---

## 🚀 Getting Started

### Clone the repository

```bash
git clone https://github.com/loblachii/TalkRight-Flutter.git
```

### Install dependencies

```bash
flutter pub get
```

### Run the application

```bash
flutter run
```

---

## 🎯 Objectives

The application aims to:

- Improve English pronunciation proficiency among elementary school students.
- Provide engaging and interactive pronunciation practice.
- Encourage self-paced learning through gamification.
- Deliver real-time pronunciation feedback using Speech-to-Text.
- Support offline learning in environments with limited internet access.

---

## 💡 What I Learned

Through the development of this project, I gained practical experience in:

- Flutter mobile application development
- UI/UX design for educational applications
- Speech Recognition integration
- Text-to-Speech implementation
- Offline-first application development
- Local data persistence using SharedPreferences
- Mobile application architecture and project organization
- Designing gamified learning experiences

---

## 👥 Development Team

This application was developed collaboratively as part of an undergraduate capstone project.

| Member | Role |
|---------|------|
| **John Sean T. Bataclan** | Lead Developer, UI/UX Designer |
| **Aljo A. Labares** | Application Quality Assurance |
| **Frankleen Mae C. Legaspi** | Lead Documentation |
| **Jhonpaul Z. Jamiladan** | Documentation Quality Assurance |

---

## 👨‍💻 My Contributions

As the **Lead Developer** and **UI/UX Designer**, I was responsible for:

- Designing the application's UI and user experience.
- Developing the application using Flutter.
- Implementing Speech-to-Text pronunciation assessment.
- Integrating Text-to-Speech pronunciation guidance.
- Developing lesson navigation and learning flow.
- Implementing achievements and learner progress tracking.
- Managing offline data storage using SharedPreferences.
- Designing interactive assessments and gamified learning activities.
- Maintaining the application's codebase and overall project architecture.

---

## 📄 License

This project is shared for educational and portfolio purposes.