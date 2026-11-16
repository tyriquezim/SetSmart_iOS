import Foundation

struct USDAService {
    private let apiKey = AppConfig.usdaAPIKey
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    enum USDAError: LocalizedError {
        case rateLimited
        var errorDescription: String? { "USDA rate limit reached. Try again shortly." }
    }

    func search(query: String) async throws -> [Food] {
        guard !query.isEmpty else { return [] }
        var comps = URLComponents(string: "\(baseURL)/foods/search")!
        comps.queryItems = [
            URLQueryItem(name: "query",    value: query),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy"),
            URLQueryItem(name: "pageSize", value: "15"),
            URLQueryItem(name: "api_key",  value: apiKey)
        ]
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw USDAError.rateLimited
        }
        let result = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return result.foods.compactMap(mapFood)
    }
}

// MARK: - Private response types

private struct USDASearchResponse: Decodable {
    var foods: [USDAFood]
}

private struct USDAFood: Decodable {
    var fdcId: Int
    var description: String
    var foodNutrients: [USDANutrient]
}

private struct USDANutrient: Decodable {
    var nutrientId: Int
    var value: Double?
}

// MARK: - Mapping

private func mapFood(_ food: USDAFood) -> Food? {
    guard let energyKj = extractEnergyKj(food.foodNutrients), energyKj > 0 else { return nil }
    return Food(
        id: UUID(),
        source: "usda",
        sourceId: String(food.fdcId),
        name: food.description,
        brand: nil,
        barcode: nil,
        baseUnit: "g",
        energyKj: energyKj,
        proteinG: extract(food.foodNutrients, id: 1003),
        carbsG:   extract(food.foodNutrients, id: 1005),
        fatG:     extract(food.foodNutrients, id: 1004),
        servingSize: nil,
        servingLabel: nil,
        archivedAt: nil,
        userId: nil
    )
}

private func extract(_ nutrients: [USDANutrient], id: Int) -> Double? {
    nutrients.first { $0.nutrientId == id }?.value
}

private func extractEnergyKj(_ nutrients: [USDANutrient]) -> Double? {
    if let kj = extract(nutrients, id: 1062), kj > 0 { return kj }
    for id in [1008, 2048, 2047] {
        if let kcal = extract(nutrients, id: id), kcal > 0 { return kcal * 4.184 }
    }
    return nil
}
