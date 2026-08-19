import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../services/supabase_service.dart';
import '../services/push_registration_service.dart';
import '../services/error_handler.dart';
import '../services/storage_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form Keys
  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _aboutController = TextEditingController();

  // Selected values
  String _selectedCountry = '';
  String _selectedGender = 'Male';
  String _selectedLookingFor = 'Long-term partner';
  String _selectedRelationshipStatus = 'Single';
  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Selected local photos
  final List<XFile> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _genderOptions = [
    'Male', 'Female', 'Non-binary', 'Other'
  ];

  final List<String> _lookingForOptions = [
    'Long-term partner', 'Short-term fun', 'Friendship', 'Serious relationship', 'Still figuring it out'
  ];

  final List<String> _relationshipStatusOptions = [
    'Single', 'In a relationship', 'It\'s complicated', 'In an open relationship', 'Divorced'
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
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
        });
      },
    );
  }

  Future<void> _pickImage() async {
    if (_selectedPhotos.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos allowed')),
      );
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedPhotos.add(image);
        });
      }
    } catch (e) {
      if (kDebugMode && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep0.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (!_formKeyStep1.currentState!.validate()) return;
      if (_selectedCountry.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your country')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (!_formKeyStep2.currentState!.validate()) return;
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the terms and privacy policy')),
        );
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _createAccount() async {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 profile photo')),
      );
      return;
    }

    setState(() => _isLoading = true);
    bool sessionCreated = false;
    String? userId;

    try {
      // Step 1: Sign up in Auth
      final response = await SupabaseService.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign up failed: User details could not be resolved.');
      }
      userId = user.id;
      SessionStore.setUserId(userId);
      sessionCreated = true;

      // Step 2: Upload selected photos
      final List<String> uploadedPhotoPaths = [];
      for (final photo in _selectedPhotos) {
        try {
          final path = await StorageService.uploadPhoto(userId, photo);
          if (path != null) {
            uploadedPhotoPaths.add(path);
          } else {
            throw Exception('Failed to upload a photo.');
          }
        } catch (uploadError) {
          if (kDebugMode) {
            // Show exact error only on debug builds
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Upload failed debug error: $uploadError')),
              );
            }
          }
        }
      }

      // Check if we managed to upload at least one photo
      if (uploadedPhotoPaths.isEmpty) {
        throw Exception('Failed to upload any photos. Please try again.');
      }

      final fullName = _fullNameController.text.trim();
      final createdAt = DateTime.now().toIso8601String();

      // Step 3: Insert user profile document
      await SupabaseService.client.from('users').insert({
        'id': userId,
        'email': _emailController.text.trim(),
        'full_name': fullName,
        'age': int.parse(_ageController.text),
        'country': _selectedCountry,
        'city': _cityController.text.trim(),
        'looking_for': _selectedLookingFor,
        'relationship_status': _selectedRelationshipStatus,
        'about': _aboutController.text.trim(),
        'avatar_letter': fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
        'photos': uploadedPhotoPaths,
        'joined_groups': <String>[],
        'is_verified': false,
        'created_at': createdAt,
      });

      if (mounted) {
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
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: _isLoading ? null : _prevStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear progress stepper
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of $_totalSteps',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _getStepTitle(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.1, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _buildCurrentStepWidget(),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom navigation action buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _prevStep,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep == _totalSteps - 1 ? _createAccount : _nextStep),
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
                          : Text(_currentStep == _totalSteps - 1 ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Personal Info';
      case 1:
        return 'Location';
      case 2:
        return 'Preferences';
      case 3:
        return 'Photos';
      default:
        return '';
    }
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return Form(
          key: _formKeyStep0,
          child: Column(
            key: const ValueKey('step0'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFullNameField(),
              const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildAgeField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGenderField()),
                ],
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _formKeyStep1,
          child: Column(
            key: const ValueKey('step1'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCountryField(),
              const SizedBox(height: 16),
              _buildCityField(),
            ],
          ),
        );
      case 2:
        return Form(
          key: _formKeyStep2,
          child: Column(
            key: const ValueKey('step2'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLookingForField(),
              const SizedBox(height: 16),
              _buildRelationshipStatusField(),
              const SizedBox(height: 16),
              _buildAboutField(),
              const SizedBox(height: 24),
              _buildTermsCheckbox(),
            ],
          ),
        );
      case 3:
        return _buildPhotosStepWidget();
      default:
        return const SizedBox.shrink();
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(LucideIcons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
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
      isExpanded: true,
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
          validator: (value) {
            if (_selectedCountry.isEmpty) {
              return 'Country is required';
            }
            return null;
          },
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

  Widget _buildPhotosStepWidget() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add Profile Photos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please upload at least 1 photo to complete your profile. You can add up to 6 photos.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            if (index < _selectedPhotos.length) {
              final file = _selectedPhotos[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(file.path, fit: BoxFit.cover)
                          : Image.file(File(file.path), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return GestureDetector(
                onTap: _pickImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    color: colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
