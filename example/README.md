# Firebase Update Example App

This app is the local showcase for the `firebase_update` package.

## Purpose

- prove the package can be consumed through a path dependency
- provide a stable place to demo the planned public API
- evolve into the real integration testbed once Firebase Remote Config support lands

## Current state

- app id: `com.qoder.firebaseupdateexample`
- package dependency: local path to `../`
- runtime package behavior: stubbed
- UI purpose: explain the package direction and planned config contract

## Next upgrades

- add Firebase setup
- wire real Remote Config reads
- demonstrate optional update, force update, and maintenance flows
- add patch-note rendering examples
