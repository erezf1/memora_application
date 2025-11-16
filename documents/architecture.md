
# Memora Voice Assistant - Architecture

## 1. Overview

This document outlines the proposed architecture for the Memora Voice Assistant Flutter application. The architecture is designed to be simple, scalable, and maintainable, following the guidelines and requirements specified in the PRD and Mobile Protocol documents.

## 2. Architectural Pattern

We will use a simple **service-oriented architecture**. This pattern separates the application's concerns into distinct, independent services. This approach is well-suited for this application due to its clear separation of UI, business logic, and external communication.

- **UI Layer**: Consists of Flutter widgets that form the application's screens. This layer is responsible for displaying data and capturing user input.
- **Service Layer**: Contains the application's business logic and handles communication with external services like the backend API, local storage, and push notification services.
- **Model Layer**: Defines the data structures used throughout the application.

## 3. Directory Structure

The project will be organized into the following directory structure:

```
lib/
|-- main.dart
|-- screens/
|   |-- splash_screen.dart
|   |-- registration_screen.dart
|   |-- main_conversation_screen.dart
|-- services/
|   |-- api_service.dart
|   |-- local_storage_service.dart
|   |-- notification_service.dart
|   |-- tts_service.dart
|   |-- stt_service.dart
|-- models/
|   |-- user_profile.dart
|-- widgets/
|   |-- incoming_call_widget.dart
|-- utils/
    |-- constants.dart
```


## 4. Component Breakdown

### 4.1. `main.dart`- **Purpose**: The entry point of the application.
- **Responsibilities**:
    - Initializes Firebase.
    - Sets up background and foreground FCM handlers by configuring the `NotificationService`.
    - Determines the initial route (`WelcomeScreen` vs. `MainConversationScreen`) based on user profile existence.

### 4.2. `screens/`

- **`welcome_screen.dart`**:
    - **Purpose**: The initial screen shown to new users.
    - **Responsibilities**:
        - Explains the permissions the app needs.
        - Navigates to `RegistrationScreen` when the user proceeds.

- **`registration_screen.dart`**:
    - **Purpose**: Onboards new users.
    - **Responsibilities**:
        - Displays input fields for name, gender, phone, and language.
        - Fetches the FCM token.
        - Calls `/register-user` via `ApiService`.
        - Saves the user profile using `UserProfileService`.
        - Navigates to `MainConversationScreen`.

- **`main_conversation_screen.dart`**:
    - **Purpose**: The primary UI for interacting with the voice assistant.
    - **Responsibilities**:
        - Displays the conversation history.
        - Integrates with `SttService` (speech-to-text) and `TtsService` (text-to-speech).
        - Sends user messages to the `/voice/process` endpoint via `ApiService`.
        - Handles the "Hang Up" button, which calls `/disconnect` via `ApiService` before closing the app.

### 4.3. `services/`

- **`api_service.dart`**:
    - **Purpose**: Manages all HTTP communication with the backend.
    - **Responsibilities**:
        - Provides methods for each API endpoint: `registerUser()`, `initiateSession()`, `processMessage()`, `disconnect()`, `answerCall()`, and `declineCall()`.
        - Handles JSON serialization and deserialization.
        - Manages the base URL.

- **`user_profile_service.dart`**:
    - **Purpose**: Manages data persistence on the device.
    - **Responsibilities**:
        - Uses `shared_preferences`.
        - Provides methods to `saveProfile`, `loadProfile`, and `deleteProfile`.

- **`notification_service.dart`**:
    - **Purpose**: Handles all incoming push notifications, especially for the "Incoming Call" feature.
    - **Responsibilities**:
        - Uses `firebase_messaging` to configure background and foreground handlers.
        - **Uses a specialized package like `flutter_callkit_incoming` to display a native incoming call UI on both iOS (CallKit) and Android.**
        - **Parses incoming FCM data messages** to identify "incoming_call" types.
        - **Handles user actions (answer/decline) from the native call UI**, calling the appropriate `ApiService` methods (`answerCall` or `declineCall`).
        - **Manages different states:**
            - **Foreground:** Shows an in-app dialog (e.g., `AlertDialog`) with "Answer/Decline" buttons.
            - **Background/Terminated:** Triggers the full-screen native call UI via the `flutter_callkit_incoming` package. This covers both locked and unlocked states seamlessly.

- **`tts_service.dart`**:
    - **Purpose**: Manages text-to-speech functionality.
    - **Responsibilities**:
        - Uses `flutter_tts`.
        - Provides a method to speak a given text.

- **`stt_service.dart`**:
    - **Purpose**: Manages speech-to-text functionality.
    - **Responsibilities**:
        - Uses `speech_to_text`.
        - Provides methods to start and stop listening.

### 4.4. `models/`

- **`user_profile.dart`**:
    - **Purpose**: Defines the data structure for a user's profile.
    - **Responsibilities**:
        - Contains fields: `name`, `gender`, `phone`, `language`.
        - Includes `toJson()` and `fromJson()` methods.

### 4.5. `widgets/`

- **`incoming_call_widget.dart`**:
    - **Purpose**: This component's UI is primarily handled by the `flutter_callkit_incoming` package to ensure a native look and feel. A custom widget in this directory would only be needed if we were building a non-native, in-app call screen.

### 4.6. `utils/`

- **`constants.dart`**:
    - **Purpose**: Stores constant values used throughout the app, such as the API base URL.

---
## 5. Core Flows

This section details the primary user and system flows.

### 5.1. Proactive Agent "Call" Handling (NEW)

This flow is initiated by the backend sending a special FCM data message.

1.  **Backend Initiates Call**: The backend sends an FCM **data message** with the payload:
    