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
  // 核心数据结构变化：Map<日期, 次数>
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

  // 加载并自动迁移旧数据
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 尝试读取新的 Map 格式数据
    final String? jsonMap = prefs.getString('day_counts_map');
    if (jsonMap != null) {
      Map<String, dynamic> decoded = jsonDecode(jsonMap);
      setState(() {
        _dayCounts.clear();
        decoded.forEach((key, value) {
          _dayCounts[DateTime.parse(key)] = value as int;
        });
      });
    } else {
      // 2. 如果没有新数据，检查是否有旧版本(List)的数据，进行迁移
      final List<String>? oldList = prefs.getString('tracked_dates');
      if (oldList != null) {
        setState(() {
          for (var dateStr in oldList) {
            // 旧数据只有“有”和“无”，所以次数默认为 1
            _dayCounts[DateTime.parse(dateStr)] = 1;
          }
        });
        _saveData(); // 保存为新格式
        prefs.remove('tracked_dates'); // 删除旧格式
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    // 将 Map 序列化为 JSON 字符串存储
    Map<String, int> stringKeyMap = {};
    _dayCounts.forEach((key, value) {
      stringKeyMap[key.toIso8601String()] = value;
    });
    await prefs.setString('day_counts_map', jsonEncode(stringKeyMap));
  }

  // 获取某一天的次数，默认为 0
  int _getCount(DateTime day) {
    // 查找 Map 中是否有这一天 (忽略时分秒)
    DateTime? key = _dayCounts.keys.firstWhere(
      (k) => isSameDay(k, day), 
      orElse: () => DateTime(0) // 返回一个无效日期作为标记
    );
    if (key.year == 0) return 0;
    return _dayCounts[key]!;
  }

  // 点击：次数 +1
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      int currentCount = _getCount(selectedDay);
      // 更新 Map：如果 Key 存在则更新，不存在则新增
      // 必须使用已经在 Map 中的 Key 或者新的标准化 Key，这里简化逻辑直接覆盖
      // 先移除旧的 Key (为了保证 Key 的唯一性，虽然 Hash 应该处理了)
      DateTime key = _dayCounts.keys.firstWhere((k) => isSameDay(k, selectedDay), orElse: () => selectedDay);
      
      _dayCounts[key] = currentCount + 1;
      _saveData();
    });
  }

  // 长按：清零
  void _onDayLongPressed(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      if (_getCount(selectedDay) > 0) {
        // 找到对应的 Key 并移除
        _dayCounts.removeWhere((key, value) => isSameDay(key, selectedDay));
        _saveData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空该日记录'), duration: Duration(milliseconds: 500)));
      }
    });
  }

  // 统计逻辑
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
      // 这里的 AppBar 也可以去掉，如果你想要极其极简
      appBar: AppBar(
        title: const Text('日常记录'),
        centerTitle: true,
        forceMaterialTransparency: true, // 透明背景
      ),
      body: Center( // 1. 垂直居中核心布局
        child: Column(
          mainAxisSize: MainAxisSize.min, // 内容包裹，不占满全屏
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              elevation: 0, // 扁平化
              color: colorScheme.surfaceContainer, // MD3 容器色
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  
                  // 样式配置
                  headerStyle: const HeaderStyle(
                    titleCentered: true, 
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                    weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),

                  // 交互回调
                  selectedDayPredicate: (day) => _getCount(day) > 0,
                  onDaySelected: _onDaySelected,
                  onDayLongPressed: _onDayLongPressed,
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },

                  // 2. 自定义 UI 构建器 (显示 x2, x3)
                  calendarBuilders: CalendarBuilders(
                    // 自定义“已打卡”的样式
                    selectedBuilder: (context, date, events) {
                      int count = _getCount(date);
                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: colorScheme.primary, 
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 日期数字
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            // 右下角显示次数 (如果是 x1 就不显示，或者你想显示也可以)
                            if (count > 1)
                              Positioned(
                                right: 8,
                                bottom: 4,
                                child: Text(
                                  "×$count",
                                  style: TextStyle(
                                    color: colorScheme.onPrimary.withOpacity(0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    // 今天的默认样式
                    todayBuilder: (context, date, events) {
                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.primary, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${date.day}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 3. 底部统计面板 (居中，带竖线分隔)
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