import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class IconPickerSheet extends StatefulWidget {
  final Color accentColor;
  final bool isDarkMode;
  final IconData? initialIcon;

  const IconPickerSheet({
    super.key,
    required this.accentColor,
    required this.isDarkMode,
    this.initialIcon,
  });

  @override
  State<IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<IconPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  IconData? _selectedIcon;

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
    _tabController = TabController(
      length: _iconCategories.length,
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
                  onPressed: () => Navigator.pop(context, _selectedIcon),
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
              tabs: _iconCategories.keys
                  .map((category) => Tab(text: category))
                  .toList(),
            ),
          ),

          // Icon grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _iconCategories.entries.map((entry) {
                return _buildIconGrid(entry.value, cardColor, textColor);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid(List<IconData> icons, Color cardColor, Color textColor) {
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
        final isSelected = _selectedIcon == icon;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIcon = icon;
            });
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
            child: Icon(
              icon,
              size: 32.sp,
              color: isSelected ? widget.accentColor : textColor.withOpacity(0.7),
            ),
          ),
        );
      },
    );
  }
}
