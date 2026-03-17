# StoreKit Local Testing

Sunclub now reads subscription product identifiers from `SunclubSubscriptionProductIDs` in `Info.plist`.

Current placeholders:

- `com.peyton.sunclub.subscription.monthly`
- `com.peyton.sunclub.subscription.annual`

The bundled `SunclubSubscriptions.storekit` file mirrors those IDs for simulator and scheme-based local testing. If App Store Connect ends up using different identifiers, update both this README and the config file so the local scheme stays aligned with production.

Recommended Xcode setup:

1. Open the `Sunclub` scheme.
2. Edit the Run action.
3. Set the StoreKit configuration to `SunclubSubscriptions.storekit`.
4. Use StoreKit Test to exercise purchase, restore, and expiration flows before wiring the paywall UI.
