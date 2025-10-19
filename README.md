
# Xepi Product Catalog

Xepi Product Catalog is a web application for browsing and managing the product catalog of Xepi, a Guatemala-based retail store. The app is built with Flutter and deployed to the web using Firebase Hosting. Product images and data are managed via Firebase Storage and Realtime Database.

## Features

- Responsive product gallery organized by category
- Dynamic category and product loading from Firebase
- High-resolution product images served from Firebase Storage
- Custom brand typography and color scheme
- Contact and business information in the footer
- Optimized for desktop and mobile browsers

## Architecture

- **Flutter Web**: All UI code is in `lib/main.dart` using Material 3 and custom fonts.
- **Firebase Realtime Database**: Stores product metadata and image URLs, organized by category.
- **Firebase Storage**: Hosts all product images.
- **Firebase Hosting**: Serves the built web app.
- **Assets**: Custom fonts and logo in `assets/`.
- **Deprecated**: Old GitHub image logic is archived in `/archive/`.

## Project Structure

- `lib/main.dart` — Main application code
- `lib/firebase_options.dart` — Firebase configuration (auto-generated)
- `assets/` — Fonts and images
- `archive/` — Deprecated scripts and legacy data
- `build/` — Build output (not tracked)
- `.github/` — AI agent and workflow instructions

## Setup & Development

1. **Install Flutter** (see [Flutter docs](https://docs.flutter.dev/get-started/install))
2. **Clone this repository**
3. **Install dependencies:**
	```sh
	flutter pub get
	```
4. **Run locally (web):**
	```sh
	flutter run -d chrome
	```
5. **Build for production:**
	```sh
	flutter build web
	```

## Firebase Integration

- Ensure you have access to the Firebase project and the correct `firebase_options.dart`.
- Product images are uploaded to Firebase Storage.
- Product metadata and image URLs are managed in Firebase Realtime Database under `images/{category}/{image_id}: url`.
- Update security rules for local development if needed.

## Deployment

1. **Build the web app:**
	```sh
	flutter build web --release
	```
2. **Deploy to Firebase Hosting:**
	```sh
	firebase deploy
	```
3. **Production site:**
	https://xepi-f5c22.web.app

## Maintenance & Updates

- To update the product catalog:
  1. Upload new images to Firebase Storage.
  2. Update image URLs and metadata in Firebase Realtime Database.
  3. The app will reflect changes on the next data fetch.
- For new categories, update the database structure; the app UI is dynamic.
- Deprecated GitHub image logic is retained in `/archive/` for reference.

## License

This project is for internal use by Xepi. Contact the repository owner for more information.
