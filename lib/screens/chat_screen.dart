class _ChatScreenState extends State<ChatScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  late OpenRouterService _openRouterService;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<String> _arduinoDataHistory = [];
  final ScrollController _scrollController = ScrollController();
  
  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;
  bool _showSystemPromptEditor = false;
  String _apiKey = '';
  String _systemPrompt = '''You are an intelligent assistant that analyzes Arduino sensor data and responds to user queries. 
You have access to real-time data from Arduino sensors connected via Bluetooth HC-05 module.
Analyze the sensor data patterns, provide insights, and answer user questions based on the available data.
Be helpful, concise, and technical when appropriate.''';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _systemPromptController.text = _systemPrompt;
  }

  void _initializeServices() {
    // TODO: Replace with your actual OpenRouter API key
    _apiKey = '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';
    _openRouterService = OpenRouterService(_apiKey);
  }

  @override
  void dispose() {
    _bluetoothService.disconnect();
    _messageController.dispose();
    _systemPromptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  Future<void> _connectToDevice() async {
    final devices = await _bluetoothService.getPairedDevices();
    
    if (!mounted) return;
    
    final selectedDevice = await showDialog<BluetoothDevice>(
      context: context,
      builder: (context) => DeviceListDialog(devices: devices),
    );

    if (selectedDevice != null) {
      final connected = await _bluetoothService.connectToDevice(selectedDevice);
      
      if (connected) {
        setState(() {
          _connectedDevice = selectedDevice;
          _isConnected = true;
        });

        _addMessage(ChatMessage(
          content: 'Connected to ${selectedDevice.name}',
          type: MessageType.ai,
        ));

        // Listen for incoming data
        _bluetoothService.getDataStream().listen((data) {
          // Add to Arduino data history but don't show in chat
          setState(() {
            _arduinoDataHistory.add('${DateTime.now().toIso8601String()}: $data');
          });

          // Process new Arduino data with AI
          _processNewArduinoData(data);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect to device')),
          );
        }
      }
    }
  }

  Future<void> _processNewArduinoData(String newData) async {
    final aiResponse = await _openRouterService.processNewArduinoData(
      newData: newData,
      allArduinoData: _arduinoDataHistory,
      systemPrompt: _systemPrompt,
    );
    
    _addMessage(ChatMessage(
      content: aiResponse,
      type: MessageType.ai,
    ));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    
    _addMessage(ChatMessage(
      content: message,
      type: MessageType.user,
    ));

    // Send to Arduino if connected
    if (_isConnected) {
      await _bluetoothService.sendData(message);
    }

    // Get AI response with Arduino data context
    final conversationHistory = _messages
        .where((msg) => msg.type != MessageType.arduino)
        .map((msg) => {
              'role': msg.type == MessageType.user ? 'user' : 'assistant',
              'content': msg.content,
            })
        .toList();

    final aiResponse = await _openRouterService.sendMessageWithArduinoData(
      userMessage: message,
      arduinoDataHistory: _arduinoDataHistory,
      systemPrompt: _systemPrompt,
      conversationHistory: conversationHistory,
    );
    
    _addMessage(ChatMessage(
      content: aiResponse,
      type: MessageType.ai,
    ));
  }

  void _updateSystemPrompt() {
    setState(() {
      _systemPrompt = _systemPromptController.text;
      _showSystemPromptEditor = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('System prompt updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth AI Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              setState(() {
                _showSystemPromptEditor = !_showSystemPromptEditor;
              });
            },
          ),
          IconButton(
            icon: Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
            onPressed: _isConnected ? null : _connectToDevice,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Not connected to Arduino. Arduino data: ${_arduinoDataHistory.length} entries'),
                  ),
                  TextButton(
                    onPressed: _connectToDevice,
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          if (_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade100,
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Connected to ${_connectedDevice?.name}. Data entries: ${_arduinoDataHistory.length}'),
                  ),
                ],
              ),
            ),
          if (_showSystemPromptEditor)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Prompt Editor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _systemPromptController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Enter system prompt for AI...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showSystemPromptEditor = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _updateSystemPrompt,
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return MessageBubble(message: _messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
