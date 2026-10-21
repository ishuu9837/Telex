import Foundation

enum AppTerms {
    static let version = "1.0"
    static let sections: [(title: String, body: String)] = [
        ("Using Telex", "Telex is a local presentation and recording tool. Use it for content you own or have permission to use, and respect the rules of the meetings, workplaces and services where you present."),
        ("Your content and privacy", "Your scripts remain yours. This version stores scripts and settings locally and does not provide accounts, cloud sync or analytics. You control where exported scripts and recordings are saved."),
        ("Permissions are separate", "Agreeing to these terms does not grant microphone, Apple Speech or screen-recording permission. No-microphone mode needs none of them. Apple transcription and screen recording are optional and require separate, explicit actions."),
        ("Recording and consent", "Record only when you have the necessary consent and permission. You are responsible for how you use and share recordings."),
        ("Stealth and macOS indicators", "Stealth is best effort, and is Limited on macOS 15 or later. Other software can still capture the prompter. Stealth does not hide macOS microphone or screen-recording indicators or the app name shown by macOS. Share a single app window or another display when needed."),
        ("Limitations and backups", "Speech matching can be inaccurate and recordings can be interrupted. Test your setup before an important presentation, and keep backups of important scripts and recordings. No guarantee of uninterrupted operation or capture invisibility is provided."),
        ("Your choice", "You can decline and quit, or agree to use this version. You can review these terms later from Help or Settings. Updated terms require a new agreement.")
    ]
}
