import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Counter',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          home: const TrackerHomePage(),
        );
      },
    );
  }
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({super.key});

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  final Map<DateTime, int> _dayCounts = LinkedHashMap<DateTime, int>(
    equals: isSameDay,
    hashCode: (DateTime key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonMap = prefs.getString('day_counts_map');
    if (jsonMap != null) {
      Map<String, dynamic> decoded = jsonDecode(jsonMap);
      setState(() {
        _dayCounts.clear();
        decoded.forEach((key, value) {
          _dayCounts[DateTime.parse(key)] = value as int;
        });
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, int> stringKeyMap = {};
    _dayCounts.forEach((key, value) {
      stringKeyMap[key.toIso8601String()] = value;
    });
    await prefs.setString('day_counts_map', jsonEncode(stringKeyMap));
  }

  int _getCount(DateTime day) {
    DateTime? key = _dayCounts.keys.firstWhere(
      (k) => isSameDay(k, day), 
      orElse: () => DateTime(0)
    );
    if (key.year == 0) return 0;
    return _dayCounts[key]!;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      int currentCount = _getCount(selectedDay);
      DateTime key = _dayCounts.keys.firstWhere((k) => isSameDay(k, selectedDay), orElse: () => selectedDay);
      _dayCounts[key] = currentCount + 1;
      _saveData();
    });
  }

  void _onDayLongPressed(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      if (_getCount(selectedDay) > 0) {
        _dayCounts.removeWhere((key, value) => isSameDay(key, selectedDay));
        _saveData();
      }
    });
  }

  int get _totalCount {
    return _dayCounts.values.fold(0, (sum, count) => sum + count);
  }

  int get _monthlyCount {
    return _dayCounts.entries
        .where((e) => e.key.year == _focusedDay.year && e.key.month == _focusedDay.month)
        .fold(0, (sum, e) => sum + e.value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('日常记录'),
        centerTitle: true,
        forceMaterialTransparency: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              elevation: 0,
              color: colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  headerStyle: const HeaderStyle(
                    titleCentered: true, 
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                    weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  selectedDayPredicate: (day) => _getCount(day) > 0,
                  onDaySelected: _onDaySelected,
                  onDayLongPressed: _onDayLongPressed,
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  // === 核心修改区域 ===
                  calendarBuilders: CalendarBuilders(
                    // 自定义“已打卡”的样式
                    selectedBuilder: (context, date, events) {
                      int count = _getCount(date);
                      return Container(
                        // 1. 去掉了 margin，让圆圈变大填满格子
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primary, 
                          shape: BoxShape.circle,
                        ),
                        // 2. 改用 Column 垂直排列，让数字清晰展示
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // 紧凑包裹
                          children: [
                            // 日期数字，加大字号
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20, // 更大的字体
                                height: 1.0, // 紧凑行高
                              ),
                            ),
                            // 次数显示，只有大于1次才显示，加大字号清晰展示
                            if (count > 1)
                              Text(
                                "×$count",
                                style: TextStyle(
                                  color: colorScheme.onPrimary.withOpacity(0.9),
                                  fontSize: 14, // 清晰的字体大小
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    // 今天的默认样式（保持不变）
                    todayBuilder: (context, date, events) {
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.primary, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${date.day}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  // =================
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatItem(context, "累计次数", "$_totalCount"),
                  Container(
                    height: 20, 
                    width: 1.5, 
                    color: colorScheme.onSecondaryContainer.withOpacity(0.4),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  _buildStatItem(context, "本月次数", "$_monthlyCount"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final color = Theme.of(context).colorScheme.onSecondaryContainer;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ],
    );
  }
}