import 'package:flutter/material.dart';
import '../constants.dart';

class CustomScaffold extends StatelessWidget {
  final Widget? child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const CustomScaffold({
    super.key,
    this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: kTextColor),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(child: child!),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
