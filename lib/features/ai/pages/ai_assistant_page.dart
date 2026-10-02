import 'package:flutter/material.dart';

import 'ai_page.dart';
import '../../../models/user_profile.dart';

/// Backwards-compatible name kept for older navigation code.
class AIAssistantPage extends AiPage {
  const AIAssistantPage({
    super.key,
    required Locale locale,
    required UserProfile profile,
  }) : super(locale: locale, profile: profile);
}
