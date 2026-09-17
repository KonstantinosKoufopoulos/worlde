import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'theme.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({super.key, required this.rows});

  final List<List<Tile>> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const cols = 5;
        const rowCount = 6;
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final tileFromW = (maxW - gap * (cols - 1)) / cols;
        final tileFromH = (maxH - gap * (rowCount - 1)) / rowCount;
        final tile = tileFromW < tileFromH ? tileFromW : tileFromH;
        final boardW = tile * cols + gap * (cols - 1);
        final boardH = tile * rowCount + gap * (rowCount - 1);

        return Center(
          child: SizedBox(
            width: boardW,
            height: boardH,
            child: Column(
              children: [
                for (var r = 0; r < rowCount; r++) ...[
                  if (r > 0) const SizedBox(height: gap),
                  Row(
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        if (c > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: tile,
                          height: tile,
                          child: _TileView(tile: rows[r][c]),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});

  final Tile tile;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filled = tile.state == LetterState.correct ||
        tile.state == LetterState.present ||
        tile.state == LetterState.absent;
    final bg = filled
        ? colorForLetterState(tile.state, brightness)
        : Colors.transparent;
    final borderColor = filled
        ? bg
        : (tile.letter.isNotEmpty
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)
            : (brightness == Brightness.dark
                ? LexColors.tileBorderDark
                : LexColors.tileBorder));
    final fg = filled
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: tile.letter.isEmpty && !filled ? 2 : 2),
      ),
      child: Text(
        tile.letter,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
