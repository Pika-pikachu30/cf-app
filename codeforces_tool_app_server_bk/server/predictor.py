import os
import json
import requests
import numpy as np
from numpy.fft import fft, ifft
from dataclasses import dataclass
import time


# ── Helpers ──────────────────────────────────────────────────────────────────

def intdiv(x: int, y: int) -> int:
    return -(-x // y) if x < 0 else x // y


# ── Data Classes ─────────────────────────────────────────────────────────────

@dataclass
class Contestant:
    party: str
    points: float
    penalty: int
    rating: int
    need_rating: int = 0
    delta: int = 0
    rank: float = 0.0
    seed: float = 0.0


# ── Mike's Rating Calculator (unchanged) ─────────────────────────────────────

class CodeforcesRatingCalculator:
    """Faithful implementation of Mike Mirzayanov's rating algorithm."""

    def __init__(self, standings: list[tuple[str, float, int, int]]) -> None:
        self.contestants = [
            Contestant(handle, points, penalty, rating if rating > 0 else 1400)
            for handle, points, penalty, rating in standings
        ]
        self._precalc_seed()
        self._reassign_ranks()
        self._process()
        self._update_delta()

    def calculate_rating_changes(self) -> dict[str, int]:
        return {c.party: c.delta for c in self.contestants}

    def get_seed(self, rating: int, me: Contestant | None = None) -> float:
        seed = self.seed[rating].real
        if me:
            diff = rating - me.rating
            if diff < 0:
                diff += len(self.elo_win_prob)
            seed -= self.elo_win_prob[diff]
        return float(seed)

    def _precalc_seed(self) -> None:
        MAX = 6144
        self._max = MAX
        self.elo_win_prob = np.roll(
            1 / (1 + pow(10, np.arange(-MAX, MAX) / 400)), -MAX
        )
        count = np.zeros(2 * MAX)
        for a in self.contestants:
            r = max(0, min(2 * MAX - 1, a.rating))
            count[r] += 1
        self.seed = 1 + ifft(fft(count) * fft(self.elo_win_prob)).real

    def _reassign_ranks(self) -> None:
        contestants = self.contestants
        contestants.sort(key=lambda o: (-o.points, o.penalty))
        points = penalty = None
        rank = 0.0
        for i in reversed(range(len(contestants))):
            if contestants[i].points != points or contestants[i].penalty != penalty:
                rank = i + 1
                points = contestants[i].points
                penalty = contestants[i].penalty
            contestants[i].rank = rank

    def _process(self) -> None:
        for a in self.contestants:
            a.seed = self.get_seed(a.rating, a)
            mid_rank = (a.rank * a.seed) ** 0.5
            a.need_rating = self._rank_to_rating(mid_rank, a)
            a.delta = intdiv(a.need_rating - a.rating, 2)

    def _rank_to_rating(self, rank: float, me: Contestant) -> int:
        left, right = 1, min(8000, 2 * self._max - 1)
        while right - left > 1:
            mid = (left + right) // 2
            if self.get_seed(mid, me) < rank:
                right = mid
            else:
                left = mid
        return left

    def _update_delta(self) -> None:
        contestants = self.contestants
        n = len(contestants)
        if n == 0:
            return
        contestants.sort(key=lambda o: -o.rating)
        correction = intdiv(-sum(c.delta for c in contestants), n) - 1
        for c in contestants:
            c.delta += correction
        zero_sum_count = min(int(4 * round(n ** 0.5 + 1e-9)), n)
        delta_sum = -sum(contestants[i].delta for i in range(zero_sum_count))
        correction = min(0, max(-10, intdiv(delta_sum, zero_sum_count)))
        for c in contestants:
            c.delta += correction


# ── Cache ─────────────────────────────────────────────────────────────────────

CACHE_FILE = os.path.join(os.path.dirname(__file__), "distributions_cache.json")
CACHE_TTL_SECONDS = 60 * 60 * 6  # 6 hours — long enough to avoid hammering CF API


def _load_cache() -> dict:
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def _save_cache(cache: dict) -> None:
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(cache, f)
    except Exception:
        pass


# ── Division Config ───────────────────────────────────────────────────────────

# How many recent contests to average per division.
# Div 1 needs more because its small pool (~500-800) is high-variance.
# Div 2/3/4 have huge pools so 5 is enough; older data just adds staleness.
CONTEST_FETCH_LIMIT: dict[str, int] = {
    "Div 1": 12,
    "Div 2": 5,
    "Div 3": 10,
    "Div 4": 10,
    "Edu":   7,
}

# Expected pool size bounds per division — used to reject wrong contests.
# e.g. a "Div. 1" result that has 18k participants is actually Div 1+2 mixed.
POOL_SIZE_BOUNDS: dict[str, tuple[int, int]] = {
    "Div 1": (200,  5_000),
    "Div 2": (5_000, 35_000),
    "Div 3": (3_000, 25_000),
    "Div 4": (3_000, 30_000),
    "Edu":   (2_000, 20_000),
}

# First-timer default rating per division (oldRating == 0 in API means unrated).
# Real Codeforces assigns 1400 internally but in practice:
#   Div 3/4 attract many true beginners whose effective strength is lower.
DEFAULT_RATING: dict[str, int] = {
    "Div 1": 1800,
    "Div 2": 1500,
    "Div 3": 1200,
    "Div 4": 1000,
    "Edu":   1500,
}


def _normalise_ctype(ctype: str) -> str:
    """Return one of: 'Div 1', 'Div 2', 'Div 3', 'Div 4', 'Edu'."""
    ct = ctype.upper().replace(".", "").replace(" ", "")
    if "DIV1" in ct: return "Div 1"
    if "DIV3" in ct: return "Div 3"
    if "DIV4" in ct: return "Div 4"
    if "EDU"  in ct: return "Edu"
    return "Div 2"


def _ctype_to_search(ctype_norm: str) -> tuple[str, list[str]]:
    """
    Returns (search_str_must_contain, list_of_substrings_to_exclude).
    Exclusions prevent mixed-division contests from polluting results.
    """
    return {
        "Div 1": ("Div. 1", ["Div. 2", "Div. 3", "+"]),  # reject Div 1+2 mixed
        "Div 2": ("Div. 2", ["Div. 1"]),                  # reject Div 1+2 mixed
        "Div 3": ("Div. 3", []),
        "Div 4": ("Div. 4", []),
        "Edu":   ("Educational", []),
    }[ctype_norm]


# ── CF API Helpers ────────────────────────────────────────────────────────────

def _fetch_recent_contest_ids(ctype_norm: str) -> list[int]:
    """
    Fetch the most recent FINISHED contest IDs for the given division.
    Count is determined by CONTEST_FETCH_LIMIT. Results are cached with TTL.
    """
    limit = CONTEST_FETCH_LIMIT[ctype_norm]
    cache = _load_cache()
    list_key = f"contest_list_{ctype_norm}_{limit}"

    entry = cache.get(list_key)
    if isinstance(entry, dict):
        if time.time() - entry.get("ts", 0) < CACHE_TTL_SECONDS:
            return entry["ids"]
    # Old list format or expired → re-fetch

    try:
        resp = requests.get(
            "https://codeforces.com/api/contest.list", timeout=10
        ).json()
        if resp.get("status") != "OK":
            return []

        search_str, excludes = _ctype_to_search(ctype_norm)
        valid_ids: list[int] = []

        for c in resp["result"]:
            name = c.get("name", "")
            if c.get("phase") != "FINISHED":
                continue
            if search_str not in name:
                continue
            if any(ex in name for ex in excludes):
                continue
            valid_ids.append(c["id"])
            if len(valid_ids) >= limit:
                break

        if valid_ids:
            cache[list_key] = {"ids": valid_ids, "ts": time.time()}
            _save_cache(cache)

        return valid_ids

    except Exception as e:
        print(f"[CF API] Error fetching contest list: {e}")
        return []


def get_registered_ratings(
    contest_id: int, default_rating: int = 1500
) -> list[tuple[int, int]]:
    """
    Returns list of (rank, rating) for every rated participant in a past contest.

    Rating used = newRating (best proxy for their CURRENT strength).
    For first-timers where oldRating == 0, falls back to division default.
    Results are cached permanently (contest history never changes).
    """
    cache = _load_cache()
    contest_key = f"contest_{contest_id}"
    if contest_key in cache:
        return [(r[0], r[1]) for r in cache[contest_key]]

    try:
        resp = requests.get(
            "https://codeforces.com/api/contest.ratingChanges",
            params={"contestId": contest_id},
            timeout=15,
        )
        if resp.status_code != 200:
            print(f"[CF API] {resp.status_code} for contest {contest_id}")
            return []

        data = resp.json()
        if data.get("status") != "OK":
            return []

        results: list[tuple[int, int]] = []
        for row in data["result"]:
            old = row.get("oldRating", 0)
            new = row.get("newRating", 0)
            # Preference order: newRating → oldRating → division default
            rating = new if new > 0 else (old if old > 0 else default_rating)
            results.append((row["rank"], rating))

        if results:
            cache[contest_key] = results
            _save_cache(cache)

        return results

    except Exception as e:
        print(f"[CF API] Error fetching ratings for contest {contest_id}: {e}")
        return []


# ── Core Prediction Logic ─────────────────────────────────────────────────────

def _run_single_prediction(
    standings_data: list[tuple[int, int]],
    my_rating: int,
    expected_rank: int,
) -> int | None:
    """
    Insert the user into a real participant pool and run Mike's algorithm.

    Key design decisions:
    - Participants are sorted by their real rank then given UNIQUE sequential
      scores (-0, -1, -2, ...). This means _reassign_ranks sees no ties and
      places _ME_ at exactly `expected_rank`, not one rank position off due
      to a collision with a real contestant at the same original rank.
    - The zero-sum correction in _update_delta uses the full real pool,
      so inflation/deflation is accurately modelled.
    """
    if not standings_data:
        return None

    sorted_data = sorted(standings_data, key=lambda x: x[0])
    ratings_in_order = [r for (_, r) in sorted_data]
    n = len(ratings_in_order)

    rank_to_use = max(1, min(expected_rank, n + 1))
    insert_pos = rank_to_use - 1  # 0-indexed

    ratings_in_order.insert(insert_pos, my_rating)

    standings = [
        (
            "_ME_" if i == insert_pos else f"u{i}",
            float(-i),   # unique score per position → zero ties
            0,
            max(rating, 1),
        )
        for i, rating in enumerate(ratings_in_order)
    ]

    calc = CodeforcesRatingCalculator(standings)
    for c in calc.contestants:
        if c.party == "_ME_":
            return c.delta

    return None


def _pool_size_ok(n: int, ctype_norm: str) -> bool:
    lo, hi = POOL_SIZE_BOUNDS[ctype_norm]
    return lo <= n <= hi


# ── Public API ────────────────────────────────────────────────────────────────

def predict_from_latest_contest(
    my_rating: int, expected_rank: int, ctype: str
) -> int:
    """
    Predict the rating delta for a given division by averaging over recent
    contests. The number of contests averaged is tuned per division:

        Div 1 → 12 contests  (small pool, high variance, need many samples)
        Div 2 → 5  contests
        Div 3 → 5  contests
        Div 4 → 5  contests
        Edu   → 7  contests

    Args:
        my_rating:     Your current CF rating.
        expected_rank: The rank you expect to finish at.
        ctype:         One of 'Div 1', 'Div 2', 'Div 3', 'Div 4', 'Edu'
                       (case-insensitive, dots optional).

    Returns:
        Predicted integer rating delta (positive = gain, negative = loss).
    """
    ctype_norm = _normalise_ctype(ctype)
    default_rating = DEFAULT_RATING[ctype_norm]
    cids = _fetch_recent_contest_ids(ctype_norm)

    if not cids:
        print(f"[Predictor] No recent contests found for: {ctype_norm}")
        return 0

    deltas: list[int] = []

    for cid in cids:
        standings_data = get_registered_ratings(cid, default_rating=default_rating)
        if not standings_data:
            print(f"  [skip] Contest {cid} — no data from API")
            continue

        n = len(standings_data)
        if not _pool_size_ok(n, ctype_norm):
            lo, hi = POOL_SIZE_BOUNDS[ctype_norm]
            print(
                f"  [skip] Contest {cid} — pool size {n} outside expected "
                f"[{lo}, {hi}] for {ctype_norm} (likely wrong division)"
            )
            continue

        delta = _run_single_prediction(standings_data, my_rating, expected_rank)
        if delta is not None:
            print(f"  Contest {cid}: pool={n:,}, rank={expected_rank} → Δ{delta:+d}")
            deltas.append(delta)

    if not deltas:
        print("[Predictor] No valid contests to average over.")
        return 0

    avg = round(sum(deltas) / len(deltas))
    print(
        f"\n[Predictor] Final predicted Δ: {avg:+d} "
        f"(averaged over {len(deltas)} contests)"
    )
    return avg


def predict_rating_change(
    my_rating: int,
    expected_rank: int,
    contest_id: int,
    ctype: str = "Div 2",
) -> int:
    """
    Direct prediction for a specific known contest ID (e.g. the upcoming contest
    whose ID is already published on CF but hasn't started yet).

    Args:
        my_rating:     Your current CF rating.
        expected_rank: The rank you expect to finish at.
        contest_id:    The Codeforces contest ID to use as the participant pool.
        ctype:         Division string for default-rating fallback.

    Returns:
        Predicted integer rating delta.
    """
    ctype_norm = _normalise_ctype(ctype)
    default_rating = DEFAULT_RATING[ctype_norm]
    standings_data = get_registered_ratings(contest_id, default_rating=default_rating)

    if not standings_data:
        print("[Predictor] Could not fetch standings.")
        return 0

    n = len(standings_data)
    if not _pool_size_ok(n, ctype_norm):
        lo, hi = POOL_SIZE_BOUNDS[ctype_norm]
        print(
            f"[Predictor] Warning: pool size {n} outside expected [{lo}, {hi}] "
            f"for {ctype_norm}. Results may be inaccurate."
        )

    delta = _run_single_prediction(standings_data, my_rating, expected_rank)
    if delta is None:
        return 0

    print(
        f"[Predictor] Contest {contest_id}: pool={n:,}, "
        f"rank={expected_rank} → Δ{delta:+d}"
    )
    return delta


# ── Quick Test ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Example: Div 2, rating 1650, expecting rank 200
    result = predict_from_latest_contest(
        my_rating=1650,
        expected_rank=200,
        ctype="Div 2"
    )
    print(f"\nResult: {result:+d}")