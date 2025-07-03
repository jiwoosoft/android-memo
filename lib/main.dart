import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

// 다크모드 적용된 앱 테마
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '간단한 메모장',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.light(),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[950],
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: MemoListScreen(),
    );
  }
}

// 메모 리스트 화면
class MemoListScreen extends StatefulWidget {
  @override
  _MemoListScreenState createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  List<String> memos = [];

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  void _saveMemos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('memo_list', memos);
  }

  void _loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = prefs.getStringList('memo_list');
    if (loaded != null) {
      setState(() {
        memos = loaded;
      });
    }
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text('메모 삭제', style: TextStyle(color: Colors.white)),
          content: Text('이 메모를 삭제하시겠습니까?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  memos.removeAt(index);
                  _saveMemos();
                });
                Navigator.pop(ctx);
              },
              child: Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 메모장'),
      ),
      body: ListView.builder(
        itemCount: memos.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ListTile(
              title: Text(memos[index]),
              leading: Icon(Icons.note, color: Colors.tealAccent),
              onLongPress: () => _confirmDelete(context, index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newMemo = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddMemoScreen()),
          );
          if (newMemo != null) {
            setState(() {
              memos.add(newMemo);
              _saveMemos();
            });
          }
        },
        child: Icon(Icons.add),
        tooltip: '메모 추가',
      ),
    );
  }
}

// 메모 추가 화면
class AddMemoScreen extends StatefulWidget {
  @override
  _AddMemoScreenState createState() => _AddMemoScreenState();
}

class _AddMemoScreenState extends State<AddMemoScreen> {
  TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('새 메모 작성'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '메모를 입력하세요...',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[850],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                String newMemo = _controller.text.trim();
                if (newMemo.isNotEmpty) {
                  Navigator.pop(context, newMemo);
                }
              },
              icon: Icon(Icons.save),
              label: Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
