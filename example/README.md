# Firebase Update Example App

This app is the local showcase for the `firebase_update` package.

## Purpose

- prove the package can be consumed through a path dependency
- demonstrate the refreshed default overlays in a branded environment
- provide a hands-on control deck for update, force, maintenance, snooze, patch-note, and custom takeover states
- act as the visual reference for screenshot capture and integration tests

## Current state

- app id: `com.qoder.firebaseupdateexample`
- package dependency: local path to `../`
- runtime package behavior: real package initialization with local payload simulation
- UI purpose: showcase the package-managed overlays, long-content behavior, live payload testing, and a custom full-screen maintenance takeover with preloaded network media

## What to try

- trigger `Optional dialog`, `Force dialog`, and `Maintenance dialog` from the control deck
- open `Long content & custom surfaces` to stress patch notes, read-more behavior, and the full-screen maintenance example
- paste raw JSON into the live tester and verify how payload changes resolve on screen
