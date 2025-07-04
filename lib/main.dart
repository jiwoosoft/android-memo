import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:pinput/pinput.dart';
import 'package:expandable/expandable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'security_service.dart';
import 'update_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

// 데이터 모델 클래스
class Category {
  String id;
  String name;
  String icon;
  List<Memo> memos;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.memos,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'memos': memos.map((memo) => memo.toJson()).toList(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      memos: (json['memos'] as List)
          .map((memo) => Memo.fromJson(memo))
          .toList(),
    );
  }
}

class Memo {
  String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;

  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

// 데이터 저장 서비스
class DataService {
  static const String _pinKey = 'app_pin';
  static const String _categoriesKey = 'categories';
  static const String _isFirstLaunchKey = 'is_first_launch';

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setNotFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPin = sha256.convert(utf8.encode(pin)).toString();
    await prefs.setString(_pinKey, hashedPin);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey);
    if (savedPin == null) return false;
    
    final hashedPin = sha256.convert(utf8.encode(pin)).toString();
    return savedPin == hashedPin;
  }

  static Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  static Future<List<Category>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedData = prefs.getString(_categoriesKey);
    if (encryptedData == null) {
      return _getDefaultCategories();
    }
    
    // 보안 강화: 디버깅 모드 감지
    if (SecurityService.isDebuggingMode()) {
      print('⚠️ 디버깅 모드에서 실행 중입니다.');
    }
    
    try {
      // 저장된 PIN 해시 가져오기
      final savedPinHash = prefs.getString(_pinKey);
      if (savedPinHash == null) {
        return _getDefaultCategories();
      }
      
      // 현재 세션에서 PIN을 가져올 수 없으므로 기본 복호화 시도
      // 실제로는 PIN 입력 후 세션에 저장된 PIN 사용
      final currentPin = await _getCurrentSessionPin();
      if (currentPin == null) {
        return _getDefaultCategories();
      }
      
      // 데이터 복호화
      final decryptedJson = SecurityService.decryptMemoData(encryptedData, currentPin);
      
      // 복호화 실패 시 기본 데이터 반환
      if (decryptedJson.isEmpty || !SecurityService.verifyDataIntegrity(decryptedJson)) {
        return _getDefaultCategories();
      }
      
      final List<dynamic> decoded = jsonDecode(decryptedJson);
      return decoded.map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      print('카테고리 로드 오류: $e');
      return _getDefaultCategories();
    }
  }

  static Future<void> saveCategories(List<Category> categories) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // 현재 세션의 PIN 가져오기
      final currentPin = await _getCurrentSessionPin();
      if (currentPin == null) {
        print('PIN이 없어서 저장할 수 없습니다.');
        return;
      }
      
      // JSON 데이터 생성
      final categoriesJson = jsonEncode(categories.map((c) => c.toJson()).toList());
      
      // 데이터 암호화
      final encryptedData = SecurityService.encryptMemoData(categoriesJson, currentPin);
      
      // 암호화된 데이터 저장
      await prefs.setString(_categoriesKey, encryptedData);
      
      print('카테고리 데이터가 암호화되어 저장되었습니다.');
    } catch (e) {
      print('카테고리 저장 오류: $e');
    }
  }
  
  // 현재 세션의 PIN을 관리하는 부분 (보안상 메모리에 임시 저장)
  static String? _sessionPin;
  
  static Future<String?> _getCurrentSessionPin() async {
    return _sessionPin;
  }
  
  static void setSessionPin(String pin) {
    _sessionPin = pin;
  }
  
  static void clearSessionPin() {
    _sessionPin = null;
  }

  static List<Category> _getDefaultCategories() {
    return [
      Category(
        id: '1',
        name: '거래처',
        icon: 'business',
        memos: [],
      ),
      Category(
        id: '2',
        name: '구매처',
        icon: 'shopping',
        memos: [],
      ),
      Category(
        id: '3',
        name: '개인메모',
        icon: 'person',
        memos: [],
      ),
    ];
  }
}

// 메인 앱 클래스
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 앱 생명주기 관찰자 등록
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 앱 생명주기 관찰자 제거
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 보안 강화: 앱이 백그라운드로 갈 때 세션 PIN 클리어
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      print('앱이 백그라운드로 이동 - 세션 PIN 클리어');
      DataService.clearSessionPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '안전한 메모장',
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
      home: SplashScreen(),
    );
  }
}

// 스플래시 화면
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  void _checkFirstLaunch() async {
    await Future.delayed(Duration(seconds: 2));
    
    final isFirstLaunch = await DataService.isFirstLaunch();
    final hasPinSet = await DataService.hasPinSet();
    
    if (isFirstLaunch || !hasPinSet) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => PinSetupScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 80,
              color: Colors.teal,
            ),
            SizedBox(height: 20),
            Text(
              '안전한 메모장',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '당신의 메모를 안전하게 보관합니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ],
        ),
      ),
    );
  }
}

// PIN 설정 화면
class PinSetupScreen extends StatefulWidget {
  @override
  _PinSetupScreenState createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isConfirming = false;
  String _firstPin = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.teal,
                ),
                SizedBox(height: 30),
                Text(
                  _isConfirming ? 'PIN 번호를 다시 입력하세요' : 'PIN 번호를 설정하세요',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  '4자리 숫자로 입력하세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                Center(
                  child: Pinput(
                    controller: _isConfirming ? _confirmPinController : _pinController,
                    length: 4,
                    obscureText: true,
                    obscuringCharacter: '●',
                    onCompleted: _onPinCompleted,
                    mainAxisAlignment: MainAxisAlignment.center,
                    defaultPinTheme: PinTheme(
                      width: 60,
                      height: 60,
                      textStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[850],
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 60,
                      height: 60,
                      textStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[850],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                if (_isConfirming)
                  TextButton(
                    onPressed: () {
      setState(() {
                        _isConfirming = false;
                        _pinController.clear();
                        _confirmPinController.clear();
                      });
                    },
                    child: Text(
                      '다시 입력',
                      style: TextStyle(color: Colors.teal),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPinCompleted(String pin) {
    if (!_isConfirming) {
      _firstPin = pin;
      setState(() {
        _isConfirming = true;
      });
    } else {
      if (_firstPin == pin) {
        _savePin(pin);
      } else {
        _showErrorDialog('PIN이 일치하지 않습니다. 다시 시도해주세요.');
        setState(() {
          _isConfirming = false;
          _pinController.clear();
          _confirmPinController.clear();
        });
      }
    }
  }

  void _savePin(String pin) async {
    await DataService.savePin(pin);
    await DataService.setNotFirstLaunch();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => CategoryListScreen()),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
        title: Text('오류', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}

// 로그인 화면
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.teal,
                ),
                SizedBox(height: 30),
                Text(
                  'PIN 번호를 입력하세요',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                Center(
                  child: Pinput(
                    controller: _pinController,
                    length: 4,
                    obscureText: true,
                    obscuringCharacter: '●',
                    onCompleted: _onPinCompleted,
                    mainAxisAlignment: MainAxisAlignment.center,
                    defaultPinTheme: PinTheme(
                      width: 60,
                      height: 60,
                      textStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[850],
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 60,
                      height: 60,
                      textStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[850],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPinCompleted(String pin) async {
    final isValid = await DataService.verifyPin(pin);
    if (isValid) {
      // 보안 강화: PIN 인증 성공 후 세션에 PIN 저장
      DataService.setSessionPin(pin);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => CategoryListScreen()),
      );
    } else {
      _pinController.clear();
      _showErrorDialog('잘못된 PIN 번호입니다.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('오류', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}

// 카테고리 리스트 화면
class CategoryListScreen extends StatefulWidget {
  @override
  _CategoryListScreenState createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  List<Category> categories = [];
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    final loadedCategories = await DataService.getCategories();
    setState(() {
      categories = loadedCategories;
    });
  }

  void _saveCategories() async {
    await DataService.saveCategories(categories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('안전한 메모장'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_category',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('카테고리 추가'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit_mode',
                child: Row(
                  children: [
                    Icon(_isEditMode ? Icons.check : Icons.edit, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(_isEditMode ? '편집 완료' : '순서 편집'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('설정'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'add_category') {
                _addCategory();
              } else if (value == 'edit_mode') {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: categories.isEmpty
          ? Center(
              child: CircularProgressIndicator(),
            )
          : _isEditMode
              ? _buildReorderableList()
              : _buildNormalList(),
    );
  }

  Widget _buildNormalList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: categories.length,
        itemBuilder: (context, index) {
        final category = categories[index];
          return Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ExpandablePanel(
            header: ListTile(
              leading: Icon(
                _getIconData(category.icon),
                color: Colors.teal,
              ),
              title: Text(
                category.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                '${category.memos.length}개의 메모',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.teal),
                    onPressed: () => _addMemo(category),
                    tooltip: '메모 추가',
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('이름 수정'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('삭제'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editCategory(category);
                      } else if (value == 'delete') {
                        _deleteCategory(category);
                      }
                    },
                  ),
                ],
              ),
            ),
            collapsed: Container(),
            expanded: _buildMemoList(category),
          ),
        );
      },
    );
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = categories.removeAt(oldIndex);
          categories.insert(newIndex, item);
        });
        _saveCategories();
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          key: ValueKey(category.id),
          margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
            leading: Icon(
              _getIconData(category.icon),
              color: Colors.teal,
            ),
            title: Text(
              category.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              '${category.memos.length}개의 메모',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: Icon(
              Icons.drag_handle,
              color: Colors.white70,
            ),
            ),
          );
        },
    );
  }

  Widget _buildMemoList(Category category) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: category.memos.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = category.memos.removeAt(oldIndex);
          category.memos.insert(newIndex, item);
        });
        _saveCategories();
      },
      itemBuilder: (context, memoIndex) {
        final memo = category.memos[memoIndex];
        return ListTile(
          key: ValueKey(memo.id),
          leading: Icon(Icons.note, color: Colors.teal, size: 20),
          title: Text(
            memo.title.isEmpty ? '제목 없음' : memo.title,
            style: TextStyle(color: Colors.white),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('수정'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _editMemo(category, memo);
                  } else if (value == 'delete') {
                    _deleteMemo(category, memo);
                  }
                },
              ),
              Icon(Icons.drag_handle, color: Colors.white54, size: 16),
            ],
          ),
          onTap: () => _viewMemo(category, memo),
        );
      },
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'business':
        return Icons.business;
      case 'shopping':
        return Icons.shopping_cart;
      case 'person':
        return Icons.person;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'travel':
        return Icons.flight;
      default:
        return Icons.folder;
    }
  }

  void _addCategory() {
    showDialog(
      context: context,
      builder: (context) => AddCategoryDialog(
        onAdd: (name, icon) {
          setState(() {
            categories.add(Category(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              icon: icon,
              memos: [],
            ));
          });
          _saveCategories();
        },
      ),
    );
  }

  void _editCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) => EditCategoryDialog(
        category: category,
        onEdit: (name, icon) {
          setState(() {
            category.name = name;
            category.icon = icon;
          });
          _saveCategories();
        },
      ),
    );
  }

  void _deleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('카테고리 삭제', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 카테고리를 삭제하시겠습니까?', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('카테고리: ${category.name}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (category.memos.isNotEmpty)
              Text('${category.memos.length}개의 메모도 함께 삭제됩니다.', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                categories.remove(category);
              });
              _saveCategories();
              Navigator.pop(context);
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addMemo(Category category) async {
    final result = await Navigator.push(
            context,
      MaterialPageRoute(
        builder: (context) => AddMemoScreen(category: category),
      ),
          );
    
    if (result != null) {
            setState(() {
        category.memos.add(result);
      });
      _saveCategories();
    }
  }

  void _editMemo(Category category, Memo memo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemoScreen(category: category, memo: memo),
      ),
    );
    
    if (result != null) {
      setState(() {
        final index = category.memos.indexOf(memo);
        category.memos[index] = result;
      });
      _saveCategories();
    }
  }

  void _viewMemo(Category category, Memo memo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoDetailScreen(memo: memo),
      ),
    );
  }

  void _deleteMemo(Category category, Memo memo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('메모 삭제', style: TextStyle(color: Colors.white)),
        content: Text('이 메모를 삭제하시겠습니까?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                category.memos.remove(memo);
              });
              _saveCategories();
              Navigator.pop(context);
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// 메모 상세 화면
class MemoDetailScreen extends StatelessWidget {
  final Memo memo;

  MemoDetailScreen({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(memo.title.isEmpty ? '제목 없음' : memo.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '작성일: ${_formatDate(memo.createdAt)}',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (memo.updatedAt != memo.createdAt)
              Text(
                '수정일: ${_formatDate(memo.updatedAt)}',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  memo.content,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// 메모 추가/수정 화면
class AddMemoScreen extends StatefulWidget {
  final Category category;
  final Memo? memo;

  AddMemoScreen({required this.category, this.memo});

  @override
  _AddMemoScreenState createState() => _AddMemoScreenState();
}

class _AddMemoScreenState extends State<AddMemoScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.memo != null) {
      _titleController.text = widget.memo!.title;
      _contentController.text = widget.memo!.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memo == null ? '새 메모' : '메모 수정'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveMemo,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '제목',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal),
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '내용',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveMemo() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    
    if (content.isEmpty) {
      _showErrorDialog('메모 내용을 입력하세요.');
      return;
    }

    final now = DateTime.now();
    final memo = Memo(
      id: widget.memo?.id ?? now.millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: widget.memo?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, memo);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('오류', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}

// 설정 화면
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('설정'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.lock, color: Colors.teal),
            title: Text('PIN 변경', style: TextStyle(color: Colors.white)),
            subtitle: Text('보안을 위해 PIN을 변경하세요', style: TextStyle(color: Colors.white70)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChangePinScreen()),
            ),
          ),
          Divider(color: Colors.grey[700]),
          ListTile(
            leading: Icon(Icons.info, color: Colors.teal),
            title: Text('앱 정보', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              packageInfo != null 
                ? '버전 ${packageInfo!.version} (${packageInfo!.buildNumber})'
                : '버전 정보 로딩 중...',
              style: TextStyle(color: Colors.white70)
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70),
            onTap: () => _showAboutDialog(context),
          ),
          Divider(color: Colors.grey[700]),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('로그아웃', style: TextStyle(color: Colors.red)),
            subtitle: Text('앱을 종료하고 다시 로그인하세요', style: TextStyle(color: Colors.white70)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('앱 정보', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              packageInfo != null 
                ? '안전한 메모장 v${packageInfo!.version}'
                : '안전한 메모장',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            if (packageInfo != null) ...[
              SizedBox(height: 4),
              Text('빌드 번호: ${packageInfo!.buildNumber}', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('패키지명: ${packageInfo!.packageName}', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            SizedBox(height: 16),
            Text('4자리 PIN 기반 보안 메모장 앱', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('📱 주요 기능:', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            Text('• 4자리 PIN 보안 인증', style: TextStyle(color: Colors.white70)),
            Text('• 메모 데이터 암호화', style: TextStyle(color: Colors.white70)),
            Text('• 카테고리별 메모 분류', style: TextStyle(color: Colors.white70)),
            Text('• 갤럭시폰 최적화', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text('👨‍💻 개발 정보:', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            Text('Powered by HaneulCCM', style: TextStyle(color: Colors.white70)),
            Text('Developer: jiwoosoft', style: TextStyle(color: Colors.white70)),
            Text('YouTube: @haneulccm', style: TextStyle(color: Colors.white70)),
            Text('E-mail: webmaster@jiwoosoft.com', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('Built with Flutter ❤️', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _checkForUpdates(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, color: Colors.teal, size: 18),
                SizedBox(width: 4),
                Text('업데이트 확인', style: TextStyle(color: Colors.teal)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  /// 업데이트 확인 메서드
  void _checkForUpdates(BuildContext context) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text(
              '업데이트 확인 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      // 업데이트 확인 실행
      final result = await UpdateService.checkForUpdate();
      
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      if (result.errorMessage != null) {
        // 에러 발생 시
        _showUpdateErrorDialog(context, result.errorMessage!);
      } else if (result.hasUpdate) {
        // 업데이트가 있는 경우
        _showUpdateAvailableDialog(context, result);
      } else {
        // 최신 버전인 경우
        _showNoUpdateDialog(context, result);
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);
      _showUpdateErrorDialog(context, '업데이트 확인 중 오류가 발생했습니다.');
    }
  }

  /// 업데이트 사용 가능 다이얼로그
  void _showUpdateAvailableDialog(BuildContext context, UpdateCheckResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.orange),
            SizedBox(width: 8),
            Text('업데이트 사용 가능', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새로운 버전이 출시되었습니다!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('현재 버전: v${result.currentVersion} (${result.currentBuildNumber})', 
                 style: TextStyle(color: Colors.white70)),
            Text('최신 버전: ${result.latestVersion} (${result.latestBuildNumber})', 
                 style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            if (result.releaseInfo != null) ...[
              Text('📋 릴리즈 노트:', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Container(
                height: 100,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    result.releaseInfo!.body.isNotEmpty 
                      ? result.releaseInfo!.body 
                      : '릴리즈 노트가 없습니다.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('나중에', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openUpdateLink(result.releaseInfo);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, color: Colors.teal, size: 18),
                SizedBox(width: 4),
                Text('다운로드', style: TextStyle(color: Colors.teal)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 최신 버전 다이얼로그
  void _showNoUpdateDialog(BuildContext context, UpdateCheckResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('최신 버전', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 최신 버전을 사용하고 있습니다.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('현재 버전: v${result.currentVersion} (${result.currentBuildNumber})', 
                 style: TextStyle(color: Colors.teal)),
            if (result.latestVersion != null)
              Text('최신 버전: ${result.latestVersion} (${result.latestBuildNumber})', 
                   style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  /// 업데이트 확인 오류 다이얼로그
  void _showUpdateErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('업데이트 확인 실패', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage,
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 12),
            Text(
              '인터넷 연결을 확인하고 다시 시도해주세요.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  /// 업데이트 링크 열기
  void _openUpdateLink(ReleaseInfo? releaseInfo) async {
    if (releaseInfo == null) return;
    
    // Google Drive 링크 (현재 APK 다운로드 링크)
    const googleDriveUrl = 'https://drive.google.com/file/d/1gIqrBNjG0m2V41c9kDkH_lV6QQeo1pkN/view?usp=sharing';
    
    try {
      final Uri url = Uri.parse(googleDriveUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('URL을 열 수 없습니다: $googleDriveUrl');
      }
    } catch (e) {
      print('URL 열기 오류: $e');
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('로그아웃', style: TextStyle(color: Colors.white)),
        content: Text('정말 로그아웃하시겠습니까?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
              onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            child: Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// PIN 변경 화면
class ChangePinScreen extends StatefulWidget {
  @override
  _ChangePinScreenState createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  int _step = 0; // 0: 현재 PIN, 1: 새 PIN, 2: 확인 PIN
  String _newPin = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PIN 변경'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_reset,
                size: 80,
                color: Colors.teal,
              ),
              SizedBox(height: 30),
              Text(
                _getStepTitle(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Center(
                child: Pinput(
                  controller: _getCurrentController(),
                  length: 4,
                  obscureText: true,
                  obscuringCharacter: '●',
                  onCompleted: _onPinCompleted,
                  mainAxisAlignment: MainAxisAlignment.center,
                  defaultPinTheme: PinTheme(
                    width: 60,
                    height: 60,
                    textStyle: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[850],
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 60,
                    height: 60,
                    textStyle: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.teal),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[850],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_step) {
      case 0:
        return '현재 PIN을 입력하세요';
      case 1:
        return '새 PIN을 입력하세요';
      case 2:
        return '새 PIN을 다시 입력하세요';
      default:
        return '';
    }
  }

  TextEditingController _getCurrentController() {
    switch (_step) {
      case 0:
        return _currentPinController;
      case 1:
        return _newPinController;
      case 2:
        return _confirmPinController;
      default:
        return _currentPinController;
    }
  }

  void _onPinCompleted(String pin) async {
    switch (_step) {
      case 0:
        final isValid = await DataService.verifyPin(pin);
        if (isValid) {
          // 보안 강화: PIN 인증 성공 후 세션에 PIN 저장 (PIN 변경 시에도 필요)
          DataService.setSessionPin(pin);
          
          setState(() {
            _step = 1;
          });
        } else {
          _showErrorDialog('현재 PIN이 올바르지 않습니다.');
          _currentPinController.clear();
        }
        break;
      case 1:
        _newPin = pin;
        setState(() {
          _step = 2;
        });
        break;
      case 2:
        if (_newPin == pin) {
          await DataService.savePin(pin);
          // 보안 강화: 새 PIN을 세션에 저장
          DataService.setSessionPin(pin);
          _showSuccessDialog();
        } else {
          _showErrorDialog('새 PIN이 일치하지 않습니다.');
          setState(() {
            _step = 1;
            _newPinController.clear();
            _confirmPinController.clear();
          });
        }
        break;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('오류', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('성공', style: TextStyle(color: Colors.white)),
        content: Text('PIN이 성공적으로 변경되었습니다.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('확인', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}

// 카테고리 추가 다이얼로그
class AddCategoryDialog extends StatefulWidget {
  final Function(String name, String icon) onAdd;

  AddCategoryDialog({required this.onAdd});

  @override
  _AddCategoryDialogState createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedIcon = 'folder';

  final List<Map<String, dynamic>> _icons = [
    {'name': 'folder', 'icon': Icons.folder},
    {'name': 'business', 'icon': Icons.business},
    {'name': 'shopping', 'icon': Icons.shopping_cart},
    {'name': 'person', 'icon': Icons.person},
    {'name': 'work', 'icon': Icons.work},
    {'name': 'home', 'icon': Icons.home},
    {'name': 'travel', 'icon': Icons.flight},
    {'name': 'school', 'icon': Icons.school},
    {'name': 'health', 'icon': Icons.local_hospital},
    {'name': 'food', 'icon': Icons.restaurant},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[850],
      title: Text('새 카테고리 추가', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '카테고리 이름',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.teal),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text('아이콘 선택', style: TextStyle(color: Colors.white)),
          SizedBox(height: 8),
          Container(
            width: double.maxFinite,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((iconData) {
                final isSelected = _selectedIcon == iconData['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = iconData['name'];
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.teal : Colors.grey[700]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconData['icon'],
                      color: isSelected ? Colors.teal : Colors.white70,
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
              ),
            ),
          ],
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              widget.onAdd(name, _selectedIcon);
              Navigator.pop(context);
            }
          },
          child: Text('추가', style: TextStyle(color: Colors.teal)),
        ),
      ],
    );
  }
}

// 카테고리 수정 다이얼로그
class EditCategoryDialog extends StatefulWidget {
  final Category category;
  final Function(String name, String icon) onEdit;

  EditCategoryDialog({required this.category, required this.onEdit});

  @override
  _EditCategoryDialogState createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;

  final List<Map<String, dynamic>> _icons = [
    {'name': 'folder', 'icon': Icons.folder},
    {'name': 'business', 'icon': Icons.business},
    {'name': 'shopping', 'icon': Icons.shopping_cart},
    {'name': 'person', 'icon': Icons.person},
    {'name': 'work', 'icon': Icons.work},
    {'name': 'home', 'icon': Icons.home},
    {'name': 'travel', 'icon': Icons.flight},
    {'name': 'school', 'icon': Icons.school},
    {'name': 'health', 'icon': Icons.local_hospital},
    {'name': 'food', 'icon': Icons.restaurant},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _selectedIcon = widget.category.icon;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[850],
      title: Text('카테고리 수정', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '카테고리 이름',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.teal),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text('아이콘 선택', style: TextStyle(color: Colors.white)),
          SizedBox(height: 8),
          Container(
            width: double.maxFinite,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((iconData) {
                final isSelected = _selectedIcon == iconData['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = iconData['name'];
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.teal : Colors.grey[700]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconData['icon'],
                      color: isSelected ? Colors.teal : Colors.white70,
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              widget.onEdit(name, _selectedIcon);
              Navigator.pop(context);
            }
          },
          child: Text('수정', style: TextStyle(color: Colors.teal)),
        ),
      ],
    );
  }
}
