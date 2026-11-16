import Foundation

struct OFFService {
    private let baseURL = "https://world.openfoodfacts.org"
    private let fields = "code,product_name,product_name_en,generic_name,brands,serving_size,serving_quantity,product_quantity_unit,nutriments"

    func search(query: String) async throws -> [Food] {
        guard !query.isEmpty else { return [] }
        var comps = URLComponents(string: "\(baseURL)/cgi/search.pl")!
        comps.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "json",         value: "true"),
            URLQueryItem(name: "fields",       value: fields),
            URLQueryItem(name: "page_size",    value: "15"),
            URLQueryItem(name: "page",         value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(for: request(comps.url!))
        let result = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return result.products.compactMap(mapProduct)
    }

    func lookup(barcode: String) async throws -> Food? {
        let url = URL(string: "\(baseURL)/api/v2/product/\(barcode)?fields=\(fields)")!
        let (data, _) = try await URLSession.shared.data(for: request(url))
        let result = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard result.status == 1, let product = result.product else { return nil }
        return mapProduct(product)
    }

    private func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("SetSmart-iOS/1.0", forHTTPHeaderField: "User-Agent")
        return r
    }
}

// MARK: - Response types

private struct OFFSearchResponse: Decodable {
    var products: [OFFProduct]
}

private struct OFFProductResponse: Decodable {
    var status: Int
    var product: OFFProduct?
}

private struct OFFProduct: Decodable {
    var code: String?
    var productName: String?
    var productNameEn: String?
    var genericName: String?
    var brands: String?
    var servingSize: String?
    var servingQuantity: Double?
    var productQuantityUnit: String?
    var nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName         = "product_name"
        case productNameEn       = "product_name_en"
        case genericName         = "generic_name"
        case brands
        case servingSize         = "serving_size"
        case servingQuantity     = "serving_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case nutriments
    }
}

private struct OFFNutriments: Decodable {
    var energyKj: Double?
    var energyKcal: Double?
    var proteins: Double?
    var carbohydrates: Double?
    var fat: Double?

    enum CodingKeys: String, CodingKey {
        case energyKj      = "energy-kj_100g"
        case energyKcal    = "energy-kcal_100g"
        case proteins      = "proteins_100g"
        case carbohydrates = "carbohydrates_100g"
        case fat           = "fat_100g"
    }
}

// MARK: - Mapping

private func mapProduct(_ p: OFFProduct) -> Food? {
    let name = p.productNameEn ?? p.productName ?? p.genericName ?? ""
    guard !name.isEmpty, let n = p.nutriments else { return nil }

    let energyKj: Double
    if let kj = n.energyKj, kj > 0 { energyKj = kj }
    else if let kcal = n.energyKcal, kcal > 0 { energyKj = kcal * 4.184 }
    else { return nil }

    let brand = p.brands?.components(separatedBy: ",").first?
        .trimmingCharacters(in: .whitespaces)
        .nilIfEmpty

    return Food(
        id: UUID(),
        source: "off",
        sourceId: p.code,
        name: name,
        brand: brand,
        barcode: p.code,
        baseUnit: isVolumeFood(unit: p.productQuantityUnit, serving: p.servingSize) ? "ml" : "g",
        energyKj: energyKj,
        proteinG: n.proteins,
        carbsG: n.carbohydrates,
        fatG: n.fat,
        servingSize: p.servingQuantity,
        servingLabel: extractServingLabel(p.servingSize),
        archivedAt: nil,
        userId: nil
    )
}

private func isVolumeFood(unit: String?, serving: String?) -> Bool {
    let vol = ["ml", "cl", "l"]
    if let u = unit?.lowercased(), vol.contains(u) { return true }
    if let s = serving?.lowercased() {
        for kw in vol where s.contains(kw) { return true }
    }
    return false
}

private func extractServingLabel(_ servingSize: String?) -> String? {
    guard let s = servingSize,
          let range = s.range(of: "\\((.+?)\\)", options: .regularExpression) else { return nil }
    let inner = String(s[range].dropFirst().dropLast())
    let isJustWeight = inner.range(
        of: #"^\s*\d+\.?\d*\s*(g|ml|kg)\s*$"#,
        options: [.regularExpression, .caseInsensitive]
    ) != nil
    return isJustWeight ? nil : inner.trimmingCharacters(in: .whitespaces)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
