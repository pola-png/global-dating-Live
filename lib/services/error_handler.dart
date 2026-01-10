class ErrorHandler {
  static String getPlainMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('invalid credentials') || 
        errorStr.contains('invalid email or password') ||
        errorStr.contains('user_invalid_credentials')) {
      return 'Email or password is incorrect';
    }
    
    if (errorStr.contains('user not found') || 
        errorStr.contains('user_not_found')) {
      return 'No user found with these details';
    }
    
    if (errorStr.contains('user_already_exists') || 
        errorStr.contains('already exists')) {
      return 'User already exists with this email';
    }
    
    if (errorStr.contains('invalid email') || 
        errorStr.contains('user_invalid_email')) {
      return 'Please enter a valid email address';
    }
    
    if (errorStr.contains('password') && errorStr.contains('short')) {
      return 'Password must be at least 8 characters';
    }
    
    if (errorStr.contains('network') || 
        errorStr.contains('connection')) {
      return 'Please check your internet connection';
    }
    
    if (errorStr.contains('rate limit') || 
        errorStr.contains('too many requests')) {
      return 'Too many attempts. Please try again later';
    }
    
    if (errorStr.contains('unauthorized') || 
        errorStr.contains('permission')) {
      return 'You do not have permission for this action';
    }
    
    if (errorStr.contains('document not found') || 
        errorStr.contains('not found')) {
      return 'Requested item not found';
    }
    
    return 'Something went wrong. Please try again';
  }
}