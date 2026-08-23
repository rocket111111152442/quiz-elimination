import 'package:flutter/material.dart';

import '../models/game_type.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'player_lobby_screen.dart';
import 'qr_scan_screen.dart';
import 'undercover_player_screen.dart';
import 'uno_game_screen.dart';
import 'werewolf_game_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  final String? initialCode;

  const JoinRoomScreen({super.key, this.initialCode});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  late final _codeController = TextEditingController(
    text: widget.initialCode ?? '',
  );
  final _nameController = TextEditingController();
  final _roomService = RoomService();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (code != null && mounted) {
      setState(() => _codeController.text = code);
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Renseigne le code et ton pseudo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await _authService.ensureSignedIn();
      final gameType = await _roomService.joinRoom(
        code: code,
        uid: uid,
        name: name,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => switch (gameType) {
            GameType.undercover => UndercoverPlayerScreen(code: code),
            GameType.werewolf => WerewolfGameScreen(code: code),
            GameType.uno => UnoGameScreen(code: code),
            GameType.quiz => PlayerLobbyScreen(code: code),
          },
        ),
      );
    } on RoomNotFoundException {
      setState(() => _error = 'Aucune partie avec ce code.');
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code de la partie',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _scanQrCode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner un QR code'),
              ),
              const SizedBox(height: 16),
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
                  onPressed: _loading ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Rejoindre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
