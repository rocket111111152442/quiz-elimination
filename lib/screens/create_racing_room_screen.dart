import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'racing_host_screen.dart';

/// No configuration needed for a race room — this screen just creates it
/// and moves on, with a small spinner while the Firestore write happens.
class CreateRacingRoomScreen extends StatefulWidget {
  const CreateRacingRoomScreen({super.key});

  @override
  State<CreateRacingRoomScreen> createState() => _CreateRacingRoomScreenState();
}

class _CreateRacingRoomScreenState extends State<CreateRacingRoomScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      final uid = await AuthService().ensureSignedIn();
      final code = await RoomService().createRacingRoom(hostUid: uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RacingHostScreen(code: code)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course de Motos')),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
