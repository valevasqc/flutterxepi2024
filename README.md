
# Xepi Product Catalog

Xepi Product Catalog is a web application for browsing the product catalog of Xepi, a Guatemala-based retail store. The app is built with Flutter and deployed to the web using Firebase Hosting. Catalog data lives in Cloud Firestore (managed by the separate admin system); product images are served from Firebase Storage.

> Start here for project context: [XEPI_CLIENT_MASTER_DOCUMENTATION.md](XEPI_CLIENT_MASTER_DOCUMENTATION.md) · [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) · [docs/ROADMAP.md](docs/ROADMAP.md)

## Features

- Responsive product gallery organized by category
- Dynamic category and product loading from Firebase
- High-resolution product images served from Firebase Storage
- Custom brand typography and color scheme
- Contact and business information in the footer
- Optimized for desktop and mobile browsers

## Architecture

- **Flutter Web**: All UI code is in `lib/main.dart` using Material 3 and custom fonts.
- **Cloud Firestore**: Stores categories, subcategories, and products (source of truth is the admin app).
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
- Product images are uploaded to Firebase Storage; their URLs live on the Firestore product/category documents.
- Catalog data (categories, nested subcategories, products) is managed from the admin app in Cloud Firestore.
- `firestore.rules` in this repo is a read-only snapshot of the live rules — the admin project owns and deploys them. Do not edit or deploy rules from here.

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

- To update the product catalog: create/edit products and categories in the admin app; this client only reads.
- For new categories, add them from the admin app; the client UI is dynamic.
- Deprecated GitHub image logic is retained in `/archive/` for reference.

## License

This project is for internal use by Xepi. Contact the repository owner for more information.
