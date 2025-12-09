import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  final _aboutController = TextEditingController();
  
  String _selectedGender = 'Male';
  String _selectedLookingFor = 'Long-term partner';
  String _selectedRelationshipStatus = 'Single';
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

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
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final doc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      final profileResponse = doc.data;

      if (mounted) {
        setState(() {
          _profile = profileResponse;
          _fullNameController.text = profileResponse['fullName'] ?? '';
          _cityController.text = profileResponse['city'] ?? '';
          _ageController.text = profileResponse['age']?.toString() ?? '';
          _aboutController.text = profileResponse['about'] ?? '';
          _selectedGender = profileResponse['gender'] ?? 'Male';
          _selectedLookingFor =
              profileResponse['lookingFor'] ?? 'Long-term partner';
          _selectedRelationshipStatus =
              profileResponse['relationshipStatus'] ?? 'Single';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {
          'fullName': _fullNameController.text.trim(),
          'city': _cityController.text.trim(),
          'age': int.parse(_ageController.text),
          'about': _aboutController.text.trim(),
          'gender': _selectedGender,
          'lookingFor': _selectedLookingFor,
          'relationshipStatus': _selectedRelationshipStatus,
          'avatarLetter': _fullNameController.text.trim().isNotEmpty
              ? _fullNameController.text.trim()[0].toUpperCase()
              : 'U',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update your profile information',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Email (non-editable)
                    TextFormField(
                      initialValue: _profile?['email'] ?? '',
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.mail),
                        helperText: 'Email cannot be changed',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Country (non-editable)
                    TextFormField(
                      initialValue: _profile?['country'] ?? '',
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.mapPin),
                        helperText: 'Country cannot be changed',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.cake),
                      ),
                      validator: (value) {
                        if (value == null || int.tryParse(value) == null || int.parse(value) < 18) {
                          return 'Must be at least 18 years old';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // City
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.building2),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'City must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.personStanding),
                      ),
                      items: _genderOptions.map((gender) {
                        return DropdownMenuItem(value: gender, child: Text(gender));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedGender = value!),
                    ),
                    const SizedBox(height: 16),

                    // Looking For
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLookingFor,
                      decoration: const InputDecoration(
                        labelText: 'Looking For',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.heart),
                      ),
                      items: _lookingForOptions.map((option) {
                        return DropdownMenuItem(value: option, child: Text(option));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedLookingFor = value!),
                    ),
                    const SizedBox(height: 16),

                    // Relationship Status
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRelationshipStatus,
                      decoration: const InputDecoration(
                        labelText: 'Relationship Status',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.glassWater),
                      ),
                      items: _relationshipStatusOptions.map((status) {
                        return DropdownMenuItem(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedRelationshipStatus = value!),
                    ),
                    const SizedBox(height: 16),

                    // About You
                    TextFormField(
                      controller: _aboutController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'About You',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.fileText),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 20 || value.trim().length > 500) {
                          return 'Bio must be between 20 and 500 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveChanges,
                        icon: _isSaving 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
