## Product Requirements Document: Memora Voice Assistant

Version: 1.1 Date: November 12, 2025 Author: Gemini Code Assist

### 1\. Introduction & Vision

#### 1.1. Project Overview

The Memora Voice Assistant is a voice-first mobile application designed to serve as a conversational companion for users. The app provides a simple, intuitive interface for users to interact with a sophisticated backend AI agent through natural conversation in Hebrew or English.

#### 1.2. Core Goal

To create a highly accessible, reliable, and empathetic digital assistant that can be initiated by the user or proactively by the system to deliver timely reminders and support. The application must be extremely simple to navigate, prioritizing voice interaction over complex UI elements.

#### 1.3. Target Audience

The primary user is an elderly individual who may have limited technical proficiency and may benefit from proactive reminders and a simple conversational interface for managing their daily lives.

### 2\. Functional Requirements

#### 2.1. Onboarding & Registration (First-Time Use)

* FR-1: Splash Screen:  
  * Upon first launch, the app shall display a splash screen.  
  * It will check for a user profile in local storage (shared\_preferences). If no profile is found, it will navigate to the Registration Screen.  
* FR-2: Registration Screen:  
  * The screen must present input fields for:  
    1. Full Name (Text Input)  
    2. Gender (Dropdown/Selector: 'זכר'/'Male', 'נקבה'/'Female', 'אחר'/'Other')  
    3. Phone Number (Text Input, numeric keyboard)  
    4. Language (Dropdown/Selector: 'עברית', 'English')  
  * A "Register" (הרשמה / Register) button will be prominently displayed.  
* FR-3: Registration Logic:  
  * Upon tapping "Register":  
    1. Input Validation: The app must validate that all fields are filled.  
    2. Phone Normalization: The entered phone number must be normalized to the E.164 format (e.g., 0541234567 becomes 972541234567).  
    3. FCM Token: The app must request a Firebase Cloud Messaging (FCM) token.  
    4. API Call: The app will send a POST request to the /register-user endpoint with the user's name, gender, language, normalized phone number, and the FCM token.  
    5. Local Storage: Upon a successful API response (HTTP 200), the app must save the user's profile (name, gender, phone, language) to shared\_preferences.  
    6. Navigation: The user is then navigated to the Main Conversation Screen.  
    7. Error Handling: If the API call fails, a user-friendly error message must be displayed.

#### 2.2. App Launch (Existing User)

* FR-4: Session Initiation:  
  * On subsequent app launches, the splash screen will detect the locally saved user profile.  
  * The app will immediately request the latest FCM token from Firebase.  
  * It will then send a POST request to the /initiate-session endpoint, providing the user's saved profile information and the new FCM token.

#### 2.3. Main Conversation Screen

* FR-5: UI Elements:  
  1. Header: A Memora logo displayed at the top of the screen.  
  2. Main Display Area: A central area that dynamically displays the current state:  
     * When the agent is speaking: Shows the text being read by TTS.  
     * When the app is listening: Shows a large microphone icon.  
     * After listening: Shows the transcribed text from the user's speech while waiting for the server's response.  
  3. Footer: A "Hang Up" (ניתוק / Hang Up) button at the bottom to end the conversation and return the app to an idle state.  
* FR-6: User-Initiated Conversation Flow:  
  1. Start Listening: User taps the Microphone Button. The app state changes to Listening..., and the speech\_to\_text engine is activated.  
  2. Listening Timeout: The app will listen for a maximum of 30 seconds. If no speech is detected in this period, the app will stop listening and return to its idle state on the main screen.  
  3. Process Speech: When the user finishes speaking, the state changes to Processing.... The transcribed text is sent in a POST request to the /voice/process endpoint.  
  4. Receive & Speak Response: The app receives a text response from the backend. The state changes to Speaking.... The flutter\_tts engine reads the response aloud.  
  5. Return to Idle: Once TTS is complete, the state returns to Ready (microphone icon visible).

#### 2.4. Agent-Initiated Conversation (Incoming Call)

* FR-7: Push Notification Handling:  
  * The app must be configured to receive and handle data-only push notifications when the app is in the foreground, background, or terminated.  
* FR-8: Incoming Notification UI:  
  * The UI presented to the user will depend on the device's state:  
    1. If the device is locked: The app must display a full-screen "Incoming Call" UI, similar to a native phone call. This UI will show the caller name ("Memora") and provide large "Answer" (Green) and "Decline" (Red) buttons.  
    2. If the device is unlocked: The app must display a "heads-up" notification banner at the top of the screen. This banner will also contain "Answer" and "Decline" buttons.  
  * A ringtone must play in both scenarios until the user interacts.  
* FR-9: Call Handling Logic:  
  * If User Answers:  
    1. The ringtone stops.  
    2. The app sends a POST request to /voice/call-answered.  
    3. The app navigates to the Main Conversation Screen.  
    4. The flutter\_tts engine immediately speaks the body text from the push notification.  
  * If User Declines:  
    1. The ringtone stops.  
    2. The app sends a POST request to /voice/call-declined.  
    3. The notification/call screen is dismissed.

### 3\. Non-Functional Requirements

* NFR-1: Performance: App launch time should be under 3 seconds.  
* NFR-2: Reliability: The app must reliably display the incoming call UI/notification from any state (foreground, background, terminated).  
* NFR-3: Usability & Accessibility: Font sizes must be large and legible. UI elements must be large and easy to tap.  
* NFR-4: Platform Support: Android (API level 23+) and iOS (latest 2 major versions).  
* NFR-5: Text-to-Speech (TTS):  
  * The app must use the device's native (local) TTS engine.  
  * The app should query the available voices on the device and select one that matches the user's registered gender and language. For example, if the user is female and the language is Hebrew, it should select a female Hebrew voice if available.

### 4\. Technical Specifications

* Framework: Flutter  
* Backend Communication: http package  
* Push Notifications: firebase\_core, firebase\_messaging  
* Local Storage: shared\_preferences  
* Speech-to-Text (STT): speech\_to\_text package (configured for selected language)  
* Text-to-Speech (TTS): flutter\_tts package (configured with gender-appropriate local voice)  
* Incoming Call UI: flutter\_callkit\_incoming or an equivalent package that can differentiate between locked/unlocked states.  
* Backend Base URL: http://memora.aigents.co.il

### 5\. Out of Scope for MVP

* User profile editing after registration.  
* Displaying images, videos, or web content.  
* In-app settings screen.  
* Detailed call history log screen.  
* 

