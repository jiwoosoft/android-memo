import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:pinput/pinput.dart';
import 'package:expandable/expandable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_service.dart';
import 'update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'auth_setup_screen.dart';
import 'login_screen.dart';

// 글로벌 설정 상태 관리
class AppSettings extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.dark;
  FontSize _currentFontSize = FontSize.medium;
  
  AppTheme get currentTheme => _currentTheme;
  FontSize get currentFontSize => _currentFontSize;
  
  void updateTheme(AppTheme newTheme) {
    _currentTheme = newTheme;
    DataService.saveThemeSettings(newTheme);
    notifyListeners();
  }
  
  void updateFontSize(FontSize newFontSize) {
    _currentFontSize = newFontSize;
    DataService.saveFontSizeSettings(newFontSize);
    notifyListeners();
  }
  
  Future<void> loadSettings() async {
    _currentTheme = await DataService.loadThemeSettings();
    _currentFontSize = await DataService.loadFontSizeSettings();
    notifyListeners();
  }
  
  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppTheme.system:
        return ThemeMode.system;
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
    }
  }
  
  double get fontSizeMultiplier {
    switch (_currentFontSize) {
      case FontSize.small:
        return 0.8;
      case FontSize.medium:
        return 1.0;
      case FontSize.large:
        return 1.2;
      case FontSize.extraLarge:
        return 1.4;
    }
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings()..loadSettings(),
      child: MyApp(),
    ),
  );
}

// 정렬 옵션 enum
enum SortOption {
  createdDate,    // 생성일순
  updatedDate,    // 수정일순
  title,          // 제목순
  content,        // 내용순
}

enum SortOrder {
  ascending,      // 오름차순
  descending,     // 내림차순
}

// 테마 옵션 enum
enum AppTheme {
  system,         // 시스템 설정 따라가기
  light,          // 라이트 테마
  dark,           // 다크 테마
}

// 폰트 크기 옵션 enum
enum FontSize {
  small,          // 작게
  medium,         // 보통
  large,          // 크게
  extraLarge,     // 매우 크게
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
  List<String> tags;

  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
    );
  }
}

// 데이터 저장 서비스
class DataService {
  static const String _pinKey = 'app_pin';
  static const String _categoriesKey = 'categories';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _sortOptionKey = 'sort_option';
  static const String _sortOrderKey = 'sort_order';
  static const String _themeKey = 'app_theme';
  static const String _fontSizeKey = 'font_size';

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setNotFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  // PIN 관련 메서드들은 AuthService로 이동됨
  static Future<void> savePin(String pin) async {
    await AuthService.savePin(pin);
  }

  static Future<bool> verifyPin(String pin) async {
    return await AuthService.verifyPin(pin);
  }

  static Future<bool> hasPinSet() async {
    return await AuthService.isPinSet();
  }

  static Future<List<Category>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedData = prefs.getString(_categoriesKey);
    if (encryptedData == null) {
      return _getDefaultCategories();
    }
    
    // 보안 강화: 디버깅 모드 감지 (간소화)
    // 디버깅 모드 체크 생략
    
    try {
      // 저장된 PIN 해시 가져오기
      final savedPinHash = prefs.getString(_pinKey);
      if (savedPinHash == null) {
        return _getDefaultCategories();
      }
      
      // 현재 세션에서 PIN을 가져올 수 없으므로 기본 복호화 시도
      // 실제로는 PIN 입력 후 세션에 저장된 PIN 사용
      final currentPin = await getCurrentSessionPin();
      if (currentPin == null) {
        return _getDefaultCategories();
      }
      
      // 데이터 복호화 (간소화)
      final decryptedJson = _simpleDecrypt(encryptedData, currentPin);
      
      // 복호화 실패 시 기본 데이터 반환
      if (decryptedJson.isEmpty) {
        return _getDefaultCategories();
      }
      
      final List<dynamic> decoded = jsonDecode(decryptedJson);
      return decoded.map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      print('카테고리 로드 오류: $e');
      return _getDefaultCategories();
    }
  }

  static Future<bool> saveCategories(List<Category> categories) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // 현재 세션의 PIN 가져오기
      final currentPin = await getCurrentSessionPin();
      if (currentPin == null) {
        print('⚠️ 세션 PIN이 없어서 저장할 수 없습니다.');
        return false;
      }
      
      // JSON 데이터 생성
      final categoriesJson = jsonEncode(categories.map((c) => c.toJson()).toList());
      
      // 데이터 암호화 (간소화)
      final encryptedData = _simpleEncrypt(categoriesJson, currentPin);
      
      // 암호화된 데이터 저장
      await prefs.setString(_categoriesKey, encryptedData);
      
      print('✅ 카테고리 데이터가 암호화되어 저장되었습니다.');
      return true;
    } catch (e) {
      print('❌ 카테고리 저장 오류: $e');
      return false;
    }
  }
  
  // 현재 세션의 PIN을 관리하는 부분 (보안상 메모리에 임시 저장)
  static String? _sessionPin;
  static const String _sessionPinKey = 'session_pin_temp';
  
  static Future<String?> getCurrentSessionPin() async {
    print('🔍 [DATA] getCurrentSessionPin 호출: 메모리=${_sessionPin != null ? '존재함' : 'null'}');
    
    // 메모리에서 먼저 확인
    if (_sessionPin != null) {
      print('🔍 [DATA] 메모리에서 세션 PIN 반환');
      return _sessionPin;
    }
    
    // 메모리에 없으면 SharedPreferences에서 확인 (백업용)
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempSessionPin = prefs.getString(_sessionPinKey);
      print('🔍 [DATA] SharedPreferences에서 확인: ${tempSessionPin != null ? '존재함' : 'null'}');
      
      if (tempSessionPin != null) {
        _sessionPin = tempSessionPin; // 메모리에 복원
        print('🔍 [DATA] 세션 PIN 메모리에 복원됨');
        return tempSessionPin;
      }
    } catch (e) {
      print('❌ [DATA] 세션 PIN 확인 중 오류: $e');
    }
    
    print('🔍 [DATA] 세션 PIN 없음');
    return null;
  }
  
  static void setSessionPin(String pin) async {
    print('🔐 [DATA] setSessionPin 호출: 길이=${pin.length}');
    _sessionPin = pin;
    
    // 백업용으로 SharedPreferences에도 저장 (임시)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionPinKey, pin);
      print('🔐 [DATA] 세션 PIN 메모리 및 SharedPreferences에 저장 완료');
    } catch (e) {
      print('❌ [DATA] 세션 PIN SharedPreferences 저장 실패: $e');
      print('🔐 [DATA] 메모리에만 저장 완료');
    }
  }
  
  // 정렬 설정 저장 및 로드
  static Future<void> saveSortSettings(SortOption option, SortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOptionKey, option.name);
    await prefs.setString(_sortOrderKey, order.name);
  }
  
  static Future<Map<String, dynamic>> loadSortSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final optionName = prefs.getString(_sortOptionKey) ?? 'createdDate';
    final orderName = prefs.getString(_sortOrderKey) ?? 'descending';
    
    return {
      'option': SortOption.values.firstWhere((e) => e.name == optionName, orElse: () => SortOption.createdDate),
      'order': SortOrder.values.firstWhere((e) => e.name == orderName, orElse: () => SortOrder.descending),
    };
  }
  
  // 테마 설정 저장 및 로드
  static Future<void> saveThemeSettings(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }
  
  static Future<AppTheme> loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey) ?? 'dark';
    
    return AppTheme.values.firstWhere((e) => e.name == themeName, orElse: () => AppTheme.dark);
  }
  
  // 폰트 크기 설정 저장 및 로드
  static Future<void> saveFontSizeSettings(FontSize fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, fontSize.name);
  }
  
  static Future<FontSize> loadFontSizeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final fontSizeName = prefs.getString(_fontSizeKey) ?? 'medium';
    
    return FontSize.values.firstWhere((e) => e.name == fontSizeName, orElse: () => FontSize.medium);
  }
  
  static void clearSessionPin() async {
    print('🧹 [DATA] 세션 PIN 정리 시작');
    _sessionPin = null;
    
    // SharedPreferences에서도 제거
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionPinKey);
      print('🧹 [DATA] 세션 PIN 메모리 및 SharedPreferences에서 정리 완료');
    } catch (e) {
      print('❌ [DATA] 세션 PIN SharedPreferences 정리 실패: $e');
      print('🧹 [DATA] 메모리에서만 정리 완료');
    }
  }

  // 간단한 암호화/복호화 메소드 (보안 강화를 위해 추후 개선 필요)
  static String _simpleEncrypt(String data, String pin) {
    try {
      // 간단한 XOR 암호화 (기본적인 보안)
      final bytes = utf8.encode(data);
      final pinBytes = utf8.encode(pin);
      final encrypted = <int>[];
      
      for (int i = 0; i < bytes.length; i++) {
        encrypted.add(bytes[i] ^ pinBytes[i % pinBytes.length]);
      }
      
      return base64.encode(encrypted);
    } catch (e) {
      print('암호화 오류: $e');
      return '';
    }
  }

  static String _simpleDecrypt(String encryptedData, String pin) {
    try {
      // 간단한 XOR 복호화
      final encrypted = base64.decode(encryptedData);
      final pinBytes = utf8.encode(pin);
      final decrypted = <int>[];
      
      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ pinBytes[i % pinBytes.length]);
      }
      
      return utf8.decode(decrypted);
    } catch (e) {
      print('복호화 오류: $e');
      return '';
    }
  }

  /// 모든 앱 데이터 삭제 (초기화용)
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _sessionPin = null;
      print('✅ 모든 앱 데이터가 삭제되었습니다.');
    } catch (e) {
      print('❌ 데이터 삭제 중 오류: $e');
      rethrow;
    }
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
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
    return MaterialApp(
      title: '안전한 메모장',
      debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          routes: {
            '/main': (context) => MemoListScreen(),
            '/auth-setup': (context) => AuthSetupScreen(),
            '/login': (context) => LoginScreen(),
          },
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
            scaffoldBackgroundColor: Colors.grey[50],
            cardColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
        ),
        textTheme: _buildTextTheme(TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
              titleMedium: TextStyle(color: Colors.black87),
              titleSmall: TextStyle(color: Colors.black54),
            ), settings.fontSizeMultiplier),
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              textStyle: TextStyle(color: Colors.black87),
            ),
      ),
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
        textTheme: _buildTextTheme(TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
            ), settings.fontSizeMultiplier),
      ),
      home: SplashScreen(),
        );
      },
    );
  }
  
  TextTheme _buildTextTheme(TextTheme baseTheme, double multiplier) {
    return TextTheme(
      displayLarge: baseTheme.displayLarge?.copyWith(fontSize: (baseTheme.displayLarge?.fontSize ?? 57) * multiplier),
      displayMedium: baseTheme.displayMedium?.copyWith(fontSize: (baseTheme.displayMedium?.fontSize ?? 45) * multiplier),
      displaySmall: baseTheme.displaySmall?.copyWith(fontSize: (baseTheme.displaySmall?.fontSize ?? 36) * multiplier),
      headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: (baseTheme.headlineLarge?.fontSize ?? 32) * multiplier),
      headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: (baseTheme.headlineMedium?.fontSize ?? 28) * multiplier),
      headlineSmall: baseTheme.headlineSmall?.copyWith(fontSize: (baseTheme.headlineSmall?.fontSize ?? 24) * multiplier),
      titleLarge: baseTheme.titleLarge?.copyWith(fontSize: (baseTheme.titleLarge?.fontSize ?? 22) * multiplier),
      titleMedium: baseTheme.titleMedium?.copyWith(fontSize: (baseTheme.titleMedium?.fontSize ?? 16) * multiplier),
      titleSmall: baseTheme.titleSmall?.copyWith(fontSize: (baseTheme.titleSmall?.fontSize ?? 14) * multiplier),
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: (baseTheme.bodyLarge?.fontSize ?? 16) * multiplier),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: (baseTheme.bodyMedium?.fontSize ?? 14) * multiplier),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: (baseTheme.bodySmall?.fontSize ?? 12) * multiplier),
      labelLarge: baseTheme.labelLarge?.copyWith(fontSize: (baseTheme.labelLarge?.fontSize ?? 14) * multiplier),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: (baseTheme.labelMedium?.fontSize ?? 12) * multiplier),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: (baseTheme.labelSmall?.fontSize ?? 11) * multiplier),
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
    final isPinSet = await AuthService.isPinSet();
    
    if (isFirstLaunch || !isPinSet) {
      // 최초 실행이거나 PIN이 설정되지 않은 경우 → 인증 설정 화면
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthSetupScreen()),
      );
    } else {
      // PIN이 설정되어 있는 경우 → 로그인 화면
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
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
          ),
          // 하단 카피라이트
          Container(
            padding: EdgeInsets.only(bottom: 30),
            child: Text(
              'Copyright (c) 2025 jiwoosoft. Powered by HaneulCCM.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// 기존 PIN 설정 및 로그인 화면은 새로운 AuthSetupScreen과 LoginScreen으로 대체됨

// 메모 리스트 화면 (기존 CategoryListScreen)
class MemoListScreen extends StatefulWidget {
  @override
  _MemoListScreenState createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  List<Category> categories = [];
  List<Category> filteredCategories = [];
  bool _isEditMode = false;
  bool _isSearchMode = false;
  String _searchQuery = '';
  String? _selectedTag = null;
  SortOption _currentSortOption = SortOption.updatedDate;
  SortOrder _currentSortOrder = SortOrder.descending;
  final TextEditingController _searchController = TextEditingController();
  
  List<Category> get displayCategories => _isSearchMode ? filteredCategories : categories;

  @override
  void initState() {
    super.initState();
    _checkSessionAndLoadData();
    _loadSortSettings();
    _searchController.addListener(_onSearchChanged);
  }
  
  // 세션 PIN 확인 후 데이터 로드
  void _checkSessionAndLoadData() async {
    print('🔍 [MAIN] 메인 화면 초기화 시작');
    print('🔍 [MAIN] 세션 PIN 확인 중...');
    
    final sessionPin = await DataService.getCurrentSessionPin();
    
    print('🔍 [MAIN] 세션 PIN 상태: ${sessionPin != null ? '존재함 (길이: ${sessionPin.length})' : 'null'}');
    
    // 세션 PIN이 없으면 로그인 화면으로 리다이렉트
    if (sessionPin == null) {
      print('⚠️ [MAIN] 세션 PIN이 없습니다. 로그인 화면으로 이동합니다.');
      
      // 약간의 지연을 두고 리다이렉트 (디버깅용)
      await Future.delayed(Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
      return;
    }
    
    // 세션 PIN이 있으면 카테고리 데이터 로드
    print('✅ [MAIN] 세션 PIN 확인됨. 데이터를 로드합니다.');
    _loadCategories();
  }
  
  void _loadSortSettings() async {
    final settings = await DataService.loadSortSettings();
    setState(() {
      _currentSortOption = settings['option'];
      _currentSortOrder = settings['order'];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
      setState(() {
      _searchQuery = _searchController.text;
      _filterCategories();
    });
  }

  void _filterCategories() {
    List<Category> baseCategories = categories;
    
    // 태그 필터링 먼저 적용
    if (_selectedTag != null) {
      baseCategories = categories.map((category) {
        final filteredMemos = category.memos.where((memo) {
          return memo.tags.contains(_selectedTag);
        }).toList();
        
        if (filteredMemos.isNotEmpty) {
          return Category(
            id: category.id,
            name: category.name,
            icon: category.icon,
            memos: filteredMemos,
          );
        }
        return null;
      }).where((category) => category != null).cast<Category>().toList();
    }
    
    // 검색 필터링 적용
    if (_searchQuery.isEmpty) {
      filteredCategories = baseCategories.map((category) => _sortCategory(category)).toList();
    } else {
      filteredCategories = baseCategories.map((category) {
        // 카테고리 이름이 검색어와 일치하는 경우
        if (category.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return _sortCategory(category);
        }
        
        // 메모에서 검색어가 포함된 것들만 필터링
        final filteredMemos = category.memos.where((memo) {
          return memo.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 memo.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 memo.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
        }).toList();
        
        // 해당 카테고리에 검색 결과가 있는 경우만 포함
        if (filteredMemos.isNotEmpty) {
          return Category(
            id: category.id,
            name: category.name,
            icon: category.icon,
            memos: _sortMemos(filteredMemos),
          );
        }
        
        return null;
      }).where((category) => category != null).cast<Category>().toList();
    }
  }
  
  // 모든 태그 수집
  Set<String> _getAllTags() {
    Set<String> allTags = {};
    for (final category in categories) {
      for (final memo in category.memos) {
        allTags.addAll(memo.tags);
      }
    }
    return allTags;
  }
  
  Category _sortCategory(Category category) {
    return Category(
      id: category.id,
      name: category.name,
      icon: category.icon,
      memos: _sortMemos(category.memos),
    );
  }
  
  List<Memo> _sortMemos(List<Memo> memos) {
    List<Memo> sortedMemos = List.from(memos);
    
    switch (_currentSortOption) {
      case SortOption.createdDate:
        sortedMemos.sort((a, b) => _currentSortOrder == SortOrder.ascending 
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.updatedDate:
        sortedMemos.sort((a, b) => _currentSortOrder == SortOrder.ascending 
            ? a.updatedAt.compareTo(b.updatedAt)
            : b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.title:
        sortedMemos.sort((a, b) => _currentSortOrder == SortOrder.ascending 
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title));
        break;
      case SortOption.content:
        sortedMemos.sort((a, b) => _currentSortOrder == SortOrder.ascending 
            ? a.content.compareTo(b.content)
            : b.content.compareTo(a.content));
        break;
    }
    
    return sortedMemos;
  }

  void _showTagFilterDialog() {
    final allTags = _getAllTags().toList();
    
    if (allTags.isEmpty) {
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text('태그 필터', style: TextStyle(color: Colors.white)),
          content: Text(
            '사용 가능한 태그가 없습니다.\n메모에 태그를 추가한 후 다시 시도해주세요.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('확인', style: TextStyle(color: Colors.teal)),
            ),
          ],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('태그 필터', style: TextStyle(color: Colors.white)),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '태그를 선택하여 메모를 필터링하세요',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 16),
              // 전체 보기 옵션
              ListTile(
                leading: Icon(
                  _selectedTag == null ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _selectedTag == null ? Colors.teal : Colors.grey,
                ),
                title: Text(
                  '전체 보기',
                  style: TextStyle(
                    color: _selectedTag == null ? Colors.teal : Colors.white,
                    fontWeight: _selectedTag == null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                setState(() {
                    _selectedTag = null;
                    _filterCategories();
                  });
                  Navigator.pop(context);
                },
              ),
              Divider(color: Colors.grey[700]),
              // 태그 목록
              ...allTags.map((tag) => ListTile(
                leading: Icon(
                  _selectedTag == tag ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _selectedTag == tag ? Colors.teal : Colors.grey,
                ),
                title: Text(
                  tag,
                  style: TextStyle(
                    color: _selectedTag == tag ? Colors.teal : Colors.white,
                    fontWeight: _selectedTag == tag ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: Chip(
                  label: Text(
                    '${_getTagCount(tag)}',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: Colors.teal.shade600,
                ),
                onTap: () {
                  setState(() {
                    _selectedTag = tag;
                    _filterCategories();
                  });
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
  
  // 태그별 메모 개수 계산
  int _getTagCount(String tag) {
    int count = 0;
    for (final category in categories) {
      for (final memo in category.memos) {
        if (memo.tags.contains(tag)) {
          count++;
        }
      }
    }
    return count;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('정렬 옵션'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정렬 기준', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            RadioListTile<SortOption>(
              title: Text('생성일순'),
              value: SortOption.createdDate,
              groupValue: _currentSortOption,
              onChanged: (value) {
                setState(() {
                  _currentSortOption = value!;
                });
              },
            ),
            RadioListTile<SortOption>(
              title: Text('수정일순'),
              value: SortOption.updatedDate,
              groupValue: _currentSortOption,
              onChanged: (value) {
                setState(() {
                  _currentSortOption = value!;
                });
              },
            ),
            RadioListTile<SortOption>(
              title: Text('제목순'),
              value: SortOption.title,
              groupValue: _currentSortOption,
              onChanged: (value) {
                setState(() {
                  _currentSortOption = value!;
                });
              },
            ),
            RadioListTile<SortOption>(
              title: Text('내용순'),
              value: SortOption.content,
              groupValue: _currentSortOption,
              onChanged: (value) {
                setState(() {
                  _currentSortOption = value!;
                });
              },
            ),
            SizedBox(height: 16),
            Text('정렬 순서', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            RadioListTile<SortOrder>(
              title: Text('오름차순'),
              value: SortOrder.ascending,
              groupValue: _currentSortOrder,
              onChanged: (value) {
                setState(() {
                  _currentSortOrder = value!;
                });
              },
            ),
            RadioListTile<SortOrder>(
              title: Text('내림차순'),
              value: SortOrder.descending,
              groupValue: _currentSortOrder,
              onChanged: (value) {
                setState(() {
                  _currentSortOrder = value!;
                });
              },
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
              _applySortSettings();
              Navigator.pop(context);
            },
            child: Text('적용'),
          ),
        ],
      ),
    );
  }

  void _applySortSettings() {
    DataService.saveSortSettings(_currentSortOption, _currentSortOrder);
    _filterCategories();
  }

  void _loadCategories() async {
    final loadedCategories = await DataService.getCategories();
    setState(() {
      categories = loadedCategories;
      filteredCategories = loadedCategories;
    });
  }

  void _saveCategories() async {
    final success = await DataService.saveCategories(categories);
    if (!success) {
      _showErrorDialog('메모 저장에 실패했습니다.\n앱을 다시 시작해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('안전한 메모장 - Secure Memo'),
            if (_selectedTag != null) ...[
              SizedBox(width: 8),
              Chip(
                label: Text(
                  _selectedTag!,
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: Colors.teal.shade600,
                deleteIcon: Icon(Icons.close, size: 16, color: Colors.white),
                onDeleted: () {
                  setState(() {
                    _selectedTag = null;
                    _filterCategories();
                  });
                },
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearchMode ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchMode = !_isSearchMode;
                if (!_isSearchMode) {
                  _searchController.clear();
                  _searchQuery = '';
                  _filterCategories();
                }
              });
            },
            tooltip: _isSearchMode ? '검색 닫기' : '검색',
          ),
          IconButton(
            icon: Icon(Icons.local_offer),
            onPressed: _showTagFilterDialog,
            tooltip: '태그 필터',
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: '정렬 옵션',
          ),
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
                  value: 'tag_management',
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('태그 관리'),
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
                } else if (value == 'tag_management') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TagManagementScreen()),
                  );
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
          : Column(
              children: [
                // 검색 바
                if (_isSearchMode) _buildSearchBar(),
                // 메인 컨텐츠
                Expanded(
                  child: _isEditMode
                      ? _buildReorderableList()
                      : _buildCategoryList(),
                ),
              ],
            ),
      // 하단 카피라이트
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[700]!)),
        ),
        child: Text(
          'Copyright (c) 2025 jiwoosoft. Powered by HaneulCCM.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '메모 검색...',
          hintStyle: TextStyle(color: Colors.white54),
          prefixIcon: Icon(Icons.search, color: Colors.teal),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal),
          ),
        ),
        autofocus: true,
      ),
    );
  }

  Widget _buildCategoryList() {
    if (displayCategories.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).brightness == Brightness.light 
                  ? Colors.black38 
                  : Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light 
                    ? Colors.black54 
                    : Colors.white54,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '"$_searchQuery"에 대한 결과를 찾을 수 없습니다',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light 
                    ? Colors.black38 
                    : Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: displayCategories.length,
        itemBuilder: (context, index) {
        final category = displayCategories[index];
          return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: Theme.of(context).brightness == Brightness.light ? 4 : 2,
          shadowColor: Theme.of(context).brightness == Brightness.light 
              ? Colors.grey.withOpacity(0.3) 
              : Colors.black.withOpacity(0.5),
          color: Theme.of(context).brightness == Brightness.light 
              ? Colors.white  // 라이트 모드: 순백색 (카테고리)
              : Colors.grey[800],  // 다크 모드: 밝은 회색 (카테고리)
          child: ExpandablePanel(
            theme: ExpandableThemeData(
              iconColor: Theme.of(context).brightness == Brightness.light 
                  ? Colors.black54 
                  : Colors.white70,
              tapHeaderToExpand: true,
              tapBodyToExpand: false,
              tapBodyToCollapse: false,
            ),
            header: ListTile(
              leading: Icon(
                _getIconData(category.icon),
                color: Colors.teal,
              ),
              title: Text(
                category.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.light 
                      ? Colors.black87 
                      : Colors.white,
                ),
              ),
              subtitle: Text(
                '${category.memos.length}개의 메모',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light 
                      ? Colors.black54 
                      : Colors.white70,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isSearchMode) ...[
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.teal),
                      onPressed: () => _addMemo(category),
                      tooltip: '메모 추가',
                    ),
                    PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context).brightness == Brightness.light 
                            ? Colors.black54 
                            : Colors.white70,
                      ),
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
                  if (_isSearchMode && _searchQuery.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '검색 결과',
                        style: TextStyle(
                          color: Colors.teal,
                          fontSize: 12,
                        ),
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light 
            ? Colors.blue[50]  // 라이트 모드: 연한 파란색 (메모 리스트)
            : Colors.black,  // 다크 모드: 순검은색 (메모 리스트)
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: ReorderableListView.builder(
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
          return Container(
          key: ValueKey(memo.id),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.light 
                      ? Colors.grey[300]! 
                      : Colors.grey[800]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Container(
              color: Theme.of(context).brightness == Brightness.light 
                  ? Colors.blue[25]  // 라이트 모드: 매우 연한 파란색 (개별 메모)
                  : Colors.grey[900],  // 다크 모드: 진한 회색 (개별 메모)
              child: ListTile(
          leading: Icon(Icons.note, color: Colors.teal, size: 20),
          title: Text(
            memo.title.isEmpty ? '제목 없음' : memo.title,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light 
                        ? Colors.black87 
                        : Colors.white,
                  ),
          ),
          subtitle: memo.tags.isNotEmpty 
                  ? Wrap(
                  spacing: 4,
                      children: memo.tags.map((tag) => Chip(
                        label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                            color: Theme.of(context).brightness == Brightness.light 
                                ? Colors.white 
                                : Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.teal.withOpacity(0.7),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
              )
            : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).brightness == Brightness.light 
                          ? Colors.black54 
                          : Colors.white70,
                      size: 20,
                    ),
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
                  Icon(
                    Icons.drag_handle, 
                    color: Theme.of(context).brightness == Brightness.light 
                        ? Colors.black38 
                        : Colors.white38, 
                    size: 16,
                  ),
            ],
          ),
          onTap: () => _viewMemo(category, memo),
              ),
            ),
        );
      },
      ),
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
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('오류', style: TextStyle(color: Colors.white)),
          ],
        ),
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
            // 태그 표시
            if (memo.tags.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                '태그:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: memo.tags.map((tag) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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
  final TextEditingController _tagController = TextEditingController();
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.memo != null) {
      _titleController.text = widget.memo!.title;
      _contentController.text = widget.memo!.content;
      _tags = List.from(widget.memo!.tags);
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
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
            // 태그 입력 영역
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '태그 추가',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add, color: Colors.teal),
                            onPressed: _addTag,
                          ),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // 태그 칩 표시
                if (_tags.isNotEmpty)
                  Container(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text(tag, style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.teal.withValues(alpha: 0.3),
                          deleteIcon: Icon(Icons.close, color: Colors.white70, size: 18),
                          onDeleted: () => _removeTag(tag),
                        );
                      }).toList(),
                    ),
                  ),
              ],
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }
  
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
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
      tags: _tags,
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
  bool _isThemeDialogOpen = false;
  bool _isFontSizeDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    packageInfo = await PackageInfo.fromPlatform();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final dividerColor = isDarkMode ? Colors.white24 : Colors.black12;

    return Scaffold(
      appBar: AppBar(
        title: Text('설정'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.lock, color: Colors.teal),
            title: Text('PIN 변경', style: TextStyle(color: textColor)),
            subtitle: Text('보안을 위해 PIN을 변경하세요', style: TextStyle(color: subtitleColor)),
            trailing: Icon(Icons.arrow_forward_ios, color: subtitleColor),
            onTap: () => _showPinChangeDialog(context),
          ),
          Divider(color: dividerColor),
          // 인증 방법 설정 제거됨 (PIN 전용)
          ListTile(
            leading: Icon(Icons.palette, color: Colors.teal),
            title: Text('테마 설정', style: TextStyle(color: textColor)),
            subtitle: Text('다크 테마', style: TextStyle(color: subtitleColor)),
            trailing: Icon(Icons.arrow_forward_ios, color: subtitleColor),
            onTap: () => _showThemeDialog(context),
          ),
          Divider(color: dividerColor),
          ListTile(
            leading: Icon(Icons.text_fields, color: Colors.teal),
            title: Text('폰트 크기', style: TextStyle(color: textColor)),
            subtitle: Text('보통', style: TextStyle(color: subtitleColor)),
            trailing: Icon(Icons.arrow_forward_ios, color: subtitleColor),
            onTap: () => _showFontSizeDialog(context),
          ),
          Divider(color: dividerColor),
          ListTile(
            leading: Icon(Icons.info, color: Colors.teal),
            title: Text('앱 정보', style: TextStyle(color: textColor)),
            subtitle: Text(
              packageInfo != null 
                ? '버전 ${packageInfo!.version} (${packageInfo!.buildNumber})'
                : '버전 정보 로딩 중...',
              style: TextStyle(color: subtitleColor)
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: subtitleColor),
            onTap: () {
              print('🎯 업데이트 확인 버튼 클릭됨!');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('업데이트 확인 버튼이 클릭되었습니다!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              _checkForUpdate(context);
            },
          ),
          Divider(color: dividerColor),
          ListTile(
            leading: Icon(Icons.description, color: Colors.teal),
            title: Text('라이선스', style: TextStyle(color: textColor)),
            subtitle: Text('MIT 라이선스 및 오픈소스 정보', style: TextStyle(color: subtitleColor)),
            trailing: Icon(Icons.arrow_forward_ios, color: subtitleColor),
            onTap: () => _showLicenseDialog(context),
          ),
          Divider(color: dividerColor),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('로그아웃', style: TextStyle(color: Colors.red)),
            subtitle: Text('보안을 위해 로그아웃하고 다시 로그인하세요', style: TextStyle(color: subtitleColor)),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    if (_isThemeDialogOpen) return;
    _isThemeDialogOpen = true;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('테마 설정', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppTheme.values.map((theme) {
            return RadioListTile<AppTheme>(
              title: Text(
                _getThemeDisplayName(theme),
                style: TextStyle(color: textColor),
              ),
              value: theme,
              groupValue: Provider.of<AppSettings>(context).currentTheme,
              onChanged: (AppTheme? value) {
                if (value != null) {
                  Provider.of<AppSettings>(context, listen: false).updateTheme(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            child: Text('취소', style: TextStyle(color: Colors.teal)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ).then((_) => _isThemeDialogOpen = false);
  }

  void _showFontSizeDialog(BuildContext context) {
    if (_isFontSizeDialogOpen) return;
    _isFontSizeDialogOpen = true;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('폰트 크기', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: FontSize.values.map((size) {
            return RadioListTile<FontSize>(
              title: Text(
                _getFontSizeDisplayName(size),
                style: TextStyle(color: textColor),
              ),
              value: size,
              groupValue: Provider.of<AppSettings>(context).currentFontSize,
              onChanged: (FontSize? value) {
                if (value != null) {
                  Provider.of<AppSettings>(context, listen: false).updateFontSize(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            child: Text('취소', style: TextStyle(color: Colors.teal)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ).then((_) => _isFontSizeDialogOpen = false);
  }

  void _showPinChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ChangePinScreen(),
    );
  }

  // 인증 방법 설정 다이얼로그 제거됨 (PIN 전용)

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LicenseScreen(),
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
              // 세션 PIN 클리어
              DataService.clearSessionPin();
              
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

  String _getThemeDisplayName(AppTheme? theme) {
    switch (theme) {
      case AppTheme.system:
        return '시스템 설정 따름';
      case AppTheme.light:
        return '라이트 테마';
      case AppTheme.dark:
        return '다크 테마';
      default:
        return '테마 로딩 중...';
    }
  }

  String _getFontSizeDisplayName(FontSize? fontSize) {
    switch (fontSize) {
      case FontSize.small:
        return '작게';
      case FontSize.medium:
        return '보통';
      case FontSize.large:
        return '크게';
      case FontSize.extraLarge:
        return '매우 크게';
      default:
        return '폰트 크기 로딩 중...';
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    print('🔍 업데이트 확인 시작...');
    
    // 로딩 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('업데이트 확인 중...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
    
    try {
      print('📡 UpdateService.checkForUpdate() 호출...');
      final result = await UpdateService.checkForUpdate();
      
      print('✅ 업데이트 확인 완료');
      print('현재 버전: ${result.currentVersion}');
      print('최신 버전: ${result.latestVersion}');
      print('업데이트 필요: ${result.hasUpdate}');
      
      if (!mounted) {
        print('⚠️ Widget이 unmounted 상태');
        return;
      }

      if (result.hasUpdate) {
        print('🚀 업데이트 다이얼로그 표시');
        _showUpdateDialog(context, result);
      } else {
        print('✅ 최신 버전입니다');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('현재 최신 버전입니다. (v${result.currentVersion})'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ 업데이트 확인 오류: $e');
      print('스택 트레이스: $stackTrace');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업데이트 확인 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateCheckResult result) {
    print('📱 업데이트 다이얼로그 표시 중...');
    print('다운로드 URL: ${result.releaseInfo?.downloadUrl ?? "정보 없음"}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('업데이트 가능', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새로운 버전이 있습니다:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              '현재 버전: ${result.currentVersion}',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '최신 버전: ${result.latestVersion}',
              style: TextStyle(color: Colors.white70),
            ),
            if (result.releaseInfo?.body?.isNotEmpty == true) ...[
              SizedBox(height: 16),
              Text(
                '업데이트 내용:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                result.releaseInfo!.body,
                style: TextStyle(color: Colors.white70),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ 사용자가 업데이트를 취소했습니다');
              Navigator.pop(context);
            },
            child: Text('나중에', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              print('🔗 업데이트 버튼 클릭됨');
              Navigator.pop(context);
              
              final url = result.releaseInfo?.downloadUrl ?? 'https://drive.google.com/file/d/1cZ3mv6Vf778cNpOxHuOuWhSbl5517anm/view?usp=drivesdk';
              print('🌐 URL 실행 시도: $url');
              
              try {
                // Google Drive 링크를 브라우저에서 열기 위해 수정
                String finalUrl = url;
                if (url.contains('drive.google.com') && url.contains('view?usp=')) {
                  // Google Drive 공유 링크를 직접 다운로드 링크로 변환하지 않고 그대로 사용
                  finalUrl = url;
                }
                
                final uri = Uri.parse(finalUrl);
                print('📱 최종 URL: $finalUrl');
                print('📱 canLaunchUrl 확인 중...');
                
                // 여러 방법으로 시도
                bool launched = false;
                
                // 방법 1: 외부 애플리케이션으로 열기
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    launched = true;
                    print('✅ 외부 애플리케이션으로 URL 실행 성공');
                  }
                } catch (e) {
                  print('⚠️ 외부 애플리케이션 실행 실패: $e');
                }
                
                // 방법 2: 기본 브라우저로 열기
                if (!launched) {
                  try {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.platformDefault,
                    );
                    launched = true;
                    print('✅ 기본 브라우저로 URL 실행 성공');
                  } catch (e) {
                    print('⚠️ 기본 브라우저 실행 실패: $e');
                  }
                }
                
                // 방법 3: 인앱 브라우저로 열기
                if (!launched) {
                  try {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.inAppWebView,
                    );
                    launched = true;
                    print('✅ 인앱 브라우저로 URL 실행 성공');
    } catch (e) {
                    print('⚠️ 인앱 브라우저 실행 실패: $e');
                  }
                }
                
                if (!launched) {
                  throw 'URL을 열 수 없습니다: $finalUrl';
                }
                
              } catch (e) {
                print('❌ URL 실행 실패: $e');
                if (!mounted) return;
                
                // 실패 시 URL을 클립보드에 복사하고 안내 메시지 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('브라우저에서 직접 열어주세요:\n$url'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 8),
                    action: SnackBarAction(
                      label: '복사',
              onPressed: () {
                        // 클립보드 복사 기능은 별도 패키지가 필요하므로 생략
                        print('URL 복사 요청: $url');
                      },
                    ),
                  ),
                );
              }
            },
            child: Text('업데이트', style: TextStyle(color: Colors.teal)),
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
      // 하단 카피라이트
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[700]!)),
        ),
        child: Text(
          'Copyright (c) 2025 jiwoosoft. Powered by HaneulCCM.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
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

// 라이선스 화면
class LicenseScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('라이선스'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 앱 정보
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔐 안전한 메모장 앱',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MIT 라이선스 기반 오픈소스 프로젝트',
                    style: TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Copyright (c) 2025 jiwoosoft. Powered by HaneulCCM.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // 영문 라이선스
            Text(
              '🇺🇸 English License',
              style: TextStyle(
                color: Colors.teal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Text(
                '''MIT License

Copyright (c) 2025 jiwoosoft

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.''',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // 한글 라이선스
            Text(
              '🇰🇷 한국어 라이선스',
              style: TextStyle(
                color: Colors.teal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Text(
                '''MIT 라이선스

저작권 (c) 2025 jiwoosoft

이 소프트웨어 및 관련 문서 파일(이하 "소프트웨어")의 복사본을 얻는 모든 사람에게 무료로 허가를 부여하며, 소프트웨어를 제한 없이 사용, 복사, 수정, 병합, 출판, 배포, 하위 라이선스 및/또는 판매할 수 있는 권한을 포함하여 소프트웨어를 다루는 권한을 부여합니다. 또한 소프트웨어가 제공되는 사람들에게 동일한 권한을 부여하는 것을 허용하며, 이는 다음 조건을 준수하는 경우에 해당합니다:

위의 저작권 고지 및 이 허가 고지는 소프트웨어의 모든 복사본 또는 상당 부분에 포함되어야 합니다.

소프트웨어는 어떠한 종류의 보증도 없이 "있는 그대로" 제공되며, 상품성, 특정 목적에 대한 적합성 및 비침해성에 대한 보증을 포함하되 이에 국한되지 않습니다. 어떠한 경우에도 작성자 또는 저작권 소유자는 소프트웨어 또는 소프트웨어의 사용 또는 기타 거래로 인해 발생하는 계약, 불법 행위 또는 기타 행위에 대한 클레임, 손해 또는 기타 책임에 대해 책임을 지지 않습니다.

저작권 (c) 2025 jiwoosoft. Powered by HaneulCCM.''',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // 개발자 정보
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👨‍💻 개발자 정보',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Developer: jiwoosoft', style: TextStyle(color: Colors.white70)),
                  Text('Powered by: HaneulCCM', style: TextStyle(color: Colors.white70)),
                  Text('Website: http://jiwoosoft.com', style: TextStyle(color: Colors.white70)),
                  Text('YouTube: @haneulccm', style: TextStyle(color: Colors.white70)),
                  Text('E-mail: webmaster@jiwoosoft.com', style: TextStyle(color: Colors.white70)),
                  Text('GitHub: https://github.com/jiwoosoft', style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 8),
                  Text('Built with Flutter ❤️', style: TextStyle(color: Colors.teal)),
                ],
              ),
            ),
            
            SizedBox(height: 24),
          ],
        ),
      ),
      // 하단 카피라이트
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[700]!)),
        ),
        child: Text(
          'Copyright (c) 2025 jiwoosoft. Powered by HaneulCCM.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// 태그 관리 화면
class TagManagementScreen extends StatefulWidget {
  @override
  _TagManagementScreenState createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  List<Category> categories = [];
  Set<String> allTags = {};
  Map<String, int> tagCounts = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  void _loadData() async {
    final loadedCategories = await DataService.getCategories();
    final tags = <String>{};
    final counts = <String, int>{};
    
    for (final category in loadedCategories) {
      for (final memo in category.memos) {
        for (final tag in memo.tags) {
          tags.add(tag);
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
    }
    
    setState(() {
      categories = loadedCategories;
      allTags = tags;
      tagCounts = counts;
    });
  }
  
  void _deleteTag(String tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('태그 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '태그 "$tag"을(를) 모든 메모에서 삭제하시겠습니까?\n\n삭제된 태그는 복구할 수 없습니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _performDeleteTag(tag);
              Navigator.pop(context);
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _performDeleteTag(String tag) async {
    // 모든 메모에서 태그 삭제
    for (final category in categories) {
      for (final memo in category.memos) {
        memo.tags.remove(tag);
      }
    }
    
    // 데이터 저장
    await DataService.saveCategories(categories);
    
    // 화면 업데이트
    _loadData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('태그 "$tag"이(가) 모든 메모에서 삭제되었습니다.'),
                backgroundColor: Colors.teal,
              ),
    );
  }
  
  void _renameTag(String oldTag) {
    final TextEditingController controller = TextEditingController(text: oldTag);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('태그 이름 변경', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '새로운 태그 이름을 입력하세요',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.teal),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.teal),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && newTag != oldTag) {
                _performRenameTag(oldTag, newTag);
              }
              Navigator.pop(context);
            },
            child: Text('변경', style: TextStyle(color: Colors.teal)),
            ),
          ],
        ),
    );
  }
  
  void _performRenameTag(String oldTag, String newTag) async {
    // 중복 태그 체크
    if (allTags.contains(newTag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('태그 "$newTag"은(는) 이미 존재합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 모든 메모에서 태그 이름 변경
    for (final category in categories) {
      for (final memo in category.memos) {
        final index = memo.tags.indexOf(oldTag);
        if (index >= 0) {
          memo.tags[index] = newTag;
        }
      }
    }
    
    // 데이터 저장
    await DataService.saveCategories(categories);
    
    // 화면 업데이트
    _loadData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('태그 "$oldTag"이(가) "$newTag"으로 변경되었습니다.'),
        backgroundColor: Colors.teal,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('태그 관리'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
      ),
      body: allTags.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 64,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '사용 중인 태그가 없습니다',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '메모에 태그를 추가하면 여기에 표시됩니다',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: allTags.length,
              itemBuilder: (context, index) {
                final tag = allTags.elementAt(index);
                final count = tagCounts[tag] ?? 0;
                
                return Card(
                  color: Colors.grey[850],
                  child: ListTile(
                    leading: Icon(
                      Icons.local_offer,
                      color: Colors.teal,
                    ),
                    title: Text(
                      tag,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$count개의 메모에서 사용됨',
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: PopupMenuButton(
                      color: Colors.grey[800],
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('이름 변경', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('삭제', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'rename') {
                          _renameTag(tag);
                        } else if (value == 'delete') {
                          _deleteTag(tag);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
