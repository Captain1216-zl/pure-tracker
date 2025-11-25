import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

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
          title: 'Daily Tracker',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.purple),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic ?? ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
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
  final Set<DateTime> _selectedDays = LinkedHashSet<DateTime>(
    equals: isSameDay,
    hashCode: (DateTime key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  // WebDAV 变量
  String _webDavUrl = "";
  String _webDavUser = "";
  String _webDavPass = "";

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
    _webDavUrl = prefs.getString('dav_url') ?? "";
    _webDavUser = prefs.getString('dav_user') ?? "";
    _webDavPass = prefs.getString('dav_pass') ?? "";
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> strList = _selectedDays.map((d) => d.toIso8601String()).toList();
    await prefs.setStringList('tracked_dates', strList);
  }

  Future<void> _saveWebDavSettings(String url, String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dav_url', url);
    await prefs.setString('dav_user', user);
    await prefs.setString('dav_pass', pass);
    setState(() {
      _webDavUrl = url;
      _webDavUser = user;
      _webDavPass = pass;
    });
  }

  Future<void> _syncWebDav() async {
    if (_webDavUrl.isEmpty || _webDavUser.isEmpty || _webDavPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先设置 WebDAV 信息')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var client = webdav.newClient(_webDavUrl, user: _webDavUser, password: _webDavPass);
      const fileName = 'tracker_backup.json';
      List<String> cloudDates = [];

      try {
        List<int> fileBytes = await client.read(fileName); 
        String fileContent = utf8.decode(fileBytes);
        List<dynamic> jsonList = jsonDecode(fileContent);
        cloudDates = jsonList.cast<String>();
      } catch (e) {
        // 文件不存在，忽略
      }

      Set<DateTime> mergedSet = Set.from(_selectedDays);
      for (var dateStr in cloudDates) {
        mergedSet.add(DateTime.parse(dateStr));
      }

      setState(() {
        _selectedDays.clear();
        _selectedDays.addAll(mergedSet);
      });
      await _saveLocalData();

      final List<String> finalStrList = _selectedDays.map((d) => d.toIso8601String()).toList();
      String jsonString = jsonEncode(finalStrList);
      await client.write(fileName, Uint8List.fromList(utf8.encode(jsonString)));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步成功')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $e')));
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      if (!_selectedDays.any((d) => isSameDay(d, selectedDay))) {
        _selectedDays.add(selectedDay);
        _saveLocalData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('长按日期可取消打卡'), duration: Duration(milliseconds: 500)));
      }
    });
  }

  void _onDayLongPressed(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      if (_selectedDays.any((d) => isSameDay(d, selectedDay))) {
        _selectedDays.removeWhere((d) => isSameDay(d, selectedDay));
        _saveLocalData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已撤销'), duration: Duration(milliseconds: 500)));
      }
    });
  }

  void _showSettingsDialog() {
    final urlCtrl = TextEditingController(text: _webDavUrl);
    final userCtrl = TextEditingController(text: _webDavUser);
    final passCtrl = TextEditingController(text: _webDavPass);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("WebDAV 设置"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               const Text("示例: https://dav.jianguoyun.com/dav/", style: TextStyle(fontSize: 12, color: Colors.grey)),
               const SizedBox(height: 10),
               TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL", border: OutlineInputBorder())),
               const SizedBox(height: 10),
               TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "账号", border: OutlineInputBorder())),
               const SizedBox(height: 10),
               TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "密码", border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
            FilledButton(
              onPressed: () {
                _saveWebDavSettings(urlCtrl.text, userCtrl.text, passCtrl.text);
                Navigator.pop(context);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('打卡'),
        actions: [
          IconButton(icon: const Icon(Icons.cloud_sync), onPressed: _syncWebDav),
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettingsDialog),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            color: colorScheme.surfaceContainerHighest,
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
              selectedDayPredicate: (day) => _selectedDays.any((d) => isSameDay(d, day)),
              onDaySelected: _onDaySelected,
              onDayLongPressed: _onDayLongPressed,
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, date, events) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                    child: Text('${date.day}', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                  );
                },
                todayBuilder: (context, date, events) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: colorScheme.primary), shape: BoxShape.circle),
                    child: Text('${date.day}', style: TextStyle(color: colorScheme.primary)),
                  );
                },
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: Text("累计: ${_selectedDays.length}", style: Theme.of(context).textTheme.headlineMedium),
          ),
        ],
      ),
    );
  }
}