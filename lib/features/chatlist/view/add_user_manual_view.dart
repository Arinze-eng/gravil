import 'package:flutter/material.dart';
import 'package:minimal_chat_app/features/chatlist/service/chat_service.dart';

class AddUserManualView extends StatefulWidget {
  const AddUserManualView({super.key});

  @override
  State<AddUserManualView> createState() => _AddUserManualViewState();
}

class _AddUserManualViewState extends State<AddUserManualView> {
  final _searchController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    setState(() {
      _loading = true;
    });
    try {
      final rows = await ChatService().searchUsers(_searchController.text);
      setState(() {
        _results = rows;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _add(String userId) async {
    try {
      await ChatService().addFriend(userId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find people')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by email / name / code',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                )
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _results[i];
                  final email = (r['email'] as String?) ?? 'unknown';
                  final name = (r['name'] as String?) ?? '';
                  final code = (r['code'] as String?) ?? '';
                  return ListTile(
                    title: Text(name.isEmpty ? email : '$name ($email)'),
                    subtitle: code.isEmpty ? null : Text('Code: $code'),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      onPressed: () => _add(r['id'] as String),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
