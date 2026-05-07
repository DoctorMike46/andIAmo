from app.schemas.locale import LocaleSummary


class RecommendationOut(LocaleSummary):
    score: float
    reasons: list[str]
