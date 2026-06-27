import 'package:flutter/material.dart';
import '../../domain/voleo_models.dart';
import '../../domain/scoring.dart';

class TeamNameWithPicks extends StatelessWidget {
  const TeamNameWithPicks({
    super.key,
    required this.teamName,
    required this.user,
    required this.isRightAligned,
    this.isWinner = false,
    this.isLoser = false,
    this.style,
  });

  final String teamName;
  final VoleoUser? user;
  final bool isRightAligned;
  final bool isWinner;
  final bool isLoser;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final List<Widget> markers = [];
    if (user != null) {
      if (user!.favoriteTeam != null &&
          isSameTeam(user!.favoriteTeam!, teamName)) {
        markers.add(
          const Icon(
            Icons.star,
            color: Colors.amber,
            size: 14,
          ),
        );
      }
      if (user!.predictedChampion != null &&
          isSameTeam(user!.predictedChampion!, teamName)) {
        markers.add(
          const Icon(
            Icons.sports_soccer,
            color: Colors.blue,
            size: 14,
          ),
        );
      }
      if (user!.riskTeam != null && isSameTeam(user!.riskTeam!, teamName)) {
        markers.add(
          const Icon(
            Icons.close,
            color: Colors.red,
            size: 14,
          ),
        );
      }
    }

    final baseStyle = style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            );
    final textWidget = Text(
      teamName,
      textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: baseStyle?.copyWith(
        color: isWinner ? Colors.green : baseStyle.color,
        fontWeight: isWinner ? FontWeight.bold : baseStyle.fontWeight,
      ),
    );

    if (markers.isEmpty) {
      return textWidget;
    }

    final List<Widget> children = [];
    if (isRightAligned) {
      for (var i = 0; i < markers.length; i++) {
        children.add(markers[i]);
        children.add(const SizedBox(width: 2));
      }
      children.add(Flexible(child: textWidget));
    } else {
      children.add(Flexible(child: textWidget));
      for (var i = 0; i < markers.length; i++) {
        children.add(const SizedBox(width: 2));
        children.add(markers[i]);
      }
    }

    return Row(
      mainAxisAlignment:
          isRightAligned ? MainAxisAlignment.end : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
