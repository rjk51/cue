import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/custom_icon_service.dart';

class IconPickerSheet extends StatefulWidget {
  final Color accentColor;
  final bool isDarkMode;
  final IconData? initialIcon;
  final String? initialCustomIconUrl;

  const IconPickerSheet({
    super.key,
    required this.accentColor,
    required this.isDarkMode,
    this.initialIcon,
    this.initialCustomIconUrl,
  });

  @override
  State<IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<IconPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  IconData? _selectedIcon;
  String? _selectedCustomIconUrl;
  final CustomIconService _customIconService = CustomIconService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  // Icon categories with relevant icons
  final Map<String, List<IconData>> _iconCategories = {
    'Health': [
      Icons.medication_outlined,
      Icons.healing_outlined,
      Icons.favorite_outline,
      Icons.medical_services_outlined,
      Icons.local_hospital_outlined,
      Icons.sanitizer_outlined,
      Icons.vaccines_outlined,
      Icons.health_and_safety_outlined,
    ],
    'Personal': [
      Icons.person_outline,
      Icons.face_outlined,
      Icons.sentiment_satisfied_outlined,
      Icons.accessibility_new_outlined,
      Icons.self_improvement_outlined,
      Icons.psychology_outlined,
      Icons.spa_outlined,
      Icons.bedtime_outlined,
    ],
    'Work': [
      Icons.work_outline,
      Icons.business_center_outlined,
      Icons.laptop_outlined,
      Icons.computer_outlined,
      Icons.description_outlined,
      Icons.folder_outlined,
      Icons.create_outlined,
      Icons.assignment_outlined,
    ],
    'Home': [
      Icons.home_outlined,
      Icons.house_outlined,
      Icons.cottage_outlined,
      Icons.kitchen_outlined,
      Icons.bed_outlined,
      Icons.weekend_outlined,
      Icons.chair_outlined,
      Icons.checkroom_outlined,
    ],
    'Food': [
      Icons.restaurant_outlined,
      Icons.fastfood_outlined,
      Icons.local_cafe_outlined,
      Icons.local_pizza_outlined,
      Icons.lunch_dining_outlined,
      Icons.dinner_dining_outlined,
      Icons.breakfast_dining_outlined,
      Icons.cake_outlined,
    ],
    'Transport': [
      Icons.directions_car_outlined,
      Icons.directions_bus_outlined,
      Icons.train_outlined,
      Icons.flight_outlined,
      Icons.directions_bike_outlined,
      Icons.directions_walk_outlined,
      Icons.local_shipping_outlined,
      Icons.two_wheeler_outlined,
    ],
    'Shopping': [
      Icons.shopping_cart_outlined,
      Icons.shopping_bag_outlined,
      Icons.store_outlined,
      Icons.local_mall_outlined,
      Icons.local_grocery_store_outlined,
      Icons.receipt_outlined,
      Icons.payment_outlined,
      Icons.loyalty_outlined,
    ],
    'Nature': [
      Icons.local_florist_outlined,
      Icons.park_outlined,
      Icons.nature_outlined,
      Icons.eco_outlined,
      Icons.wb_sunny_outlined,
      Icons.nightlight_outlined,
      Icons.pets_outlined,
      Icons.water_drop_outlined,
    ],
    'Social': [
      Icons.groups_outlined,
      Icons.people_outline,
      Icons.forum_outlined,
      Icons.chat_outlined,
      Icons.call_outlined,
      Icons.video_call_outlined,
      Icons.mail_outline,
      Icons.notifications_outlined,
    ],
    'Fitness': [
      Icons.fitness_center_outlined,
      Icons.directions_run_outlined,
      Icons.sports_outlined,
      Icons.pool_outlined,
      Icons.sports_basketball_outlined,
      Icons.sports_tennis_outlined,
      Icons.sports_soccer_outlined,
      Icons.sports_handball_outlined,
    ],
    'Education': [
      Icons.school_outlined,
      Icons.book_outlined,
      Icons.menu_book_outlined,
      Icons.library_books_outlined,
      Icons.class_outlined,
      Icons.grade_outlined,
      Icons.history_edu_outlined,
      Icons.science_outlined,
    ],
    'Entertainment': [
      Icons.movie_outlined,
      Icons.music_note_outlined,
      Icons.theater_comedy_outlined,
      Icons.sports_esports_outlined,
      Icons.tv_outlined,
      Icons.headphones_outlined,
      Icons.camera_outlined,
      Icons.photo_camera_outlined,
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon;
    _selectedCustomIconUrl = widget.initialCustomIconUrl;
    _tabController = TabController(
      length: _iconCategories.length + 1, // +1 for Custom tab
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode
        ? const Color.fromARGB(255, 21, 23, 25)
        : Colors.white;
    final cardColor = widget.isDarkMode
        ? const Color.fromARGB(255, 33, 36, 39)
        : const Color(0xFFF5F5F5);
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Icon',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Return either custom icon URL or regular icon
                    if (_selectedCustomIconUrl != null) {
                      Navigator.pop(context, {
                        'type': 'custom',
                        'url': _selectedCustomIconUrl,
                      });
                    } else {
                      Navigator.pop(context, _selectedIcon);
                    }
                  },
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
          Container(
            color: backgroundColor,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              indicatorPadding: EdgeInsets.zero,
              tabAlignment: TabAlignment.start,
              controller: _tabController,
              isScrollable: true,
              labelColor: widget.accentColor,
              unselectedLabelColor: textColor.withOpacity(0.5),
              indicatorColor: widget.accentColor,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                const Tab(text: 'Custom'),
                ..._iconCategories.keys
                    .map((category) => Tab(text: category))
                    .toList(),
              ],
            ),
          ),

          // Icon grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomIconsTab(cardColor, textColor, backgroundColor),
                ..._iconCategories.entries.map((entry) {
                  return _buildIconGrid(entry.value, cardColor, textColor);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid(
    List<IconData> icons,
    Color cardColor,
    Color textColor,
  ) {
    return GridView.builder(
      padding: EdgeInsets.all(20.r),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final isSelected =
            _selectedIcon == icon && _selectedCustomIconUrl == null;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIcon = icon;
              _selectedCustomIconUrl = null; // Clear custom selection
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? widget.accentColor.withOpacity(0.2)
                  : cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: isSelected
                  ? Border.all(color: widget.accentColor, width: 2.w)
                  : null,
            ),
            child: Icon(
              icon,
              size: 32.sp,
              color: isSelected
                  ? widget.accentColor
                  : textColor.withOpacity(0.7),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomIconsTab(
    Color cardColor,
    Color textColor,
    Color backgroundColor,
  ) {
    return StreamBuilder<List<CustomIcon>>(
      stream: _customIconService.getCustomIconsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: widget.accentColor),
          );
        }

        final customIcons = snapshot.data ?? [];

        return Column(
          children: [
            // Add icon button
            Padding(
              padding: EdgeInsets.all(20.r),
              child: GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadImage,
                child: Container(
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: widget.accentColor,
                      width: 2.w,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _isUploading
                      ? Center(
                          child: SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: CircularProgressIndicator(
                              color: widget.accentColor,
                              strokeWidth: 2.w,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: widget.accentColor,
                              size: 24.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Add Custom Icon',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: widget.accentColor,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // Custom icons grid
            if (customIcons.isEmpty && !_isUploading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.collections_outlined,
                        size: 64.sp,
                        color: textColor.withOpacity(0.3),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'No custom icons yet',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: textColor.withOpacity(0.5),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Tap "Add Custom Icon" to upload',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: textColor.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                  ),
                  itemCount: customIcons.length,
                  itemBuilder: (context, index) {
                    final customIcon = customIcons[index];
                    final isSelected =
                        _selectedCustomIconUrl == customIcon.imageUrl;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCustomIconUrl = customIcon.imageUrl;
                          _selectedIcon = null; // Clear regular icon selection
                        });
                      },
                      onLongPress: () {
                        _showDeleteDialog(customIcon);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accentColor.withOpacity(0.2)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: isSelected
                              ? Border.all(
                                  color: widget.accentColor,
                                  width: 2.w,
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14.r),
                          child: Image.network(
                            customIcon.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.error_outline,
                                size: 32.sp,
                                color: textColor.withOpacity(0.5),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 24.w,
                                  height: 24.h,
                                  child: CircularProgressIndicator(
                                    color: widget.accentColor,
                                    strokeWidth: 2.w,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final imageFile = File(image.path);
      final customIcon = await _customIconService.uploadCustomIcon(imageFile);

      if (customIcon != null && mounted) {
        setState(() {
          _selectedCustomIconUrl = customIcon.imageUrl;
          _selectedIcon = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom icon uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading icon: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _showDeleteDialog(CustomIcon customIcon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Icon'),
        content: const Text(
          'Are you sure you want to delete this custom icon? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _customIconService.deleteCustomIcon(customIcon.id);
      if (mounted) {
        // If the deleted icon was selected, clear selection
        if (_selectedCustomIconUrl == customIcon.imageUrl) {
          setState(() {
            _selectedCustomIconUrl = null;
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Custom icon deleted')));
      }
    }
  }
}
