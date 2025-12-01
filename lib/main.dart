import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'firebase_options.dart';

// ============================================================================
// CART MODELS
// ============================================================================

/// Represents a product in the shopping cart
class CartItem {
  final String barcode;
  final String name;
  final String categoryCode;
  final String subcategory;
  final String primaryCategory;
  final double price;
  final String imageUrl;
  final String? warehouseCode; // Warehouse code from Firestore
  int quantity;

  CartItem({
    required this.barcode,
    required this.name,
    required this.categoryCode,
    required this.subcategory,
    required this.primaryCategory,
    required this.price,
    required this.imageUrl,
    this.warehouseCode,
    this.quantity = 1,
  });

  /// Convert to JSON for localStorage
  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'categoryCode': categoryCode,
        'subcategory': subcategory,
        'primaryCategory': primaryCategory,
        'price': price,
        'imageUrl': imageUrl,
        'warehouseCode': warehouseCode,
        'quantity': quantity,
      };

  /// Create from JSON stored in localStorage
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        barcode: json['barcode'] as String,
        name: json['name'] as String,
        categoryCode: json['categoryCode'] as String,
        subcategory: json['subcategory'] as String,
        primaryCategory: json['primaryCategory'] as String,
        price: (json['price'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String,
        warehouseCode: json['warehouseCode'] as String?,
        quantity: json['quantity'] as int,
      );
}

// ============================================================================
// CART SERVICE - Manages localStorage persistence
// ============================================================================

class CartService {
  static const String _storageKey = 'xepi_cart';
  static CartService? _instance;
  final List<CartItem> _items = [];
  final List<VoidCallback> _listeners = [];

  CartService._();

  static CartService get instance {
    _instance ??= CartService._();
    return _instance!;
  }

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Load cart from localStorage
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_storageKey);
      if (cartJson != null) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        _items.clear();
        _items.addAll(decoded.map((item) => CartItem.fromJson(item)));
        _notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  /// Save cart to localStorage
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString(_storageKey, cartJson);
      _notifyListeners();
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  /// Add item to cart or increase quantity if exists
  Future<void> addItem(CartItem item) async {
    final existingIndex = _items.indexWhere((i) => i.barcode == item.barcode);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    await _saveCart();
  }

  /// Update quantity of an item
  Future<void> updateQuantity(String barcode, int newQuantity) async {
    final index = _items.indexWhere((item) => item.barcode == barcode);
    if (index >= 0) {
      if (newQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = newQuantity;
      }
      await _saveCart();
    }
  }

  /// Remove item from cart
  Future<void> removeItem(String barcode) async {
    _items.removeWhere((item) => item.barcode == barcode);
    await _saveCart();
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    _items.clear();
    await _saveCart();
  }

  /// Check if item is in cart
  bool isInCart(String barcode) {
    return _items.any((item) => item.barcode == barcode);
  }

  /// Get quantity of specific item
  int getQuantity(String barcode) {
    final item = _items.firstWhere(
      (item) => item.barcode == barcode,
      orElse: () => CartItem(
        barcode: '',
        name: '',
        categoryCode: '',
        subcategory: '',
        primaryCategory: '',
        price: 0,
        imageUrl: '',
        quantity: 0,
      ),
    );
    return item.quantity;
  }

  /// Get total quantity of all LAT-2030 and LAT-1530 items combined
  int _getTotalBulkPricingQuantity() {
    return _items
        .where((item) =>
            item.categoryCode == 'LAT-2030' || item.categoryCode == 'LAT-1530')
        .fold(0, (sum, item) => sum + item.quantity);
  }

  /// Calculate bulk price for cuadros de latón (LAT-2030 and LAT-1530)
  /// Pricing applies across ALL LAT-2030 and LAT-1530 items combined:
  /// 1 total unit = Q35 each, 2+ total units = Q30 each, 5+ total units = Q25 each
  double getBulkPrice(String categoryCode, int itemQuantity, double basePrice) {
    // Only apply bulk pricing to specific cuadros categories
    if (categoryCode != 'LAT-2030' && categoryCode != 'LAT-1530') {
      return basePrice;
    }

    // Get total quantity across ALL LAT-2030 and LAT-1530 products
    final totalQuantity = _getTotalBulkPricingQuantity();

    if (totalQuantity >= 5) {
      return 25.0;
    } else if (totalQuantity >= 2) {
      return 30.0;
    } else {
      return 35.0;
    }
  }

  /// Calculate total for all items with bulk pricing applied
  double calculateTotal() {
    double total = 0;
    for (final item in _items) {
      final unitPrice =
          getBulkPrice(item.categoryCode, item.quantity, item.price);
      total += unitPrice * item.quantity;
    }
    return total;
  }

  /// Get the effective price for an item (with bulk discount applied)
  double getEffectivePrice(CartItem item) {
    return getBulkPrice(item.categoryCode, item.quantity, item.price);
  }

  /// Add listener for cart changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

// ============================================================================
// CONSTANTS
// ============================================================================

/// Brand colors used throughout the app
class AppColors {
  static const darkGray = Color(0xFF2B2B2B);
  static const orange = Color(0xFFDB6A19);
  static const yellow = Color(0xFFFEC800);
  static const blue = Color(0xFF00ACC0);

  /// Category card colors cycle through these
  static const categoryColors = [orange, yellow, blue];
}

/// Responsive breakpoints
class Breakpoints {
  static const double mobile = 600.0;
  static const double desktop = 1200.0;
}

// ============================================================================
// MAIN APP
// ============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CartService.instance.loadCart(); // Load cart from localStorage
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xepi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const CategoryGallery(),
    );
  }
}

// ============================================================================
// CATEGORY GALLERY - Main page displaying all product categories
// ============================================================================

class CategoryGallery extends StatefulWidget {
  const CategoryGallery({super.key});

  @override
  State<CategoryGallery> createState() => _CategoryGalleryState();
}

class _CategoryGalleryState extends State<CategoryGallery> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _primaryCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPrimaryCategories();
  }

  /// Fetches primary categories from Firestore (new nested structure)
  Future<void> _fetchPrimaryCategories() async {
    try {
      final snapshot = await _firestore.collection('categories').get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No categories found in Firestore');
        setState(() {
          _primaryCategories = [];
          _isLoading = false;
        });
        return;
      }

      // Map primary categories directly from documents
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id, // Document ID is the primary category name
              'name': data['name'] as String? ?? doc.id,
              'primaryCode': data['primaryCode'] as String?,
              'coverImageUrl': data['coverImageUrl'] as String?,
              'displayOrder': data['displayOrder'] as int? ?? 999,
              'isActive': data['isActive'] as bool? ?? true,
            };
          })
          .where((cat) => cat['isActive'] == true)
          .toList();

      // Sort by displayOrder
      categories.sort((a, b) =>
          (a['displayOrder'] as int).compareTo(b['displayOrder'] as int));

      setState(() {
        _primaryCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching primary categories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobile;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logoxepi.jpg',
              height: isMobile ? 35 : 50,
              width: isMobile ? 35 : 50,
            ),
            SizedBox(width: isMobile ? 5.0 : 7.0),
            Text(
              'Catálogo',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: isMobile ? 20 : 30,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          const CartIconButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Determine grid layout based on screen width
                final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
                final horizontalPadding =
                    _getHorizontalPadding(constraints.maxWidth);

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 20.0,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = _primaryCategories[index];
                            final color =
                                _getCategoryColor(index, crossAxisCount);

                            return CategoryCard(
                              categoryName: category['name'] as String,
                              color: color,
                              coverImageUrl:
                                  category['coverImageUrl'] as String?,
                              onTap: () => _navigateToSubcategoriesPage(
                                  context, category),
                            );
                          },
                          childCount: _primaryCategories.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Footer()),
                  ],
                );
              },
            ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width > Breakpoints.desktop) return 3;
    if (width > Breakpoints.mobile) return 3;
    return 2;
  }

  double _getHorizontalPadding(double width) {
    if (width > Breakpoints.desktop) return (width - 1000) / 2;
    if (width > Breakpoints.mobile) return 40.0;
    return 20.0;
  }

  /// Get category color using diagonal cycling pattern
  Color _getCategoryColor(int index, int crossAxisCount) {
    final colorIndex = crossAxisCount == 2
        ? index % AppColors.categoryColors.length
        : (index + (index ~/ crossAxisCount)) % AppColors.categoryColors.length;
    return AppColors.categoryColors[colorIndex];
  }

  void _navigateToSubcategoriesPage(
      BuildContext context, Map<String, dynamic> primaryCategory) async {
    // Check if this primary category has multiple subcategories
    final snapshot = await _firestore
        .collection('categories')
        .doc(primaryCategory['id'] as String) // Use document ID
        .collection('subcategories')
        .get();

    if (snapshot.docs.isEmpty) {
      // No subcategories found
      return;
    }

    if (snapshot.docs.length == 1) {
      // Only one subcategory - skip to products page directly
      final categoryData = snapshot.docs.first.data();
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductsPage(
            categoryCode: categoryData['code'] as String,
            categoryName: categoryData['name'] as String,
            defaultPrice: categoryData['defaultPrice'] as num?,
            primaryCategory: primaryCategory['name'] as String,
          ),
        ),
      );
    } else {
      // Multiple subcategories - show subcategories page
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubcategoriesPage(
            primaryCategoryId: primaryCategory['id'] as String,
            primaryCategoryName: primaryCategory['name'] as String,
            primaryCoverImageUrl: primaryCategory['coverImageUrl'] as String?,
          ),
        ),
      );
    }
  }
}

// ============================================================================
// SUBCATEGORIES PAGE - Shows subcategories within a primary category
// ============================================================================

class SubcategoriesPage extends StatefulWidget {
  final String primaryCategoryId; // Document ID in Firestore
  final String primaryCategoryName; // Display name
  final String? primaryCoverImageUrl; // Fallback cover image

  const SubcategoriesPage({
    super.key,
    required this.primaryCategoryId,
    required this.primaryCategoryName,
    this.primaryCoverImageUrl,
  });

  @override
  State<SubcategoriesPage> createState() => _SubcategoriesPageState();
}

class _SubcategoriesPageState extends State<SubcategoriesPage> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _subcategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubcategories();
  }

  Future<void> _fetchSubcategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .doc(widget.primaryCategoryId)
          .collection('subcategories')
          .get();

      final subcategories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'code': data['code'] as String?,
              'name': data['name'] as String?,
              'subcategoryName': data['subcategoryName'] as String?,
              'coverImageUrl': data['coverImageUrl'] as String? ??
                  widget.primaryCoverImageUrl,
              'defaultPrice': data['defaultPrice'] as num?,
              'primaryCategory': widget.primaryCategoryName,
              'displayOrder': data['displayOrder'] as int? ?? 999,
              'isActive': data['isActive'] as bool? ?? true,
            };
          })
          .where((cat) => cat['isActive'] == true)
          .toList();

      // Sort by displayOrder in memory
      subcategories.sort((a, b) =>
          (a['displayOrder'] as int).compareTo(b['displayOrder'] as int));

      setState(() {
        _subcategories = subcategories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching subcategories: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final crossAxisCount = isMobile ? 2 : 3;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        title: Text(
          widget.primaryCategoryName.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isMobile ? 18 : 30,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          CartIconButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth > Breakpoints.desktop
                        ? (constraints.maxWidth - 1000) / 2
                        : constraints.maxWidth > Breakpoints.mobile
                            ? 40.0
                            : 20.0;

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 20.0,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final subcategory = _subcategories[index];
                            final color = AppColors.categoryColors[
                                (index + (index ~/ crossAxisCount)) %
                                    AppColors.categoryColors.length];

                            return CategoryCard(
                              // TODO color doesnt cycle in mobile, only shows orange and yellow columns
                              categoryName:
                                  subcategory['subcategoryName'] as String? ??
                                      subcategory['name'] as String,
                              color: color,
                              coverImageUrl:
                                  subcategory['coverImageUrl'] as String?,
                              onTap: () =>
                                  _navigateToProductsPage(context, subcategory),
                            );
                          },
                          childCount: _subcategories.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Footer()),
                  ],
                );
              },
            ),
    );
  }

  void _navigateToProductsPage(
      BuildContext context, Map<String, dynamic> subcategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductsPage(
          categoryCode: subcategory['code'] as String,
          categoryName: subcategory['name'] as String,
          defaultPrice: subcategory['defaultPrice'] as num?,
          primaryCategory: subcategory['primaryCategory'] as String,
        ),
      ),
    );
  }
}

// ============================================================================
// PRODUCTS PAGE - Product grid view for selected subcategory
// ============================================================================

class ProductsPage extends StatefulWidget {
  final String categoryCode;
  final String categoryName;
  final num? defaultPrice;
  final String primaryCategory;

  const ProductsPage({
    super.key,
    required this.categoryCode,
    required this.categoryName,
    required this.defaultPrice,
    required this.primaryCategory,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreProducts();
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _products = [];
        _lastDocument = null;
        _hasMore = true;
        _isLoading = true;
      });
    }

    try {
      var query = _firestore
          .collection('products')
          .where('categoryCode', isEqualTo: widget.categoryCode)
          .where('isActive', isEqualTo: true)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        final images = data['images'] as List<dynamic>?;
        final primaryImage = images?.isNotEmpty == true
            ? images![0] as String?
            : data['primaryImageUrl'] as String?;

        return {
          'barcode': data['barcode'],
          'name': data['name'],
          'imageUrl': primaryImage,
          'priceOverride': data['priceOverride'],
          'displayOrder': data['displayOrder'] ?? 999,
          'warehouseCode': data['warehouseCode'],
        };
      }).toList();

      products.sort((a, b) =>
          (a['displayOrder'] as int).compareTo(b['displayOrder'] as int));

      setState(() {
        _products = products;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_lastDocument == null || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await _firestore
          .collection('products')
          .where('categoryCode', isEqualTo: widget.categoryCode)
          .where('isActive', isEqualTo: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final newProducts = snapshot.docs.map((doc) {
        final data = doc.data();
        final images = data['images'] as List<dynamic>?;
        final primaryImage = images?.isNotEmpty == true
            ? images![0] as String?
            : data['primaryImageUrl'] as String?;

        return {
          'barcode': data['barcode'],
          'name': data['name'],
          'imageUrl': primaryImage,
          'priceOverride': data['priceOverride'],
          'displayOrder': data['displayOrder'] ?? 999,
          'warehouseCode': data['warehouseCode'],
        };
      }).toList();

      setState(() {
        _products.addAll(newProducts);
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more products: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final crossAxisCount = isMobile ? 2 : 4;
    final isCuadros =
        widget.primaryCategory.toLowerCase().contains('cuadros') ||
            widget.primaryCategory.toLowerCase().contains('latón');
    final showBulkPricing =
        widget.categoryCode == 'LAT-2030' || widget.categoryCode == 'LAT-1530';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        title: Text(
          widget.categoryName.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isMobile ? 18 : 30,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          CartIconButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bulk pricing banner
                if (showBulkPricing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.yellow.withOpacity(0.2),
                          AppColors.orange.withOpacity(0.1),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.yellow.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: AppColors.orange,
                          size: isMobile ? 18 : 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Precios especiales: 1 cuadro Q35 • 2+ cuadros Q30 c/u • 5+ cuadros Q25 c/u',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Products grid with pull-to-refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _fetchProducts(refresh: true),
                    color: AppColors.blue,
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _products.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final product = _products[index];
                        final price = (product['priceOverride'] as num?) ??
                            widget.defaultPrice;

                        return _ProductThumbnail(
                          barcode: product['barcode'] as String,
                          imageUrl: product['imageUrl'] as String?,
                          name: isCuadros ? null : product['name'] as String?,
                          price: price,
                          categoryCode: widget.categoryCode,
                          subcategory: widget.categoryName,
                          primaryCategory: widget.primaryCategory,
                          warehouseCode: product['warehouseCode'] as String?,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageFullScreenPage(
                                imageUrl: product['imageUrl'] as String? ?? '',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// SEARCH PAGE - Global product search
// ============================================================================

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Search in products collection
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      final queryLower = query.toLowerCase();

      // Filter results locally for better search across multiple fields
      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] as String?)?.toLowerCase() ?? '';
        final barcode = (data['barcode'] as String?)?.toLowerCase() ?? '';
        final categoryCode =
            (data['categoryCode'] as String?)?.toLowerCase() ?? '';
        final warehouseCode =
            (data['warehouseCode'] as String?)?.toLowerCase() ?? '';
        final temas = (data['temas'] as List<dynamic>?)
                ?.map((t) => t.toString().toLowerCase())
                .toList() ??
            [];
        final primaryCategory =
            (data['primaryCategory'] as String?)?.toLowerCase() ?? '';
        final subcategory =
            (data['subcategory'] as String?)?.toLowerCase() ?? '';

        return name.contains(queryLower) ||
            barcode.contains(queryLower) ||
            categoryCode.contains(queryLower) ||
            warehouseCode.contains(queryLower) ||
            primaryCategory.contains(queryLower) ||
            subcategory.contains(queryLower) ||
            temas.any((tema) => tema.contains(queryLower));
      }).map((doc) {
        final data = doc.data();
        final images = data['images'] as List<dynamic>?;
        final primaryImage = images?.isNotEmpty == true
            ? images![0] as String?
            : data['primaryImageUrl'] as String?;

        return {
          'barcode': data['barcode'],
          'name': data['name'],
          'imageUrl': primaryImage,
          'priceOverride': data['priceOverride'],
          'categoryCode': data['categoryCode'],
          'subcategory': data['subcategory'],
          'primaryCategory': data['primaryCategory'],
          'warehouseCode': data['warehouseCode'],
          'defaultPrice': data['defaultPrice'],
        };
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching products: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobile;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Buscar productos...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {});
            _performSearch(value);
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          CartIconButton(),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Buscar por nombre, código, tema...',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron resultados',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        final price = (product['priceOverride'] as num?) ??
                            (product['defaultPrice'] as num?);

                        return _ProductThumbnail(
                          barcode: product['barcode'] as String,
                          imageUrl: product['imageUrl'] as String?,
                          name: product['name'] as String?,
                          price: price,
                          categoryCode: product['categoryCode'] as String,
                          subcategory: product['subcategory'] as String,
                          primaryCategory: product['primaryCategory'] as String,
                          warehouseCode: product['warehouseCode'] as String?,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageFullScreenPage(
                                imageUrl: product['imageUrl'] as String? ?? '',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ProductThumbnail extends StatefulWidget {
  final String barcode;
  final String? imageUrl;
  final String? name;
  final num? price;
  final String categoryCode;
  final String subcategory;
  final String primaryCategory;
  final String? warehouseCode;
  final VoidCallback onTap;

  const _ProductThumbnail({
    required this.barcode,
    required this.imageUrl,
    this.name,
    this.price,
    required this.categoryCode,
    required this.subcategory,
    required this.primaryCategory,
    this.warehouseCode,
    required this.onTap,
  });

  @override
  State<_ProductThumbnail> createState() => _ProductThumbnailState();
}

class _ProductThumbnailState extends State<_ProductThumbnail> {
  final _cartService = CartService.instance;

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addToCart() async {
    final item = CartItem(
      barcode: widget.barcode,
      name: widget.name ?? 'Sin nombre',
      categoryCode: widget.categoryCode,
      subcategory: widget.subcategory,
      primaryCategory: widget.primaryCategory,
      price: (widget.price ?? 0).toDouble(),
      imageUrl: widget.imageUrl ?? '',
      warehouseCode: widget.warehouseCode,
      quantity: 1,
    );
    await _cartService.addItem(item);
  }

  @override
  Widget build(BuildContext context) {
    final isInCart = _cartService.isInCart(widget.barcode);
    final quantity = _cartService.getQuantity(widget.barcode);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onTap,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: widget.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error, color: Colors.red),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          if (widget.name != null || widget.price != null)
            Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.name != null)
                    Text(
                      widget.name!,
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (widget.price != null)
                    Text(
                      'Q${widget.price!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orange,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Cart button or quantity controls
                  if (!isInCart)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 2,
                          shadowColor: AppColors.blue.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Añadir',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () =>
                                _cartService.removeItem(widget.barcode),
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () => quantity == 1
                                    ? _cartService.removeItem(widget.barcode)
                                    : _cartService.updateQuantity(
                                        widget.barcode, quantity - 1),
                                icon: Icon(
                                    quantity == 1
                                        ? Icons.delete_outline
                                        : Icons.remove,
                                    size: 16,
                                    color: AppColors.blue),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () => _cartService.updateQuantity(
                                    widget.barcode, quantity + 1),
                                icon: const Icon(Icons.add,
                                    size: 16, color: AppColors.blue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// IMAGE FULLSCREEN - Full-screen product image viewer with zoom toggle
// ============================================================================

/// Full-screen view of a product image
/// Tap to toggle between contain and cover fit modes
class ImageFullScreenPage extends StatefulWidget {
  final String imageUrl;

  const ImageFullScreenPage({super.key, required this.imageUrl});

  @override
  State<ImageFullScreenPage> createState() => _ImageFullScreenPageState();
}

class _ImageFullScreenPageState extends State<ImageFullScreenPage> {
  bool _isZoomedOut = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          CartIconButton(),
        ],
      ),
      body: GestureDetector(
        onTap: () => setState(() => _isZoomedOut = !_isZoomedOut),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: _isZoomedOut ? BoxFit.contain : BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.error,
                color: Colors.red,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CATEGORY CARD - Display card for each product category
// ============================================================================

class CategoryCard extends StatelessWidget {
  final String categoryName;
  final Color color;
  final VoidCallback onTap;
  final String? coverImageUrl;

  const CategoryCard({
    super.key,
    required this.categoryName,
    required this.color,
    required this.onTap,
    this.coverImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final iconSize = isMobile ? 60.0 : 80.0;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image or placeholder icon
            Expanded(
              flex: 3,
              child: coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: color,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholderIcon(color, iconSize),
                    )
                  : _buildPlaceholderIcon(color, iconSize),
            ),
            // Category name
            Container(
              padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
              child: Text(
                categoryName.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: isMobile ? 14 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(Color backgroundColor, double size) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Icon(Icons.image, size: size, color: Colors.white),
      ),
    );
  }
}

// ============================================================================
// FOOTER
// ============================================================================

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkGray,
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 40.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < Breakpoints.mobile;
          final titleSize = isNarrow ? 16.0 : 18.0;
          final textSize = isNarrow ? 12.0 : 14.0;

          final content = _buildFooterContent(titleSize, textSize);

          return isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content.$1,
                    const SizedBox(height: 32),
                    content.$2,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content.$1,
                    const SizedBox(width: 120),
                    content.$2,
                  ],
                );
        },
      ),
    );
  }

  /// Returns (contactInfo, addressInfo)
  (Widget, Widget) _buildFooterContent(double titleSize, double textSize) {
    final contactInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contáctanos',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: titleSize,
          ),
        ),
        const SizedBox(height: 8),
        LinkText(
            text: '@xepi_gt',
            url: 'https://www.instagram.com/xepi_gt/',
            textSize: textSize,
            icon: FontAwesomeIcons.instagram),
        LinkText(
            text: 'Xepi',
            url: 'https://www.facebook.com/XEPI-170757886730372/',
            textSize: textSize,
            icon: FontAwesomeIcons.facebook),
        LinkText(
            text: '5885-8000',
            url: 'https://wa.me/50258858000',
            textSize: textSize,
            icon: FontAwesomeIcons.whatsapp),
        LinkText(
            text: '5885-8000',
            url: 'tel:58858000',
            textSize: textSize,
            icon: FontAwesomeIcons.phone),
        LinkText(
            text: 'dicosa.kiosko@gmail.com',
            url: 'mailto:dicosa.kiosko@gmail.com',
            textSize: textSize,
            icon: FontAwesomeIcons.envelope),
      ],
    );

    final addressInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dirección',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: titleSize)),
        const SizedBox(height: 8),
        LinkText(
            text: 'C Comercial Century Plaza,',
            url:
                'https://www.google.com/maps/place/Xepi/@14.5901288,-90.5208995,15z/data=!4m5!3m4!1s0x0:0x348f8b022618f5b8!8m2!3d14.5901288!4d-90.5208995',
            textSize: textSize,
            icon: FontAwesomeIcons.locationDot),
        Text('Kiosco 3, (frente a las gradas del primer nivel)',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontSize: textSize)),
        Text('15 Avenida 6-01 Zona 13, ciudad capital',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontSize: textSize)),
        Text('(a media cuadra de Las Américas, vecindad helados Sarita).',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontSize: textSize)),
        const SizedBox(height: 8),
        Text('Horario',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: titleSize)),
        const SizedBox(height: 8),
        Text('Lunes a Domingo',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontSize: textSize)),
        Text('De 9:00 a 17:00',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontSize: textSize)),
      ],
    );

    return (contactInfo, addressInfo);
  }
}

// ============================================================================
// LINK TEXT - Animated hover link widget for footer
// ============================================================================

/// Interactive link widget with hover animation and color change
class LinkText extends StatefulWidget {
  final String text;
  final String url;
  final double textSize;
  final IconData? icon;

  const LinkText({
    super.key,
    required this.text,
    required this.url,
    required this.textSize,
    this.icon,
  });

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.05, 0), // Slight horizontal slide on hover
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverEnter(_) {
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _onHoverExit(_) {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final hoverColor = _isHovered ? AppColors.yellow : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.url)),
          child: SlideTransition(
            position: _slideAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: hoverColor,
                    size: widget.textSize + 4,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: hoverColor,
                      fontFamily: 'Quicksand',
                      fontSize: widget.textSize,
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
}

// ============================================================================
// CART PAGE - Shopping cart display and checkout
// ============================================================================

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _cartService = CartService.instance;

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {});
  }

  Future<void> _sendToWhatsApp() async {
    if (_cartService.items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío')),
      );
      return;
    }

    // Group items by subcategory
    final groupedItems = <String, List<CartItem>>{};
    for (final item in _cartService.items) {
      groupedItems.putIfAbsent(item.subcategory, () => []).add(item);
    }

    // Build WhatsApp message with bulk pricing
    String message = 'Hola, quisiera realizar un pedido:\n\n';
    double total = 0;

    for (final entry in groupedItems.entries) {
      final subcategory = entry.key;
      final items = entry.value;

      message += '*$subcategory*\n';

      for (final item in items) {
        // Get bulk price if applicable
        final effectivePrice = _cartService.getEffectivePrice(item);
        final itemTotal = effectivePrice * item.quantity;
        total += itemTotal;

        // Use warehouse code if available, otherwise show product name
        final displayText =
            item.warehouseCode != null && item.warehouseCode!.isNotEmpty
                ? 'Código: ${item.warehouseCode}'
                : item.name;

        message +=
            '  • $displayText - ${item.quantity} x Q${effectivePrice.toStringAsFixed(2)} = Q${itemTotal.toStringAsFixed(2)}\n';
      }
      message += '\n';
    }

    message += '*Total: Q${total.toStringAsFixed(2)}*';

    // Launch WhatsApp
    final phoneNumber = '50258858000';
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = 'https://wa.me/$phoneNumber?text=$encodedMessage';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Carrito'),
        content: const Text('¿Estás seguro de que quieres vaciar el carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, vaciar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cartService.clearCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final items = _cartService.items;
    final total = _cartService.calculateTotal(); // Use bulk pricing calculation

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'MI CARRITO',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isMobile ? 18 : 30,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: AppColors.blue.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tu carrito está vacío',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Añade productos para empezar',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final effectivePrice =
                          _cartService.getEffectivePrice(item);
                      final hasDiscount = effectivePrice < item.price;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Product details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.subcategory,
                                          style: const TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.warehouseCode != null &&
                                                  item.warehouseCode!.isNotEmpty
                                              ? 'Código: ${item.warehouseCode}'
                                              : item.name,
                                          style: TextStyle(
                                            fontFamily: 'Quicksand',
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (hasDiscount) ...[
                                              Text(
                                                'Q${item.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontFamily: 'Quicksand',
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Flexible(
                                              child: Text(
                                                'Q${effectivePrice.toStringAsFixed(2)} c/u',
                                                style: const TextStyle(
                                                  fontFamily: 'Quicksand',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.orange,
                                                ),
                                              ),
                                            ),
                                            if (hasDiscount)
                                              Flexible(
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.yellow,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: const [
                                                      Icon(
                                                        Icons.local_offer,
                                                        size: 12,
                                                        color:
                                                            AppColors.darkGray,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Descuento',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'Quicksand',
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .darkGray,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _cartService.removeItem(item.barcode),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Quantity controls
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => item.quantity == 1
                                              ? _cartService
                                                  .removeItem(item.barcode)
                                              : _cartService.updateQuantity(
                                                  item.barcode,
                                                  item.quantity - 1),
                                          icon: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppColors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              item.quantity == 1
                                                  ? Icons.delete_outline
                                                  : Icons.remove,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          constraints: const BoxConstraints(
                                              minWidth: 40),
                                          child: Text(
                                            '${item.quantity}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.blue,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _cartService.updateQuantity(
                                                  item.barcode,
                                                  item.quantity + 1),
                                          icon: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppColors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.add,
                                                size: 18, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Q${(effectivePrice * item.quantity).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer with total and buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Q${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearCart,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                    color: Colors.red[400]!, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.delete_sweep_outlined,
                                color: Colors.red[400],
                                size: 20,
                              ),
                              label: Text(
                                'Vaciar',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[400],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _sendToWhatsApp,
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: const Text(
                                'Enviar a WhatsApp',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 3,
                                shadowColor:
                                    const Color(0xFF25D366).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// CART ICON BUTTON - Reusable cart button with badge for AppBar
// ============================================================================

class CartIconButton extends StatefulWidget {
  const CartIconButton({super.key});

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  final _cartService = CartService.instance;

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _cartService.itemCount;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          },
        ),
        if (itemCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.yellow, AppColors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                itemCount > 99 ? '99+' : '$itemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
