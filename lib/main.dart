import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'services/bank_provider.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BankProvider()),
      ],
      child: const VillageBankApp(),
    ),
  );
}

class VillageBankApp extends StatelessWidget {
  const VillageBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BankProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Village Bank',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: NotificationService.messengerKey,
          theme: BankTheme.lightTheme,
          darkTheme: BankTheme.darkTheme,
          themeMode: provider.themeMode,
          home: const AuthScreen(),
        );
      },
    );
  }
}
