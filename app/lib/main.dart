import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';

// TODO: Re-enable authentication after testing
// import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
// import 'package:amplify_flutter/amplify_flutter.dart';
// import 'amplifyconfiguration.dart';
// import 'screens/auth/login_screen.dart';
// import 'services/auth_service.dart';

void main() {
  runApp(const SpatialSyncApp());
}

class SpatialSyncApp extends StatelessWidget {
  const SpatialSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpatialSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeScreen(onLogout: () {}),
    );
  }
}
