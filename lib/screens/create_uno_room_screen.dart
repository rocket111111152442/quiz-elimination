import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'uno_game_screen.dart';

/// Like the Loup-Garou host, the UNO host also plays — this screen just
/// asks for their name before creating the room.
class CreateUnoRoomScreen extends StatefulWidget {
  const CreateUnoRoomScreen({super.key});

  @override
  State<CreateUnoRoomScreen> createState() => _CreateUnoRoomScreenState();
}

class _CreateUnoRoomScreenState extends State<CreateUnoRoomScreen> {
  final _nameController = TextEditingController();
  final _roomService = RoomService();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Renseigne ton pseudo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await _authService.ensureSignedIn();
      final code = await _roomService.createUnoRoom(
        hostUid: uid,
        hostName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => UnoGameScreen(code: code)),
      );
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un UNO')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🃏 Tu vas aussi jouer dans cette partie !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ton pseudo'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer la salle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
