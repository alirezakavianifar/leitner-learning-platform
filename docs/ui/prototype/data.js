// Mock Data for Leitner Learning Platform Interactive Prototype

const mockBanners = [
  {
    id: 1,
    title: "Boost Your Focus!",
    subtitle: "Study Box 1 cards twice daily for optimal retention.",
    color: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    actionText: "Read Study Tips"
  },
  {
    id: 2,
    title: "Offline-First Learning",
    subtitle: "Download your courses now and study without internet.",
    color: "linear-gradient(135deg, #11998e 0%, #38ef7d 100%)",
    actionText: "Manage Downloads"
  },
  {
    id: 3,
    title: "New Course Available: German A2",
    subtitle: "Expand your vocabulary with our latest space-repetition deck.",
    color: "linear-gradient(135deg, #f857a6 0%, #ff5858 100%)",
    actionText: "Explore Courses"
  },
  {
    id: 4,
    title: "Analyze Your Progress",
    subtitle: "Check out the detailed color-coded statistics tab.",
    color: "linear-gradient(135deg, #00c6ff 0%, #0072ff 100%)",
    actionText: "View Stats"
  },
  {
    id: 5,
    title: "Join Our Support Community",
    subtitle: "Report typos directly inside any flashcard screen.",
    color: "linear-gradient(135deg, #f12711 0%, #f5af19 100%)",
    actionText: "Contact Us"
  }
];

const mockCourses = [
  {
    id: "course-1",
    title: "English Vocabulary Masterclass",
    description: "Learn high-frequency English words used in IELTS and TOEFL exams.",
    category: "Languages",
    cardCount: 12,
    price: 0,
    isPaid: false,
    purchased: true,
    downloaded: true,
    progress: 40 // %
  },
  {
    id: "course-2",
    title: "German A1 Starter Pack",
    description: "Essential German vocabulary, phrases, and pronunciations.",
    category: "Languages",
    cardCount: 6,
    price: 0,
    isPaid: false,
    purchased: true,
    downloaded: true,
    progress: 75
  },
  {
    id: "course-3",
    title: "Advanced Persian Grammar",
    description: "Deep dive into Persian sentence structure, poetry, and classical scripts.",
    category: "Literature",
    cardCount: 10,
    price: 29.99,
    isPaid: true,
    purchased: true,
    downloaded: false,
    progress: 0
  },
  {
    id: "course-4",
    title: "Core Flutter & Dart Development",
    description: "Build beautiful native iOS and Android apps from a single codebase.",
    category: "Programming",
    cardCount: 15,
    price: 49.99,
    isPaid: true,
    purchased: false,
    downloaded: false,
    progress: 0
  }
];

const mockCards = [
  // English Masterclass Cards
  {
    id: "card-e1",
    courseId: "course-1",
    cardNumber: 1,
    box: 1,
    question: "What is the meaning of the word 'Ephemeral'?",
    answer: "Lasting for a very short time; transient or fleeting.",
    imageUrl: "", // No image
    audioUrl: "", // No audio
    favorite: false
  },
  {
    id: "card-e2",
    courseId: "course-1",
    cardNumber: 2,
    box: 1,
    question: "Identify the word: 'Showing great care and perseverance.'",
    answer: "Assiduous",
    imageUrl: "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=300&auto=format&fit=crop&q=60", // Image
    audioUrl: "dummy_audio_file.mp3", // Audio available
    favorite: false
  },
  {
    id: "card-e3",
    courseId: "course-1",
    cardNumber: 3,
    box: 2, // Active Box (requires due check)
    question: "What does 'Loquacious' mean?",
    answer: "Tending to talk a great deal; extremely talkative.",
    imageUrl: "",
    audioUrl: "loquacious_pronounce.mp3",
    favorite: true
  },
  {
    id: "card-e4",
    courseId: "course-1",
    cardNumber: 4,
    box: 2,
    question: "Define the term 'Alacrity'.",
    answer: "Brisk and cheerful readiness; eagerness.",
    imageUrl: "https://images.unsplash.com/photo-1472289065668-ce650ac443d2?w=300&auto=format&fit=crop&q=60",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e5",
    courseId: "course-1",
    cardNumber: 5,
    box: 3,
    question: "What is the meaning of 'Capricious'?",
    answer: "Given to sudden and unaccountable changes of mood or behavior.",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e6",
    courseId: "course-1",
    cardNumber: 6,
    box: 3,
    question: "Match: 'To make something bad or unsatisfactory better.'",
    answer: "Ameliorate",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e7",
    courseId: "course-1",
    cardNumber: 7,
    box: 4,
    question: "What is the definition of 'Equanimity'?",
    answer: "Mental calmness, composure, and evenness of temper, especially in a difficult situation.",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e8",
    courseId: "course-1",
    cardNumber: 8,
    box: 4,
    question: "What does 'Fastidious' mean?",
    answer: "Very attentive to and concerned about accuracy and detail; very concerned about cleanliness.",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e9",
    courseId: "course-1",
    cardNumber: 9,
    box: 5,
    question: "Define the verb 'Obfuscate'.",
    answer: "To render obscure, unclear, or unintelligible.",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e10",
    courseId: "course-1",
    cardNumber: 10,
    box: 5,
    question: "What is the noun form of the word 'Pernicious'?",
    answer: "Perniciousness (meaning the quality of being harmful or destructive).",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e11",
    courseId: "course-1",
    cardNumber: 11,
    box: 6, // Finished
    question: "What does 'Sycophant' mean?",
    answer: "A person who acts obsequiously toward someone important in order to gain advantage; a flatterer.",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-e12",
    courseId: "course-1",
    cardNumber: 12,
    box: 6, // Finished
    question: "Define 'Taciturn'.",
    answer: "(Of a person) reserved or uncommunicative in speech; saying little.",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },

  // German A1 Starter Pack Cards
  {
    id: "card-g1",
    courseId: "course-2",
    cardNumber: 1,
    box: 1,
    question: "How do you say 'Good Morning' in German?",
    answer: "Guten Morgen",
    imageUrl: "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=300&auto=format&fit=crop&q=60",
    audioUrl: "guten_morgen.mp3",
    favorite: false
  },
  {
    id: "card-g2",
    courseId: "course-2",
    cardNumber: 2,
    box: 1,
    question: "Translate: 'Thank you very much'",
    answer: "Vielen Dank",
    imageUrl: "",
    audioUrl: "vielen_dank.mp3",
    favorite: false
  },
  {
    id: "card-g3",
    courseId: "course-2",
    cardNumber: 3,
    box: 3,
    question: "What does the German word 'Apfel' mean?",
    answer: "Apple",
    imageUrl: "https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=300&auto=format&fit=crop&q=60",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-g4",
    courseId: "course-2",
    cardNumber: 4,
    box: 4,
    question: "Translate the pronoun: 'She'",
    answer: "sie",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-g5",
    courseId: "course-2",
    cardNumber: 5,
    box: 6, // Finished
    question: "What is 'The library' in German?",
    answer: "Die Bibliothek",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  },
  {
    id: "card-g6",
    courseId: "course-2",
    cardNumber: 6,
    box: 6, // Finished
    question: "Translate: 'Please'",
    answer: "Bitte",
    imageUrl: "",
    audioUrl: "",
    favorite: false
  }
];

const mockNotifications = [
  {
    id: 1,
    title: "Welcome to Leitner Learning!",
    content: "Start by navigating to the Courses Catalog, choosing a free course, and downloading it to study offline.",
    timestamp: "2026-06-21T01:00:00Z"
  },
  {
    id: 2,
    title: "System Update: SQLite Schema Version 2",
    content: "Local course database files have been optimized. Sync speeds are now 40% faster.",
    timestamp: "2026-06-20T18:30:00Z"
  },
  {
    id: 3,
    title: "Reminder: Review Box 1 Cards",
    content: "You have 2 cards in Box 1 waiting for review. Overdue cards will reset to Box 1 if not reviewed today!",
    timestamp: "2026-06-20T10:00:00Z"
  }
];

const onboardingSteps = [
  {
    target: "nav-courses",
    title: "1. Courses Catalog",
    text: "Access all available study materials here. Downloaded items appear at the top.",
    arrowDirection: "down"
  },
  {
    target: "search-input",
    title: "2. Search System",
    text: "Find specific courses quickly, then query matching cards inside them.",
    arrowDirection: "up"
  },
  {
    target: "card-scene-inner",
    title: "3. Flashcard View",
    text: "Tap the center card to flip it and reveal the answer, support files, and translations.",
    arrowDirection: "up"
  },
  {
    target: "btn-know",
    title: "4. Know Button",
    text: "Tap 'Know' if you remembered correctly. This advances the card to the next box (e.g. Box 1 to 2).",
    arrowDirection: "down"
  },
  {
    target: "btn-dontknow",
    title: "5. Don't Know Button",
    text: "Tap 'Don't Know' if you forgot. This resets the card's progress immediately back to Box 1.",
    arrowDirection: "down"
  },
  {
    target: "menu-create-card",
    title: "6. Create Card",
    text: "Author custom study items stored securely, only on your local device.",
    arrowDirection: "left"
  },
  {
    target: "dash-shortcut-finished",
    title: "7. Finished Cards",
    text: "Displays all mastered cards that successfully navigated all 5 Leitner stages.",
    arrowDirection: "left"
  },
  {
    target: "dash-shortcut-favorites",
    title: "8. Favorites",
    text: "View bookmarked cards. Opening a card from here resets it to Box 1 after confirmation.",
    arrowDirection: "left"
  },
  {
    target: "courses-tab-my",
    title: "9. My Courses Screen",
    text: "Displays only your purchased and fully downloaded courses, outlined in green.",
    arrowDirection: "up"
  },
  {
    target: "btn-report-typo",
    title: "10. Reports System",
    text: "Submit feedback, content typos, or correction inquiries directly to administrators.",
    arrowDirection: "up"
  },
  {
    target: "dash-shortcut-today",
    title: "11. Today's Reviews",
    text: "Shows the pending count of items due for recall check-ins today.",
    arrowDirection: "left"
  },
  {
    target: "menu-stats",
    title: "12. Statistics Hub",
    text: "Analyze study analytics. Boxes are color-coded: Orange (1), Yellow (2), Green (3), Blue (4), Purple (5), Gold (Finished).",
    arrowDirection: "left"
  }
];
