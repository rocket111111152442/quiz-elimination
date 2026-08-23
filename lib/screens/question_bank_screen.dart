import 'package:flutter/material.dart';

import '../data/question_bank.dart';
import '../theme.dart';

/// Lets the host browse the built-in question bank by category and pick
/// a batch to add to the room being created.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  String _selectedCategory = questionCategories.first;
  final Set<BankQuestion> _selected = {};

  @override
  Widget build(BuildContext context) {
    final visible = questionBank
        .where((q) => q.category == _selectedCategory)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Banque de questions')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: questionCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = questionCategories[index];
                  final selected = category == _selectedCategory;
                  final countInCategory = questionBank
                      .where(
                        (q) => q.category == category && _selected.contains(q),
                      )
                      .length;
                  return ChoiceChip(
                    label: Text(
                      countInCategory > 0
                          ? '$category ($countInCategory)'
                          : category,
                    ),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final question = visible[index];
                  final checked = _selected.contains(question);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(question.text),
                    subtitle: Text(question.options[question.correctIndex]),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selected.add(question);
                        } else {
                          _selected.remove(question);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(() => _selected.clear()),
                      child: const Text('Tout désélectionner'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(_selected.toList()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      child: Text('Ajouter ${_selected.length} question(s)'),
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
