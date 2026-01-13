import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'viewmodels/blackjack_viewmodel.dart';
import 'views/blackjack_view.dart';
import 'utils/constants.dart';

void main() {
  runApp(const BlackjackApp());
}

class BlackjackApp extends StatelessWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BlackjackViewModel(),
      child: MaterialApp(
        title: appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
        ),
        home: const BlackjackView(),
      ),
    );
  }
}
