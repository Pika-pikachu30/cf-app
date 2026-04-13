import 'dart:math' as math;

class Party {
  final String? members;
  Party({this.members});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Party &&
          runtimeType == other.runtimeType &&
          members == other.members;

  @override
  int get hashCode => members.hashCode;
}

class StandingsRow {
  final Party party;
  final int rank;
  final double points;

  StandingsRow(this.party, this.rank, this.points);
}

class RatingChange {
  final int change;
  RatingChange(this.change);
}

class Contestant {
  Party? party;
  double rank;
  double points;
  int rating;
  int needRating = 0;
  double seed = 0;
  int delta = 0;

  Contestant(this.party, this.rank, this.points, this.rating);
}

class CodeforcesRatingCalculator {
  static const int initialRating = 1500;

  int aggregateRating(List<RatingChange>? ratingChanges) {
    int rating = initialRating;
    if (ratingChanges != null) {
      for (var ratingChange in ratingChanges) {
        rating += ratingChange.change;
      }
    }
    return rating;
  }

  int getMaxRating(List<RatingChange>? ratingChanges) {
    int maxRating = 0;
    if (ratingChanges != null) {
      int rating = initialRating;
      for (var ratingChange in ratingChanges) {
        rating += ratingChange.change;
        maxRating = math.max(rating, maxRating);
      }
    }
    return maxRating;
  }

  Map<String, int> calculateRatingChangesSync(
      Map<String, int> previousRatings, List<StandingsRow> standingsRows) {
    List<Contestant> contestants = [];

    for (var standingsRow in standingsRows) {
      int rank = standingsRow.rank;
      Party party = standingsRow.party;
      int rating =
          previousRatings[party.members ?? party.members!] ?? initialRating;
      contestants
          .add(Contestant(party, rank.toDouble(), standingsRow.points, rating));
    }

    processSync(contestants);

    Map<String, int> ratingChanges = {};
    for (var contestant in contestants) {
      if (contestant.party != null && contestant.party!.members != null) {
        ratingChanges[contestant.party!.members!] = contestant.delta;
      }
    }

    return ratingChanges;
  }

  void processSync(List<Contestant> contestants) {
    if (contestants.isEmpty) return;

    reassignRanks(contestants);

    for (var a in contestants) {
      a.seed = 1;
      for (var b in contestants) {
        if (a != b) {
          a.seed += getEloWinProbability(b, a);
        }
      }
    }

    for (var contestant in contestants) {
      double midRank = math.sqrt(contestant.rank * contestant.seed);
      contestant.needRating = getRatingToRank(contestants, midRank);
      contestant.delta = (contestant.needRating - contestant.rating) ~/ 2;
    }

    sortByRatingDesc(contestants);

    // Total sum should not be more than zero
    {
      int sum = 0;
      for (var c in contestants) {
        sum += c.delta;
      }
      int inc = -sum ~/ contestants.length - 1;
      for (var contestant in contestants) {
        contestant.delta += inc;
      }
    }

    // Sum of top-4*sqrt should be adjusted to zero
    {
      int sum = 0;
      int zeroSumCount = math.min(
          (4 * math.sqrt(contestants.length).round()).toInt(),
          contestants.length);
      for (int i = 0; i < zeroSumCount; i++) {
        sum += contestants[i].delta;
      }
      int inc = math.min(math.max(-sum ~/ zeroSumCount, -10), 0);
      for (var contestant in contestants) {
        contestant.delta += inc;
      }
    }

    validateDeltas(contestants);
  }

  Future<Map<String, int>> calculateRatingChanges(
      Map<String, int> previousRatings,
      List<StandingsRow> standingsRows) async {
    List<Contestant> contestants = [];

    for (var standingsRow in standingsRows) {
      int rank = standingsRow.rank;
      Party party = standingsRow.party;
      int rating =
          previousRatings[party.members ?? party.members!] ?? initialRating;
      contestants
          .add(Contestant(party, rank.toDouble(), standingsRow.points, rating));
    }

    await process(contestants);

    Map<String, int> ratingChanges = {};
    for (var contestant in contestants) {
      if (contestant.party != null && contestant.party!.members != null) {
        ratingChanges[contestant.party!.members!] = contestant.delta;
      }
    }

    return ratingChanges;
  }

  static double getEloWinProbabilityStatic(double ra, double rb) {
    return 1.0 / (1 + math.pow(10, (rb - ra) / 400.0));
  }

  double getEloWinProbability(Contestant a, Contestant b) {
    return getEloWinProbabilityStatic(a.rating.toDouble(), b.rating.toDouble());
  }

  int composeRatingsByTeamMemberRatings(List<int> ratings) {
    double left = 100;
    double right = 4000;

    for (int tt = 0; tt < 20; tt++) {
      double r = (left + right) / 2.0;

      double rWinsProbability = 1.0;
      for (int rating in ratings) {
        rWinsProbability *= getEloWinProbabilityStatic(r, rating.toDouble());
      }

      double ratingVal =
          math.log(1 / (rWinsProbability) - 1) / math.ln10 * 400 + r;

      if (ratingVal > r) {
        left = r;
      } else {
        right = r;
      }
    }

    return ((left + right) / 2).round();
  }

  double getSeed(List<Contestant> contestants, int rating) {
    Contestant extraContestant = Contestant(null, 0, 0, rating);

    double result = 1;
    for (var other in contestants) {
      result += getEloWinProbability(other, extraContestant);
    }

    return result;
  }

  int getRatingToRank(List<Contestant> contestants, double rank) {
    int left = 1;
    int right = 8000;

    while (right - left > 1) {
      int mid = (left + right) ~/ 2;

      if (getSeed(contestants, mid) < rank) {
        right = mid;
      } else {
        left = mid;
      }
    }

    return left;
  }

  void reassignRanks(List<Contestant> contestants) {
    sortByPointsDesc(contestants);

    for (var contestant in contestants) {
      contestant.rank = 0;
      contestant.delta = 0;
    }

    int first = 0;
    double points = contestants[0].points;
    for (int i = 1; i < contestants.length; i++) {
      if (contestants[i].points < points) {
        for (int j = first; j < i; j++) {
          contestants[j].rank = i.toDouble();
        }
        first = i;
        points = contestants[i].points;
      }
    }

    {
      double rank = contestants.length.toDouble();
      for (int j = first; j < contestants.length; j++) {
        contestants[j].rank = rank;
      }
    }
  }

  void sortByPointsDesc(List<Contestant> contestants) {
    contestants.sort((o1, o2) => -o1.points.compareTo(o2.points));
  }

  Future<void> process(List<Contestant> contestants) async {
    if (contestants.isEmpty) {
      return;
    }

    reassignRanks(contestants);

    final stopwatch = Stopwatch()..start();

    for (var a in contestants) {
      a.seed = 1;
      for (var b in contestants) {
        if (a != b) {
          a.seed += getEloWinProbability(b, a);
        }
      }
      if (stopwatch.elapsedMilliseconds > 20) {
        await Future.delayed(Duration.zero);
        stopwatch.reset();
      }
    }

    for (var contestant in contestants) {
      double midRank = math.sqrt(contestant.rank * contestant.seed);
      contestant.needRating = getRatingToRank(contestants, midRank);
      contestant.delta = (contestant.needRating - contestant.rating) ~/ 2;

      if (stopwatch.elapsedMilliseconds > 20) {
        await Future.delayed(Duration.zero);
        stopwatch.reset();
      }
    }

    sortByRatingDesc(contestants);

    // Total sum should not be more than zero
    {
      int sum = 0;
      for (var c in contestants) {
        sum += c.delta;
      }
      int inc = -sum ~/ contestants.length - 1;
      for (var contestant in contestants) {
        contestant.delta += inc;
      }
    }

    // Sum of top-4*sqrt should be adjusted to zero
    {
      int sum = 0;
      int zeroSumCount = math.min(
          (4 * math.sqrt(contestants.length).round()).toInt(),
          contestants.length);
      for (int i = 0; i < zeroSumCount; i++) {
        sum += contestants[i].delta;
      }
      int inc = math.min(math.max(-sum ~/ zeroSumCount, -10), 0);
      for (var contestant in contestants) {
        contestant.delta += inc;
      }
    }

    validateDeltas(contestants);
  }

  void validateDeltas(List<Contestant> contestants) {
    sortByPointsDesc(contestants);

    for (int i = 0; i < contestants.length; i++) {
      for (int j = i + 1; j < contestants.length; j++) {
        if (contestants[i].rating > contestants[j].rating) {
          ensure(
              contestants[i].rating + contestants[i].delta >=
                  contestants[j].rating + contestants[j].delta,
              "First rating invariant failed: ${contestants[i].party?.members} vs. ${contestants[j].party?.members}.");
        }
        if (contestants[i].rating < contestants[j].rating) {
          ensure(contestants[i].delta >= contestants[j].delta,
              "Second rating invariant failed: ${contestants[i].party?.members} vs. ${contestants[j].party?.members}.");
        }
      }
    }
  }

  void ensure(bool b, String message) {
    if (!b) {
      // We won't throw exceptions here because it might bring down the Isolate.
      // Print or handle silently based on implementation requirements.
      print(message);
    }
  }

  void sortByRatingDesc(List<Contestant> contestants) {
    contestants.sort((o1, o2) => -o1.rating.compareTo(o2.rating));
  }

  double _randomNormal(math.Random rand, double mean, double stdDev) {
    double u1 = 1.0 - rand.nextDouble();
    double u2 = 1.0 - rand.nextDouble();
    double randStdNormal =
        math.sqrt(-2.0 * math.log(u1)) * math.sin(2.0 * math.pi * u2);
    return mean + stdDev * randStdNormal;
  }

  List<int> simulateContestDistribution(
      String contestType, int numParticipants) {
    math.Random rand = math.Random();
    List<int> ratings = [];

    for (int i = 0; i < numParticipants; i++) {
      double r;
      if (contestType == "Div 1" ||
          contestType == "Div1" ||
          contestType == "Div. 1") {
        r = _randomNormal(rand, 2200, 250);
        ratings.add(math.max(1900, r.toInt()));
      } else if (contestType == "Div 2" ||
          contestType == "Div2" ||
          contestType == "Div. 2") {
        r = _randomNormal(rand, 1450, 300);
        ratings.add(math.max(0, math.min(2099, r.toInt())));
      } else if (contestType == "Div 3" ||
          contestType == "Div3" ||
          contestType == "Div. 3") {
        r = _randomNormal(rand, 1150, 250);
        ratings.add(math.max(0, math.min(1599, r.toInt())));
      } else if (contestType == "Div 4" ||
          contestType == "Div4" ||
          contestType == "Div. 4") {
        r = _randomNormal(rand, 950, 250);
        ratings.add(math.max(0, math.min(1399, r.toInt())));
      } else {
        // Edu / Global
        r = _randomNormal(rand, 1450, 350);
        ratings.add(math.max(0, r.toInt()));
      }
    }
    return ratings;
  }

  int predictRatingChange(int myRating, int expectedRank, String contestType) {
    // Use scale factor to reduce the synthetic pool linearly to turn an O(N^2)
    // 400M operation cycle (lagging phone) into a 40K ~ 1 Million operation cycle (instant).
    int scaleFactor = 20;

    int numParts = (contestType == "Div 1" ||
            contestType == "Div1" ||
            contestType == "Div. 1")
        ? (8000 ~/ scaleFactor)
        : (20000 ~/ scaleFactor);

    // Keep math proportions exactly identical
    int scaledExpectedRank =
        math.max(1, (expectedRank.toDouble() / scaleFactor).round());

    List<int> ratings = simulateContestDistribution(contestType, numParts);
    ratings.sort((a, b) => b.compareTo(a));

    List<StandingsRow> fakeStandings = [];
    Map<String, int> fakeRatings = {};

    int rank = 1;
    for (int i = 0; i < ratings.length; i++) {
      if (rank == scaledExpectedRank) rank++;
      String handle = 'syn_$i';
      fakeRatings[handle] = ratings[i];
      fakeStandings.add(StandingsRow(
          Party(members: handle), rank, (numParts + 2 - rank).toDouble()));
      rank++;
    }

    String myHandle = '_CURRENT_USER_';
    fakeRatings[myHandle] = myRating;
    fakeStandings.add(StandingsRow(Party(members: myHandle), scaledExpectedRank,
        (numParts + 2 - scaledExpectedRank).toDouble()));

    Map<String, int> results =
        calculateRatingChangesSync(fakeRatings, fakeStandings);
    return results[myHandle] ?? 0;
  }
}
