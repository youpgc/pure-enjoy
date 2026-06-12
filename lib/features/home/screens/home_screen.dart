import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await ApiClient.getOne(
        'users',
        filters: {'id': 'eq.$userId'},
      );

      if (result.isSuccess) {
        setState(() {
          _userData = result.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('未登录'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '欢迎回来, ${_userData!['nickname'] ?? _userData!['username'] ?? '用户'}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('个人信息'),
                          subtitle: Text(_userData!['email'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
