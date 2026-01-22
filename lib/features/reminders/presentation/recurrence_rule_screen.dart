import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../domain/recurrence_rule.dart';

class RecurrenceRuleScreen extends StatefulWidget {
  const RecurrenceRuleScreen({
    super.key,
    this.initialStartDate,
    this.initialTimeOfDay,
    this.initialRule,
  });

  final DateTime? initialStartDate;
  final TimeOfDay? initialTimeOfDay;
  final RecurrenceRule? initialRule;

  @override
  State<RecurrenceRuleScreen> createState() => _RecurrenceRuleScreenState();
}

class _RecurrenceRuleScreenState extends State<RecurrenceRuleScreen> {
  late RecurrenceFrequency _selectedFrequency;
  late Set<int> _selectedDays;
  late TimeOfDay _selectedTime;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _endDateEnabled = false;

  // Map day indices to abbreviated names
  final List<String> _dayAbbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final List<String> _fullDayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    final seedStart = widget.initialStartDate ?? DateTime.now();
    final seedTime = widget.initialTimeOfDay ?? const TimeOfDay(hour: 8, minute: 0);
    final seedRule = widget.initialRule;

    _selectedFrequency = seedRule?.frequency ?? RecurrenceFrequency.weekly;
    _selectedDays = {...(seedRule?.selectedWeekDays ?? {seedStart.weekday})};
    _selectedTime = seedRule?.timeOfDay ?? seedTime;
    _startDate = seedRule?.startDate ?? seedStart;
    _endDate = seedRule?.endDate;
    _endDateEnabled = _endDate != null;
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      if (_selectedDays.contains(dayIndex)) {
        _selectedDays.remove(dayIndex);
      } else {
        _selectedDays.add(dayIndex);
      }
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  List<Map<String, String>> _generateNextOccurrences() {
    final rule = _buildRule();
    final occurrences = <Map<String, String>>[];
    DateTime? cursor = rule.nextOccurrence(from: DateTime.now());
    int safety = 0;

    while (cursor != null && occurrences.length < 3 && safety < 12) {
      occurrences.add({
        'title': DateFormat('EEEE, MMM dd').format(cursor),
        'subtitle': _relativeSubtitle(cursor),
        'time': DateFormat('hh:mm a').format(cursor),
      });

      cursor = rule.nextOccurrence(from: cursor.add(const Duration(minutes: 1)));
      safety++;
    }

    return occurrences;
  }

  String _relativeSubtitle(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    final days = diff.inDays;
    if (days <= 0) {
      final hours = diff.inHours;
      if (hours <= 0) {
        return 'In less than 1 hour';
      }
      return 'In $hours hour${hours == 1 ? '' : 's'}';
    }
    return 'In $days day${days == 1 ? '' : 's'}';
  }

  List<TextSpan> _buildSummaryTextSpans() {
    final List<TextSpan> spans = [];
    
    spans.add(const TextSpan(
      text: 'Repeats every ',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600
      ),
    ));
    
    String frequencyText = '';
    switch (_selectedFrequency) {
      case RecurrenceFrequency.daily:
        frequencyText = 'Day';
        break;
      case RecurrenceFrequency.weekly:
        frequencyText = 'Week';
        break;
      case RecurrenceFrequency.monthly:
        frequencyText = 'Month';
        break;
      case RecurrenceFrequency.yearly:
        frequencyText = 'Year';
        break;
    }
    
    spans.add(TextSpan(
      text: frequencyText,
      style: const TextStyle(
        color: Color.fromARGB(255, 70, 107, 109),
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Color.fromARGB(255, 70, 107, 109),
      ),
    ));
    
    if (_selectedFrequency == RecurrenceFrequency.weekly && _selectedDays.isNotEmpty) {
      spans.add(const TextSpan(
        text: ' on ',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ));
      
      final sortedDays = _selectedDays.toList()..sort();
      final dayNames = sortedDays.map((dayIndex) {
        return _fullDayNames[dayIndex - 1].substring(0, 3);
      }).join(', ');
      
      spans.add(TextSpan(
        text: dayNames,
        style: const TextStyle(
          color: Color.fromARGB(255, 70, 107, 109),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Color.fromARGB(255, 70, 107, 109),
        ),
      ));
    }
    
    spans.add(const TextSpan(
      text: ' at ',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ));
    
    final hour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    
    spans.add(TextSpan(
      text: '$hour:$minute $period',
      style: const TextStyle(
        color: Color.fromARGB(255, 70, 107, 109),
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Color.fromARGB(255, 70, 107, 109),
      ),
    ));
    
    spans.add(const TextSpan(
      text: ' starting ',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ));
    
    final now = DateTime.now();
    final isToday = _startDate.year == now.year && 
                    _startDate.month == now.month && 
                    _startDate.day == now.day;
    final startDateText = isToday ? 'Today' : DateFormat('MMM dd, yyyy').format(_startDate);
    
    spans.add(TextSpan(
      text: startDateText,
      style: const TextStyle(
        color: Color.fromARGB(255, 70, 107, 109),
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Color.fromARGB(255, 70, 107, 109),
      ),
    ));
    
    if (_endDateEnabled && _endDate != null) {
      spans.add(const TextSpan(
        text: ' until ',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ));
      
      spans.add(TextSpan(
        text: DateFormat('MMM dd, yyyy').format(_endDate!),
        style: const TextStyle(
          color: Color.fromARGB(255, 70, 107, 109),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Color.fromARGB(255, 70, 107, 109),
        ),
      ));
    }
    
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 21, 23, 25),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 21, 23, 25),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            'Skip',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Recurrence Rule',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _buildRule()),
            child: Text(
              'Save',
              style: TextStyle(
                color: const Color.fromARGB(255, 70, 107, 109),
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Summary Text (no background)
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 22.sp,
                    height: 1.4,
                    color: Colors.white,
                  ),
                  children: _buildSummaryTextSpans(),
                ),
              ),

              SizedBox(height: 32.h),

              // Single container for all controls
              Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 33, 36, 39),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Frequency Selector Section
                    Padding(
                      padding: EdgeInsets.all(18.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FREQUENCY',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              _buildFrequencyChip('Daily', RecurrenceFrequency.daily),
                              SizedBox(width: 8.w),
                              _buildFrequencyChip('Weekly', RecurrenceFrequency.weekly),
                              SizedBox(width: 8.w),
                              _buildFrequencyChip('Monthly', RecurrenceFrequency.monthly),
                              SizedBox(width: 8.w),
                              _buildFrequencyChip('Yearly', RecurrenceFrequency.yearly),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Days Selector (only for weekly)
                    if (_selectedFrequency == RecurrenceFrequency.weekly) ...[
                      Divider(color: const Color.fromARGB(255, 38, 42, 46), height: 1.h),
                      Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ON THESE DAYS',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final dayIndex = index + 1;
                                final isSelected = _selectedDays.contains(dayIndex);
                                return _buildDayButton(
                                  _dayAbbreviations[index],
                                  dayIndex,
                                  isSelected,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Time Selector Section
                    Divider(color: const Color.fromARGB(255, 38, 42, 46), height: 1.h),
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: _selectTime,
                            borderRadius: BorderRadius.circular(20.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    () {
                                      final hour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
                                      final minute = _selectedTime.minute.toString().padLeft(2, '0');
                                      final period = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
                                      return '$hour:$minute $period';
                                    }(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.white70,
                                    size: 18.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Start Date Section
                    Divider(color: const Color.fromARGB(255, 38, 42, 46), height: 1.h),
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: _selectStartDate,
                            borderRadius: BorderRadius.circular(20.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_startDate),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                    size: 16.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // End Date Section
                    Divider(color: const Color.fromARGB(255, 38, 42, 46), height: 1.h),
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'End Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              if (_endDateEnabled) ...[
                                InkWell(
                                  onTap: _selectEndDate,
                                  borderRadius: BorderRadius.circular(20.r),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1F2E),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _endDate != null 
                                              ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                              : 'Select Date',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Icon(
                                          Icons.calendar_today,
                                          color: Colors.white70,
                                          size: 16.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                              ],
                              Switch(
                                value: _endDateEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _endDateEnabled = value;
                                    if (value && _endDate == null) {
                                      _endDate = _startDate.add(const Duration(days: 30));
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF4FC3A1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // Next Occurrences Section
              Text(
                'NEXT 3 OCCURRENCES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12.h),

              // Next occurrences in single container with dividers
              Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 33, 36, 39),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Column(
                  children: () {
                    final occurrences = _generateNextOccurrences();
                    return occurrences.asMap().entries.map((entry) {
                    final index = entry.key;
                    final occurrence = entry.value;
                    final isLast = index == occurrences.length - 1;
                    
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    occurrence['title']!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    occurrence['subtitle']!,
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F2E),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  occurrence['time']!,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast) Divider(color: const Color.fromARGB(255, 38, 42, 46), height: 1.h),
                      ],
                    );
                    }).toList();
                  }(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(String label, RecurrenceFrequency frequency) {
    final isSelected = _selectedFrequency == frequency;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFrequency = frequency;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color.fromARGB(255, 70, 107, 109) : const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  RecurrenceRule _buildRule() {
    return RecurrenceRule(
      frequency: _selectedFrequency,
      selectedWeekDays: _selectedDays,
      timeOfDay: _selectedTime,
      startDate: _startDate,
      endDate: _endDateEnabled ? _endDate : null,
    );
  }

  Widget _buildDayButton(String label, int dayIndex, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleDay(dayIndex),
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D8A7A) : const Color(0xFF1A1F2E),
          shape: BoxShape.circle,
          border: isSelected 
              ? Border.all(
                  color: const Color(0xFF4FC3A1),
                  width: 2.w,
                )
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
