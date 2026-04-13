import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class FriendsComparisonPage extends StatefulWidget {
  final String handle;
  const FriendsComparisonPage({super.key, required this.handle});

  @override
  State<FriendsComparisonPage> createState() => _FriendsComparisonPageState();
}

class _FriendsComparisonPageState extends State<FriendsComparisonPage> {
  final TextEditingController _friendController = TextEditingController();
  List<String> friends = [];
  Map<String, int?> friendRatings = {};
  bool loading = false;
  int? userRating;

  @override
  void initState() {
    super.initState();
    loadUserRating();
    loadFriends();
  }

  Future<void> loadUserRating() async {
    userRating = await ApiService.getUserRating(widget.handle);
    setState(() {});
  }

  Future<void> loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFriends = prefs.getStringList('friends') ?? [];
    setState(() {
      friends = savedFriends;
    });
    // Fetch ratings for all friends
    await fetchAllRatings();
  }

  Future<void> saveFriends() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('friends', friends);
  }

  Future<void> fetchAllRatings() async {
    setState(() {
      loading = true;
    });
    for (final friend in friends) {
      try {
        final rating = await ApiService.getUserRating(friend);
        friendRatings[friend] = rating;
      } catch (e) {
        friendRatings[friend] = null;
      }
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> removeFriend(String friend) async {
    setState(() {
      friends.remove(friend);
      friendRatings.remove(friend);
    });
    await saveFriends();
  }

  Future<void> addFriend() async {
    final friend = _friendController.text.trim();
    if (friend.isEmpty || friends.contains(friend)) return;

    setState(() {
      friends.add(friend);
    });
    await saveFriends();

    try {
      final rating = await ApiService.getUserRating(friend);
      setState(() {
        friendRatings[friend] = rating;
      });
    } catch (e) {
      setState(() {
        friendRatings[friend] = null;
      });
    }
    _friendController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: const Text("Friends Comparison"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllRatings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _friendController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter friend handle",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1B1D3A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: addFriend,
                  child: const Text("Add"),
                ),
              ],
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        // User's entry
                        if (userRating != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B61FF)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${widget.handle} (You)",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text("Rating: $userRating",
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        // Friends sorted by rating
                        ...(friends
                                .where((f) => friendRatings[f] != null)
                                .toList()
                              ..sort((a, b) => (friendRatings[b] ?? 0)
                                  .compareTo(friendRatings[a] ?? 0)))
                            .map((friend) {
                          final rating = friendRatings[friend]!;
                          return ListTile(
                            title: Text(friend,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text("Rating: $rating",
                                style: const TextStyle(color: Colors.white54)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.redAccent),
                              onPressed: () => removeFriend(friend),
                            ),
                          );
                        }).toList(),
                        // Friends with failed load
                        ...friends
                            .where((f) => friendRatings[f] == null)
                            .map((friend) {
                          return ListTile(
                            title: Text(friend,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: const Text("Failed to load rating",
                                style: TextStyle(color: Colors.redAccent)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.redAccent),
                              onPressed: () => removeFriend(friend),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
