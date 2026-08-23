import 'package:flutter/material.dart';

import '../data/word_bank.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'undercover_host_screen.dart';

class CreateUndercoverRoomScreen extends StatefulWidget {
  const CreateUndercoverRoomScreen({super.key});

  @override
  State<CreateUndercoverRoomScreen> createState() =>
      _CreateUndercoverRoomScreenState();
}

class _CreateUndercoverRoomScreenState
    extends State<CreateUndercoverRoomScreen> {
  final _roomService = RoomService();
  final _authService = AuthService();
  String _category = 'Aléatoire';
  int _undercoverCount = 1;
  bool _loading = false;
  String? _error;

  Future<void> _createRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await _authService.ensureSignedIn();
      final code = await _roomService.createUndercoverRoom(
        hostUid: uid,
        category: _category,
        undercoverCount: _undercoverCount,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => UndercoverHostScreen(code: code)),
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
      appBar: AppBar(title: const Text('Créer un Undercover')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catégorie de mots',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ['Aléatoire', ...wordCategories])
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Nombre d\'Undercover',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _undercoverCount > 1
                        ? () => setState(() => _undercoverCount--)
                        : null,
                  ),
                  Text(
                    '$_undercoverCount',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _undercoverCount < 3
                        ? () => setState(() => _undercoverCount++)
                        : null,
                  ),
                ],
              ),
              Text(
                'Ajusté automatiquement si le nombre de joueurs est trop petit.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createRoom,
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
