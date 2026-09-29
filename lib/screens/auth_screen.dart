import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bank_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'super_admin_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isOrgAdminReg = false; // Toggle between Member registration and Organization Admin registration
  bool _obscurePassword = true;
  int _logoTapCount = 0;

  // Member Registration Controllers
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedOrgCode = 'default_org';

  // Organization Admin Registration Controllers
  final _orgNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _expectedMembersController = TextEditingController(text: '10');
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BankProvider>(context, listen: false).refreshActiveOrganizations();
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'One uppercase letter required';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'One number required';
    if (!RegExp(r'[!@#$&*~]').hasMatch(value)) return 'One special character required';
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final bankProvider = Provider.of<BankProvider>(context, listen: false);

    if (_isLogin) {
      // LOGIN FLOW
      bool success = await bankProvider.login(
        _phoneController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) {
            final role = bankProvider.user?.role;
            if (role == 'super_admin') {
              return const SuperAdminDashboardScreen();
            } else if (role == 'admin') {
              return const AdminDashboardScreen();
            } else {
              return const DashboardScreen();
            }
          }),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bankProvider.errorMessage ?? 'Access Denied')),
        );
      }
    } else if (_isOrgAdminReg) {
      // ORGANIZATION ADMIN REGISTRATION FLOW
      bool success = await bankProvider.registerOrganization(
        name: _orgNameController.text.trim(),
        expectedMembers: int.tryParse(_expectedMembersController.text) ?? 10,
        contactPerson: _adminNameController.text.trim(),
        contactPhone: _adminPhoneController.text.trim(),
        contactEmail: _emailController.text.trim(),
        description: _descriptionController.text.trim(),
        adminName: _adminNameController.text.trim(),
        adminPhone: _adminPhoneController.text.trim(),
        adminPassword: _adminPasswordController.text,
      );

      if (!mounted) return;

      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Text('Registration Submitted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: const Text(
              'Your organization and admin account registration has been submitted!\n\nYour account will be active as soon as the Super Admin approves your registration.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isLogin = true;
                    _phoneController.text = _adminPhoneController.text;
                    _passwordController.text = _adminPasswordController.text;
                  });
                },
                child: const Text('OK', style: TextStyle(color: BankTheme.accentPurple, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bankProvider.errorMessage ?? 'Failed to register organization. Phone number may be in use.')),
        );
      }
    } else {
      // MEMBER REGISTRATION FLOW
      bool success = await bankProvider.register(
        _phoneController.text.trim(),
        _passwordController.text,
        _fullNameController.text.trim(),
        role: 'member',
        organizationId: _selectedOrgCode,
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bankProvider.errorMessage ?? 'Registration failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<BankProvider>(context);
    final activeOrgs = provider.activeOrganizations;

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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Column(
            children: [
              // Hidden 4-tap Logo Gesture to jump directly to Management Portal (for testing)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _logoTapCount++;
                    if (_logoTapCount >= 4) {
                      _logoTapCount = 0;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
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
                        // Border Accents
                        Positioned(top: 0, left: 0, right: 0, child: Container(height: 2, color: BankTheme.accentPurple)),
                        Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 2, color: BankTheme.accentPurple)),
                        Positioned(left: 0, top: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                        Positioned(left: 0, bottom: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                        Positioned(right: 0, top: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                        Positioned(right: 0, bottom: 0, child: Container(width: 2, height: 12, color: BankTheme.accentPurple)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1.5, width: 100, color: BankTheme.accentPurple.withOpacity(0.8)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              GlassContainer(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLogin
                            ? 'Sign In'
                            : (_isOrgAdminReg ? 'Register Organization (Admin)' : 'Create Member Account'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Registration Type Toggle (Member vs Org Admin)
                      if (!_isLogin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Member Account'),
                                selected: !_isOrgAdminReg,
                                onSelected: (selected) {
                                  if (selected) setState(() => _isOrgAdminReg = false);
                                },
                                selectedColor: BankTheme.accentPurple,
                                labelStyle: TextStyle(
                                  color: !_isOrgAdminReg ? Colors.white : (isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('New Org (Admin)'),
                                selected: _isOrgAdminReg,
                                onSelected: (selected) {
                                  if (selected) setState(() => _isOrgAdminReg = true);
                                },
                                selectedColor: Colors.amberAccent,
                                labelStyle: TextStyle(
                                  color: _isOrgAdminReg ? Colors.black : (isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ================= LOGIN FORM =================
                      if (_isLogin) ...[
                        TextFormField(
                          controller: _phoneController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number / Username',
                            prefixIcon: Icon(Icons.phone_rounded, color: BankTheme.accentPurple, size: 20),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded, color: BankTheme.accentPurple, size: 20),
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
                      ]
                      // ================= ORGANIZATION ADMIN REGISTRATION FORM =================
                      else if (_isOrgAdminReg) ...[
                        TextFormField(
                          controller: _orgNameController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Organization Name',
                            hintText: 'e.g. Lilongwe Village Bank',
                            prefixIcon: Icon(Icons.apartment_rounded, color: Colors.amberAccent, size: 20),
                          ),
                          validator: (v) => v!.isEmpty ? 'Organization name required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _adminNameController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Admin / Contact Person Name',
                            prefixIcon: Icon(Icons.person_rounded, color: Colors.amberAccent, size: 20),
                          ),
                          validator: (v) => v!.isEmpty ? 'Admin name required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _adminPhoneController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Admin Phone Number',
                            prefixIcon: Icon(Icons.phone_rounded, color: Colors.amberAccent, size: 20),
                          ),
                          validator: (v) => v!.isEmpty ? 'Phone number required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _adminPasswordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            labelText: 'Admin Password',
                            helperText: 'Min. 8 chars, 1 uppercase, 1 number, 1 special char',
                            helperStyle: const TextStyle(fontSize: 10, color: Colors.amberAccent),
                            prefixIcon: const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.amberAccent, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _expectedMembersController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Expected Members Count',
                            prefixIcon: Icon(Icons.groups_rounded, color: Colors.amberAccent, size: 20),
                          ),
                        ),
                      ]
                      // ================= MEMBER REGISTRATION FORM =================
                      else ...[
                        TextFormField(
                          controller: _fullNameController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_rounded, color: BankTheme.accentPurple, size: 20),
                          ),
                          validator: (v) => v!.isEmpty ? 'Name required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_rounded, color: BankTheme.accentPurple, size: 20),
                          ),
                          validator: (v) => v!.isEmpty ? 'Phone required' : null,
                        ),
                        const SizedBox(height: 14),
                        // Organization Selection Dropdown
                        DropdownButtonFormField<String>(
                          value: activeOrgs.any((o) => o['code'] == _selectedOrgCode)
                              ? _selectedOrgCode
                              : (activeOrgs.isNotEmpty ? activeOrgs.first['code'] : 'default_org'),
                          decoration: const InputDecoration(
                            labelText: 'Select Organization',
                            prefixIcon: Icon(Icons.account_balance_rounded, color: BankTheme.accentPurple, size: 20),
                          ),
                          dropdownColor: theme.colorScheme.surface,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          items: activeOrgs.isEmpty
                              ? [const DropdownMenuItem(value: 'default_org', child: Text('Default Village Bank'))]
                              : activeOrgs.map((org) {
                                  return DropdownMenuItem<String>(
                                    value: org['code'],
                                    child: Text('${org['name']} (${org['memberCount'] ?? 0} members)'),
                                  );
                                }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedOrgCode = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: 'Min. 8 chars, 1 uppercase, 1 number, 1 special char',
                            helperStyle: const TextStyle(fontSize: 10, color: BankTheme.accentPurple),
                            prefixIcon: const Icon(Icons.lock_rounded, color: BankTheme.accentPurple, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: BankTheme.accentPurple, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: _isOrgAdminReg
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black)
                              : null,
                          onPressed: provider.isLoading ? null : _submitForm,
                          child: provider.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  _isLogin
                                      ? 'LOGIN'
                                      : (_isOrgAdminReg ? 'REGISTER ORGANIZATION' : 'REGISTER MEMBER'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _isOrgAdminReg = false;
                          });
                        },
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
