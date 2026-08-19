import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/supabase_service.dart';

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

      final doc = await SupabaseService.client
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (doc != null) {
        final profileResponse = {
          'id': doc['id'],
          'fullName': doc['full_name'],
          'city': doc['city'],
          'age': doc['age'],
          'about': doc['about'],
          'gender': doc['gender'] ?? 'Male',
          'lookingFor': doc['looking_for'],
          'relationshipStatus': doc['relationship_status'],
          'email': doc['email'],
          'country': doc['country'],
        };

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

      await SupabaseService.client
          .from('users')
          .update({
            'full_name': _fullNameController.text.trim(),
            'city': _cityController.text.trim(),
            'age': int.parse(_ageController.text),
            'about': _aboutController.text.trim(),
            'gender': _selectedGender,
            'looking_for': _selectedLookingFor,
            'relationship_status': _selectedRelationshipStatus,
            'avatar_letter': _fullNameController.text.trim().isNotEmpty
                ? _fullNameController.text.trim()[0].toUpperCase()
                : 'U',
          })
          .eq('id', userId);

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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Modern app bar
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      LucideIcons.edit,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Edit Profile',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    title: const Text(
                      'Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                
                // Form content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.info,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Update your profile information to help others get to know you better',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Account Information Section
                          _buildSection('Account Information', [
                            _buildReadOnlyField(
                              'Email',
                              _profile?['email'] ?? '',
                              LucideIcons.mail,
                              'Email cannot be changed',
                            ),
                            _buildReadOnlyField(
                              'Country',
                              _profile?['country'] ?? '',
                              LucideIcons.mapPin,
                              'Country cannot be changed',
                            ),
                          ]),
                          
                          const SizedBox(height: 32),
                          
                          // Personal Information Section
                          _buildSection('Personal Information', [
                            _buildFullNameField(),
                            Row(
                              children: [
                                Expanded(child: _buildAgeField()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildGenderField()),
                              ],
                            ),
                            _buildCityField(),
                          ]),
                          
                          const SizedBox(height: 32),
                          
                          // Dating Preferences Section
                          _buildSection('Dating Preferences', [
                            _buildLookingForField(),
                            _buildRelationshipStatusField(),
                          ]),
                          
                          const SizedBox(height: 32),
                          
                          // About Section
                          _buildSection('About You', [
                            _buildAboutField(),
                          ]),
                          
                          const SizedBox(height: 40),
                          
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
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
                                  : const Icon(LucideIcons.save, size: 18),
                              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...fields.map((field) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: field,
        )),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon, String helperText) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: value.isEmpty 
                        ? colorScheme.onSurface.withOpacity(0.4)
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  helperText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        labelText: 'Looking For',
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
}