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

### Onboarding Module

<img width="462" height="342" alt="image" src="https://github.com/user-attachments/assets/04562e9a-24a7-4efa-b1e9-c124d88c0cb3" />
<img width="769" height="339" alt="image" src="https://github.com/user-attachments/assets/e7fc35aa-b1f8-4d61-ae71-24080ac4c1f9" />
<img width="465" height="342" alt="image" src="https://github.com/user-attachments/assets/585bb32e-75ec-4943-b00e-3caae623147f" />


---

### Home Module

<img width="420" height="463" alt="image" src="https://github.com/user-attachments/assets/721177b1-f0a3-4357-8bf6-429e387d8541" />
<img width="720" height="268" alt="image" src="https://github.com/user-attachments/assets/1c166224-e2dc-482f-9877-631b782b917d" />
<img width="481" height="798" alt="image" src="https://github.com/user-attachments/assets/05f710fe-9620-4719-8be0-fa2835492616" />
<img width="649" height="288" alt="image" src="https://github.com/user-attachments/assets/6b55e806-c6b0-4a27-a4f8-2d1f7a11ecd8" />
<img width="390" height="290" alt="image" src="https://github.com/user-attachments/assets/c3598c17-d04d-4d83-b3e9-be6aaf86e04b" />
<img width="441" height="327" alt="image" src="https://github.com/user-attachments/assets/64121eda-dc36-476d-ba8b-47d582e49312" />


---

### Assessment Module

<img width="272" height="598" alt="image" src="https://github.com/user-attachments/assets/a705e445-fb25-4a34-a32b-f91ffc3f1deb" />
<img width="746" height="552" alt="image" src="https://github.com/user-attachments/assets/0f32e286-a090-42d2-b30b-f982a0e4698e" />
<img width="510" height="376" alt="image" src="https://github.com/user-attachments/assets/4b95e9bd-42f2-4cec-95a5-186c393de7fb" />
<img width="508" height="376" alt="image" src="https://github.com/user-attachments/assets/2b9fc9fb-81b2-462f-ab01-51fcf5960e72" />
<img width="509" height="377" alt="image" src="https://github.com/user-attachments/assets/16d94a85-48ad-405b-9ea0-8687bb9c0304" />
<img width="747" height="551" alt="image" src="https://github.com/user-attachments/assets/887c16a6-76d2-4b89-9104-05cf9f322c4e" />


---

### Profile Module

<img width="411" height="454" alt="image" src="https://github.com/user-attachments/assets/dc7fa06a-90af-4791-ae23-c49ec379acb8" />
<img width="209" height="455" alt="image" src="https://github.com/user-attachments/assets/7b8e7bf2-ca4a-4896-b017-2af25c2b49eb" />


---

### Settings Module

<img width="245" height="538" alt="image" src="https://github.com/user-attachments/assets/12695ead-8c10-4cec-b8cb-5e2ebae4db70" />


---

### About Module

<img width="259" height="568" alt="image" src="https://github.com/user-attachments/assets/85fc4299-f879-42d7-9d81-6e4bc5e9f4b7" />
<img width="513" height="569" alt="image" src="https://github.com/user-attachments/assets/fc6e03ce-3b61-4b4b-9cea-112d9704a8ad" />
<img width="514" height="569" alt="image" src="https://github.com/user-attachments/assets/40b77649-ea6d-4dfd-b3a4-d52c67894623" />
<img width="512" height="568" alt="image" src="https://github.com/user-attachments/assets/06af7d08-a113-4106-b32b-38cfb4ddd07a" />


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
