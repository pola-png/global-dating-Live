import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

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
  String _countryCode = '+1';
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
          _countryCode = '+${country.phoneCode}';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AppwriteException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
        // If we already have a session, still move the user to home.
        if (sessionCreated) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
          ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.heart,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create an Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Join our global community and find your connection.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWide = constraints.maxWidth > 500;
                          
                          return Column(
                            children: [
                              if (isWide) 
                                Row(
                                  children: [
                                    Expanded(child: _buildFullNameField()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildEmailField()),
                                  ],
                                )
                              else ...[
                                _buildFullNameField(),
                                const SizedBox(height: 16),
                                _buildEmailField(),
                                const SizedBox(height: 16),
                              ],

                              if (isWide) const SizedBox(height: 16),

                              if (isWide)
                                Row(
                                  children: [
                                    Expanded(child: _buildPasswordField()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildAgeField()),
                                  ],
                                )
                              else ...[
                                _buildPasswordField(),
                                const SizedBox(height: 16),
                                _buildAgeField(),
                                const SizedBox(height: 16),
                              ],

                              if (isWide) const SizedBox(height: 16),

                              if (isWide)
                                Row(
                                  children: [
                                    Expanded(child: _buildGenderField()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildCountryField()),
                                  ],
                                )
                              else ...[
                                _buildGenderField(),
                                const SizedBox(height: 16),
                                _buildCountryField(),
                                const SizedBox(height: 16),
                              ],

                              if (isWide) const SizedBox(height: 16),

                              _buildCityField(),
                              const SizedBox(height: 16),

                              if (isWide)
                                Row(
                                  children: [
                                    Expanded(child: _buildLookingForField()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildRelationshipStatusField()),
                                  ],
                                )
                              else ...[
                                _buildLookingForField(),
                                const SizedBox(height: 16),
                                _buildRelationshipStatusField(),
                                const SizedBox(height: 16),
                              ],

                              if (isWide) const SizedBox(height: 16),

                              _buildAboutField(),
                              const SizedBox(height: 16),

                              _buildTermsCheckbox(),
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _createAccount,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          'Create Account',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              TextButton(
                                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                child: Text(
                                  'Already have an account? Login',
                                  style: TextStyle(color: Theme.of(context).primaryColor),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      decoration: const InputDecoration(
        labelText: 'Full Name',
        border: OutlineInputBorder(),
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
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
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
      decoration: const InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(),
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
      decoration: const InputDecoration(
        labelText: 'Age',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || int.tryParse(value) == null || int.parse(value) < 18) {
          return 'Must be at least 18 years old';
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: const InputDecoration(
        labelText: 'Gender',
        border: OutlineInputBorder(),
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
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            hintText: _selectedCountry,
          ),
          controller: TextEditingController(text: _selectedCountry),
        ),
      ),
    );
  }

  Widget _buildCityField() {
    return TextFormField(
      controller: _cityController,
      decoration: const InputDecoration(
        labelText: 'City',
        border: OutlineInputBorder(),
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
      initialValue: _selectedLookingFor,
      decoration: const InputDecoration(
        labelText: 'Looking for',
        border: OutlineInputBorder(),
      ),
      items: _lookingForOptions.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList(),
      onChanged: (value) => setState(() => _selectedLookingFor = value!),
    );
  }

  Widget _buildRelationshipStatusField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRelationshipStatus,
      decoration: const InputDecoration(
        labelText: 'Relationship Status',
        border: OutlineInputBorder(),
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
      decoration: const InputDecoration(
        labelText: 'About You',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.alertCircle, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You must be 18 years or older to use this service',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _acceptTerms,
              onChanged: (value) => setState(() => _acceptTerms = value!),
              activeColor: Theme.of(context).primaryColor,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/policy'),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF333333)),
                    children: [
                      const TextSpan(text: 'I am 18+ and accept the '),
                      TextSpan(
                        text: 'Terms and Privacy Policy',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
