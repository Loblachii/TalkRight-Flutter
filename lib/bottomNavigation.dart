import 'package:flutter/material.dart';
import 'homeScreen.dart';
import 'assessmentScreen.dart';
import 'profileScreen.dart';
import 'settingsScreen.dart';
import 'aboutScreen.dart';

class SharedWidgets {
  static Widget buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
  ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(context, Icons.home, 0, currentIndex),
          _buildBottomNavItem(context, Icons.grid_view, 1, currentIndex),
          _buildBottomNavItem(context, Icons.person, 2, currentIndex),
          _buildBottomNavItem(context, Icons.settings, 3, currentIndex),
          _buildBottomNavItem(context, Icons.info, 4, currentIndex),
        ],
      ),
    );
  }

  static Widget _buildBottomNavItem(
    BuildContext context,
    IconData icon,
    int index,
    int currentIndex,
  ) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        // Navigate to the appropriate screen
        Widget targetScreen;
        switch (index) {
          case 0:
            targetScreen = const HomeScreen();
            break;
          case 1:
            targetScreen = const AssessmentScreen();
            break;
          case 2:
            targetScreen = const ProfileScreen();
            break;
          case 3:
            targetScreen = const SettingsScreen();
            break;
          case 4:
            targetScreen = const AboutScreen();
            break;
          default:
            targetScreen = const HomeScreen();
        }

        // Only navigate if not already on the current screen
        if (index != currentIndex) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => targetScreen,
              transitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? const Color(0xFFFFB703) : const Color(0xFFBFBFBF),
        ),
      ),
    );
  }
}
