import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/widgets/animated_tick.dart';

class AnimationShowcasePage extends StatefulWidget {
  const AnimationShowcasePage({super.key});

  @override
  State<AnimationShowcasePage> createState() => _AnimationShowcasePageState();
}

class _AnimationShowcasePageState extends State<AnimationShowcasePage> {
  bool _showLoader = false;
  bool _showTick = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animation Showcase Sandbox'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Navigate to splash page explicitly
                context.pushNamed('splash');
              },
              child: const Text('Play Splash Screen'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showLoader = !_showLoader;
                  _showTick = false;
                });
              },
              child: Text(_showLoader ? 'Hide Loader' : 'Show Loader'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showTick = false;
                  _showLoader = false;
                });
                // Small delay to reset the state and replay the tick animation
                Future.delayed(const Duration(milliseconds: 100), () {
                  setState(() {
                    _showTick = true;
                  });
                });
              },
              child: const Text('Play Animated Tick'),
            ),
            const SizedBox(height: 64),
            // Display area for the animations
            if (_showLoader)
              const SizedBox(
                width: 100,
                height: 100,
                child: VitalUpLoader(),
              ),
            if (_showTick)
              const SizedBox(
                width: 100,
                height: 100,
                child: AnimatedTick(totalSize: 100),
              ),
          ],
        ),
      ),
    );
  }
}
