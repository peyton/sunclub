import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var showTimePicker = false
    @State private var reminderTime = Date()
    @State private var showProductPicker = false
    @State private var productNameDraft = ""
    @State private var showSubscriptionFallback = false

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 30) {
                SunLightHeader(title: "Settings", showsBack: true) {
                    router.goHome()
                }

                VStack(alignment: .leading, spacing: 18) {
                    currentProductSection

                    SunSettingsRow(title: "Notification Time") {
                        reminderTime = appState.reminderDate
                        showTimePicker = true
                    }
                    .accessibilityIdentifier("settings.notificationTime")

                    SunSettingsRow(title: "Retrain Active Product") {
                        appState.clearTrainingDataForActiveProduct()
                        router.open(.trainPhotos)
                    }
                    .accessibilityIdentifier("settings.retrain")

                    SunSettingsRow(title: "Add Another Product") {
                        appState.startNewProduct()
                        router.open(.scanBarcode)
                    }
                    .accessibilityIdentifier("settings.addProduct")

                    SunSettingsRow(title: "Manage Subscription") {
                        openManageSubscriptions()
                    }
                    .accessibilityIdentifier("settings.manageSubscription")
                }

                Spacer(minLength: 420)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
        .sheet(isPresented: $showProductPicker) {
            productPickerSheet
        }
        .onAppear {
            productNameDraft = appState.activeProduct?.name ?? ""
        }
        .alert("Manage Subscription Unavailable", isPresented: $showSubscriptionFallback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Subscription management is not available in this environment.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var currentProductSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Active Product")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(appState.activeProduct?.name ?? "No active product")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.activeProductName")

            if let barcode = appState.activeProduct?.barcode, !barcode.isEmpty {
                Text("Barcode: \(barcode)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }

            TextField("Product Name", text: $productNameDraft)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                )
                .accessibilityIdentifier("settings.productNameField")

            Button("Save Product Name") {
                appState.renameActiveProduct(productNameDraft)
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("settings.saveProductName")

            if appState.hasMultipleProducts {
                Button("Switch Product") {
                    showProductPicker = true
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.switchProduct")
            }
        }
    }

    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Reminder Time",
                    selection: $reminderTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("Save Time") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                    appState.updateDailyReminder(hour: components.hour ?? 8, minute: components.minute ?? 0)
                    showTimePicker = false
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }
            .padding(24)
            .navigationTitle("Notification Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showTimePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var productPickerSheet: some View {
        NavigationStack {
            List(appState.products) { product in
                Button {
                    appState.setActiveProduct(product)
                    productNameDraft = product.name
                    showProductPicker = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .foregroundStyle(AppPalette.ink)

                            if let barcode = product.barcode, !barcode.isEmpty {
                                Text(barcode)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppPalette.softInk)
                            }
                        }

                        Spacer()

                        if product.id == appState.activeProduct?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppPalette.sun)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Switch Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showProductPicker = false
                    }
                }
            }
        }
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
            showSubscriptionFallback = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                showSubscriptionFallback = true
            }
        }
    }
}
