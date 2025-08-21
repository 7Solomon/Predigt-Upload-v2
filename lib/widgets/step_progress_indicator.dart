import 'package:flutter/material.dart';
import '../models/models.dart';

class StepProgressIndicator extends StatelessWidget {
  final ProcessingStep currentStep;
  final List<ProcessingStep> steps;
  const StepProgressIndicator({super.key, required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    final currentIndex = steps.indexOf(currentStep);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepDot(
            label: steps[i].displayName,
            isDone: i < currentIndex,
            isCurrent: i == currentIndex,
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: i < currentIndex ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ]
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  const _StepDot({required this.label, required this.isDone, required this.isCurrent});
  @override
  Widget build(BuildContext context) {
    final color = isDone || isCurrent ? Colors.green : Colors.grey;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isDone ? color : Colors.white,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : (isCurrent ? Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle)) : null),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
