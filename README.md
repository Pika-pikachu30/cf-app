# CP Mentor AI (Codeforces Companion)

CP Mentor AI is a cross-platform application (built with Flutter) bundled with a high-performance Python FastAPI backend. It serves as an ultimate companion for competitive programmers on Codeforces. It provides real-time rating predictions, AI-driven problem hints, personalized training recommendations, and robust lifetime performance analytics.

## Features

- **Accurate Rating Predictor**: Simulates Codeforces ELO rating changes efficiently using FFT (Fast Fourier Transform) math and active pool size zero-sum corrections, providing predictions that mirror the official Codeforces algorithm across Div 1, Div 2, Div 3, Div 4, and Educational rounds.
- **AI Mentor & Hints**: Integrates with Google's Gemini AI to analyze your recent performances, weak topics, and suggest custom problem tags. Get stuck on a problem? The AI Hint page will help you without giving away the exact solution.
- **Lifetime Performance Analysis**: Aggregates all your combined Codeforces submissions to build a comprehensive view of your strengths, weaknesses, and consistency.
- **Friends Comparison**: Add multiple Codeforces handles and compare rating progress, max ratings, and problem counts.
- **Multi-Platform Support**: Built natively on Flutter for Android, iOS, Web, Windows, macOS, and Linux.

## Tech Stack

### Frontend (Flutter)
- Framework: Flutter / Dart
- HTTP Client: `http` (with CORS handling for web)
- UI Integrations: Animated widgets, responsive charts and Dashboards.
- Extensibility: Google Generative AI integration.

### Backend (Python FastAPI)
- Framework: FastAPI, Uvicorn
- Database: SQLite + SQLAlchemy ORM (for local user config auth & history)
- Algorithm: Complex FFT convolution and Binary Search models ported from renowned competitive programming standards (like Carrot/TLE) to compute rating changes.

## Project Structure
```text
.
├── lib/                             # Main Flutter frontend codebase
│   ├── dashboard/                   # UI components for statistics & predictions 
│   ├── chat/                        # AI-driven mentor conversation integration
│   ├── settings/                    # Preferences & auth
│   └── api_service.dart             # Core HTTP client proxy for Codeforces & AI
├── codeforces_tool_app_server_bk/   # Python FastAPI backend server
│   └── server/
│       ├── main.py                  # FastAPI application entry point
│       ├── predictor.py             # FFT/ELO mathematical rating core
│       ├── database.py              # SQLite configuration
│       └── routes.py                # Core App Endpoints (Login, API queries)
└── test/                            # Flutter automated tests
```

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable)
- [Python 3.9+](https://www.python.org/downloads/)

### Running the Python Backend
The backend proxy bypasses default Codeforces CORS restrictions for Web, powers the FFT rating predictor engine, and manages persistent auth.
```bash
cd codeforces_tool_app_server_bk/server
python -m venv venv
# Activate venv: `venv\Scripts\activate` on Windows or `source venv/bin/activate` on Unix
pip install fastapi "uvicorn[standard]" sqlalchemy requests pydantic pydantic[email] passlib[bcrypt] pyjwt
uvicorn main:app --reload --port 8000
```
*The server will be running at `http://127.0.0.1:8000`.*

### Running the Flutter Client
```bash
# From the root directory:
flutter pub get

# To run locally natively or on web:
flutter run
# If testing Web without starting the python proxy relay, bypass CORS:
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

## Contributing
1. Fork the project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Acknowledgements
- Codeforces API handling based on the robust platform built by [Mike Mirzayanov](https://codeforces.com/).
- Rating prediction formulas natively port and adapt mathematics from [Carrot](https://github.com/meooow25/carrot) & [TLE](https://github.com/cheran-senthil/TLE). 
# codeforces_tool_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
