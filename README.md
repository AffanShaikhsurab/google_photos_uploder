# Google Photos Uploader

Welcome to the Google Photos Uploader project! This project is an open-source solution for uploading photos to Google Photos using Flutter.

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Directory Structure](#directory-structure)
- [Contributing](#contributing)
- [License](#license)

Setup Credentials : [visit here](https://github.com/AffanShaikhsurab/google_photos_uploder/blob/main/CREDENTIALS.MD)
## Introduction

The Google Photos Uploader is a cross-platform application built with Flutter, designed to facilitate the uploading of photos to Google Photos from  Windows.

## Features

- Upload photos to Google Photos
- Cross-platform support (Android, iOS, Linux, macOS, Web, Windows)
- Easy-to-use interface

## Requirements

- Flutter SDK
- Dart
- Google Photos API credentials

## Installation

1. **Clone the repository:**

   ```sh
   git clone https://github.com/AffanShaikhsurab/google_photos_uploder.git
   cd google_photos_uploder
   ```

2. **Install dependencies:**

   ```sh
   flutter pub get
   ```

3. **Set up Google Photos API:**

   - Go to the [Google Cloud Console](https://console.cloud.google.com/).
   - Create a new project or select an existing one.
   - Enable the Google Photos API for your project.
   - Create OAuth 2.0 credentials and download the `credentials.json` file.
   - Place the `credentials.json` file in the root of the project directory.

## Usage

1. **Run the application:**

   ```sh
   flutter run
   ```

2. **Upload Photos:**
   - Open the app on your desired platform.
   - Authenticate with your Google account.
   - Select photos to upload.
   - Click the upload button to upload photos to Google Photos.

## Directory Structure

```plaintext
google_photos_uploder/
├── android/
├── ios/
├── lib/
│   ├── ImageCubit_state.dart
│   ├── ImageState.dart
│   ├── gallery.dart
│   ├── home.dart
│   ├── main.dart
│   ├── main_state.dart
├── linux/
├── macos/
├── web/
├── windows/
├── .gitignore
├── .metadata
├── README.md
├── analysis_options.yaml
├── heic_converter.py
├── pubspec.lock
├── pubspec.yaml
```

- **android/**, **ios/**, **linux/**, **macos/**, **web/**, **windows/**: Platform-specific directories for building the application.
- **lib/**: Contains the main application code.
  - **ImageCubit_state.dart**: State management for image cubit.
  - **ImageState.dart**: Image state management.
  - **gallery.dart**: Gallery page implementation.
  - **home.dart**: Home page implementation.
  - **main.dart**: Entry point of the application.
  - **main_state.dart**: Main state management.
- **.gitignore**: Git ignore file.
- **.metadata**: Metadata for the project.
- **README.md**: Project documentation (this file).
- **analysis_options.yaml**: Linter rules for Dart.
- **heic_converter.py**: Script for converting HEIC images.
- **pubspec.lock**: Lock file for dependencies.
- **pubspec.yaml**: Project dependencies and configurations.

## Contributing

We welcome contributions to the Google Photos Uploader project! To contribute, please follow these steps:

1. Fork the repository.
2. Create a new branch: `git checkout -b feature/your-feature-name`.
3. Make your changes and commit them: `git commit -m 'Add new feature'`.
4. Push to the branch: `git push origin feature/your-feature-name`.
5. Submit a pull request.

Please ensure your code adheres to the existing code style and includes appropriate tests.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
