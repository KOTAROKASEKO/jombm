import 'package:flutter/material.dart';

import '../chat/chat_launch.dart';
import 'conversation_screen.dart';
import 'course_screen.dart';
import 'notes_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1;

  @override
  void initState() {
    super.initState();
    ChatLaunch.instance.addListener(_openConversationTab);
  }

  @override
  void dispose() {
    ChatLaunch.instance.removeListener(_openConversationTab);
    super.dispose();
  }

  void _openConversationTab() {
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CourseScreen(),
          ConversationScreen(),
          NotesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'コース',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '会話',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '単語',
          ),
        ],
      ),
    );
  }
}
