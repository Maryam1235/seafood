import os
from functools import lru_cache

import firebase_admin
from firebase_admin import credentials, firestore


@lru_cache(maxsize=1)
def get_db() -> firestore.Client:
    if not firebase_admin._apps:
        credentials_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if credentials_path:
            firebase_admin.initialize_app(
                credentials.Certificate(credentials_path)
            )
        else:
            firebase_admin.initialize_app()
    return firestore.client()
