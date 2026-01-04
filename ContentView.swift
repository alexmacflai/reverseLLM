import SwiftUI

struct ContentView: View {
    struct QuestionThread: Identifiable, Decodable {
        let id: String
        let llm: String
        let messages: [String]

        var title: String { messages.first ?? "Untitled" }
    }

    enum BottomTab {
        case giveAnswers
        case getQuestions
    }

    @State private var showAnswered = false
    @State private var selectedPill: String = "All"
    @State private var fetchAutoReturnWorkItem: DispatchWorkItem? = nil
    @State private var isFetchingQuestions = false
    @State private var fetchProgress: Double = 0
    @State private var fetchProgressTimer: Timer? = nil
    @State private var listScrollID: String? = nil

    @State private var showAddedNotification = false
    @State private var addedQuestionsCount = 12
    @State private var addedNotificationDismissWorkItem: DispatchWorkItem? = nil

    // Tunables for testing timings
    private let fetchDelaySeconds: Double = 1.0
    private let notificationVisibleSeconds: Double = 1.0

    private let chatbotPills: [String] = [
        "All",
        "ChatGPT",
        "DeepSeek",
        "Gemini",
        "Claude",
        "Copilot",
        "Grok",
        "Meta AI",
        "Mistral"
    ]

    private let solvedItems: [(title: String, badge: String)] = []

    @State private var inboxThreads: [QuestionThread] = []
    @State private var selectedThreadID: String? = nil
    @State private var selectedBottomTab: BottomTab = .giveAnswers

    private var filteredInboxThreads: [QuestionThread] {
        if selectedPill == "All" { return inboxThreads }
        return inboxThreads.filter { $0.llm.caseInsensitiveCompare(selectedPill) == .orderedSame }
    }

    private var giveAnswersScreen: some View {
        VStack(alignment: .leading, spacing: 0) {

            // HEADER CONTAINER
            VStack(alignment: .leading, spacing: 16) {
                Text("Reverse LLM")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack {
                    Text("Show answered")
                    Spacer()
                    Toggle("", isOn: $showAnswered)
                        .labelsHidden()
                }
                .padding(.vertical, 0)

                // Full-bleed pills row (horizontal, scrollable)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chatbotPills, id: \.self) { name in
                            let isSelected = (name == selectedPill)
                            Text(name)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                )
                                .foregroundColor(isSelected ? .accentColor : .primary)
                                .onTapGesture {
                                    selectedPill = name
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
            .padding(.top, 0)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 0.5)
                        .edgesIgnoringSafeArea(.horizontal)
                }
            )

            // Lists
            VStack(spacing: 0) {
                List {
                    Section {
                        if showAnswered {
                            if solvedItems.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("no chats")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                    Spacer()
                                }
                            } else {
                                ForEach(solvedItems.indices, id: \.self) { index in
                                    let item = solvedItems[index]
                                    questionRow(
                                        title: item.title,
                                        badge: item.badge,
                                        trailingIcon: "checkmark.circle.fill",
                                        trailingColor: .green
                                    )
                                }
                            }
                        } else {
                            if filteredInboxThreads.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("no chats")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                    Spacer()
                                }
                            } else {
                                ForEach(filteredInboxThreads) { thread in
                                    questionRow(title: thread.title, badge: thread.llm)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedThreadID = thread.id
                                        }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 16)
                .listSectionSpacing(.compact)
                .scrollPosition(id: $listScrollID, anchor: .top)
            }
            .onAppear {
                if inboxThreads.isEmpty {
                    inboxThreads = loadRandomThreads(count: 20)
                }
            }
        }
        // Added questions notification
        .safeAreaInset(edge: .bottom) {
            ZStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.medium)
                    Text("\(addedQuestionsCount) questions added")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(Color.accentColor)
                )
                .scaleEffect(showAddedNotification ? 1.0 : 0.4)
                .offset(y: showAddedNotification ? 0 : 40)
                .animation(showAddedNotification ? .spring(response: 0.32, dampingFraction: 0.4) : .spring(response: 0.24, dampingFraction: 0.9), value: showAddedNotification)
                .opacity(showAddedNotification ? 1 : 0)
                .animation(showAddedNotification ? .easeOut(duration: 0.2) : .linear(duration: 0.1), value: showAddedNotification)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .allowsHitTesting(false)
        }
    }

    private var getQuestionsScreen: some View {
        VStack(spacing: 16) {
            Spacer()

            if isFetchingQuestions {
                ProgressView()
            }

            Text("Getting questions…")
                .font(.headline)

            Text("Hold tight. We'll be back in a moment.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    var body: some View {
        TabView(selection: $selectedBottomTab) {

            // GIVE ANSWERS TAB
            giveAnswersScreen
                .tabItem {
                    Label("Give answers", systemImage: "hand.wave.fill")
                }
                .tag(BottomTab.giveAnswers)

            // GET QUESTIONS TAB
            getQuestionsScreen
                .tabItem {
                    VStack(spacing: 4) {
                        if isFetchingQuestions {
                            Image(systemName: "progress.indicator", variableValue: fetchProgress)
                                .symbolRenderingMode(.hierarchical)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Get questions")
                    }
                }
                .tag(BottomTab.getQuestions)
        }
        .onChange(of: selectedBottomTab) { oldValue, newValue in
            // Cancel any previous auto-return timer
            fetchAutoReturnWorkItem?.cancel()
            fetchAutoReturnWorkItem = nil
            fetchProgressTimer?.invalidate()
            fetchProgressTimer = nil

            if newValue == .getQuestions {
                isFetchingQuestions = true
                fetchProgress = 0
                let start = Date()
                fetchProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    let elapsed = Date().timeIntervalSince(start)
                    let p = min(max(elapsed / fetchDelaySeconds, 0), 1)
                    fetchProgress = p
                    if p >= 1 {
                        fetchProgressTimer?.invalidate()
                        fetchProgressTimer = nil
                    }
                }

                // Auto-return after fetchDelaySeconds
                let work = DispatchWorkItem {
                    fetchProgressTimer?.invalidate()
                    fetchProgressTimer = nil
                    fetchProgress = 0
                    isFetchingQuestions = false
                    selectedBottomTab = .giveAnswers
                }
                fetchAutoReturnWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(fetchDelaySeconds * 1000)), execute: work)
            } else {
                // User went back manually
                fetchProgress = 0
                isFetchingQuestions = false
                if oldValue == .getQuestions {
                    addedQuestionsCount = 12
                    showAddedNotification = true

                    addedNotificationDismissWorkItem?.cancel()
                    let dismiss = DispatchWorkItem {
                        showAddedNotification = false
                    }
                    addedNotificationDismissWorkItem = dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(notificationVisibleSeconds * 1000)), execute: dismiss)
                }
            }
        }
    }

    private func loadRandomThreads(count: Int) -> [QuestionThread] {
        guard let url = Bundle.main.url(forResource: "Questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([QuestionThread].self, from: data) else {
            print("Failed to load or decode questions.json")
            return []
        }

        return Array(all.shuffled().prefix(count))
    }

    @ViewBuilder
    private func questionRow(title: String, badge: String, trailingIcon: String = "chevron.right", trailingColor: Color = .secondary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Badge(text: badge, color: Badge.color(for: badge))
            }

            Spacer()

            Image(systemName: trailingIcon)
                .foregroundColor(trailingColor)
        }
        .padding(.vertical, 0)
    }
}

#Preview {
    ContentView()
}
