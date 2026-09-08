import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bank_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isAdminRegistration = false;
  bool _obscurePassword = true;
  int _logoTapCount = 0;
  bool _showAdminOption = false;

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'One uppercase letter required';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'One number required';
    if (!RegExp(r'[!@#$&*~]').hasMatch(value)) return 'One special character required';
    return null;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final bankProvider = Provider.of<BankProvider>(context, listen: false);
      bool success = _isLogin 
          ? await bankProvider.login(_phoneController.text.trim(), _passwordController.text)
          : await bankProvider.register(_phoneController.text.trim(), _passwordController.text, _fullNameController.text.trim(), role: _isAdminRegistration ? 'admin' : 'member');

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => bankProvider.user?.role == 'admin' ? const AdminDashboardScreen() : const DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bankProvider.errorMessage ?? 'Access Denied')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<BankProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              provider.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary,
            ),
            onPressed: () => provider.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
          child: Column(
            children: [
              // Updated Brand Logo with Frame Openings
              GestureDetector(
                onTap: () {
                  setState(() {
                    _logoTapCount++;
                    if (_logoTapCount >= 4) {
                      _showAdminOption = true;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Admin registration enabled')),
                      );
                    }
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Container(height: 1.5, width: 100, color: BankTheme.accentPurple.withOpacity(0.8)),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'VILLAGE',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'BANK',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: BankTheme.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Top Horizontal Border
                      Positioned(top: 0, left: 0, right: 0, child: Container(height: 2, color: BankTheme.accentPurple)),
                      // Bottom Horizontal Border
                      Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 2, color: BankTheme.accentPurple)),
                      // Left Side Corners
                      Positioned(left: 0, top: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                      Positioned(left: 0, bottom: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                      // Right Side Corners
                      Positioned(right: 0, top: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                      Positioned(right: 0, bottom: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1.5, width: 100, color: BankTheme.accentPurple.withOpacity(0.8)),
                ],
              ),
            ),
              const SizedBox(height: 40),
              GlassContainer(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLogin ? 'Sign In' : 'Create Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _fullNameController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(hintText: 'Full Name'),
                          validator: (v) => v!.isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        if (_showAdminOption)
                          Row(
                            children: [
                              Checkbox(
                                value: _isAdminRegistration,
                                onChanged: (v) => setState(() => _isAdminRegistration = v ?? false),
                                activeColor: BankTheme.accentPurple,
                              ),
                              Text(
                                'Admin Access',
                                style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                              ),
                            ],
                          ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                        decoration: const InputDecoration(hintText: 'Phone Number'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                        validator: _isLogin ? (v) => v!.isEmpty ? 'Required' : null : _validatePassword,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          helperText: _isLogin ? null : 'Min. 8 chars, 1 uppercase, 1 number, 1 special char',
                          helperStyle: const TextStyle(fontSize: 10, color: BankTheme.accentPurple),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: BankTheme.accentPurple,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Consumer<BankProvider>(builder: (context, provider, child) {
                        return ElevatedButton(
                          onPressed: provider.isLoading ? null : _submitForm,
                          child: provider.isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : Text(_isLogin ? 'Login' : 'Register'),
                        );
                      }),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? "Don't have an account? Register" : "Already have an account? Sign In", 
                          style: const TextStyle(color: BankTheme.accentPurple),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
