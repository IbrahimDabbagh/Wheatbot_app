class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  final String _apiKey;

  OpenRouterService(this._apiKey);

  Future<String> sendMessageWithArduinoData({
    required String userMessage,
    required List<String> arduinoDataHistory,
    required String systemPrompt,
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      // Prepare Arduino data context
      String arduinoContext = '';
      if (arduinoDataHistory.isNotEmpty) {
        arduinoContext = '\n\nArduino Data History:\n${arduinoDataHistory.join('\n')}';
      }

      final messages = [
        {'role': 'system', 'content': systemPrompt + arduinoContext},
        ...conversationHistory,
        {'role': 'user', 'content': userMessage}
      ];

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://your-app-name.com',
          'X-Title': 'Bluetooth AI Chat',
        },
        body: jsonEncode({
          'model': 'anthropic/claude-3.5-sonnet',
          'messages': messages,
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message to OpenRouter: $e');
      return 'Sorry, I encountered an error processing your request.';
    }
  }

  Future<String> processNewArduinoData({
    required String newData,
    required List<String> allArduinoData,
    required String systemPrompt,
  }) async {
    try {
      final arduinoContext = 'All Arduino data received so far:\n${allArduinoData.join('\n')}\n\nLatest data: $newData';
      
      final messages = [
        {'role': 'system', 'content': '$systemPrompt\n\n$arduinoContext'},
        {'role': 'user', 'content': 'New data received from Arduino. Please analyze and respond.'}
      ];

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://your-app-name.com',
          'X-Title': 'Bluetooth AI Chat',
        },
        body: jsonEncode({
          'model': 'anthropic/claude-3.5-sonnet',
          'messages': messages,
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      print('Error processing Arduino data: $e');
      return 'Error processing Arduino data.';
    }
  }
}
