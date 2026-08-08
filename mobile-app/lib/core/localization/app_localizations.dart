import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ?? AppLocalizations(const Locale('fa'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Leitner Platform',
      'enter_mobile_otp': 'Enter your mobile number to receive an OTP',
      'mobile_number': 'Mobile Number',
      'captcha_answer': 'CAPTCHA Answer',
      'send_verification_code': 'Send Verification Code',
      'verify_phone': 'Verify Phone Number',
      'enter_code_sent_to': 'Enter the 5-digit code sent to',
      'verify_and_continue': 'Verify & Continue',
      'resend_code': 'Resend Code',
      'enter_code_validation_error': 'Please enter the 5-digit verification code',
      'resend_code_in': 'Resend code in',
      'seconds': 'seconds',
      'terms_conditions': 'Terms & Conditions',
      'accept_terms_prompt': 'Please read and accept the terms to proceed.',
      'accept_and_continue': 'I Accept & Continue',
      'complete_profile': 'Complete Profile',
      'tell_us_profile': 'Tell us about yourself to personalize your studies',
      'mobile_readonly': 'Mobile Number (Read-only)',
      'username': 'Username',
      'interests': 'Interests',
      'educational_field': 'Educational Field',
      'educational_level': 'Educational Level',
      'save_enter_app': 'Save and Enter App',
      'save_profile': 'Save Profile',
      'welcome_back': 'Welcome back,',
      'custom_flashcards': 'Custom Flashcards',
      'create_custom_cards_desc': 'Create and study custom cards stored strictly on your device.',
      'quick_hub': 'Quick Hub',
      'home': 'Home',
      'review': 'Review',
      'courses': 'Courses',
      'leitner_learning': 'Leitner Learning',
      'my_courses': 'My Courses',
      'catalog': 'Catalog',
      'all_courses': 'All Courses',
      'ready_to_study': 'Ready to Study',
      'download_now': 'Download Now',
      'purchase': 'Purchase',
      'free': 'Free',
      'toman': 'Toman',
      'cards_count': 'Cards',
      'review_today': "Today's Cards",
      'finished_cards': 'Finished Cards',
      'custom_cards': 'Custom Cards',
      'favorites': 'Favorites',
      'reports': 'Reports',
      'statistics': 'Statistics',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'support': 'Support',
      'logout': 'Logout',
      'logout_confirm': 'Are you sure you want to log out?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'scheduled_maintenance': 'Scheduled Maintenance',
      'maintenance_msg': 'The platform is currently undergoing maintenance. Please try again later.',
      'security_alert': 'Security Alert',
      'jailbreak_detected': 'Device jailbreak or root detected. Access restricted for content protection.',
      'know': 'Know',
      'dont_know': "Don't Know",
      'box_1': 'Box 1',
      'box_2': 'Box 2',
      'box_3': 'Box 3',
      'box_4': 'Box 4',
      'box_5': 'Box 5',
      'box_6': 'Box 6',
      'finished': 'Finished',
      'language': 'Language / زبان',
      'persian': 'فارسی (Persian)',
      'english': 'English (انگلیسی)',
      'failed_load_banner': 'Failed to load banner',
      'could_not_open_banner': 'Could not open banner link.',
      'no_downloaded_courses': 'No downloaded courses found to browse favorites.',
      'select_course': 'Select Course',
      'banner_1_title': 'Spaced Repetition Mastery',
      'banner_1_sub': 'Study systematically to retain 90% of what you learn.',
      'banner_2_title': 'Offline Learning Active',
      'banner_2_sub': 'All your downloaded courses are stored securely offline.',
      'banner_3_title': 'Custom Flashcards',
      'banner_3_sub': 'Create and study custom cards stored strictly on your device.',
      'due_badge': 'Due',
      'total_cards_count': 'total cards',
      'start_study': 'Start Study',
      'no_downloaded_courses_title': 'No Downloaded Courses',
      'no_downloaded_courses_desc': 'Go to the Courses tab to download packages and start studying offline.',
      'profile_details': 'Profile Details',
      'update_profile': 'Update Profile',
      'about_us': 'About Us',
      'offline_backup_restore': 'Offline Backup & Restore',
      'backup_desc': 'Protect your database! Backups export your progress, custom cards, and favorites to an encrypted file.',
      'backup_encryption_password': 'Backup Encryption Password',
      'export_new_backup': 'Export New Encrypted Backup',
      'available_backups': 'Available Backups',
      'no_backups_found': 'No backup files found on device.',
      'logout_account': 'Log Out Account',
      'review_queue': 'Review Queue',
      'question_label': 'QUESTION',
      'answer_label': 'ANSWER',
      'i_know_it': 'I Know It',
      'direct_card_jump': 'Direct Card Jump',
      'enter_card_number_hint': 'Enter card number (e.g. 15)',
      'jump': 'Jump',
      'submit_report': 'Submit Content Report',
      'report_hint': 'Describe card typos, errors, or feedback here...',
      'submit': 'Submit',
      'warning': 'Warning',
      'jump_warning_msg': 'This card is currently in an active Leitner Box. Viewing it directly will reset its learning progress back to Box 1. Do you want to proceed?',
      'reset_and_jump': 'Reset & Jump',
      'study_loop_complete': 'Study Loop Complete!',
      'study_loop_complete_desc': 'You have reviewed all currently due cards in this course.',
      'back_to_courses': 'Back to Courses',
      'card_prefix': 'Card #',
      'favorite_cards': 'Favorite Cards',
      'no_favorites_yet': 'No favorited cards yet.',
      'reset_progress_question': 'Reset Progress?',
      'proceed': 'Proceed',
      'learning_statistics': 'Learning Statistics',
      'active_courses': 'Active Courses',
      'total_cards': 'Total Cards',
      'global_box_distribution': 'Global Box Distribution',
      'per_course_progression': 'Per-Course Progression',
      'box_1_orange': 'Box 1 (Orange)',
      'box_2_yellow': 'Box 2 (Yellow)',
      'box_3_green': 'Box 3 (Green)',
      'box_4_blue': 'Box 4 (Blue)',
      'box_5_purple': 'Box 5 (Purple)',
      'box_6_gold': 'Box 6 (Gold)',
      'finished_gold': 'Finished (Gold)',
      'cards_unit': 'cards',
      'b1_mini': 'B1',
      'b2_mini': 'B2',
      'b3_mini': 'B3',
      'b4_mini': 'B4',
      'b5_mini': 'B5',
      'b6_mini': 'B6',
      'fin_mini': 'Fin',
      'no_downloaded_courses_stats': 'No downloaded courses found. Please download courses to see statistics.',
      'card_retained_msg': 'Card retained in Finished pool.',
      'card_reset_msg': 'Card reset and returned to Box 1.',
      'no_finished_cards_title': 'No Finished Cards Yet',
      'no_finished_cards_desc': 'Once you master and complete Box 5 cards, they will appear here.',
      'reviewing_mastered_cards': 'Reviewing Mastered Cards',
      'tap_card_to_flip': 'Tap card to flip',
      'tap_card_to_show_answer': 'Tap card to show answer',
      'help_and_support': 'Help & Support',
      'email_support': 'Email Support',
      'phone_support': 'Phone Support',
      'submit_a_ticket': 'Submit a Ticket',
      'contact_email': 'Contact Email',
      'contact_email_required': 'Contact email is required',
      'enter_valid_email': 'Please enter a valid email address',
      'how_can_we_help': 'How can we help you?',
      'message_required': 'Message content is required',
      'submit_ticket': 'Submit Ticket',
      'support_submitted_msg': 'Support ticket submitted successfully! We will contact you soon.',
      'report_submitted_success': 'Flashcard report submitted successfully.',
      'report_submitted_failure': 'Failed to submit report. Please check your network connection.',
      'notification_center': 'Notification Center',
      'failed_load_notifications': 'Failed to load system notifications.',
      'no_notifications_found': 'No notifications found.',
      'retry': 'Retry',
      'no_custom_cards_found': 'No Custom Cards Found',
      'create_custom_cards_empty_desc': 'Create your own custom cards with images and voice recording, and study them locally.',
      'create_first_card': 'Create First Card',
      'all_cards': 'All Cards',
      'study_mode': 'Study Mode',
      'tour_menu_title': 'Sidebar Menu',
      'tour_menu_desc': 'Tap this purple button to access settings, statistics, notifications, and support guides.',
      'tour_today_title': "Today's Cards",
      'tour_today_desc': 'Check how many cards are scheduled for review today. Reviewing consistently prevents cards from resetting back to Box 1!',
      'tour_my_courses_title': 'My Courses',
      'tour_my_courses_desc': 'Tap here to see exclusively your purchased and downloaded offline course packages.',
      'tour_create_card_title': 'Create Custom Card',
      'tour_create_card_desc': 'Create your own custom flashcards and manage custom decks. Decks are stored 100% locally on your device for absolute privacy.',
      'tour_bottom_nav_title': 'Bottom Navigation Bar',
      'tour_bottom_nav_desc': 'Use the persistent bottom navigation bar to switch between the Home Dashboard, Review lists, and the Courses Catalog quickly from any screen.',
      'tour_skip': 'Skip',
      'tour_back': 'Back',
      'tour_next': 'Next',
      'tour_done': 'Done',
      'tour_favorites_title': 'Favorite Cards',
      'tour_favorites_desc': 'Access your marked or bookmarked flashcards here for quick lookup and revision.',
      'tour_finished_title': 'Finished Cards',
      'tour_finished_desc': 'View all the flashcards you have fully mastered and graduated through all 5 Leitner boxes.',
      'tour_catalog_title': 'Courses Catalog',
      'tour_catalog_desc': 'Browse the complete catalog of available courses. You can download and study them offline.',
      'please_enter_mobile_number': 'Please enter your mobile number',
      'enter_valid_iranian_mobile': 'Enter a valid Iranian mobile number',
      'refresh_captcha': 'Refresh CAPTCHA',
      'please_enter_captcha': 'Please enter the CAPTCHA answer',
      'please_enter_username': 'Please enter your username',
      'please_select_interest': 'Please select your interest',
      'please_select_field': 'Please select your field of study',
      'please_select_level': 'Please select your educational level',
      'invalid_mobile_number': 'The provided mobile number is invalid.',
      'invalid_captcha': 'The CAPTCHA verification failed.',
      'sms_send_failed': 'Failed to dispatch verification code.',
      'invalid_otp': 'The verification code is incorrect or expired.',
      'invalid_input': 'Mobile number and OTP code are required.',
      // New localization keys
      'checking_config': 'Checking Configuration...',
      'loading_platform': 'Loading Platform...',
      'typo_search_title': 'Typo-Tolerant Search',
      'step_select_courses': 'Step 1: Select Courses',
      'no_downloaded_courses_found': 'No downloaded courses found.',
      'step_search_cards': 'Step 2: Search Cards Inside Selection',
      'select_courses_first': 'Please select one or more courses first',
      'search_cards_hint': 'Search card contents or numbers...',
      'select_courses_begin': 'Select courses above to begin searching.',
      'type_to_search': 'Type keywords or card number to show results.',
      'no_matching_cards': 'No matching cards found.',
      'finished_box': 'Finished',
      'box_label_prefix': 'Box ',
      'course_label_prefix': 'Course: ',
      'security_block_desc': 'For security and content protection reasons, the Leitner Learning Platform cannot be run on rooted or jailbroken devices.\n\nPlease use a secure, non-rooted device to access your courses and learning progress.',
      'check_again': 'Check Again',
      'yes_label': 'Yes',
      'no_label': 'No',
      'play_audio_failed': 'Failed to play card audio file.',
      'reset_progress_desc': 'This card is currently in Box {box}. Do you want to reset its progress to Box 1?\n\n• Yes: Reset progress to Box 1 and show the card.\n• No: Keep current progress and show the card.',
      'delete_custom_card_title': 'Delete Custom Card',
      'delete_custom_card_confirm': 'Are you sure you want to delete this card? This action cannot be undone.',
      'card_deleted': 'Card deleted.',
      'failed_load_catalog': 'Failed to load courses catalog.',
      'offline_catalog_warning': 'Internet connection unavailable; course catalog update not performed.',
      'no_downloaded_courses_avail': 'No downloaded courses available.',
      'no_courses_avail': 'No courses available.',
      'update_available': 'Update available',
      'update_now': 'Update',
      'course_no_longer_in_store': 'No longer available in store - you keep access',
      'critical_update_desc': 'This course was updated to fix a reported issue. Please update to get the corrected content.',
      'select_payment_method': 'Select Payment Method',
      'zarinpal_gateway': 'Direct Gateway (ZarinPal)',
      'bazaar_billing': 'Cafe Bazaar Billing',
      'myket_billing': 'Myket Billing',
      'google_play_iap': 'Google Play IAP',
      'purchase_course_title': 'Purchase Course',
      'iap_not_supported_desc': 'In-App Purchases are not supported in this edition.\n\nPlease visit our official website to purchase courses and unlock premium content.',
      'visit_website': 'Visit Website',
      'course_unlocked_success': 'Course "{title}" unlocked successfully!',
      'purchase_failed': 'Purchase transaction failed. Please try again.',
      'password_length_warning': 'Password must be at least 6 characters.',
      'backup_success_msg': 'Backup exported successfully: {filename}',
      'backup_failed_msg': 'Backup failed: {error}',
      'enter_backup_password': 'Enter Backup Password',
      'restore_db': 'Restore',
      'database_restored_success': 'Local database restored successfully!',
      'restore_failed_msg': 'Restore failed: {error}',
      'delete_backup_title': 'Delete Backup',
      'delete_backup_confirm': 'Are you sure you want to delete this backup file?',
      'help_guide_title': 'Help Guide',
      'walkthrough_btn': 'Walkthrough',
      'leitner_btn': 'Leitner Method',
      'color_guide_btn': 'Color Status Guide',
      'leitner_method_title': 'Leitner Method',
      'leitner_desc': 'The Leitner system is a scientific method for transferring information to long-term memory based on review intervals:',
      'progress_rules_title': 'Progression Rules:',
      'progress_rules_desc': '- Correct response (Know): Card moves forward by one box.\n- Incorrect response (Don\'t Know): Card immediately returns to Box 1, restarting all stages.',
      'color_guide_title': 'Color Guide',
      'close_btn': 'Close',
      // Profile Options dynamic localizations
      'Foreign Languages': 'Foreign Languages',
      'Basic Sciences': 'Basic Sciences',
      'Information Technology': 'Information Technology',
      'Exams & Academics': 'Exams & Academics',
      'General & Misc': 'General & Misc',
      'Technical & Engineering': 'Technical & Engineering',
      'Humanities': 'Humanities',
      'Medical Sciences': 'Medical Sciences',
      'Art': 'Art',
      'General': 'General',
      'Student': 'Student',
      'High School Diploma': 'High School Diploma',
      'Associate Degree': 'Associate Degree',
      'Bachelor\'s': 'Bachelor\'s',
      'Master\'s': 'Master\'s',
      'PhD & Above': 'PhD & Above',
      'Learner': 'Learner',
      // Leitner step instructions
      'leitner_step_1_title': 'Box 1',
      'leitner_step_1_desc': 'New & incorrect cards. Daily review.',
      'leitner_step_2_title': 'Box 2',
      'leitner_step_2_desc': 'Review after 3 days.',
      'leitner_step_3_title': 'Box 3',
      'leitner_step_3_desc': 'Review after 7 days.',
      'leitner_step_4_title': 'Box 4',
      'leitner_step_4_desc': 'Review after 16 days.',
      'leitner_step_5_title': 'Box 5',
      'leitner_step_5_desc': 'Review after 31 days.',
      'leitner_step_6_title': 'Finished',
      'leitner_step_6_desc': 'Graduated / Archived.',
    },
    'fa': {
      'app_title': 'سامانه لایتنر',
      'enter_mobile_otp': 'شماره موبایل خود را جهت دریافت کد تایید وارد کنید',
      'mobile_number': 'شماره موبایل',
      'captcha_answer': 'پاسخ کد امنیتی',
      'send_verification_code': 'ارسال کد تایید',
      'verify_phone': 'تایید شماره موبایل',
      'enter_code_sent_to': 'کد ۵ رقمی ارسال شده به شماره زیر را وارد کنید:',
      'verify_and_continue': 'تایید و ادامه',
      'resend_code': 'ارسال مجدد کد',
      'enter_code_validation_error': 'لطفاً کد تأیید ۵ رقمی را وارد کنید',
      'resend_code_in': 'ارسال مجدد کد پس از',
      'seconds': 'ثانیه',
      'terms_conditions': 'قوانین و مقررات',
      'accept_terms_prompt': 'لطفا جهت ادامه، قوانین و مقررات را مطالعه و تایید کنید.',
      'accept_and_continue': 'مطالعه کردم و می‌پذیرم',
      'complete_profile': 'تکمیل پروفایل',
      'tell_us_profile': 'اطلاعات خود را جهت شخصی‌سازی یادگیری وارد کنید',
      'mobile_readonly': 'شماره موبایل (غیرقابل تغییر)',
      'username': 'نام کاربری',
      'interests': 'علاقه‌مندی‌ها',
      'educational_field': 'رشته تحصیلی',
      'educational_level': 'مقطع تحصیلی',
      'save_enter_app': 'ذخیره و ورود به برنامه',
      'save_profile': 'ذخیره پروفایل',
      'welcome_back': 'خوش آمدید،',
      'custom_flashcards': 'کارت‌های اختصاصی',
      'create_custom_cards_desc': 'ایجاد و مطالعه کارت‌های دلخواه ذخیره‌شده روی دستگاه شما.',
      'quick_hub': 'دسترسی سریع',
      'home': 'خانه',
      'review': 'مرور',
      'courses': 'دوره‌ها',
      'leitner_learning': 'آموزش لایتنر',
      'my_courses': 'دوره‌های من',
      'catalog': 'کاتالوگ دوره‌ها',
      'all_courses': 'همه دوره‌ها',
      'ready_to_study': 'آماده مطالعه',
      'download_now': 'دانلود دوره',
      'purchase': 'خرید دوره',
      'free': 'رایگان',
      'toman': 'تومان',
      'cards_count': 'کارت',
      'review_today': 'کارت‌های امروز',
      'finished_cards': 'کارت‌های پایان یافته',
      'custom_cards': 'کارت‌های اختصاصی',
      'favorites': 'نشان‌شده‌ها',
      'reports': 'گزارش‌ها',
      'statistics': 'آمار و نمودارها',
      'settings': 'تنظیمات',
      'notifications': 'اعلان‌ها',
      'support': 'پشتیبانی',
      'logout': 'خروج از حساب',
      'logout_confirm': 'آیا برای خروج از حساب کاربری اطمینان دارید؟',
      'cancel': 'انصراف',
      'confirm': 'تایید خروج',
      'scheduled_maintenance': 'به‌روزرسانی و پشتیبانی سیستم',
      'maintenance_msg': 'سامانه در حال حاضر در حال بروزرسانی می‌باشد. لطفا شکیبا باشید.',
      'security_alert': 'هشدار امنیتی',
      'jailbreak_detected': 'دستگاه شما روت شده یا غیرایمن است. دسترسی به محتوا محدود گردید.',
      'know': 'بلدم',
      'dont_know': 'بلد نیستم',
      'box_1': 'جعبه ۱',
      'box_2': 'جعبه ۲',
      'box_3': 'جعبه ۳',
      'box_4': 'جعبه ۴',
      'box_5': 'جعبه ۵',
      'box_6': 'جعبه ۶',
      'finished': 'پایان یافته',
      'language': 'زبان برنامه / Language',
      'persian': 'فارسی (Persian)',
      'english': 'English (انگلیسی)',
      'failed_load_banner': 'خطا در بارگذاری بنر',
      'could_not_open_banner': 'امکان باز کردن لینک بنر وجود ندارد.',
      'no_downloaded_courses': 'هیچ دوره دانلود شده‌ای برای نمایش نشان‌شده‌ها یافت نشد.',
      'select_course': 'انتخاب دوره',
      'banner_1_title': 'تسلط با تکرار فاصله‌دار',
      'banner_1_sub': 'برای تثبیت ۹۰ درصدی مطالب، سیستماتیک مطالعه کنید.',
      'banner_2_title': 'یادگیری آفلاین فعال است',
      'banner_2_sub': 'تمام دوره‌های دانلود شده شما به صورت امن و آفلاین در دسترس هستند.',
      'banner_3_title': 'کارت‌های اختصاصی',
      'banner_3_sub': 'کارت‌های دلخواه ایجاد کرده و روی دستگاه خود مطالعه کنید.',
      'due_badge': 'مرور',
      'total_cards_count': 'کل کارت‌ها',
      'start_study': 'شروع مطالعه',
      'no_downloaded_courses_title': 'هیچ دوره‌ای دانلود نشده است',
      'no_downloaded_courses_desc': 'جهت دانلود پکیج‌ها و مطالعه آفلاین به تب دوره‌ها مراجعه کنید.',
      'profile_details': 'اطلاعات پروفایل',
      'update_profile': 'به‌روزرسانی پروفایل',
      'about_us': 'درباره ما',
      'offline_backup_restore': 'پشتیبان‌گیری و بازیابی آفلاین',
      'backup_desc': 'از اطلاعات خود محافظت کنید! فایل پشتیبان شامل پیشرفت مطالعه، کارت‌های اختصاصی و نشان‌شده‌ها می‌باشد.',
      'backup_encryption_password': 'رمز عبور رمزنگاری فایل پشتیبان',
      'export_new_backup': 'ایجاد فایل پشتیبان رمزنگاری‌شده',
      'available_backups': 'فایل‌های پشتیبان موجود',
      'no_backups_found': 'هیچ فایل پشتیبانی روی دستگاه یافت نشد.',
      'logout_account': 'خروج از حساب کاربری',
      'review_queue': 'صف مرور',
      'question_label': 'سوال',
      'answer_label': 'پاسخ',
      'i_know_it': 'بلدم',
      'direct_card_jump': 'پرش مستقیم به کارت',
      'enter_card_number_hint': 'شماره کارت را وارد کنید (مثلا ۱۵)',
      'jump': 'پرش',
      'submit_report': 'ثبت گزارش خطای کارت',
      'report_hint': 'توضیحات خطا یا بازخورد خود را بنویسید...',
      'submit': 'ارسال',
      'warning': 'هشدار',
      'jump_warning_msg': 'این کارت در جعبه فعال لایتنر قرار دارد. مشاهده مستقیم آن، پیشرفت کارت را به جعبه ۱ بازمی‌گرداند. آیا ادامه می‌دهید؟',
      'reset_and_jump': 'بازنشانی و پرش',
      'study_loop_complete': 'مرور دوره‌ای پایان یافت!',
      'study_loop_complete_desc': 'تمام کارت‌های آماده مرور این دوره را مطالعه کردید.',
      'back_to_courses': 'بازگشت به دوره‌ها',
      'card_prefix': 'کارت #',
      'favorite_cards': 'کارت‌های نشان‌شده',
      'no_favorites_yet': 'هنوز هیچ کارتی نشان نشده است.',
      'reset_progress_question': 'بازنشانی پیشرفت مطالعه؟',
      'proceed': 'ادامه',
      'learning_statistics': 'آمار و نمودارهای یادگیری',
      'active_courses': 'دوره‌های فعال',
      'total_cards': 'کل کارت‌ها',
      'global_box_distribution': 'توزیع کلی کارت‌ها در جعبه‌ها',
      'per_course_progression': 'پیشرفت به تفکیک دوره',
      'box_1_orange': 'جعبه ۱ (نارنجی)',
      'box_2_yellow': 'جعبه ۲ (زرد)',
      'box_3_green': 'جعبه ۳ (سبز)',
      'box_4_blue': 'جعبه ۴ (آبی)',
      'box_5_purple': 'جعبه ۵ (بنفش)',
      'box_6_gold': 'جعبه ۶ (طلایی)',
      'finished_gold': 'پایان یافته (طلایی)',
      'cards_unit': 'کارت',
      'b1_mini': 'ج۱',
      'b2_mini': 'ج۲',
      'b3_mini': 'ج۳',
      'b4_mini': 'ج۴',
      'b5_mini': 'ج۵',
      'b6_mini': 'ج۶',
      'fin_mini': 'پایان',
      'no_downloaded_courses_stats': 'هیچ دوره دانلود شده‌ای یافت نشد. لطفا جهت مشاهده آمار، ابتدا دوره دانلود کنید.',
      'card_retained_msg': 'کارت در دسته تثبیت‌شده‌ها باقی ماند.',
      'card_reset_msg': 'کارت بازنشانی شده و به جعبه ۱ بازگشت.',
      'no_finished_cards_title': 'هنوز هیچ کارتی پایان نیافته است',
      'no_finished_cards_desc': 'کارت‌هایی که به تسلط کامل در جعبه ۵ برسند، در اینجا نمایش داده خواهند شد.',
      'reviewing_mastered_cards': 'مرور کارت‌های تثبیت‌شده',
      'tap_card_to_flip': 'برای چرخاندن کارت ضربه بزنید',
      'tap_card_to_show_answer': 'برای مشاهده پاسخ، روی کارت ضربه بزنید',
      'help_and_support': 'راهنما و پشتیبانی',
      'email_support': 'پشتیبانی ایمیلی',
      'phone_support': 'پشتیبانی تلفنی',
      'submit_a_ticket': 'ثبت تیکت پشتیبانی',
      'contact_email': 'ایمیل تماس',
      'contact_email_required': 'ورود ایمیل تماس الزامی است',
      'enter_valid_email': 'لطفا یک آدرس ایمیل معتبر وارد کنید',
      'how_can_we_help': 'چگونه می‌توانیم به شما کمک کنیم؟',
      'message_required': 'ورود متن پیام الزامی است',
      'submit_ticket': 'ارسال تیکت',
      'support_submitted_msg': 'تیکت پشتیبانی با موفقیت ثبت شد. به‌زودی با شما تماس خواهیم گرفت.',
      'report_submitted_success': 'گزارش خطا با موفقیت ثبت شد.',
      'report_submitted_failure': 'خطا در ثبت گزارش. لطفاً اتصال اینترنت خود را بررسی کنید.',
      'notification_center': 'مرکز اعلان‌ها',
      'failed_load_notifications': 'خطا در دریافت اعلان‌های سیستم.',
      'no_notifications_found': 'هیچ اعلانی یافت نشد.',
      'retry': 'تلاش مجدد',
      'no_custom_cards_found': 'هیچ کارت اختصاصی یافت نشد',
      'create_custom_cards_empty_desc': 'کارت‌های اختصاصی دلخواه خود را همراه با تصویر و ضبط صدا ایجاد کرده و به صورت محلی مطالعه کنید.',
      'create_first_card': 'ایجاد اولین کارت',
      'all_cards': 'همه کارت‌ها',
      'study_mode': 'حالت مطالعه',
      'tour_menu_title': 'منوی جانبی',
      'tour_menu_desc': 'برای دسترسی به تنظیمات، آمار، اعلان‌ها و راهنماهای پشتیبانی، روی این دکمه بنفش ضربه بزنید.',
      'tour_today_title': 'کارت‌های امروز',
      'tour_today_desc': 'تعداد کارت‌های آماده مرور امروز را بررسی کنید. مرور منظم از بازنشانی کارت‌ها به جعبه ۱ جلوگیری می‌کند!',
      'tour_my_courses_title': 'دوره‌های من',
      'tour_my_courses_desc': 'برای مشاهده دوره‌های خریداری‌ شده و دانلود شده آفلاین خود، اینجا ضربه بزنید.',
      'tour_create_card_title': 'ایجاد کارت اختصاصی',
      'tour_create_card_desc': 'کارت‌های اختصاصی خود را بسازید و مدیریت کنید. جهت حفظ حریم خصوصی، کارت‌ها فقط روی دستگاه شما ذخیره می‌شوند.',
      'tour_bottom_nav_title': 'نوار ناوبری پایین',
      'tour_bottom_nav_desc': 'از نوار ناوبری پایین برای جابجایی سریع بین خانه، صف مرور و کاتالوگ دوره‌ها استفاده کنید.',
      'tour_skip': 'رد کردن',
      'tour_back': 'قبلی',
      'tour_next': 'بعدی',
      'tour_done': 'پایان',
      'tour_favorites_title': 'کارت‌های نشان‌شده',
      'tour_favorites_desc': 'برای دسترسی سریع و مرور آسان، فلش‌کارت‌های نشان‌شده یا بوکمارک خود را در اینجا مشاهده کنید.',
      'tour_finished_title': 'کارت‌های پایان‌یافته',
      'tour_finished_desc': 'تمام فلش‌کارت‌هایی که کاملاً یاد گرفته‌اید و از هر ۵ جعبه لایتنر با موفقیت عبور کرده‌اند را در اینجا ببینید.',
      'tour_catalog_title': 'کاتالوگ دوره‌ها',
      'tour_catalog_desc': 'کاتالوگ کامل دوره‌های موجود را بررسی کنید. می‌توانید آن‌ها را دانلود کرده و به صورت آفلاین مطالعه کنید.',
      'please_enter_mobile_number': 'لطفاً شماره موبایل خود را وارد کنید',
      'enter_valid_iranian_mobile': 'یک شماره موبایل معتبر وارد کنید',
      'refresh_captcha': 'بارگذاری مجدد کد امنیتی',
      'please_enter_captcha': 'لطفاً پاسخ کد امنیتی را وارد کنید',
      'please_enter_username': 'لطفاً نام کاربری خود را وارد کنید',
      'please_select_interest': 'لطفاً علاقه‌مندی خود را انتخاب کنید',
      'please_select_field': 'لطفاً رشته تحصیلی خود را انتخاب کنید',
      'please_select_level': 'لطفاً مقطع تحصیلی خود را انتخاب کنید',
      'invalid_mobile_number': 'شماره موبایل وارد شده نامعتبر است.',
      'invalid_captcha': 'پاسخ کد امنیتی نادرست است.',
      'sms_send_failed': 'خطا در ارسال کد تأیید. لطفاً مجدداً تلاش کنید.',
      'invalid_otp': 'کد تأیید وارد شده نادرست یا منقضی شده است.',
      'invalid_input': 'شماره موبایل و کد تأیید الزامی هستند.',
      // New localization keys
      'checking_config': 'در حال بررسی پیکربندی...',
      'loading_platform': 'در حال بارگذاری برنامه...',
      'typo_search_title': 'جستجوی پیشرفته',
      'step_select_courses': 'گام ۱: انتخاب دوره‌ها',
      'no_downloaded_courses_found': 'هیچ دوره دانلود شده‌ای یافت نشد.',
      'step_search_cards': 'گام ۲: جستجوی کارت‌ها در دوره‌های انتخاب‌شده',
      'select_courses_first': 'لطفاً ابتدا یک یا چند دوره را انتخاب کنید',
      'search_cards_hint': 'جستجو در محتوا یا شماره کارت...',
      'select_courses_begin': 'برای شروع جستجو، دوره‌های بالا را انتخاب کنید.',
      'type_to_search': 'کلمه کلیدی یا شماره کارت را جهت جستجو وارد کنید.',
      'no_matching_cards': 'هیچ کارتی یافت نشد.',
      'finished_box': 'پایان یافته',
      'box_label_prefix': 'جعبه ',
      'course_label_prefix': 'دوره: ',
      'security_block_desc': 'به دلایل امنیتی و حفاظت از محتوای آموزشی، امکان اجرای سامانه لایتنر روی دستگاه‌های روت‌شده یا جیلبریک‌شده وجود ندارد.\n\nلطفاً از یک دستگاه امن و غیر روت‌شده برای دسترسی به دوره‌ها و پیشرفت یادگیری خود استفاده کنید.',
      'check_again': 'بررسی مجدد',
      'yes_label': 'بله',
      'no_label': 'خیر',
      'play_audio_failed': 'خطا در پخش فایل صوتی کارت.',
      'reset_progress_desc': 'این کارت در حال حاضر در جعبه {box} قرار دارد. آیا می‌خواهید پیشرفت آن را به جعبه ۱ بازنشانی کنید؟\n\n• بله: بازنشانی پیشرفت به جعبه ۱ و نمایش کارت.\n• خیر: حفظ پیشرفت فعلی و نمایش کارت.',
      'delete_custom_card_title': 'حذف کارت اختصاصی',
      'delete_custom_card_confirm': 'آیا از حذف این کارت اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
      'card_deleted': 'کارت حذف شد.',
      'failed_load_catalog': 'خطا در بارگذاری کاتالوگ دوره‌ها.',
      'offline_catalog_warning': 'اتصال به اینترنت برقرار نیست؛ بروزرسانی کاتالوگ دوره‌ها انجام نشد.',
      'no_downloaded_courses_avail': 'هیچ دوره دانلود شده‌ای در دسترس نیست.',
      'no_courses_avail': 'هیچ دوره‌ای در دسترس نیست.',
      'update_available': 'بروزرسانی موجود است',
      'update_now': 'بروزرسانی',
      'course_no_longer_in_store': 'دیگر در فروشگاه موجود نیست - دسترسی شما حفظ می‌شود',
      'critical_update_desc': 'این دوره برای رفع یک مشکل گزارش‌شده بروزرسانی شده است. لطفاً برای دریافت محتوای اصلاح‌شده بروزرسانی کنید.',
      'select_payment_method': 'انتخاب روش پرداخت',
      'zarinpal_gateway': 'درگاه مستقیم (زرین‌پال)',
      'bazaar_billing': 'پرداخت درون‌برنامه‌ای بازار',
      'myket_billing': 'پرداخت درون‌برنامه‌ای مایکت',
      'google_play_iap': 'پرداخت درون‌برنامه‌ای گوگل‌پلی',
      'purchase_course_title': 'خرید دوره',
      'iap_not_supported_desc': 'پرداخت درون‌برنامه‌ای در این نسخه پشتیبانی نمی‌شود.\n\nلطفاً برای خرید دوره‌ها و باز کردن محتوای ویژه به وب‌سایت رسمی ما مراجعه کنید.',
      'visit_website': 'مشاهده وب‌سایت',
      'course_unlocked_success': 'دوره "{title}" با موفقیت فعال شد!',
      'purchase_failed': 'تراکنش خرید ناموفق بود. لطفاً دوباره تلاش کنید.',
      'password_length_warning': 'رمز عبور باید حداقل ۶ کاراکتر باشد.',
      'backup_success_msg': 'فایل پشتیبان با موفقیت ایجاد شد: {filename}',
      'backup_failed_msg': 'پشتیبان‌گیری ناموفق بود: {error}',
      'enter_backup_password': 'رمز عبور فایل پشتیبان را وارد کنید',
      'restore_db': 'بازیابی',
      'database_restored_success': 'دیتابیس محلی با موفقیت بازیابی شد!',
      'restore_failed_msg': 'بازیابی ناموفق بود: {error}',
      'delete_backup_title': 'حذف فایل پشتیبان',
      'delete_backup_confirm': 'آیا از حذف این فایل پشتیبان اطمینان دارید؟',
      'help_guide_title': 'راهنمای برنامه',
      'walkthrough_btn': 'آموزش ابتدای برنامه',
      'leitner_btn': 'آموزش روش لایتنر',
      'color_guide_btn': 'راهنمای رنگ‌ها',
      'leitner_method_title': 'روش جعبه لایتنر',
      'leitner_desc': 'روش لایتنر یک روش علمی برای انتقال اطلاعات به حافظه بلندمدت بر اساس فواصل مرور است:',
      'progress_rules_title': 'قوانین پیشرفت:',
      'progress_rules_desc': '- پاسخ صحیح (بلدم): کارت یک خانه به جلو می‌رود.\n- پاسخ غلط (بلد نیستم): کارت بلافاصله به خانه اول (جعبه ۱) برمی‌گردد و تمام مراحل از اول آغاز می‌شود.',
      'color_guide_title': 'راهنمای رنگ وضعیت خانه‌ها',
      'close_btn': 'بستن',
      // Profile Options dynamic localizations
      'Foreign Languages': 'زبان‌های خارجی',
      'Basic Sciences': 'علوم پایه',
      'Information Technology': 'فناوری اطلاعات',
      'Exams & Academics': 'کنکور و تحصیلات',
      'General & Misc': 'عمومی و متفرقه',
      'Technical & Engineering': 'فنی و مهندسی',
      'Humanities': 'علوم انسانی',
      'Medical Sciences': 'علوم پزشکی',
      'Art': 'هنر',
      'General': 'عمومی',
      'Student': 'دانش‌آموز',
      'High School Diploma': 'دیپلم',
      'Associate Degree': 'کاردانی',
      'Bachelor\'s': 'کارشناسی',
      'Master\'s': 'کارشناسی ارشد',
      'PhD & Above': 'دکتری و بالاتر',
      'Learner': 'یادگیرنده',
      // Leitner step instructions
      'leitner_step_1_title': 'جعبه ۱',
      'leitner_step_1_desc': 'کارت‌های جدید و اشتباه شده. مرور روزانه.',
      'leitner_step_2_title': 'جعبه ۲',
      'leitner_step_2_desc': 'مرور پس از ۳ روز.',
      'leitner_step_3_title': 'جعبه ۳',
      'leitner_step_3_desc': 'مرور پس از ۷ روز.',
      'leitner_step_4_title': 'جعبه ۴',
      'leitner_step_4_desc': 'مرور پس از ۱۶ روز.',
      'leitner_step_5_title': 'جعبه ۵',
      'leitner_step_5_desc': 'مرور پس از ۳۱ روز.',
      'leitner_step_6_title': 'پایان یافته',
      'leitner_step_6_desc': 'اتمام یادگیری کارت و آرشیو شدن آن.',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['fa']?[key] ?? key;
  }

  String get appTitle => translate('app_title');
  String get enterMobileOtp => translate('enter_mobile_otp');
  String get mobileNumber => translate('mobile_number');
  String get captchaAnswer => translate('captcha_answer');
  String get sendVerificationCode => translate('send_verification_code');
  String get verifyPhone => translate('verify_phone');
  String get enterCodeSentTo => translate('enter_code_sent_to');
  String get verifyAndContinue => translate('verify_and_continue');
  String get resendCode => translate('resend_code');
  String get enterCodeValidationError => translate('enter_code_validation_error');
  String get resendCodeIn => translate('resend_code_in');
  String get seconds => translate('seconds');
  String get termsConditions => translate('terms_conditions');
  String get acceptTermsPrompt => translate('accept_terms_prompt');
  String get acceptAndContinue => translate('accept_and_continue');
  String get completeProfile => translate('complete_profile');
  String get tellUsProfile => translate('tell_us_profile');
  String get mobileReadonly => translate('mobile_readonly');
  String get username => translate('username');
  String get interests => translate('interests');
  String get educationalField => translate('educational_field');
  String get educationalLevel => translate('educational_level');
  String get saveEnterApp => translate('save_enter_app');
  String get saveProfile => translate('save_profile');
  String get welcomeBack => translate('welcome_back');
  String get customFlashcards => translate('custom_flashcards');
  String get createCustomCardsDesc => translate('create_custom_cards_desc');
  String get quickHub => translate('quick_hub');
  String get home => translate('home');
  String get review => translate('review');
  String get courses => translate('courses');
  String get leitnerLearning => translate('leitner_learning');
  String get myCourses => translate('my_courses');
  String get catalog => translate('catalog');
  String get allCourses => translate('all_courses');
  String get readyToStudy => translate('ready_to_study');
  String get downloadNow => translate('download_now');
  String get updateAvailable => translate('update_available');
  String get updateNow => translate('update_now');
  String get purchase => translate('purchase');
  String get free => translate('free');
  String get toman => translate('toman');
  String get cardsCount => translate('cards_count');
  String get reviewToday => translate('review_today');
  String get finishedCards => translate('finished_cards');
  String get customCards => translate('custom_cards');
  String get favorites => translate('favorites');
  String get reports => translate('reports');
  String get statistics => translate('statistics');
  String get settings => translate('settings');
  String get notifications => translate('notifications');
  String get support => translate('support');
  String get logout => translate('logout');
  String get logoutConfirm => translate('logout_confirm');
  String get cancel => translate('cancel');
  String get confirm => translate('confirm');
  String get scheduledMaintenance => translate('scheduled_maintenance');
  String get maintenanceMsg => translate('maintenance_msg');
  String get securityAlert => translate('security_alert');
  String get jailbreakDetected => translate('jailbreak_detected');
  String get know => translate('know');
  String get dontKnow => translate('dont_know');
  String get box1 => translate('box_1');
  String get box2 => translate('box_2');
  String get box3 => translate('box_3');
  String get box4 => translate('box_4');
  String get box5 => translate('box_5');
  String get box6 => translate('box_6');
  String get finished => translate('finished');
  String get language => translate('language');
  String get persian => translate('persian');
  String get english => translate('english');
  String get failedLoadBanner => translate('failed_load_banner');
  String get couldNotOpenBanner => translate('could_not_open_banner');
  String get noDownloadedCourses => translate('no_downloaded_courses');
  String get selectCourse => translate('select_course');

  String get banner1Title => translate('banner_1_title');
  String get banner1Sub => translate('banner_1_sub');
  String get banner2Title => translate('banner_2_title');
  String get banner2Sub => translate('banner_2_sub');
  String get banner3Title => translate('banner_3_title');
  String get banner3Sub => translate('banner_3_sub');

  String get dueBadge => translate('due_badge');
  String get totalCardsCount => translate('total_cards_count');
  String get startStudy => translate('start_study');
  String get noDownloadedCoursesTitle => translate('no_downloaded_courses_title');
  String get noDownloadedCoursesDesc => translate('no_downloaded_courses_desc');

  String get profileDetails => translate('profile_details');
  String get updateProfile => translate('update_profile');
  String get offlineBackupRestore => translate('offline_backup_restore');
  String get backupDesc => translate('backup_desc');
  String get backupEncryptionPassword => translate('backup_encryption_password');
  String get exportNewBackup => translate('export_new_backup');
  String get availableBackups => translate('available_backups');
  String get noBackupsFound => translate('no_backups_found');
  String get logoutAccount => translate('logout_account');

  String get reviewQueue => translate('review_queue');
  String get questionLabel => translate('question_label');
  String get answerLabel => translate('answer_label');
  String get iKnowIt => translate('i_know_it');
  String get directCardJump => translate('direct_card_jump');
  String get enterCardNumberHint => translate('enter_card_number_hint');
  String get jump => translate('jump');
  String get submitReport => translate('submit_report');
  String get reportHint => translate('report_hint');
  String get submit => translate('submit');
  String get warning => translate('warning');
  String get jumpWarningMsg => translate('jump_warning_msg');
  String get resetAndJump => translate('reset_and_jump');
  String get studyLoopComplete => translate('study_loop_complete');
  String get studyLoopCompleteDesc => translate('study_loop_complete_desc');
  String get backToCourses => translate('back_to_courses');
  String get cardPrefix => translate('card_prefix');

  String get favoriteCards => translate('favorite_cards');
  String get noFavoritesYet => translate('no_favorites_yet');
  String get resetProgressQuestion => translate('reset_progress_question');
  String get proceed => translate('proceed');

  String get learningStatistics => translate('learning_statistics');
  String get activeCourses => translate('active_courses');
  String get totalCards => translate('total_cards');
  String get globalBoxDistribution => translate('global_box_distribution');
  String get perCourseProgression => translate('per_course_progression');
  String get box1Orange => translate('box_1_orange');
  String get box2Yellow => translate('box_2_yellow');
  String get box3Green => translate('box_3_green');
  String get box4Blue => translate('box_4_blue');
  String get box5Purple => translate('box_5_purple');
  String get box6Gold => translate('box_6_gold');
  String get finishedGold => translate('finished_gold');
  String get cardsUnit => translate('cards_unit');
  String get b1Mini => translate('b1_mini');
  String get b2Mini => translate('b2_mini');
  String get b3Mini => translate('b3_mini');
  String get b4Mini => translate('b4_mini');
  String get b5Mini => translate('b5_mini');
  String get b6Mini => translate('b6_mini');
  String get finMini => translate('fin_mini');
  String get noDownloadedCoursesStats => translate('no_downloaded_courses_stats');

  String get cardRetainedMsg => translate('card_retained_msg');
  String get cardResetMsg => translate('card_reset_msg');
  String get noFinishedCardsTitle => translate('no_finished_cards_title');
  String get noFinishedCardsDesc => translate('no_finished_cards_desc');
  String get reviewingMasteredCards => translate('reviewing_mastered_cards');
  String get tapCardToFlip => translate('tap_card_to_flip');
  String get tapCardToShowAnswer => translate('tap_card_to_show_answer');

  String get helpAndSupport => translate('help_and_support');
  String get emailSupport => translate('email_support');
  String get phoneSupport => translate('phone_support');
  String get submitATicket => translate('submit_a_ticket');
  String get contactEmail => translate('contact_email');
  String get contactEmailRequired => translate('contact_email_required');
  String get enterValidEmail => translate('enter_valid_email');
  String get howCanWeHelp => translate('how_can_we_help');
  String get messageRequired => translate('message_required');
  String get submitTicket => translate('submit_ticket');
  String get supportSubmittedMsg => translate('support_submitted_msg');
  String get reportSubmittedSuccess => translate('report_submitted_success');
  String get reportSubmittedFailure => translate('report_submitted_failure');

  String get notificationCenter => translate('notification_center');
  String get failedLoadNotifications => translate('failed_load_notifications');
  String get noNotificationsFound => translate('no_notifications_found');
  String get retry => translate('retry');

  String get noCustomCardsFound => translate('no_custom_cards_found');
  String get createCustomCardsEmptyDesc => translate('create_custom_cards_empty_desc');
  String get createFirstCard => translate('create_first_card');
  String get allCards => translate('all_cards');
  String get studyMode => translate('study_mode');
  String get pleaseEnterMobileNumber => translate('please_enter_mobile_number');
  String get enterValidIranianMobile => translate('enter_valid_iranian_mobile');
  String get refreshCaptcha => translate('refresh_captcha');
  String get pleaseEnterCaptcha => translate('please_enter_captcha');
  String get pleaseEnterUsername => translate('please_enter_username');
  String get pleaseSelectInterest => translate('please_select_interest');
  String get pleaseSelectField => translate('please_select_field');
  String get pleaseSelectLevel => translate('please_select_level');
  String get invalidMobileNumber => translate('invalid_mobile_number');
  String get invalidCaptcha => translate('invalid_captcha');
  String get smsSendFailed => translate('sms_send_failed');
  String get invalidOtp => translate('invalid_otp');
  String get invalidInput => translate('invalid_input');
  String get tourFavoritesTitle => translate('tour_favorites_title');
  String get tourFavoritesDesc => translate('tour_favorites_desc');
  String get tourFinishedTitle => translate('tour_finished_title');
  String get tourFinishedDesc => translate('tour_finished_desc');
  String get tourCatalogTitle => translate('tour_catalog_title');
  String get tourCatalogDesc => translate('tour_catalog_desc');
  String get aboutUs => translate('about_us');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fa'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
