import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_elimination/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows the two entry buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Créer une partie'), findsOneWidget);
    expect(find.text('Rejoindre une partie'), findsOneWidget);
  });
}
