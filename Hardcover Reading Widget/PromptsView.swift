import SwiftUI

struct PromptsView: View {
    @State private var prompts: [PromptAnswer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(NSLocalizedString("Loading prompts...", comment: "Message while loading prompts"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("Failed to load prompts", comment: "Error message when prompts fail to load"))
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await loadPrompts() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if prompts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "questionmark.bubble")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("No answered prompts", comment: "Message when user has no answered prompts"))
                        .font(.headline)
                    Text(NSLocalizedString("Answer prompts on Hardcover to see them here", comment: "Empty state message for prompts view"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(prompts) { promptAnswer in
                            PromptAnswerCard(promptAnswer: promptAnswer)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(NSLocalizedString("Answered Prompts", comment: "Title for answered prompts view"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadPrompts()
        }
    }
    
    private func loadPrompts() async {
        isLoading = true
        errorMessage = nil
        
        let fetchedPrompts = await HardcoverService.fetchAnsweredPrompts()
        
        await MainActor.run {
            if fetchedPrompts.isEmpty && errorMessage == nil {
                // Could be legitimately empty or an error
                self.prompts = []
            } else {
                self.prompts = fetchedPrompts
            }
            self.isLoading = false
        }
    }
}

struct PromptAnswerCard: View {
    let promptAnswer: PromptAnswer
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var date: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: promptAnswer.createdAt)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt Title - use slug as fallback if title not available
            Text(promptAnswer.prompt.title ?? promptAnswer.prompt.slug.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Prompt Description
            if let description = promptAnswer.prompt.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Books
            if let books = promptAnswer.books, !books.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(books.indices, id: \.self) { index in
                            PromptBookCover(book: books[index].book)
                        }
                    }
                }
            }
            
            // Date
            if let date = date {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct PromptBookCover: View {
    let book: PromptBookDetails
    
    private var imageUrl: URL? {
        if let cachedUrl = book.cachedImage?.url {
            return URL(string: cachedUrl)
        } else if let imageUrl = book.image {
            return URL(string: imageUrl)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let url = imageUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 120)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 120)
                            .overlay(
                                Image(systemName: "book.fill")
                                    .foregroundColor(.gray)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 120)
                    .overlay(
                        Image(systemName: "book.fill")
                            .foregroundColor(.gray)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Text(book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}

#Preview {
    NavigationStack {
        PromptsView()
    }
}
