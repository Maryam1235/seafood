import logging
import os
from datetime import datetime, timedelta
from threading import Lock

from apscheduler.schedulers.background import BackgroundScheduler
from dotenv import load_dotenv
from fastapi import FastAPI

from .firebase_client import get_db
from .recommender import RecommendationEngine

load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="ZanSeaFood Recommendation Service", version="1.0.0")
engine = RecommendationEngine(get_db())
scheduler = BackgroundScheduler()
training_lock = Lock()
PURCHASE_TRAINING_JOB_ID = "purchase_event_training"


@app.on_event("startup")
def start_scheduler() -> None:
    if os.getenv("TRAIN_ON_STARTUP", "true").lower() == "true":
        _run_training_job("startup")

    if os.getenv("SCHEDULE_DAILY_TRAINING", "true").lower() == "true":
        hour = int(os.getenv("TRAINING_HOUR", "2"))
        scheduler.add_job(_run_training_job, "cron", hour=hour, minute=0, args=["daily"])
        logger.info("Daily recommendation training scheduled at %02d:00", hour)

    _ensure_scheduler_running()


@app.on_event("shutdown")
def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/train")
def train() -> dict:
    return _run_training_job("manual")


@app.post("/events/purchase")
def purchase_event(payload: dict) -> dict[str, str]:
    logger.info("Purchase event received: %s", payload.get("orderId", "unknown"))
    delay_seconds = int(os.getenv("PURCHASE_TRAINING_DELAY_SECONDS", "120"))
    run_date = datetime.now() + timedelta(seconds=delay_seconds)
    scheduler.add_job(
        _run_training_job,
        "date",
        id=PURCHASE_TRAINING_JOB_ID,
        run_date=run_date,
        args=["purchase_event"],
        replace_existing=True,
    )
    _ensure_scheduler_running()
    return {"status": "accepted", "training": "scheduled"}


@app.get("/recommendations/{user_id}")
def recommendations(user_id: str) -> dict:
    return engine.get_recommendations(user_id)


def _ensure_scheduler_running() -> None:
    if not scheduler.running:
        scheduler.start()


def _run_training_job(source: str) -> dict:
    if not training_lock.acquire(blocking=False):
        logger.info("Recommendation training skipped; already running. source=%s", source)
        return {"status": "skipped", "reason": "training_already_running"}

    try:
        logger.info("Recommendation training started. source=%s", source)
        result = engine.train()
        logger.info("Recommendation training finished. source=%s", source)
        return result
    except Exception:
        logger.exception("Recommendation training failed. source=%s", source)
        return {"status": "error", "message": "Recommendation training failed."}
    finally:
        training_lock.release()
