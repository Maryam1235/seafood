from dotenv import load_dotenv

from .firebase_client import get_db
from .recommender import RecommendationEngine


def main() -> None:
    load_dotenv()
    result = RecommendationEngine(get_db()).train()
    print(result)


if __name__ == "__main__":
    main()
