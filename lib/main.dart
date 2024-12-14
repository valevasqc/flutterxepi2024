import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';

// nvm use --lts

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with default options.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

class CategoryGallery extends StatefulWidget {
  const CategoryGallery({super.key});

  @override
  State<CategoryGallery> createState() => _CategoryGalleryState();
}

class _CategoryGalleryState extends State<CategoryGallery> {
  final databaseRef = FirebaseDatabase.instance.ref('images'); // Reference to "images" node in Firebase.
  Map<String, Map<dynamic, dynamic>> categories = {}; // To store category data.

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  // Fetch categories and their image URLs from Firebase Realtime Database
  void fetchCategories() async {
    try {
      final snapshot = await databaseRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, Map<String, dynamic>> parsedCategories = {};

        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            // Filter out null values here
            final filteredValues = Map<String, dynamic>.fromEntries(
                value
                    .cast<String, dynamic>()
                    .entries // Convert to iterable of key-value pairs
                    // .where((entry) => entry.value != null) // Filter out null values

            );

            // data.remove((key, value) => value == null);

            print(data);
            // print('Parsing category: $key');

            // Only add the category if there are valid entries
            if (filteredValues.isNotEmpty) {
              parsedCategories[key] = filteredValues;
            }
          }
          // print('Fetched data: $data');
          // print('Parsing category: $key');
        });

        setState(() {
          categories = parsedCategories;
        });
      } else {
        print('No data available');
        setState(() {
          categories = {};
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff2b2b2b),
        centerTitle: true,
        title: InkWell(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logoxepi.jpg', height: 50, width: 50),
              const SizedBox(width: 7.0),
              const Text(
                'Catálogo',
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 30, color: Colors.white),
              ),
            ],
          ),
          onTap: () {},
        ),
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator()) // Show loading spinner while fetching.
          : ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final categoryName = categories.keys.elementAt(index);
          return ListTile(
            title: Text(categoryName.toUpperCase()),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              // Navigate to the category-specific page
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CategoryPage(
                    categoryName: categoryName,
                    imageUrls: categories[categoryName]!.values.cast<String>().toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CategoryPage extends StatelessWidget {
  final String categoryName;
  final List<String> imageUrls;

  const CategoryPage({
    super.key,
    required this.categoryName,
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 2; // Adjust based on screen size.

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff2b2b2b),
        title: Text(
          categoryName.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 30,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return _ImageThumbnail(
            imageUrl: imageUrls[index],
            onTap: () {
              // Navigate to the full image screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageFullScreenPage(imageUrl: imageUrls[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const _ImageThumbnail({required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.error, color: Colors.red);
        },
      ),
    );
  }
}

class ImageFullScreenPage extends StatefulWidget {
  final String imageUrl;

  const ImageFullScreenPage({super.key, required this.imageUrl});

  @override
  State<ImageFullScreenPage> createState() => _ImageFullScreenPageState();
}

class _ImageFullScreenPageState extends State<ImageFullScreenPage> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.close, color: Colors.white), // Close icon (X)
        //     onPressed: () {
        //       Navigator.pop(context); // Close the full-screen view
        //     },
        //   ),
        // ],
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Image.network(
              widget.imageUrl,
              fit: _isExpanded ? BoxFit.contain : BoxFit.cover, // Expanded or normal
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, color: Colors.red);
              },
            ),
          ),
        ),
      ),
    );
  }
}
