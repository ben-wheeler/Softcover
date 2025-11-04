import Foundation

// MARK: - Prompt Models
struct PromptAnswer: Codable, Identifiable {
    let id: Int
    let createdAt: String
    let prompt: Prompt
    let books: [PromptBook]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case prompt
        case books = "prompt_answer_books"
    }
}

struct Prompt: Codable {
    let id: Int
    let slug: String
    let title: String
    let description: String?
}

struct PromptBook: Codable {
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

// MARK: - GraphQL Response
struct GraphQLPromptsResponse: Codable {
    let data: PromptsData?
    let errors: [GraphQLPromptError]?
}

struct PromptsData: Codable {
    let promptAnswers: [PromptAnswer]?
    
    enum CodingKeys: String, CodingKey {
        case promptAnswers = "prompt_answers"
    }
}

struct GraphQLPromptError: Codable {
    let message: String
}

extension HardcoverService {
    /// Fetch answered prompts for the current user
    static func fetchAnsweredPrompts() async -> [PromptAnswer] {
        guard !HardcoverConfig.apiKey.isEmpty else {
            print("❌ No API key available")
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
          me {
            prompt_answers(order_by: {created_at: desc}) {
              id
              created_at
              prompt {
                id
                slug
                title
                description
              }
              prompt_answer_books {
                book {
                  id
                  title
                  image
                  cached_image {
                    url
                  }
                }
              }
            }
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
            
            // First try to decode as a direct response with prompt_answers
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let meArray = dataDict["me"] as? [[String: Any]],
               let firstMe = meArray.first,
               let promptAnswers = firstMe["prompt_answers"] as? [[String: Any]] {
                
                // Convert back to data and decode
                let promptsData = try JSONSerialization.data(withJSONObject: promptAnswers)
                let answers = try decoder.decode([PromptAnswer].self, from: promptsData)
                print("✅ Fetched \(answers.count) prompt answers")
                return answers
            }
            
            print("⚠️ No prompt answers found in response")
            return []
            
        } catch {
            print("❌ Error fetching prompts: \(error)")
            return []
        }
    }
}
