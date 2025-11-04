import Foundation

// MARK: - Prompt Models
struct PromptAnswer: Codable, Identifiable {
    let id: Int
    let createdAt: String
    let promptId: Int
    let userId: Int
    let prompt: Prompt
    var previewBooks: [PromptBook]? // Not from API, populated separately
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case promptId = "prompt_id"
        case userId = "user_id"
        case prompt
    }
}

struct Prompt: Codable {
    let id: Int
    let slug: String
    let question: String?
    let description: String?
}

// MARK: - Prompt Answer Details
struct PromptAnswerBookEntry: Codable, Identifiable {
    let id: Int
    let position: Int?
    let promptAnswerId: Int
    let promptAnswer: PromptAnswerInfo
    let book: PromptBook
    
    enum CodingKeys: String, CodingKey {
        case id
        case position
        case promptAnswerId = "prompt_answer_id"
        case promptAnswer = "prompt_answer"
        case book
    }
}

struct PromptAnswerInfo: Codable {
    let id: Int
    let user: PromptUser
}

struct UserPromptAnswer: Identifiable {
    let id: Int
    let user: PromptUser
    let books: [PromptBook]
}

struct PromptUser: Codable {
    let username: String
    let image: UserImage?
}

struct UserImage: Codable {
    let url: String?
}

struct PromptBook: Codable, Identifiable {
    let id: Int
    let title: String
    let image: String?
    let cachedImage: CachedPromptImage?
    
    enum CodingKeys: String, CodingKey {
        case id, title, image
        case cachedImage = "cached_image"
    }
}

struct CachedPromptImage: Codable {
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
          prompt_answers(where: {user_id: {_eq: \(profile.id)}}, order_by: {created_at: desc}) {
            id
            created_at
            prompt_id
            user_id
            prompt {
              id
              slug
              question
              description
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
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let promptAnswers = dataDict["prompt_answers"] as? [[String: Any]] {
                
                // Convert back to data and decode
                let answersData = try JSONSerialization.data(withJSONObject: promptAnswers)
                var answers = try decoder.decode([PromptAnswer].self, from: answersData)
                
                // Remove duplicates based on promptId (database may return one row per book)
                var uniqueAnswers: [PromptAnswer] = []
                var seenPromptIds = Set<Int>()
                
                for answer in answers {
                    if !seenPromptIds.contains(answer.promptId) {
                        uniqueAnswers.append(answer)
                        seenPromptIds.insert(answer.promptId)
                    }
                }
                
                // Fetch preview books for each prompt (first 3 books)
                for i in 0..<uniqueAnswers.count {
                    let userAnswers = await fetchPromptAnswers(promptId: uniqueAnswers[i].promptId, userId: uniqueAnswers[i].userId)
                    if let firstAnswer = userAnswers.first {
                        uniqueAnswers[i].previewBooks = firstAnswer.books
                    }
                }
                
                print("✅ Fetched \(uniqueAnswers.count) unique prompt answers (from \(answers.count) total rows)")
                return uniqueAnswers
            }
            
            print("⚠️ No prompt answers found in response")
            return []
            
        } catch {
            print("❌ Error fetching prompts: \(error)")
            return []
        }
    }
    
    /// Fetch a specific user's answer for a specific prompt
    static func fetchPromptAnswers(promptId: Int, userId: Int) async -> [UserPromptAnswer] {
        guard !HardcoverConfig.apiKey.isEmpty else {
            print("❌ No API key available")
            return []
        }
        
        // Get username from profile
        guard let profile = await fetchUserProfile() else {
            print("❌ Could not fetch user profile")
            return []
        }
        
        // For now, use a simple mapping. In production, we should cache the slug from fetchAnsweredPrompts
        let promptSlugMap: [Int: String] = [
            1: "what-are-your-favorite-books-of-all-time"
        ]
        
        guard let slug = promptSlugMap[promptId] else {
            print("❌ Unknown prompt ID: \(promptId)")
            return []
        }
        
        guard let url = URL(string: "https://hardcover.app/@\(profile.username)/prompts/\(slug)") else {
            print("❌ Invalid URL")
            return []
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(HardcoverConfig.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTML Response Status: \(httpResponse.statusCode)")
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                print("❌ Could not decode HTML")
                return []
            }
            
            // Extract JSON from data-page attribute
            guard let dataPageStart = html.range(of: "data-page=\"{") else {
                print("❌ Could not find data-page attribute")
                return []
            }
            
            let jsonStart = html.index(dataPageStart.lowerBound, offsetBy: 11) // Skip 'data-page="'
            
            // Find matching closing brace by counting depth
            var depth = 0
            var jsonEnd: String.Index? = nil
            var i = jsonStart
            
            while i < html.endIndex {
                let char = html[i]
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        jsonEnd = html.index(after: i)
                        break
                    }
                } else if char == "\"" && i == jsonStart {
                    // Skip the opening quote of the data-page attribute
                    i = html.index(after: i)
                    continue
                }
                i = html.index(after: i)
            }
            
            guard let jsonEnd = jsonEnd else {
                print("❌ Could not find matching closing brace")
                return []
            }
            
            let jsonString = String(html[jsonStart..<jsonEnd])
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#x27;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
            
            print("📦 Extracted JSON length: \(jsonString.count)")
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("❌ Could not convert to data")
                return []
            }
            
            guard let pageData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Invalid JSON - first 500 chars:")
                if jsonString.count > 500 {
                    print(String(jsonString.prefix(500)))
                } else {
                    print(jsonString)
                }
                return []
            }
            
            print("📦 Page data keys: \(pageData.keys.joined(separator: ", "))")
            
            guard let props = pageData["props"] as? [String: Any] else {
                print("❌ No props found")
                return []
            }
            
            print("📦 Props keys: \(props.keys.joined(separator: ", "))")
            
            guard let prompt = props["prompt"] as? [String: Any] else {
                print("❌ No prompt found")
                return []
            }
            
            print("📦 Prompt keys: \(prompt.keys.joined(separator: ", "))")
            
            guard let promptBooks = prompt["promptBooks"] as? [[String: Any]] else {
                print("❌ No promptBooks found")
                return []
            }
            
            print("✅ Found \(promptBooks.count) prompt books")
            
            // Parse books
            var books: [PromptBook] = []
            for promptBook in promptBooks {
                guard let bookDict = promptBook["book"] as? [String: Any],
                      let id = bookDict["id"] as? Int,
                      let title = bookDict["title"] as? String else {
                    continue
                }
                
                // Parse image - can be either a string URL or an object with url property
                var imageUrl: String? = nil
                if let imageStr = bookDict["image"] as? String {
                    imageUrl = imageStr
                } else if let imageDict = bookDict["image"] as? [String: Any],
                          let url = imageDict["url"] as? String {
                    imageUrl = url
                }
                
                let cachedImageUrl = (bookDict["cached_image"] as? [String: Any])?["url"] as? String
                let cachedImage = cachedImageUrl != nil ? CachedPromptImage(url: cachedImageUrl) : nil
                
                books.append(PromptBook(id: id, title: title, image: imageUrl, cachedImage: cachedImage))
            }
            
            // Create a single answer with the user and their books
            let user = PromptUser(username: profile.username, image: profile.image != nil ? UserImage(url: profile.image?.url) : nil)
            let answer = UserPromptAnswer(id: promptId, user: user, books: books)
            
            print("✅ Fetched \(books.count) books from HTML")
            return [answer]
            
        } catch {
            print("❌ Error fetching prompt HTML: \(error)")
            return []
        }
    }
}
