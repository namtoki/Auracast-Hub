import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'amplifyconfiguration.dart';
import 'screens/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const SpatialSyncApp());
}

class SpatialSyncApp extends StatefulWidget {
  const SpatialSyncApp({super.key});

  @override
  State<SpatialSyncApp> createState() => _SpatialSyncAppState();
}

class _SpatialSyncAppState extends State<SpatialSyncApp> {
  bool _isLoading = true;
  AuthState _authState = AuthState.unknown;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  Future<void> _configureAmplify() async {
    try {
      await Amplify.addPlugins([AmplifyAuthCognito()]);
      await Amplify.configure(amplifyConfig);
      await _checkAuthState();
    } on AmplifyAlreadyConfiguredException {
      await _checkAuthState();
    } catch (e) {
      safePrint('Error configuring Amplify: $e');
      setState(() {
        _isLoading = false;
        _authState = AuthState.unauthenticated;
      });
    }
  }

  Future<void> _checkAuthState() async {
    final state = await _authService.checkAuthState();
    setState(() {
      _authState = state;
      _isLoading = false;
    });
  }

  void _handleLoginSuccess() {
    setState(() {
      _authState = AuthState.authenticated;
    });
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    setState(() {
      _authState = AuthState.unauthenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpatialSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (_authState == AuthState.authenticated) {
      return HomeScreen(onLogout: _handleLogout);
    }

    return LoginScreen(onLoginSuccess: _handleLoginSuccess);
  }
}
