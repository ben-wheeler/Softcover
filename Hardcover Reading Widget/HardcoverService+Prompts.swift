import Foundation

// MARK: - Prompt Models
struct PromptAnswer: Codable, Identifiable {
    let id: Int
    let createdAt: String
    let data: PromptActivityData
    let bookId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case data
        case bookId = "book_id"
    }
}

struct PromptActivityData: Codable {
    let prompt: Prompt
}

struct Prompt: Codable {
    let id: Int
    let slug: String
    let question: String?
    let description: String?
    let answers: [PromptAnswerBook]?
}

struct PromptAnswerBook: Codable {
    let book: PromptBookDetails
}

struct PromptBookDetails: Codable {
    let id: Int
    let title: String
    let image: String?
    let cachedImage: CachedImage?
    
    enum CodingKeys: String, CodingKey {
        case id, title, image
        case cachedImage = "cached_image"
    }
}

struct CachedImage: Codable {
    let url: String?
}

extension HardcoverService {
    /// Fetch answered prompts for the current user
    static func fetchAnsweredPrompts() async -> [PromptAnswer] {
        guard !HardcoverConfig.apiKey.isEmpty else {
            print("❌ No API key available")
            return []
        }
        
        // First get user ID
        guard let profile = await fetchUserProfile() else {
            print("❌ Could not fetch user profile")
            return []
        }
        
        guard let url = URL(string: "https://api.hardcover.app/v1/graphql") else {
            print("❌ Invalid API URL")
            return []
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(HardcoverConfig.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        
        let query = """
        query {
          activities(where: {user_id: {_eq: \(profile.id)}, event: {_eq: "PromptActivity"}}, order_by: {created_at: desc}, limit: 50) {
            id
            created_at
            book_id
            data
          }
        }
        """
        
        let body: [String: Any] = ["query": query]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ Failed to serialize request body")
            return []
        }
        
        req.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Prompts HTTP Status: \(httpResponse.statusCode)")
            }
            
            if let raw = String(data: data, encoding: .utf8) {
                print("📥 Prompts Raw Response: \(raw)")
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let activities = dataDict["activities"] as? [[String: Any]] {
                
                // Convert back to data and decode
                let activitiesData = try JSONSerialization.data(withJSONObject: activities)
                let answers = try decoder.decode([PromptAnswer].self, from: activitiesData)
                print("✅ Fetched \(answers.count) prompt activities")
                return answers
            }
            
            print("⚠️ No prompt activities found in response")
            return []
            
        } catch {
            print("❌ Error fetching prompts: \(error)")
            return []
        }
    }
}
