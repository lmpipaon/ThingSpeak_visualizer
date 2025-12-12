# 📊 Flutter ThingSpeak Data Visualizer

A cross-platform mobile and desktop application developed with Flutter and Dart, designed to efficiently visualize real-time and historical data from your ThingSpeak channels. This viewer offers a clean, user-friendly interface for monitoring data fields.

## ✨ Key Features

* **Multi-Language Support:** Choose between **English, Spanish (Español), and Basque (Euskara)** for the application interface.
* **Persistent API Management:** The application only requires the user to input a comma-separated list of **ThingSpeak User API Keys** on the first run. These keys are securely stored for subsequent sessions, eliminating the need to re-enter them.
* **Intuitive Navigation:** Easily navigate through a menu interface to select the desired **ThingSpeak Channel** and specific **Field** you wish to plot and visualize.

## 🚀 Getting Started

This project is built using the Flutter framework. To run it locally, follow these steps:

### Prerequisites

* Flutter SDK (v3.19.0 or later recommended)
* Dart SDK
* A code editor (VS Code recommended)

### Installation and Run

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/lmpipaon/ThingSpeak_visualizer.git](https://github.com/lmpipaon/ThingSpeak_visualizer.git)
    cd ThingSpeak_visualizer
    ```

2.  **Get the project dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application on a target device/emulator:**
    ```bash
    flutter run
    ```
    *(Note: You can specify a target platform like `flutter run -d windows` or `flutter run -d chrome`)*

## ⚙️ How to Use the Visualizer

When the application launches:

1.  **First Run Setup:**
    * You will be prompted to enter your **ThingSpeak User Read API Keys**.
    * Enter all keys separated by commas (e.g., `key1,key2,key3`).
    * Select your preferred application language (English, Español, or Euskara).
    * This setup only runs once. On subsequent launches, the keys and language will be loaded automatically.

2.  **Data Selection:**
    * Navigate to the main menu.
    * Use the navigation options to **select a specific Channel** associated with one of your provided API keys.
    * Choose the **Field** (e.g., Field 1, Field 2) within that channel whose data you wish to graph.
    * The application will fetch and display the data for the selected field.

## 🤝 Contribution & License

This project is open-source and released under the **MIT License**.

### 🤖 AI Assistance

This project was developed by Lmpipaon. The development process, including complex structure generation and optimization of certain Dart/Flutter code snippets, was assisted by the **Gemini AI model** (Google) to enhance efficiency and explore best practices.
