import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'screens/super_admin_dashboard_screen.dart';
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
          onGenerateRoute: (settings) {
            final name = (settings.name ?? '').toLowerCase();
            final uri = Uri.parse(name);
            final path = uri.path;

            if (path == '/management_portal' ||
                path == '/management-portal' ||
                path == '/management' ||
                path == '/portal' ||
                path == '/super_admin' ||
                path == '/superadmin' ||
                path.contains('management')) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const SuperAdminDashboardScreen(),
              );
            }

            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const AuthScreen(),
            );
          },
        );
      },
    );
  }
}
