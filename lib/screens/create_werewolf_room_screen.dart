import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'werewolf_game_screen.dart';

/// Unlike the quiz/Undercover host, the Loup-Garou host also plays — so
/// this screen just asks for their name before creating the room.
class CreateWerewolfRoomScreen extends StatefulWidget {
  const CreateWerewolfRoomScreen({super.key});

  @override
  State<CreateWerewolfRoomScreen> createState() =>
      _CreateWerewolfRoomScreenState();
}

class _CreateWerewolfRoomScreenState extends State<CreateWerewolfRoomScreen> {
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
      final code = await _roomService.createWerewolfRoom(
        hostUid: uid,
        hostName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WerewolfGameScreen(code: code)),
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
      appBar: AppBar(title: const Text('Créer un Loup-Garou')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🐺 Tu vas aussi jouer dans cette partie, en plus de la '
                'mener !',
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
