# Xepi Product Catalog - AI Coding Agent Instructions

## Project Overview
Flutter web app for **Xepi** (Guatemala retail store) displaying products organized by categories. Web-only deployment via Firebase Hosting—no mobile platforms configured.

**Tech Stack:**
- **Client:** Flutter web (single-file monolith in `lib/main.dart`)
- **Backend:** Firebase Firestore + Firebase Storage
- **Admin:** Separate Flutter app in `admin/` (different project, code here for reference)
- **Deployment:** Firebase Hosting at `https://xepi-f5c22.web.app`

## Architecture: Firestore Database

### Current State: Nested Subcollections Structure

#### Primary Categories Collection (Top-level)
Document ID: Spanish primary category name (e.g., "Cuadros de latón", "Juguetes")
```javascript
categories/{primaryCategoryName}/
  ├── name: "Cuadros de latón"              // Display name
  ├── primaryCode: "LAT"                    // Prefix code
  ├── coverImageUrl: "url"                  // Primary category cover image
  ├── isActive: true                        // Show on website
  ├── displayOrder: 1                       // Sort order
  └── subcategories/                        // Nested subcollection
      └── {categoryCode}/
          ├── code: "LAT-2030"              // Subcategory code
          ├── name: "Cuadros de latón 20 x 30 cms"
          ├── subcategoryName: "20 x 30 cms"
          ├── defaultPrice: 35              // Default price
          ├── coverImageUrl: "url"          // Falls back to primary if null
          ├── isActive: true
          └── displayOrder: 1
```

#### Products Collection
Document ID: barcode (13-digit string)
```javascript
products/{barcode}/
  ├── barcode: "1203023000562"
  ├── name: "Coca Cola Vintage"           // Product name
  ├── categoryCode: "LAT-2030"            // Links to categories
  ├── primaryCategory: "Cuadros de latón" // For filtering
  ├── subcategory: "20 x 30 cms"
  ├── images: ["url1", "url2"]            // Multiple images
  ├── primaryImageUrl: "url1"             // First/main image
  ├── priceOverride: null                 // Override category price
  ├── stockWarehouse: 0                   // Future inventory
  ├── stockStore: 0
  ├── isActive: true                      // Show on website
  ├── displayOrder: 1                     // Sort order within category
  ├── size: "20x30"                       // Optional attributes
  ├── color: null
  ├── warehouseCode: "COD-1"              // Xepi warehouse label (used in WhatsApp messages)
  └── temas: ["Coca Cola"]
``` 

## Critical Development Workflows

### Running & Building
```bash
# Development (web only)
flutter run -d chrome

# Production build
flutter build web --release

# Deploy (requires Firebase CLI)
firebase deploy
```

**Platform Note:** iOS/Android throw `UnsupportedError` in `lib/firebase_options.dart`. To add mobile support, run `flutterfire configure`.

### Admin Dashboard Workflow
1. **Location:** `admin/admin_dashboard_with_barcodes.dart` (standalone app)
2. **Authentication:** Requires Firebase Auth (UIDs hardcoded in `database.rules.json`)
3. **Key Features:**
   - Upload product images to Firebase Storage
   - Assign barcodes to images (creates `products/{barcode}` entries)
   - Drag-and-drop reorder (updates `images/{category}/products` indexes)
   - Set category cover images


### Category Management
**Adding New Categories:**
1. Upload images via admin dashboard (creates `images/{newCategory}` automatically)
2. Update `data/categories.json` with category codes/subcategories
3. Client app dynamically generates category cards—no code changes needed

**Category Card Color Pattern:**
```dart
// Diagonal color cycling (lib/main.dart:200-210)
final colors = [Color(0xFFdb6a19), Color(0xFFfec800), Color(0xFF00acc0)];
final colorIndex = (index + (index ~/ crossAxisCount)) % colors.length;
```

### Deprecated: GitHub Image Workflow
**Location:** `archive/imagegenerator.js`
```javascript
// OLD METHOD: Fetch images from GitHub repo, generate images.json
// This script is DEPRECATED but kept for reference
// DON'T USE: Images now managed via Firebase Storage
```

## Project-Specific Patterns

### 1. Client App Navigation (`lib/main.dart` ~2400 lines)
```dart
MyApp (MaterialApp)
└── CategoryGallery (StatefulWidget) — Home page
    ├── SearchPage (StatefulWidget) — Global product search
    ├── SubcategoriesPage (StatefulWidget) — Subcategory selection
    │   └── ProductsPage (StatefulWidget) — Product grid with prices & pagination
    │       └── ImageFullScreenPage (StatefulWidget) — Fullscreen zoom
    └── CartPage (StatefulWidget) — Shopping cart with WhatsApp checkout
```

**Navigation Flow:**
1. **Home** → Displays primary categories from top-level `categories/` collection (8 documents)
   - Search icon in AppBar navigates to SearchPage
   - Cart icon shows item count badge
2. **Search** → Global search across all products
   - Real-time search by name, barcode, category code, warehouse code, tema, primary category, subcategory
   - Client-side filtering for comprehensive multi-field matching
   - Results displayed in product grid with cart integration
3. **Subcategories** → Shows subcategories from nested `categories/{primary}/subcategories/` (24 documents across 8 primaries)
4. **Products** → Paginated grid of products with images + prices (flat `products/` collection)
   - Pagination: 20 items per page with infinite scroll
   - Pull-to-refresh to reload products
   - Bulk pricing banner for LAT-2030 and LAT-1530 categories
   - Blue "Añadir" button adds to cart
   - Quantity controls with blue circular buttons (+/-)
   - Trash icon (blue) appears when quantity=1 instead of minus button
   - Square aspect ratio (1.0) for all product images
   - Image caching with cached_network_image package
5. **Cart** → View cart, adjust quantities, send to WhatsApp
   - Shows warehouse code or product name
   - Orange prices with strikethrough for discounts
   - Yellow discount badge when bulk pricing applies
   - Blue quantity controls with trash icon when quantity=1
   - WhatsApp integration sends formatted message to +50258858000
6. **Fullscreen** → Tap-to-zoom image view with cached images

**Shopping Cart Features:**
- **localStorage Persistence:** Cart survives page reloads using `shared_preferences`
- **Cart Icon:** Shows in all AppBars with item count badge
- **Bulk Pricing:** Automatic discounts for LAT-2030 and LAT-1530 (combined across both categories)
  - 1 unit: Q35
  - 2+ units: Q30 each
  - 5+ units: Q25 each
  - Discount badge shows on cart items and total when applicable
- **WhatsApp Integration:** Sends formatted order to +50258858000
  - Groups by subcategory
  - Shows warehouse code (from `warehouseCode` field) when available
  - Falls back to product name if no warehouse code
  - Includes quantities and totals with bulk pricing applied
- **Design System:**
  - Blue (#00acc0): Action buttons, quantity controls
  - Orange (#db6a19): Prices and totals
  - Yellow (#fec800): Discount badges and highlights
  - Dark gray (#2B2B2B): Text and backgrounds

**Data Fetching (Nested Structure):**
```dart
// Home: Fetch primary categories from top-level documents
_firestore.collection('categories').get()
// Map documents where doc.id = primary category name

// Subcategories: Query nested subcollection
_firestore.collection('categories')
  .doc(primaryCategoryId)
  .collection('subcategories')
  .get()

// Products: Filter by categoryCode (unchanged)
_firestore.collection('products')
  .where('categoryCode', isEqualTo: selectedCode)
  .where('isActive', isEqualTo: true)
```

**Image Fallback Pattern:**
```dart
// Subcategories: Use primary cover if subcategory has none
subcategory.coverImageUrl ?? primary.coverImageUrl

// Products: Support both new and legacy patterns
images?.isNotEmpty == true ? images![0] : primaryImageUrl
```
**Product Display:**
- **Cuadros de latón:** Show price only (no product name)
- **Other categories:** Show product name + price
- **All products:** Square aspect ratio (1.0) for images
- **Performance:** Images cached with `cached_network_image` package
- **Pagination:** 20 items per page with infinite scroll on ProductsPage
- **Pull-to-refresh:** RefreshIndicator on ProductsPage to manually reload data
finalPrice = product.priceOverride ?? category.defaultPrice
```

**Product Display:**
- **Cuadros de latón:** Show price only (no product name)
- **Other categories:** Show product name + price

### 2. Responsive Grid Breakpoints
```dart
// lib/main.dart:150-165
if (constraints.maxWidth > 1200) {
  crossAxisCount = 3; 
  horizontalPadding = (constraints.maxWidth - 1000) / 2; // Center content
} else if (constraints.maxWidth > 600) {
  crossAxisCount = 3; horizontalPadding = 40.0;
} else {
  crossAxisCount = 2; horizontalPadding = 20.0; // Mobile
}
```

### 3. Firebase Security Rules
**Firestore Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Categories: Public read, admin write
    match /categories/{categoryId} {
      allow read: if true;
      allow write: if request.auth != null;
      
      // Subcategories: Nested subcollection
      match /subcategories/{subcategoryId} {
        allow read: if true;
        allow write: if request.auth != null;
      }
    }
    
    // Products: Public read, admin write  
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
### 4. Typography & Assets
- **Fonts:** `Montserrat-Bold.ttf` (headers), `Quicksand-Regular.ttf` (body)
- **Logo:** `assets/images/logoxepi.jpg` (must match exact path in `pubspec.yaml`)
- **Font Declaration:** All assets declared in `pubspec.yaml` flutter section

### 5. Key Dependencies
- **Firebase:** `firebase_core: ^4.2.1`, `cloud_firestore: ^6.1.0`
- **Storage:** `shared_preferences: ^2.3.3` (cart persistence)
- **Images:** `cached_network_image: ^3.4.1` (performance optimization)
- **URL Launcher:** `url_launcher: ^6.3.0` (WhatsApp integration)
- **Icons:** `font_awesome_flutter: ^10.8.0`
### 4. Typography & Assets
- **Fonts:** `Montserrat-Bold.ttf` (headers), `Quicksand-Regular.ttf` (body)
- **Logo:** `assets/images/logoxepi.jpg` (must match exact path in `pubspec.yaml`)
- **Font Declaration:** All assets declared in `pubspec.yaml` flutter section

## Common Pitfalls

### 1. Category Cover Images
If a category's `coverImageUrl` is null, the app will use a placeholder icon. Ensure all categories have cover images set in Firestore for the best user experience.

### 2. Price Display Logic
Products inherit their category's `defaultPrice` unless they have a `priceOverride`. Make sure at least one of these values is set to avoid displaying "null" prices.

### 3. Stock Filtering
## Key File Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entire client UI (~2400 lines with cart, search, pagination) |
| `lib/firebase_options.dart` | Firebase configuration (web only) |
| `admin/` | Admin dashboard code (separate project, for reference) |
| `data/categories.json` | Category codes reference (legacy) |
| `firebase.json` | Hosting config for web deployment |
| `firestore.rules` | Firestore security rules (public read, auth write) |
| `firestore.indexes.json` | Firestore composite indexes |
| `.gitignore` | Excludes build/, .firebase/, archives, admin/ |
firebase deploy
```

## Key File Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entire client UI (~800 lines) |
| `admin/` | Admin dashboard code (separate project) |
| `data/categories.json` | Category codes reference |
| `firebase.json` | Hosting config for web deployment |
