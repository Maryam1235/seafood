import logging
import os

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


@app.on_event("startup")
def start_scheduler() -> None:
    if os.getenv("TRAIN_ON_STARTUP", "true").lower() == "true":
        try:
            engine.train()
        except Exception:
            logger.exception("Startup recommendation training failed")

    if os.getenv("SCHEDULE_DAILY_TRAINING", "true").lower() == "true":
        hour = int(os.getenv("TRAINING_HOUR", "2"))
        scheduler.add_job(engine.train, "cron", hour=hour, minute=0)
        scheduler.start()
        logger.info("Daily recommendation training scheduled at %02d:00", hour)


@app.on_event("shutdown")
def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/train")
def train() -> dict:
    return engine.train()


@app.post("/events/purchase")
def purchase_event(payload: dict) -> dict[str, str]:
    logger.info("Purchase event received: %s", payload.get("orderId", "unknown"))
    return {"status": "accepted"}


@app.get("/recommendations/{user_id}")
def recommendations(user_id: str) -> dict:
    return engine.get_recommendations(user_id)
