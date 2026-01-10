import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/push_registration_service.dart';
import '../services/error_handler.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();

  final _cityController = TextEditingController();
  final _aboutController = TextEditingController();
  
  String _selectedGender = 'Male';
  String _selectedCountry = 'United States';
  // String _countryCode = '+1'; // Unused field
  String _selectedLookingFor = 'Long-term partner';
  String _selectedRelationshipStatus = 'Single';
  bool _acceptTerms = false;
  bool _isLoading = false;

  final List<String> _genderOptions = [
    'Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say'
  ];

  final List<String> _lookingForOptions = [
    'Long-term partner', 'Short-term fun', 'Friendship', 'Serious relationship', 'Still figuring it out'
  ];

  final List<String> _relationshipStatusOptions = [
    'Single', 'In a relationship', 'It\'s complicated', 'In an open relationship', 'Divorced'
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();

    _cityController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country.name;
          // _countryCode = '+${country.phoneCode}';
        });
      },
    );
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate() || !_acceptTerms) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the terms and privacy policy')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    bool sessionCreated = false;

    try {
      final account = AppwriteService.account;
      final databases = AppwriteService.databases;

      final user = await account.create(
        userId: ID.unique(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _fullNameController.text.trim(),
      );

      await account.createEmailPasswordSession(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      SessionStore.setUserId(user.$id);
      sessionCreated = true;

      final fullName = _fullNameController.text.trim();
      final createdAt = DateTime.now().toIso8601String();

      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: user.$id,
        data: {
          'userId': user.$id,
          'fullName': fullName,
          'email': _emailController.text.trim(),
          'age': int.parse(_ageController.text),
          'country': _selectedCountry,
          'city': _cityController.text.trim(),
          'lookingFor': _selectedLookingFor,
          'relationshipStatus': _selectedRelationshipStatus,
          'about': _aboutController.text.trim(),
          'avatarLetter': fullName.isNotEmpty
              ? fullName[0].toUpperCase()
              : 'U',
          'photos': <String>[],
          'joinedGroups': <String>[],
          'coinBalance': 0,
          'isBoosted': false,
          'boostedUntil': null,
          'isVerified': false,
          'createdAt': createdAt,
          'avatarPath': null,
        },
      );

      if (mounted) {
        // Auto-register for push notifications
        PushRegistrationService.registerForPush();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getPlainMessage(e))),
        );
        if (sessionCreated) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    // Modern hero section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.heart,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Join Global Dating',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connect with people worldwide and find meaningful relationships',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form fields with modern spacing
                    _buildFormSection('Personal Information', [
                      _buildFullNameField(),
                      _buildEmailField(),
                      _buildPasswordField(),
                      Row(
                        children: [
                          Expanded(child: _buildAgeField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildGenderField()),
                        ],
                      ),
                    ]),
                    
                    const SizedBox(height: 24),
                    
                    _buildFormSection('Location', [
                      _buildCountryField(),
                      _buildCityField(),
                    ]),
                    
                    const SizedBox(height: 24),
                    
                    _buildFormSection('Dating Preferences', [
                      _buildLookingForField(),
                      _buildRelationshipStatusField(),
                      _buildAboutField(),
                    ]),
                    
                    const SizedBox(height: 24),
                    
                    _buildTermsCheckbox(),
                    const SizedBox(height: 32),
                    
                    // Modern CTA button
                    FilledButton(
                      onPressed: _isLoading ? null : _createAccount,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFormSection(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...fields.map((field) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: field,
        )),
      ],
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      decoration: InputDecoration(
        labelText: 'Full Name',
        prefixIcon: const Icon(LucideIcons.user),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      validator: (value) {
        if (value == null || value.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: const Icon(LucideIcons.mail),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      validator: (value) {
        if (value == null || !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(LucideIcons.lock),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      validator: (value) {
        if (value == null || value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildAgeField() {
    return TextFormField(
      controller: _ageController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Age',
        prefixIcon: const Icon(LucideIcons.cake),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      validator: (value) {
        if (value == null || int.tryParse(value) == null || int.parse(value) < 18) {
          return 'Must be 18+';
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: 'Gender',
        prefixIcon: const Icon(LucideIcons.personStanding),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      items: _genderOptions.map((gender) {
        return DropdownMenuItem(value: gender, child: Text(gender));
      }).toList(),
      onChanged: (value) => setState(() => _selectedGender = value!),
    );
  }

  Widget _buildCountryField() {
    return GestureDetector(
      onTap: _selectCountry,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: 'Country',
            prefixIcon: const Icon(LucideIcons.mapPin),
            suffixIcon: const Icon(LucideIcons.chevronDown),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
          controller: TextEditingController(text: _selectedCountry),
        ),
      ),
    );
  }

  Widget _buildCityField() {
    return TextFormField(
      controller: _cityController,
      decoration: InputDecoration(
        labelText: 'City',
        prefixIcon: const Icon(LucideIcons.building2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      validator: (value) {
        if (value == null || value.trim().length < 2) {
          return 'City must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildLookingForField() {
    return DropdownButtonFormField<String>(
      value: _selectedLookingFor,
      decoration: InputDecoration(
        labelText: 'Looking for',
        prefixIcon: const Icon(LucideIcons.heart),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      items: _lookingForOptions.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList(),
      onChanged: (value) => setState(() => _selectedLookingFor = value!),
    );
  }

  Widget _buildRelationshipStatusField() {
    return DropdownButtonFormField<String>(
      value: _selectedRelationshipStatus,
      decoration: InputDecoration(
        labelText: 'Relationship Status',
        prefixIcon: const Icon(LucideIcons.users),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      items: _relationshipStatusOptions.map((status) {
        return DropdownMenuItem(value: status, child: Text(status));
      }).toList(),
      onChanged: (value) => setState(() => _selectedRelationshipStatus = value!),
    );
  }

  Widget _buildAboutField() {
    return TextFormField(
      controller: _aboutController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'About You',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(LucideIcons.fileText),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        alignLabelWithHint: true,
        helperText: 'Tell others about yourself (20-500 characters)',
      ),
      validator: (value) {
        if (value == null || value.trim().length < 20 || value.trim().length > 500) {
          return 'Bio must be between 20 and 500 characters';
        }
        return null;
      },
    );
  }

  Widget _buildTermsCheckbox() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.error.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.shieldAlert,
                color: colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You must be 18 years or older to use this service',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value!),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/policy'),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'I am 18+ and accept the '),
                  TextSpan(
                    text: 'Terms and Privacy Policy',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
