import 'package:flutter/material.dart';

class ActivityList extends StatelessWidget {
  final List items;
  const ActivityList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recent Activity",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...items.map((e) => ListTile(
              title: Text(e['name']),
              trailing: Text(
                e['verdict'],
                style: TextStyle(
                  color: e['verdict'] == "OK"
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
              ),
            )),
      ],
    );
  }
}
