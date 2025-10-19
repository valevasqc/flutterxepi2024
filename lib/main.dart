import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final databaseRef = FirebaseDatabase.instance
      .ref('images'); // Reference to "images" node in Firebase.
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
            final filteredValues = Map<String, dynamic>.fromEntries(value
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
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 30,
                    color: Colors.white),
              ),
            ],
          ),
          onTap: () {},
        ),
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                double horizontalPadding;

                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 3;
                  horizontalPadding = (constraints.maxWidth - 1000) / 2;
                } else if (constraints.maxWidth > 600) {
                  crossAxisCount = 3;
                  horizontalPadding = 40.0;
                } else {
                  crossAxisCount = 2;
                  horizontalPadding = 20.0;
                }

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding, vertical: 20.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final categoryName =
                                categories.keys.elementAt(index);
                            final colors = [
                              const Color(0xFFdb6a19), // Orange
                              const Color(0xFFfec800), // Yellow
                              const Color(0xFF00acc0), // Blue
                            ];
                            final colorIndex;
                            if (crossAxisCount == 2) {
                              colorIndex = index % colors.length;
                            } else {
                              colorIndex = (index + (index ~/ crossAxisCount)) %
                                  colors.length;
                            }
                            final color = colors[colorIndex];

                            return CategoryCard(
                              categoryName: categoryName,
                              color: color,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CategoryPage(
                                      categoryName: categoryName,
                                      imageUrls: categories[categoryName]!
                                          .values
                                          .cast<String>()
                                          .toList(),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: categories.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: const Footer(),
                    ),
                  ],
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
    final crossAxisCount =
        screenWidth > 600 ? 4 : 2; // Adjust based on screen size.

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
                  builder: (context) =>
                      ImageFullScreenPage(imageUrl: imageUrls[index]),
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
              fit: _isExpanded
                  ? BoxFit.contain
                  : BoxFit.cover, // Expanded or normal
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

class CategoryCard extends StatelessWidget {
  final String categoryName;
  final Color color;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.categoryName,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(
              Icons.image,
              size: 80,
              color: Colors.white,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                categoryName.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff2b2b2b),
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isNarrow = constraints.maxWidth < 600;
          double titleSize = isNarrow ? 16 : 18;
          double textSize = isNarrow ? 12 : 14;

          return isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: footerContent(titleSize, textSize, isNarrow),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: footerContent(titleSize, textSize, isNarrow),
                );
        },
      ),
    );
  }

  List<Widget> footerContent(double titleSize, double textSize, bool isNarrow) {
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
            text: 'Instagram: @xepi_gt',
            url: 'https://www.instagram.com/xepi_gt/',
            textSize: textSize),
        LinkText(
            text: 'Facebook: Xepi',
            url: 'https://www.facebook.com/XEPI-170757886730372/',
            textSize: textSize),
        LinkText(
            text: 'WhatsApp: 5885-8000',
            url: 'https://wa.me/50258858000',
            textSize: textSize),
        LinkText(
            text: 'Teléfono: 5885-8000',
            url: 'tel:58858000',
            textSize: textSize),
        LinkText(
            text: 'Correo electrónico: dicosa.kiosko@gmail.com',
            url: 'mailto:dicosa.kiosko@gmail.com',
            textSize: textSize),
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
            textSize: textSize),
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

    if (isNarrow) {
      return [
        contactInfo,
        const SizedBox(height: 32),
        addressInfo,
      ];
    } else {
      return [
        Flexible(child: contactInfo),
        Flexible(child: addressInfo),
      ];
    }
  }
}

class LinkText extends StatefulWidget {
  final String text;
  final String url;
  final double textSize;

  const LinkText({
    super.key,
    required this.text,
    required this.url,
    required this.textSize,
  });

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url)),
        child: Text(
          widget.text,
          style: TextStyle(
            color: _isHovered ? const Color(0xFFfec800) : Colors.white,
            fontFamily: 'Quicksand',
            fontSize: widget.textSize,
          ),
        ),
      ),
    );
  }
}
