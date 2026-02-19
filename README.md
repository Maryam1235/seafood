# Flutter + Django Authentication App

## Project Structure
- `flutter_app/` - Flutter mobile application
- `django_backend/` - Django REST API with PostgreSQL

## Setup Instructions

### Backend (Django)
```bash
cd django_backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### Frontend (Flutter)
```bash
cd flutter_app
flutter pub get
flutter run
```

## API Endpoints
- POST `/api/auth/register/` - User registration
- POST `/api/auth/login/` - User login
- GET `/api/auth/user/` - Get current user (requires token)
