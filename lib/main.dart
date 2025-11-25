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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  // --- 弹窗逻辑 ---
  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    // 为了测试方便，我把 key 版本号升级到了 v2，这样你更新后会再看到一次弹窗
    // 如果不想看，把 true 改成 false 即可
    bool isFirst = prefs.getBool('is_first_launch_v2') ?? true;
    if (isFirst) {
      _showIntroDialog();
    }
  }

  Future<void> _markAsLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch_v2', false);
  }

  void _showIntroDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            height: 300,
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Positioned(
                  right: 0, top: 0,
                  child: GestureDetector(
                    onTap: () { Navigator.pop(context); _showSkipConfirmDialog(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                      child: const Text("跳过", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 50, color: Colors.deepPurple),
                      SizedBox(height: 20),
                      Text("点击日期记录飞了一次\n长按删除记录\n多点几次试试呢", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Positioned(bottom: 0, left: 0, right: 0, child: Text("删除记录不代表没飞哦宝贝", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey))),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSkipConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("提示"),
          content: const Text("跳过介绍就是跳过人生--袁神"),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); _showIntroDialog(); }, child: const Text("返回")),
            FilledButton(onPressed: () { Navigator.pop(context); _markAsLaunched(); }, child: const Text("坚持跳过")),
          ],
        );
      },
    );
  }
  // --- 弹窗逻辑结束 ---

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
    DateTime? key = _dayCounts.keys.firstWhere((k) => isSameDay(k, day), orElse: () => DateTime(0));
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

  int get _totalCount => _dayCounts.values.fold(0, (sum, count) => sum + count);
  int get _monthlyCount => _dayCounts.entries.where((e) => e.key.year == _focusedDay.year && e.key.month == _focusedDay.month).fold(0, (sum, e) => sum + e.value);

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
        child: SingleChildScrollView( // 防止小屏幕手机溢出，包裹一个滚动视图
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              // ✅✅✅ === 插入图片的位置 === ✅✅✅
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                // 设置固定高度，防止图片太高把日历挤没了，你可以根据需要修改这个值
                height: 120, 
                width: double.infinity, // 宽度撑满
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16), // 圆角
                  boxShadow: [ // 一点点阴影让它更有质感
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                  image: const DecorationImage(
                    // 这里指定我们刚才上传的图片路径
                    image: AssetImage('assets/images/banner.png'),
                    fit: BoxFit.cover, // 图片铺满容器，可能会裁剪
                  ),
                ),
              ),
              // ✅✅✅ ===================== ✅✅✅
              
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
                    calendarBuilders: CalendarBuilders(
                      selectedBuilder: (context, date, events) {
                        int count = _getCount(date);
                        return Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.primary, 
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${date.day}', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 20, height: 1.0)),
                              if (count > 1) Text("×$count", style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      },
                      todayBuilder: (context, date, events) {
                        return Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(border: Border.all(color: colorScheme.primary, width: 1.5), shape: BoxShape.circle),
                          child: Text('${date.day}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
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
                    Container(height: 20, width: 1.5, color: colorScheme.onSecondaryContainer.withOpacity(0.4), margin: const EdgeInsets.symmetric(horizontal: 20)),
                    _buildStatItem(context, "本月次数", "$_monthlyCount"),
                  ],
                ),
              ),
            ],
          ),
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