import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      home: const TrackerHomePage(),
    );
  }
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({super.key});

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  final Set<DateTime> _selectedDays = LinkedHashSet<DateTime>(
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
    final List<String>? storedList = prefs.getStringList('tracked_dates');
    if (storedList != null) {
      setState(() {
        _selectedDays.clear();
        for (var dateStr in storedList) {
          _selectedDays.add(DateTime.parse(dateStr));
        }
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> strList = _selectedDays.map((d) => d.toIso8601String()).toList();
    await prefs.setStringList('tracked_dates', strList);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      if (!_selectedDays.any((d) => isSameDay(d, selectedDay))) {
        _selectedDays.add(selectedDay);
        _saveData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已打卡'), duration: Duration(milliseconds: 500)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('长按可取消打卡'), duration: Duration(milliseconds: 800)),
        );
      }
    });
  }

  void _onDayLongPressed(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      if (_selectedDays.any((d) => isSameDay(d, selectedDay))) {
        _selectedDays.removeWhere((d) => isSameDay(d, selectedDay));
        _saveData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消'), duration: Duration(milliseconds: 500)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('打卡日历'), centerTitle: true),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Card(
            margin: const EdgeInsets.all(12.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => _selectedDays.any((d) => isSameDay(d, day)),
                onDaySelected: _onDaySelected,
                onDayLongPressed: _onDayLongPressed,
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
                calendarBuilders: CalendarBuilders(
                  selectedBuilder: (context, date, events) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text("累计次数: ${_selectedDays.length}", style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}