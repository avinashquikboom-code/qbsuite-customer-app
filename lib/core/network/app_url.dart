/// Centralized API URLs and endpoints for QuikBoom CRM Mobile.
class AppUrl {
  AppUrl._();

  //baseurl for local
  // static const String baseUrl = 'https://api.qbapp.online/api/v1';
  // static const String baseUrl = 'http://[IP_ADDRESS]/api/v1';

  static const String baseUrl = 'https://api.qbapp.online/api/v1';
  // auth
  static const String login = '/auth/login';
  static const String loginCustomer = '/mobile/auth/login/customer';
  static const String customerChangePassword = '/auth/customer/change-password';
  static const String loginEmployee = '/mobile/auth/login/employee';
  static const String loginCompanyAdmin = '/mobile/auth/login/company-admin';
  static const String loginSuperAdmin = '/admin/auth/login/super-admin';
  static const String register = '/auth/register';
  static const String registerCustomer = '/auth/register/customer';
  static const String registerEmployee = '/mobile/auth/register/employee';
  static const String refreshToken = '/auth/refresh';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/profile';
  static const String dataCapture = '/data-capture';
  // work
  static const String works = '/works';
  static const String worksCalendar = '/works/calendar';
  static const String employeeCalendar = '/works/employee/calendar';
  static const String productionMetrics = '/works/production/metrics';
  static const String productionFilterOptions =
      '/works/production/filter-options';
  static const String employeeProfile = '/employees/profile/me';

  static const String plans = '/plans';
  static const String effectivePlan = '/subscriptions/effective-plan';
  static const String customerOrders = '/subscriptions/orders';
  static const String razorpayOrder = '/payments/razorpay/order';
  static const String razorpayVerify = '/payments/razorpay/verify';
  static const String paymentConfig = '/payments/config';
  static const String paymentsHistory = '/payments/history';

  static const String customers = '/customers';
  static const String customerProfile = '/customers/me';
  static const String customerProfileUpdate = '/customers/me';
  static String customerDetails(dynamic id) => '/customers/$id';
  static String customerAssignTeam(dynamic id) => '/customers/$id/assign-team';
  static const String teams = '/teams';
  static const String myTeams = '/teams/my-teams';
  static const String myTeamCalendar = '/teams/me/calendar';
  static String teamCalendar(dynamic teamId) => '/teams/$teamId/calendar';
  static const String invoices = '/invoices';

  static const String customPlanServices = '/custom-plan/services';
  static const String customPlanQuote = '/custom-plan/quote';
  static const String customPlanCreateOrder = '/custom-plan/create-order';
  static const String customPlanVerify = '/custom-plan/verify';
  static const String customPlanHistory = '/custom-plan/history';

  static const String currentSubscription = '/subscriptions/current';
  static const String renewalStatus = '/subscriptions/renewal-status';
  static const String newPlan = '/subscriptions/new-plan';
  static const String trendingCustomer = '/customer/trending';
  static const String trendingAdmin = '/admin/trending';
  static const String marketingTrendingCustomer =
      '/customer/marketing/trending';
  static const String marketingTrendingAdmin = '/admin/marketing/trending';
  static const String marketingBannersCustomer = '/customer/marketing/banners';
  static const String marketingBannersAdmin = '/admin/marketing/banners';
  static const String marketingVideosCustomer = '/customer/marketing/videos';
  static const String marketingVideosAdmin = '/admin/marketing/videos';
  static const String marketingIntroductionVideoCustomer =
      '/customer/marketing/introduction-video';
  static String marketingIntroductionVideoSeen(dynamic id) =>
      '/customer/marketing/introduction-video/$id/seen';
  static const String notifications = '/notifications';
  static const String notificationsDeviceToken = '/notifications/device-token';
  static const String socialMediaHandlersCustomer =
      '/customer/social-media-handler';
  static const String socialMediaHandlersAdmin = '/admin/social-media-handler';
  static const String productShowcase = '/customer/products/showcase';
  static const String marketplaceTools = '/marketplace/tools';
  // Use /influencers/* (not /customer/influencers) — avoids CustomerController GET /customer/:id collision on production.
  static const String influencers = '/influencers';
  static const String influencerCategories = '/influencers/categories';
  static String influencerDetails(dynamic id) => '/customer/influencers/$id';
  static String influencerFavorite(dynamic id) =>
      '/customer/influencers/$id/favorite';
  static String influencerBook(dynamic id) => '/customer/influencers/$id/book';
  static String influencerPackages(dynamic id) =>
      '/customer/influencers/$id/packages';
  static String influencerAvailability(dynamic id) =>
      '/customer/influencers/$id/availability';
  static const String influencerBookings = '/customer/influencer-bookings';
  static const String influencerMyBookings = '/customer/influencer-bookings/my';
  static const String influencerVerifyPayment =
      '/customer/influencer-bookings/verify-payment';
  static const String influencerRegister = '/customer/influencers/register';
  static const String influencerApplicationStatus =
      '/customer/influencers/application-status';
  static String influencerResubmit(dynamic id) =>
      '/customer/influencers/$id/resubmit';

  // AI Content Studio & Social Publishing
  static const String aiServices = '/customer/ai/services';
  static const String aiWallet = '/customer/ai/wallet';
  static const String aiCreditsOrder = '/customer/ai/credits/order';
  static const String aiCreditsVerify = '/customer/ai/credits/verify';
  static const String aiGenerate = '/customer/ai/generate';
  static const String aiGenerations = '/customer/ai/generations';
  static String aiGenerationDetails(dynamic id) =>
      '/customer/ai/generations/$id';
  static const String socialAccounts = '/customer/social/accounts';
  static const String socialConnect = '/customer/social/connect';
  static String socialDisconnect(dynamic id) => '/customer/social/accounts/$id';
  static const String socialPublish = '/customer/social/publish';
  static const String socialPublishes = '/customer/social/publishes';
  static String socialOAuthStart(String platform) =>
      '/customer/social/oauth/start/$platform';

  static const String planScheduleWs = '/ws/plan-schedule/';

  /// Construct WebSocket URL from current baseUrl
  static String getWsUrl(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse(baseUrl);
    final isSecure = uri.scheme == 'https' || uri.scheme == 'wss';
    final scheme = isSecure ? 'wss' : 'ws';
    final normalizedPath = path.endsWith('/') ? path : '$path/';
    final params = Map<String, String>.from(queryParams ?? {});
    // Auto-inject Engine.IO parameters for Socket.IO gateway endpoints
    if (normalizedPath.startsWith('/ws/')) {
      params.putIfAbsent('EIO', () => '4');
      params.putIfAbsent('transport', () => 'websocket');
    }
    final wsUri = Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: normalizedPath,
      queryParameters: params.isNotEmpty ? params : null,
    );
    return wsUri.toString();
  }
}
