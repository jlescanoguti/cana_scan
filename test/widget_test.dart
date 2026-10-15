// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cana_scan/main.dart';
import 'package:cana_scan/screens/home_screen.dart';

import 'package:cana_scan/screens/login_screen.dart';

void main() {
  testWidgets('renders SplashScreen and navigates to HomeScreen when unauthenticated (Guest mode)', (WidgetTester tester) async {
    await tester.pumpWidget(const CanaScanApp());

    expect(find.text('CañaScan'), findsOneWidget);

    // Avanzar el reloj virtual para completar el Future.delayed de SplashScreen
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    // Comprobar que redirige a HomeScreen en Modo Invitado
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Diagnostica tu cultivo'), findsOneWidget);
    expect(find.text('Acceder'), findsOneWidget);
  });

  testWidgets('HomeScreen renders info button and opens AppInfoSheet', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.byType(HomeScreen), findsOneWidget);
    final infoButton = find.byIcon(Icons.info_outline_rounded);
    expect(infoButton, findsOneWidget);

    // Tocar el botón de información y verificar que se abre el modal
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.text('Acerca de CañaScan'), findsOneWidget);
    expect(find.text('Recomendaciones para una buena captura'), findsOneWidget);
  });
}
