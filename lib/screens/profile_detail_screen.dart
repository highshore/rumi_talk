import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/utils/interests.dart';
import 'package:firebase_app/widgets/tag.dart';
import 'package:firebase_app/services/stream_service.dart';
import 'package:firebase_app/services/auth_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String userId;
  const ProfileDetailScreen({super.key, required this.userId});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isLoading = false;
  File? _newImageFile;
  final _displayNameController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  DateTime? dateOfBirth;
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;
  String gender = '';
  String mbtiType = '';
  String profileImage = '';
  Set<String> _selectedInterests = {};
  String nativeLang = '';
  String targetLang = '';

  final List<String> _mbtiTypes = const [
    'ISTJ',
    'ISFJ',
    'INFJ',
    'INTJ',
    'ISTP',
    'ISFP',
    'INFP',
    'INTP',
    'ESTP',
    'ESFP',
    'ENFP',
    'ENTP',
    'ESTJ',
    'ESFJ',
    'ENFJ',
    'ENTJ',
  ];

  final List<String> _monthNames = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _displayNameController.text =
            (data['displayName'] ?? _auth.currentUser?.displayName ?? '')
                .toString();
        dateOfBirth = data['dateOfBirth'] != null
            ? (data['dateOfBirth'] as Timestamp).toDate()
            : null;
        gender = (data['gender'] ?? '').toString();
        mbtiType = (data['mbtiType'] ?? '').toString();
        profileImage = (data['profileImage'] ?? '').toString();
        final interests = data['interests'] != null
            ? List<String>.from(data['interests'])
            : <String>[];
        _selectedInterests = Set<String>.from(interests);
        nativeLang = (data['nativeLang'] ?? '').toString();
        targetLang = (data['targetLang'] ?? '').toString();
        if (dateOfBirth != null) {
          _selectedYear = dateOfBirth!.year;
          _selectedMonth = dateOfBirth!.month;
          _selectedDay = dateOfBirth!.day;
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access photos')),
        );
      }
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (image == null) return;
    setState(() => _newImageFile = File(image.path));
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final streamService = StreamService(
        client: StreamService.staticClient,
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instance,
      );
      if (_newImageFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
          'prof_pics/${widget.userId}.jpg',
        );
        await storageRef.putFile(_newImageFile!);
        profileImage = await storageRef.getDownloadURL();
      }
      DateTime? finalDOB;
      if (_selectedYear != null &&
          _selectedMonth != null &&
          _selectedDay != null) {
        finalDOB = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
            'displayName': _displayNameController.text.trim(),
            'dateOfBirth': finalDOB,
            'gender': gender,
            'mbtiType': mbtiType,
            'interests': _selectedInterests.toList(),
            'profileImage': profileImage,
            'nativeLang': nativeLang,
            'targetLang': targetLang,
          }, SetOptions(merge: true));

      await streamService.updateStreamUser(
        name: _displayNameController.text.trim(),
        image: profileImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: _newImageFile != null
                  ? FileImage(_newImageFile!)
                  : (profileImage.isNotEmpty
                            ? NetworkImage(profileImage)
                            : null)
                        as ImageProvider<Object>?,
              child: (_newImageFile == null && profileImage.isEmpty)
                  ? const Icon(Icons.person, size: 60, color: Colors.white70)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xff545454),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropDownField(
    String label,
    String value,
    List<String> items, {
    void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value.isNotEmpty ? value : null,
            hint: Text(label, style: const TextStyle(color: Colors.white54)),
            dropdownColor: Colors.black.withOpacity(0.8),
            iconEnabledColor: Colors.white70,
            isExpanded: true,
            underline: const SizedBox(),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(color: Colors.white)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDOBFields() {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 1978, (index) => 1979 + index);
    final days = (_selectedYear != null && _selectedMonth != null)
        ? List.generate(
            DateTime(_selectedYear!, _selectedMonth! + 1, 0).day,
            (i) => i + 1,
          )
        : List.generate(31, (i) => i + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMonthDropdown(_selectedMonth, 'Month', (val) {
              setState(() {
                _selectedMonth = val;
                if (_selectedDay != null && val != null) {
                  final maxDay = DateTime(
                    _selectedYear ?? 2000,
                    val + 1,
                    0,
                  ).day;
                  if (_selectedDay! > maxDay) _selectedDay = null;
                }
              });
            }),
            const SizedBox(width: 8),
            _buildIntDropdown(
              _selectedDay,
              'Day',
              days,
              (val) => setState(() => _selectedDay = val),
            ),
            const SizedBox(width: 8),
            _buildIntDropdown(_selectedYear, 'Year', years, (val) {
              setState(() {
                _selectedYear = val;
                if (_selectedMonth != null &&
                    _selectedDay != null &&
                    val != null) {
                  final maxDay = DateTime(val, _selectedMonth! + 1, 0).day;
                  if (_selectedDay! > maxDay) _selectedDay = null;
                }
              });
            }),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMonthDropdown(
    int? currentValue,
    String hint,
    ValueChanged<int?> onChanged,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<int>(
          value: currentValue,
          hint: Text(hint, style: const TextStyle(color: Colors.white54)),
          dropdownColor: Colors.black.withOpacity(0.8),
          iconEnabledColor: Colors.white70,
          isExpanded: true,
          underline: const SizedBox(),
          items: List.generate(12, (i) => i + 1)
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    _monthNames[m - 1],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildIntDropdown(
    int? currentValue,
    String hint,
    List<int> items,
    ValueChanged<int?> onChanged,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<int>(
          value: currentValue,
          hint: Text(hint, style: const TextStyle(color: Colors.white54)),
          dropdownColor: Colors.black.withOpacity(0.8),
          iconEnabledColor: Colors.white70,
          isExpanded: true,
          underline: const SizedBox(),
          items: items
              .map(
                (d) => DropdownMenuItem(
                  value: d,
                  child: Text(
                    d.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInterestsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...categorizedInterests.entries.map((entry) {
          final category = entry.key;
          final interests = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  final color = isSelected
                      ? darkenColor(getColorForInterest(interest))
                      : const Color(0xff424242);
                  final emoji = getEmojiForInterest(interest);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedInterests.remove(interest);
                        } else {
                          if (_selectedInterests.length >= 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You can only choose up to 8 interest tags.',
                                ),
                              ),
                            );
                          } else {
                            _selectedInterests.add(interest);
                          }
                        }
                      });
                    },
                    child: Tag(label: interest, emoji: emoji, color: color),
                  );
                }).toList(),
              ),
            ],
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff242424),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will permanently delete your account and data. Continue?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final streamService = StreamService(
        client: StreamService.staticClient,
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instance,
      );
      await streamService.deleteUser();
      await _authService.deleteAccount();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff181818),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile Info',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildProfileImage(),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xff333333),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _displayNameController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Display Name',
                                hintStyle: TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Color(0xff0f0f0f),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Card(
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: Colors.white.withOpacity(0.08),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Basic Info',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDOBFields(),
                                  _buildDropDownField(
                                    'Gender',
                                    gender,
                                    const ['Male', 'Female', 'Other'],
                                    onChanged: (v) =>
                                        setState(() => gender = v ?? ''),
                                  ),
                                  _buildDropDownField(
                                    'MBTI Type',
                                    mbtiType,
                                    _mbtiTypes,
                                    onChanged: (v) =>
                                        setState(() => mbtiType = v ?? ''),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Languages',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDropDownField(
                                    'Native Language',
                                    nativeLang,
                                    const [
                                      'en',
                                      'es',
                                      'ko',
                                      'ja',
                                      'zh',
                                      'fr',
                                      'de',
                                      'it',
                                      'pt',
                                    ],
                                    onChanged: (v) =>
                                        setState(() => nativeLang = v ?? ''),
                                  ),
                                  _buildDropDownField(
                                    'Target Language',
                                    targetLang,
                                    const [
                                      'en',
                                      'es',
                                      'ko',
                                      'ja',
                                      'zh',
                                      'fr',
                                      'de',
                                      'it',
                                      'pt',
                                    ],
                                    onChanged: (v) =>
                                        setState(() => targetLang = v ?? ''),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Choose Your Interests',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInterestsField(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xffdc2626),
                                    Color(0xffb91c1c),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _authService.signOut();
                                  if (mounted) {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/login',
                                      (route) => false,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign Out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _confirmDeleteAccount,
                              child: const Text(
                                'Delete Account',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
    );
  }
}
