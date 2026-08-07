// Application Logic for Leitner Learning Platform Interactive Prototype

// --- State Configurations ---
let appState = {
  isAuthenticated: false,
  termsAccepted: false,
  profileCompleted: false,
  onboardingCompleted: false,
  userProfile: {
    username: "",
    interests: "",
    educationalField: "",
    educationalLevel: "",
    mobileNumber: "+98 912 345 6789" // Strictly Read-Only
  },
  courses: JSON.parse(JSON.stringify(mockCourses)), // Deep copy mock databases
  cards: JSON.parse(JSON.stringify(mockCards)),
  currentScreen: "screen-otp",
  activeCourseId: "course-1",
  activeCardIndex: 0,
  isOffline: false,
  currentOnboardingStep: 0,
  carouselIndex: 0,
  carouselTimer: null,
  otpTimer: null,
  otpSeconds: 120
};

// --- DOM References ---
const screens = {
  otp: document.getElementById("screen-otp"),
  terms: document.getElementById("screen-terms"),
  profile: document.getElementById("screen-profile"),
  home: document.getElementById("screen-home"),
  courses: document.getElementById("screen-courses"),
  flashcard: document.getElementById("screen-flashcard"),
  favorites: document.getElementById("screen-favorites"),
  statistics: document.getElementById("screen-statistics"),
  notifications: document.getElementById("screen-notifications"),
  createCard: document.getElementById("screen-create-card"),
  settings: document.getElementById("screen-settings"),
  support: document.getElementById("screen-support"),
  finishedCards: document.getElementById("screen-finished-cards"),
  todaysReviews: document.getElementById("screen-todays-reviews")
};

const bottomNav = document.getElementById("bottom-nav");
const networkBanner = document.getElementById("network-banner");

// --- View Router & Screen Controller ---
function showScreen(screenId) {
  appState.currentScreen = screenId;
  
  // Hide all screens
  Object.values(screens).forEach(screen => {
    if (screen) screen.classList.remove("active");
  });

  // Activate target
  const targetScreen = document.getElementById(screenId);
  if (targetScreen) targetScreen.classList.add("active");

  // Bottom Navigation Visibility
  const noNavScreens = ["screen-otp", "screen-terms", "screen-profile"];
  if (noNavScreens.includes(screenId)) {
    bottomNav.classList.remove("visible");
  } else {
    bottomNav.classList.add("visible");
    updateNavTabsHighlight(screenId);
  }

  // Hook Screen Specific Init Logic
  if (screenId === "screen-home") {
    initHomeCarousel();
    renderDashboardStats();
  } else {
    clearInterval(appState.carouselTimer);
  }

  if (screenId === "screen-courses") {
    renderCoursesCatalog();
  }

  if (screenId === "screen-flashcard") {
    renderFlashcard();
  }

  if (screenId === "screen-favorites") {
    renderFavorites();
  }

  if (screenId === "screen-statistics") {
    renderStatistics();
  }

  if (screenId === "screen-notifications") {
    renderNotifications();
  }

  if (screenId === "screen-finished-cards") {
    renderFinishedCards();
  }

  if (screenId === "screen-todays-reviews") {
    renderTodaysReviewsList();
  }
}

function updateNavTabsHighlight(screenId) {
  document.querySelectorAll(".nav-tab").forEach(tab => {
    tab.classList.remove("active");
  });

  if (screenId === "screen-home") {
    document.getElementById("nav-home").classList.add("active");
  } else if (screenId === "screen-flashcard" || screenId === "screen-todays-reviews") {
    document.getElementById("nav-review").classList.add("active");
  } else if (screenId === "screen-courses" || screenId === "screen-my-courses") {
    document.getElementById("nav-courses").classList.add("active");
  }
}

// --- OTP Logic ---
function startOtpTimer() {
  clearInterval(appState.otpTimer);
  appState.otpSeconds = 120;
  const timerSpan = document.getElementById("otp-countdown");
  
  appState.otpTimer = setInterval(() => {
    appState.otpSeconds--;
    if (appState.otpSeconds <= 0) {
      clearInterval(appState.otpTimer);
      timerSpan.textContent = "Expired";
    } else {
      const mins = Math.floor(appState.otpSeconds / 60);
      const secs = appState.otpSeconds % 60;
      timerSpan.textContent = `${mins}:${secs.toString().padStart(2, '0')}`;
    }
  }, 1000);
}

function handleOtpInput() {
  const inputs = document.querySelectorAll(".otp-digit-input");
  inputs.forEach((input, index) => {
    input.addEventListener("input", (e) => {
      if (input.value.length === 1 && index < inputs.length - 1) {
        inputs[index + 1].focus();
      }
    });

    input.addEventListener("keydown", (e) => {
      if (e.key === "Backspace" && input.value.length === 0 && index > 0) {
        inputs[index - 1].focus();
      }
    });
  });
}

function verifyOtp() {
  const inputs = document.querySelectorAll(".otp-digit-input");
  let code = "";
  inputs.forEach(input => code += input.value);

  if (code.length < 5) {
    alert("Please enter the 5-digit verification code.");
    return;
  }

  appState.isAuthenticated = true;
  showScreen("screen-terms");
}

function resendOtp() {
  alert("Simulating sending a new OTP verification code via SMS...");
  startOtpTimer();
}

// --- Terms Acceptance ---
function proceedFromTerms() {
  const checkbox = document.getElementById("chk-terms-accept");
  if (!checkbox.checked) {
    alert("You must read and accept the terms and rules to proceed.");
    return;
  }
  appState.termsAccepted = true;
  showScreen("screen-profile");
}

// --- Profile Completion ---
function saveUserProfile(e) {
  if (e) e.preventDefault();
  const username = document.getElementById("profile-username").value.trim();
  const interests = document.getElementById("profile-interests").value.trim();
  const field = document.getElementById("profile-field").value.trim();
  const level = document.getElementById("profile-level").value.trim();

  if (!username) {
    alert("Username is required.");
    return;
  }

  appState.userProfile.username = username;
  appState.userProfile.interests = interests;
  appState.userProfile.educationalField = field;
  appState.userProfile.educationalLevel = level;
  appState.profileCompleted = true;

  document.getElementById("dash-username").textContent = username;

  // Start Guided Onboarding
  startGuidedOnboarding();
}

// --- Onboarding Tutorial sequence ---
function startGuidedOnboarding() {
  appState.currentOnboardingStep = 0;
  // Make sure we go to Course List Catalog first because tutorial step 1 is highlighted there
  showScreen("screen-courses");
  document.getElementById("courses-tab-catalog").click(); // Trigger Catalog tab
  
  const overlay = document.getElementById("onboarding-overlay");
  overlay.style.display = "block";
  renderOnboardingStep();
}

function renderOnboardingStep() {
  const step = onboardingSteps[appState.currentOnboardingStep];
  
  // Force screen navigation to ensure the target element is visible and rendered
  if (step.target === "card-scene-inner" || step.target === "btn-know" || step.target === "btn-dontknow" || step.target === "btn-report-typo") {
    showScreen("screen-flashcard");
  } else if (step.target === "menu-create-card" || step.target === "dash-shortcut-finished" || step.target === "dash-shortcut-favorites" || step.target === "dash-shortcut-today" || step.target === "menu-stats") {
    showScreen("screen-home");
  } else if (step.target === "courses-tab-my") {
    showScreen("screen-courses");
    document.getElementById("courses-tab-my").click();
  } else if (step.target === "nav-courses" || step.target === "search-input") {
    showScreen("screen-courses");
    document.getElementById("courses-tab-catalog").click();
  }

  const targetEl = document.getElementById(step.target);
  const highlight = document.getElementById("onboarding-highlight");
  const tooltip = document.getElementById("onboarding-tooltip");
  
  if (!targetEl) {
    // Defer alignment to let the screen render
    setTimeout(renderOnboardingStep, 100);
    return;
  }

  // Calculate coordinates relative to simulator frame
  const frameRect = document.querySelector(".simulator-frame").getBoundingClientRect();
  const targetRect = targetEl.getBoundingClientRect();

  const top = targetRect.top - frameRect.top;
  const left = targetRect.left - frameRect.left;
  const width = targetRect.width;
  const height = targetRect.height;

  // Position highlight
  highlight.style.top = `${top - 4}px`;
  highlight.style.left = `${left - 4}px`;
  highlight.style.width = `${width + 8}px`;
  highlight.style.height = `${height + 8}px`;

  // Update Tooltip Title & Text
  document.getElementById("onboarding-title").textContent = step.title;
  document.getElementById("onboarding-text").textContent = step.text;

  // Position tooltip relative to target
  let tooltipTop = top + height + 10;
  let tooltipLeft = left + (width / 2) - 120; // 120 is half tooltip width

  // Bound checks to ensure tooltip stays inside screen
  if (tooltipLeft < 10) tooltipLeft = 10;
  if (tooltipLeft + 240 > 344) tooltipLeft = 344 - 240;

  if (tooltipTop + 130 > 700) {
    // Show tooltip above target instead
    tooltipTop = top - 130 - 10;
  }

  tooltip.style.top = `${tooltipTop}px`;
  tooltip.style.left = `${tooltipLeft}px`;
}

function nextOnboardingStep() {
  appState.currentOnboardingStep++;
  if (appState.currentOnboardingStep >= onboardingSteps.length) {
    completeOnboarding();
  } else {
    renderOnboardingStep();
  }
}

function completeOnboarding() {
  document.getElementById("onboarding-overlay").style.display = "none";
  appState.onboardingCompleted = true;
  showScreen("screen-home");
}

// --- Home Carousel Banners ---
function initHomeCarousel() {
  clearInterval(appState.carouselTimer);
  const container = document.getElementById("carousel-slides-wrapper");
  const dotsContainer = document.getElementById("carousel-dots");
  
  container.innerHTML = "";
  dotsContainer.innerHTML = "";

  mockBanners.slice(0, 5).forEach((banner, index) => {
    // Create Slide
    const slide = document.createElement("div");
    slide.className = `carousel-slide ${index === 0 ? 'active' : ''}`;
    slide.style.background = banner.color;
    slide.innerHTML = `
      <div>
        <h4>${banner.title}</h4>
        <p>${banner.subtitle}</p>
      </div>
      <button onclick="handleBannerAction(${banner.id})">${banner.actionText}</button>
    `;
    container.appendChild(slide);

    // Create Dot
    const dot = document.createElement("div");
    dot.className = `indicator-dot ${index === 0 ? 'active' : ''}`;
    dotsContainer.appendChild(dot);
  });

  appState.carouselIndex = 0;
  appState.carouselTimer = setInterval(rotateCarousel, 4000);
}

function rotateCarousel() {
  const slides = document.querySelectorAll(".carousel-slide");
  const dots = document.querySelectorAll(".indicator-dot");
  if (slides.length === 0) return;

  slides[appState.carouselIndex].classList.remove("active");
  dots[appState.carouselIndex].classList.remove("active");

  appState.carouselIndex = (appState.carouselIndex + 1) % slides.length;

  slides[appState.carouselIndex].classList.add("active");
  dots[appState.carouselIndex].classList.add("active");
}

function handleBannerAction(id) {
  if (id === 1) {
    showScreen("screen-todays-reviews");
  } else if (id === 2) {
    showScreen("screen-courses");
    document.getElementById("courses-tab-my").click();
  } else if (id === 3) {
    showScreen("screen-courses");
    document.getElementById("courses-tab-catalog").click();
  } else if (id === 4) {
    showScreen("screen-statistics");
  } else {
    showScreen("screen-support");
  }
}

// --- Dashboard Statistics & Badges ---
function renderDashboardStats() {
  // Calculate badges
  const dueReviews = appState.cards.filter(c => c.box >= 1 && c.box <= 5).length; // Simulate review counts
  const finishedCount = appState.cards.filter(c => c.box === 6).length;

  document.getElementById("dash-badge-today").textContent = dueReviews;
  document.getElementById("dash-badge-finished").textContent = finishedCount;
  
  // Set tab badges
  const reviewTabBadge = document.getElementById("tab-badge-review");
  if (dueReviews > 0) {
    reviewTabBadge.style.display = "block";
    reviewTabBadge.textContent = dueReviews;
  } else {
    reviewTabBadge.style.display = "none";
  }

  // Dashboard counts
  document.getElementById("dash-count-today").textContent = dueReviews;
  document.getElementById("dash-count-finished").textContent = finishedCount;

  // Favorites Count
  const favCount = appState.cards.filter(c => c.favorite).length;
  document.getElementById("dash-count-favorites").textContent = favCount;
}

// --- Course Catalog Renderers ---
function renderCoursesCatalog(filterType = "catalog") {
  const container = document.getElementById("course-list-container");
  const offlineWrapper = document.getElementById("offline-notice-wrapper");
  container.innerHTML = "";

  if (appState.isOffline) {
    offlineWrapper.innerHTML = `
      <div class="offline-notice-box">
        <i class="fa-solid fa-cloud-bolt"></i>
        <h5>Working Offline</h5>
        <p>No internet connection available. Displays previously downloaded offline courses only.</p>
      </div>
    `;
  } else {
    offlineWrapper.innerHTML = "";
  }

  // Filter lists
  let filtered = appState.courses;
  if (filterType === "my") {
    // Only purchased and downloaded
    filtered = appState.courses.filter(c => c.purchased && c.downloaded);
  } else {
    if (appState.isOffline) {
      // Offline mode limits view to downloaded courses
      filtered = appState.courses.filter(c => c.downloaded);
    }
  }

  // Sort: Downloaded/Purchased courses always at the top
  filtered.sort((a, b) => {
    const aVal = (a.downloaded && a.purchased) ? 1 : 0;
    const bVal = (b.downloaded && b.purchased) ? 1 : 0;
    return bVal - aVal;
  });

  if (filtered.length === 0) {
    container.innerHTML = `<div class="empty-list-indicator" style="text-align:center; padding:20px; font-size:12px; color:var(--text-muted);">No courses found.</div>`;
    return;
  }

  filtered.forEach(course => {
    const cardElement = document.createElement("div");
    
    // Strict Border Classes
    const borderClass = course.downloaded ? "downloaded" : "undownloaded";
    
    cardElement.className = `course-item ${borderClass}`;
    cardElement.innerHTML = `
      <div class="course-item-header">
        <div class="course-item-title">${course.title}</div>
        <div class="course-item-badge ${course.isPaid ? 'paid' : 'free'}">${course.isPaid ? 'Paid' : 'Free'}</div>
      </div>
      <div style="font-size: 11px; color: var(--text-muted); line-height: 1.3;">${course.description}</div>
      <div class="course-item-meta">
        <span><i class="fa-solid fa-layer-group"></i> ${course.cardCount} Cards</span>
        ${renderCourseButton(course)}
      </div>
    `;
    
    // Clickable card navigates to flashcards if downloaded
    cardElement.addEventListener("click", (e) => {
      if (e.target.tagName === "BUTTON") return;
      if (course.downloaded) {
        appState.activeCourseId = course.id;
        // Set index to first card of this course
        const firstCardIdx = appState.cards.findIndex(c => c.courseId === course.id);
        if (firstCardIdx !== -1) {
          appState.activeCardIndex = firstCardIdx;
          showScreen("screen-flashcard");
        } else {
          alert("This course has no flashcards.");
        }
      } else {
        alert("Please download or purchase the course first to review cards.");
      }
    });

    container.appendChild(cardElement);
  });
}

function renderCourseButton(course) {
  if (course.downloaded) {
    return `<button class="btn-course-action" onclick="alert('Course is already downloaded and ready!')"><i class="fa-solid fa-circle-check" style="color:var(--leitner-green)"></i> Study</button>`;
  }

  if (course.purchased && !course.downloaded) {
    return `<button class="btn-course-action download-trigger" onclick="downloadCourse('${course.id}')"><i class="fa-solid fa-arrow-down-to-bracket"></i> Download</button>`;
  }

  // Not Purchased
  return `<button class="btn-course-action download-trigger" onclick="purchaseCourse('${course.id}')"><i class="fa-solid fa-cart-shopping"></i> Buy ($${course.price})</button>`;
}

function purchaseCourse(id) {
  if (appState.isOffline) {
    alert("Connection error: Unable to purchase courses while offline.");
    return;
  }

  const course = appState.courses.find(c => c.id === id);
  if (course) {
    const confirmBuy = confirm(`Simulating Store Checkout gateway interface.\nWould you like to buy "${course.title}" for $${course.price}?`);
    if (confirmBuy) {
      course.purchased = true;
      alert(`Success! "${course.title}" purchase receipt verified.\nYou can now download the course.`);
      renderCoursesCatalog();
    }
  }
}

function downloadCourse(id) {
  if (appState.isOffline) {
    alert("Connection error: Unable to download course package while offline.");
    return;
  }

  const course = appState.courses.find(c => c.id === id);
  if (course) {
    alert(`Downloading encrypted course package for "${course.title}"...\nDecrypting and performing SQLite schema integrations...`);
    course.downloaded = true;
    alert(`Course package "${course.title}" downloaded and decrypted locally.`);
    renderCoursesCatalog();
  }
}

function filterCoursesTab(type, btn) {
  document.querySelectorAll(".tab-header").forEach(b => b.classList.remove("active"));
  btn.classList.add("active");
  renderCoursesCatalog(type);
}

// --- Flashcard Review Screen Renderers ---
function renderFlashcard() {
  const activeCard = appState.cards[appState.activeCardIndex];
  if (!activeCard) {
    alert("No active card found.");
    showScreen("screen-home");
    return;
  }

  const course = appState.courses.find(c => c.id === activeCard.courseId);
  document.getElementById("card-course-title").textContent = course ? course.title : "Course Deck";

  // Card Box stages classes
  const boxIndicator = document.getElementById("card-box-indicator");
  boxIndicator.className = `leitner-box-indicator stage-${activeCard.box}`;
  boxIndicator.textContent = activeCard.box === 6 ? "Finished" : `Box ${activeCard.box}`;

  // Update card counter text
  // Find index relative to course cards
  const courseCards = appState.cards.filter(c => c.courseId === activeCard.courseId);
  const relativeIdx = courseCards.findIndex(c => c.id === activeCard.id) + 1;
  document.getElementById("card-index-trigger").textContent = `Card ${relativeIdx}/${courseCards.length}`;

  // Star bookmark toggle
  const favBtn = document.getElementById("card-fav-star");
  if (activeCard.favorite) {
    favBtn.className = "fa-solid fa-star card-fav-btn active";
  } else {
    favBtn.className = "fa-regular fa-star card-fav-btn";
  }

  // Render Front & Back content
  const cardFront = document.getElementById("card-front-content");
  const cardBack = document.getElementById("card-back-content");

  // Conditional Rendering Rules: If no image, no audio, collapse containers
  const imgHtml = activeCard.imageUrl ? `<div class="card-image-box"><img src="${activeCard.imageUrl}" alt="Flashcard visual description"></div>` : '';
  const audioHtml = activeCard.audioUrl ? `<button class="card-audio-btn" onclick="playAudioText('${activeCard.id}')"><i class="fa-solid fa-volume-high"></i></button>` : '';

  cardFront.innerHTML = `
    <div class="card-content-wrapper" id="card-review-indicator">
      ${imgHtml}
      <div class="card-question">${activeCard.question}</div>
      ${audioHtml}
    </div>
    <div class="flip-hint-badge"><i class="fa-solid fa-rotate"></i> Tap to flip</div>
  `;

  cardBack.innerHTML = `
    <div class="card-content-wrapper">
      <div style="font-size:10px; color:var(--primary-accent); font-weight:700; text-transform:uppercase;">Correct Answer</div>
      <div class="card-answer">${activeCard.answer}</div>
    </div>
    <div class="flip-hint-badge"><i class="fa-solid fa-rotate"></i> Tap to flip</div>
  `;

  // Always reset flip state back to front
  document.getElementById("card-scene-inner").classList.remove("flipped");
}

function toggleCardFlip() {
  document.getElementById("card-scene-inner").classList.toggle("flipped");
}

function playAudioText(id) {
  alert("🎵 Playing local decrypted course audio pronunciation file...");
}

// Bookmark toggler
function toggleCardFavorite() {
  const activeCard = appState.cards[appState.activeCardIndex];
  if (activeCard) {
    activeCard.favorite = !activeCard.favorite;
    renderFlashcard();
  }
}

// Leitner know action (Advances Box + 1)
function submitCardReview(knewIt) {
  const activeCard = appState.cards[appState.activeCardIndex];
  if (!activeCard) return;

  if (knewIt) {
    // Know Button logic: Moves card box to next box
    const oldBox = activeCard.box;
    if (activeCard.box < 6) {
      activeCard.box += 1;
      alert(`Correct! Card progressed from Box ${oldBox} to ${activeCard.box === 6 ? 'Finished' : 'Box ' + activeCard.box}.`);
    } else {
      alert(`Card is already in the Finished deck.`);
    }
  } else {
    // Don't Know logic: Resets immediately to Box 1
    alert(`Incorrect! Card progress has been reset back to Box 1.`);
    activeCard.box = 1;
  }

  // Re-save stats & render next card
  renderDashboardStats();
  advanceCard(1);
}

function advanceCard(direction) {
  const activeCard = appState.cards[appState.activeCardIndex];
  const courseCards = appState.cards.filter(c => c.courseId === activeCard.courseId);
  const relativeIdx = courseCards.findIndex(c => c.id === activeCard.id);
  
  let newIdx = relativeIdx + direction;
  if (newIdx < 0) newIdx = courseCards.length - 1;
  if (newIdx >= courseCards.length) newIdx = 0;

  const targetCard = courseCards[newIdx];
  appState.activeCardIndex = appState.cards.findIndex(c => c.id === targetCard.id);
  renderFlashcard();
}

// Jump To Card modal trigger
function triggerJumpToCardModal() {
  const modal = document.getElementById("modal-jump");
  modal.style.display = "flex";
  document.getElementById("jump-card-number-input").value = "";
  document.getElementById("jump-card-number-input").focus();
}

function closeJumpToModal() {
  document.getElementById("modal-jump").style.display = "none";
}

function executeJumpToCard() {
  const inputVal = parseInt(document.getElementById("jump-card-number-input").value);
  const activeCard = appState.cards[appState.activeCardIndex];
  const courseCards = appState.cards.filter(c => c.courseId === activeCard.courseId);

  if (isNaN(inputVal) || inputVal < 1 || inputVal > courseCards.length) {
    alert(`Please enter a valid card number between 1 and ${courseCards.length}.`);
    return;
  }

  const targetCard = courseCards[inputVal - 1];
  
  // Rule C: Navigating directly. If card in active boxes (Boxes 2–5), prompt warning reset
  if (targetCard.box >= 2 && targetCard.box <= 5) {
    const confirmReset = confirm(`WARNING!\nCard ${inputVal} is currently in Box ${targetCard.box}.\nJumping directly to it will reset its Leitner stage back to Box 1.\nDo you want to proceed?`);
    if (!confirmReset) {
      closeJumpToModal();
      return;
    }
    // Proceed reset
    targetCard.box = 1;
    renderDashboardStats();
  }

  // Perform Jump
  appState.activeCardIndex = appState.cards.findIndex(c => c.id === targetCard.id);
  closeJumpToModal();
  renderFlashcard();
}

// --- Favorites Screen Renderers ---
function renderFavorites() {
  const container = document.getElementById("favorites-list");
  container.innerHTML = "";

  const favCards = appState.cards.filter(c => c.favorite);
  if (favCards.length === 0) {
    container.innerHTML = `<div class="empty-list-indicator" style="text-align:center; padding:30px; font-size:12px; color:var(--text-muted);">No bookmarked cards in favorites.</div>`;
    return;
  }

  favCards.forEach(card => {
    const item = document.createElement("div");
    item.className = "settings-item";
    item.innerHTML = `
      <div style="text-align:left;">
        <div style="font-weight:700; font-size:12px;">Q: ${card.question.substring(0, 30)}...</div>
        <div style="font-size:10px; color:var(--text-muted);">Box stage: ${card.box === 6 ? 'Finished' : 'Box ' + card.box}</div>
      </div>
      <i class="fa-solid fa-angle-right" style="color:var(--text-muted)"></i>
    `;

    // Rule B: Viewing card from Favorites resets stage to Box 1 after warning
    item.addEventListener("click", () => {
      const confirmReset = confirm(`WARNING!\nReviewing this card from the favorites list will reset its Leitner stage to Box 1.\nDo you want to proceed?`);
      if (confirmReset) {
        card.box = 1;
        renderDashboardStats();
        
        // Open this card in study view
        appState.activeCardIndex = appState.cards.findIndex(c => c.id === card.id);
        showScreen("screen-flashcard");
      }
    });

    container.appendChild(item);
  });
}

// --- Finished Cards Screen Renderer ---
function renderFinishedCards() {
  const container = document.getElementById("finished-cards-list");
  const countSpan = document.getElementById("finished-cards-count");
  container.innerHTML = "";

  const finished = appState.cards.filter(c => c.box === 6);
  countSpan.textContent = finished.length;

  if (finished.length === 0) {
    container.innerHTML = `<div class="empty-list-indicator" style="text-align:center; padding:30px; font-size:12px; color:var(--text-muted);">You haven't completed any flashcards yet. Keep studying!</div>`;
    return;
  }

  finished.forEach(card => {
    const item = document.createElement("div");
    item.className = "course-item";
    item.style.border = `1px solid var(--border-color)`;
    item.innerHTML = `
      <div style="text-align:left;">
        <div style="font-weight:700; font-size:12px; margin-bottom:4px;">Q: ${card.question}</div>
        <div style="font-size:11px; color:var(--text-muted); margin-bottom:10px;">A: ${card.answer}</div>
      </div>
      <div style="display:flex; gap:10px;">
        <button class="btn-course-action" style="flex:1; border-color:var(--leitner-green); color:var(--leitner-green);" onclick="finishedCardsAction('${card.id}', true)">Know it (No Action)</button>
        <button class="btn-course-action" style="flex:1; border-color:var(--leitner-orange); color:var(--leitner-orange);" onclick="finishedCardsAction('${card.id}', false)">Don't Know (Reset to 1)</button>
      </div>
    `;
    container.appendChild(item);
  });
}

function finishedCardsAction(id, knewIt) {
  const card = appState.cards.find(c => c.id === id);
  if (!card) return;

  if (knewIt) {
    // "Know It" does nothing
    alert("Card remains in the Finished deck.");
  } else {
    // "Don't Know" resets the card's progress back to Box 1
    card.box = 1;
    alert("Card progress reset back to Box 1.");
    renderDashboardStats();
    renderFinishedCards();
  }
}

// --- Today's Reviews Screen Renderer ---
function renderTodaysReviewsList() {
  const container = document.getElementById("todays-reviews-list");
  const countSpan = document.getElementById("todays-reviews-count");
  container.innerHTML = "";

  // Cards in active Leitner boxes are simulated as due today
  const due = appState.cards.filter(c => c.box >= 1 && c.box <= 5);
  countSpan.textContent = due.length;

  if (due.length === 0) {
    container.innerHTML = `<div class="empty-list-indicator" style="text-align:center; padding:30px; font-size:12px; color:var(--text-muted);">Hooray! No cards due for review today.</div>`;
    return;
  }

  due.forEach(card => {
    const course = appState.courses.find(c => c.id === card.courseId);
    const item = document.createElement("div");
    item.className = "settings-item";
    item.innerHTML = `
      <div style="text-align:left; max-width:80%;">
        <div style="font-weight:700; font-size:12px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">Q: ${card.question}</div>
        <div style="font-size:10px; color:var(--text-muted);">${course ? course.title : ''} • Stage: Box ${card.box}</div>
      </div>
      <i class="fa-solid fa-angle-right" style="color:var(--text-muted)"></i>
    `;

    item.addEventListener("click", () => {
      appState.activeCardIndex = appState.cards.findIndex(c => c.id === card.id);
      showScreen("screen-flashcard");
    });

    container.appendChild(item);
  });
}

// --- Create Custom Card Screen ---
function saveCustomCard(e) {
  if (e) e.preventDefault();
  const q = document.getElementById("new-card-question").value.trim();
  const a = document.getElementById("new-card-answer").value.trim();

  if (!q || !a) {
    alert("Both Question and Answer are required.");
    return;
  }

  // Custom user cards are stored locally in simulated SQLite
  const newCard = {
    id: `custom-${Date.now()}`,
    courseId: "course-1", // Add to local default deck
    cardNumber: appState.cards.length + 1,
    box: 1, // Created cards start in Box 1
    question: q,
    answer: a,
    imageUrl: "",
    audioUrl: "",
    favorite: false,
    isCustom: true
  };

  appState.cards.push(newCard);
  alert("Custom card saved locally on device successfully!");
  
  // Reset Form fields
  document.getElementById("new-card-question").value = "";
  document.getElementById("new-card-answer").value = "";

  renderDashboardStats();
  showScreen("screen-home");
}

// --- Statistics Screen Renderers (Color Mapping) ---
function renderStatistics() {
  const stats = {
    box1: appState.cards.filter(c => c.box === 1).length,
    box2: appState.cards.filter(c => c.box === 2).length,
    box3: appState.cards.filter(c => c.box === 3).length,
    box4: appState.cards.filter(c => c.box === 4).length,
    box5: appState.cards.filter(c => c.box === 5).length,
    finished: appState.cards.filter(c => c.box === 6).length
  };

  const total = appState.cards.length;

  // Render metrics labels
  document.getElementById("stats-total-cards").textContent = total;
  const accuracy = Math.round(((stats.box2 + stats.box3 + stats.box4 + stats.box5 + stats.finished) / total) * 100);
  document.getElementById("stats-accuracy").textContent = `${accuracy}%`;

  // Helper function to update bar widths
  updateSingleStatBar("stats-bar-b1", stats.box1, total, "var(--leitner-orange)");
  updateSingleStatBar("stats-bar-b2", stats.box2, total, "var(--leitner-yellow)");
  updateSingleStatBar("stats-bar-b3", stats.box3, total, "var(--leitner-green)");
  updateSingleStatBar("stats-bar-b4", stats.box4, total, "var(--leitner-blue)");
  updateSingleStatBar("stats-bar-b5", stats.box5, total, "var(--leitner-purple)");
  updateSingleStatBar("stats-bar-finished", stats.finished, total, "var(--leitner-gold)");
}

function updateSingleStatBar(elementId, count, total, colorHex) {
  const percentage = total > 0 ? (count / total) * 100 : 0;
  const fillNode = document.getElementById(elementId);
  if (fillNode) {
    fillNode.style.width = `${percentage}%`;
    fillNode.style.background = colorHex;
    fillNode.parentElement.previousElementSibling.lastElementChild.textContent = `${count} cards (${Math.round(percentage)}%)`;
  }
}

// --- Notifications Renderer ---
function renderNotifications() {
  const container = document.getElementById("notifications-list");
  container.innerHTML = "";

  // Latest notifications at the top (mockNotifications is predefined as sorted newest-first)
  mockNotifications.forEach(notif => {
    const item = document.createElement("div");
    item.className = "notif-item";
    
    // Parse timestamp
    const date = new Date(notif.timestamp);
    const dateStr = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + ' - ' + date.toLocaleDateString();

    item.innerHTML = `
      <div class="notif-item-header">
        <span class="notif-item-title">${notif.title}</span>
        <span class="notif-item-time">${dateStr}</span>
      </div>
      <div class="notif-item-content">${notif.content}</div>
    `;
    container.appendChild(item);
  });
}

// --- Typo Content Reports Form ---
function submitCardReport(e) {
  if (e) e.preventDefault();
  const text = document.getElementById("report-issue-text").value.trim();
  if (!text) {
    alert("Please enter details describing the issue.");
    return;
  }

  alert("Typo report submitted successfully!\nRecord stored: User ID, Course, Card #, Report details, and current timestamp.");
  document.getElementById("report-issue-text").value = "";
  showScreen("screen-flashcard");
}

function openReportForActiveCard() {
  const activeCard = appState.cards[appState.activeCardIndex];
  if (activeCard) {
    showScreen("screen-support");
    const course = appState.courses.find(c => c.id === activeCard.courseId);
    const details = `Course: ${course ? course.title : activeCard.courseId}\nCard Reference Number: ${activeCard.cardNumber}\nQuestion Text: "${activeCard.question}"\n\n[Please enter typo corrections below]\n`;
    document.getElementById("report-issue-text").value = details;
  }
}

// --- Settings: Logout Dialog System ---
function triggerLogoutConfirmation() {
  const modal = document.getElementById("modal-logout");
  modal.style.display = "flex";
}

function closeLogoutModal() {
  document.getElementById("modal-logout").style.display = "none";
}

function executeLogout() {
  closeLogoutModal();
  
  // Clear State details
  appState.isAuthenticated = false;
  appState.termsAccepted = false;
  appState.profileCompleted = false;
  
  // Reset form inputs
  document.getElementById("profile-username").value = "";
  document.getElementById("profile-interests").value = "";
  document.getElementById("profile-field").value = "";
  document.getElementById("profile-level").value = "";
  
  // Empty OTP inputs
  document.querySelectorAll(".otp-digit-input").forEach(i => i.value = "");
  
  // Redirect back to Login Screen
  showScreen("screen-otp");
  startOtpTimer();
}

// --- Custom Control Console Functions ---
function setPrototypeTheme(themeName) {
  const body = document.body;
  const toggleHifi = document.getElementById("toggle-theme-hifi");
  const toggleWire = document.getElementById("toggle-theme-wireframe");

  if (themeName === "hifi") {
    body.classList.remove("theme-wireframe");
    body.classList.add("theme-hifi");
    toggleHifi.classList.add("active");
    toggleWire.classList.remove("active");
  } else {
    body.classList.remove("theme-hifi");
    body.classList.add("theme-wireframe");
    toggleWire.classList.add("active");
    toggleHifi.classList.remove("active");
  }
}

function setNetworkSimulation(status) {
  const toggleOn = document.getElementById("toggle-net-online");
  const toggleOff = document.getElementById("toggle-net-offline");
  const banner = document.getElementById("network-banner");

  if (status === "online") {
    appState.isOffline = false;
    toggleOn.classList.add("active");
    toggleOff.classList.remove("active");
    banner.style.display = "none";
  } else {
    appState.isOffline = true;
    toggleOff.classList.add("active");
    toggleOn.classList.remove("active");
    banner.style.display = "block";
  }

  // Refresh courses catalog if open
  if (appState.currentScreen === "screen-courses") {
    renderCoursesCatalog();
  }
}

function resetSimulationState() {
  if (confirm("Reset local simulation storage settings, onboarding logs, and customized card lists back to factory defaults?")) {
    appState.courses = JSON.parse(JSON.stringify(mockCourses));
    appState.cards = JSON.parse(JSON.stringify(mockCards));
    appState.isAuthenticated = false;
    appState.termsAccepted = false;
    appState.profileCompleted = false;
    
    document.querySelectorAll(".otp-digit-input").forEach(i => i.value = "");
    document.getElementById("profile-username").value = "";
    document.getElementById("profile-interests").value = "";
    document.getElementById("profile-field").value = "";
    document.getElementById("profile-level").value = "";

    showScreen("screen-otp");
    startOtpTimer();
    renderDashboardStats();
    alert("Simulation state successfully restored.");
  }
}

function switchScreenDirect(screenId, btnEl) {
  if (btnEl) {
    document.querySelectorAll('.screen-chip').forEach(c => c.classList.remove('active'));
    btnEl.classList.add('active');
  }
  showScreen(screenId);
  if (screenId !== 'screen-otp' && screenId !== 'screen-terms' && screenId !== 'screen-profile') {
    if (bottomNav) bottomNav.style.display = 'flex';
  } else {
    if (bottomNav) bottomNav.style.display = 'none';
  }
}

// --- Window Lifecycle Hooks ---
window.addEventListener("DOMContentLoaded", () => {
  // Set default hi-fi theme
  setPrototypeTheme("hifi");
  setNetworkSimulation("online");
  
  // Init Event Triggers
  handleOtpInput();
  startOtpTimer();
  
  // Navigation Menu clicks
  document.getElementById("nav-home").addEventListener("click", () => showScreen("screen-home"));
  document.getElementById("nav-review").addEventListener("click", () => showScreen("screen-todays-reviews"));
  document.getElementById("nav-courses").addEventListener("click", () => showScreen("screen-courses"));
  
  // Dashboard shortcuts
  document.getElementById("dash-shortcut-today").addEventListener("click", () => showScreen("screen-todays-reviews"));
  document.getElementById("dash-shortcut-finished").addEventListener("click", () => showScreen("screen-finished-cards"));
  document.getElementById("dash-shortcut-favorites").addEventListener("click", () => showScreen("screen-favorites"));
  
  // Initial Screen set to Course Catalog
  showScreen("screen-courses");
  if (bottomNav) bottomNav.style.display = 'flex';
});
