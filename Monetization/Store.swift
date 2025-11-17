import StoreKit

@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @Published var removeAds = false
    private let productID = "com.yourco.ctk.removeads"
    private var product: Product?

    private init() {
        Task {
            await listenForTransactions()
            await loadProduct()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [productID]).first
            for await transaction in Transaction.currentEntitlements where transaction.productID == productID {
                removeAds = true
            }
        } catch {
            // Handle errors as needed
        }
    }

    func buyRemoveAds() async -> Bool {
        guard let product = product else { return false }
        do {
            let result = try await product.purchase()
            if case .success(let verificationResult) = result,
               let transaction = try? await verificationResult.payloadValue {
                await handle(transaction)
                return true
            }
        } catch {
            // Handle errors as needed
        }
        return false
    }

    func restore() async {
        try? await AppStore.sync()
    }

    private func listenForTransactions() async {
        for await transaction in Transaction.updates {
            await handle(transaction)
        }
    }

    private func handle(_ transaction: Transaction) async {
        guard transaction.productID == productID else { return }
        removeAds = true
        await transaction.finish()
    }
}
