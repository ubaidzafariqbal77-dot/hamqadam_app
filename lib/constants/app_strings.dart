/// User-facing strings kept in one place for consistency and future i18n.
class AppStrings {
  const AppStrings._();

  static const String appName = 'HamQadam';
  static const String tagline = 'A respectful path to marriage';

  // Generic
  static const String retry = 'Retry';
  static const String refresh = 'Refresh';
  static const String next = 'Save & Continue';
  static const String back = 'Back';
  static const String submit = 'Submit';
  static const String cancel = 'Cancel';
  static const String discard = 'Discard';
  static const String stayHere = 'Keep Editing';

  // Auth
  static const String login = 'Login';
  static const String loginTitle = 'Welcome back';
  static const String loginSubtitle = 'Sign in to continue your journey';
  static const String createAccount = 'Create Account';
  static const String noAccount = "Don't have?";
  static const String haveAccount = 'Already registered?';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot password?';

  // Field system
  static const String requiredBadge = 'Required';
  static const String optionalBadge = 'Optional';
  static const String legendTitle = 'Field guide';
  static const String legendRequired = 'Required — must be filled to continue';
  static const String legendOptional = 'Optional — you may skip this';

  // States
  static const String noInternetTitle = 'No internet connection';
  static const String noInternetMessage = 'Please check your connection and try again.';
  static const String serverErrorTitle = 'Something went wrong';
  static const String serverErrorMessage = 'We could not complete your request. Please try again.';
  static const String emptyTitle = 'Nothing here yet';
  static const String unauthorizedMessage = 'Your session has expired. Please sign in again.';
  static const String timeoutMessage = 'The request timed out. Please retry.';

  // Registration
  static const String stepOf = 'Step'; // "Step 2 of 12"
  static const String unsavedTitle = 'Leave this step?';
  static const String unsavedMessage = 'Your entered data on this step is kept as a draft.';
  static const String registrationCompleteTitle = 'Profile complete!';
  static const String registrationCompleteMessage =
      'Your HamQadam profile is ready. May your search be blessed.';
}
