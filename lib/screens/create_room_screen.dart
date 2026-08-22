import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'host_lobby_screen.dart';

class _QuestionDraft {
  final textController = TextEditingController();
  final optionControllers = List.generate(4, (_) => TextEditingController());
  int correctIndex = 0;
  int timeLimitSeconds = 20;

  void dispose() {
    textController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }

  bool get isValid =>
      textController.text.trim().isNotEmpty &&
      optionControllers.every((c) => c.text.trim().isNotEmpty);

  Question toQuestion() => Question(
    text: textController.text.trim(),
    options: optionControllers.map((c) => c.text.trim()).toList(),
    correctIndex: correctIndex,
    timeLimitSeconds: timeLimitSeconds,
  );
}

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final List<_QuestionDraft> _drafts = [_QuestionDraft()];
  final _roomService = RoomService();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _drafts.add(_QuestionDraft()));

  void _removeQuestion(int index) {
    if (_drafts.length == 1) return;
    setState(() {
      _drafts.removeAt(index).dispose();
    });
  }

  Future<void> _createRoom() async {
    if (_drafts.any((d) => !d.isValid)) {
      setState(
        () =>
            _error = 'Complète le texte et les 4 réponses de chaque question.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await _authService.ensureSignedIn();
      final questions = _drafts.map((d) => d.toQuestion()).toList();
      final code = await _roomService.createRoom(
        hostUid: uid,
        questions: questions,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HostLobbyScreen(code: code)),
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
      appBar: AppBar(title: const Text('Créer une partie')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _drafts.length,
                itemBuilder: (context, index) => _QuestionCard(
                  index: index,
                  draft: _drafts[index],
                  onRemove: _drafts.length > 1
                      ? () => _removeQuestion(index)
                      : null,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _addQuestion,
                      child: const Text('+ Question'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createRoom,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lancer la salle'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final _QuestionDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _QuestionCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Question ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
            TextField(
              controller: draft.textController,
              decoration: const InputDecoration(
                labelText: 'Intitulé de la question',
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: draft.correctIndex,
              onChanged: (value) {
                draft.correctIndex = value!;
                onChanged();
              },
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<int>(value: i),
                          Expanded(
                            child: TextField(
                              controller: draft.optionControllers[i],
                              decoration: InputDecoration(
                                labelText: 'Réponse ${i + 1}',
                              ),
                              onChanged: (_) => onChanged(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const Text('Temps (sec) : '),
                DropdownButton<int>(
                  value: draft.timeLimitSeconds,
                  items: const [10, 15, 20, 30, 45]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (value) {
                    draft.timeLimitSeconds = value!;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
