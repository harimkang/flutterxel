import 'dart:math' as math;

enum PuzzlePhase { title, playing, cleared }

class PixelPuzzleGame {
  PixelPuzzleGame({math.Random? random}) : _random = random ?? math.Random();

  static const int screenWidth = 160;
  static const int screenHeight = 240;
  static const int boardSize = 5;
  static const int tileSize = 24;

  final math.Random _random;
  final List<List<bool>> _board = List<List<bool>>.generate(
    boardSize,
    (_) => List<bool>.filled(boardSize, false, growable: false),
    growable: false,
  );

  PuzzlePhase _phase = PuzzlePhase.title;
  int _cursorRow = boardSize ~/ 2;
  int _cursorCol = boardSize ~/ 2;
  int _moves = 0;
  int? _bestMoves;

  bool _left = false;
  bool _right = false;
  bool _up = false;
  bool _down = false;
  bool _action = false;

  bool _prevLeft = false;
  bool _prevRight = false;
  bool _prevUp = false;
  bool _prevDown = false;
  bool _prevAction = false;

  PuzzlePhase get phase => _phase;
  int get cursorRow => _cursorRow;
  int get cursorCol => _cursorCol;
  int get moves => _moves;
  int? get bestMoves => _bestMoves;

  int get litTiles {
    var count = 0;
    for (final row in _board) {
      for (final cell in row) {
        if (cell) {
          count += 1;
        }
      }
    }
    return count;
  }

  bool isLit(int row, int col) => _board[row][col];

  void setControls({
    required bool left,
    required bool right,
    required bool up,
    required bool down,
    required bool action,
  }) {
    _left = left;
    _right = right;
    _up = up;
    _down = down;
    _action = action;
  }

  void startOrRestart() {
    _phase = PuzzlePhase.playing;
    _cursorRow = boardSize ~/ 2;
    _cursorCol = boardSize ~/ 2;
    _moves = 0;

    for (final row in _board) {
      row.fillRange(0, row.length, false);
    }

    for (var i = 0; i < 16; i++) {
      _toggleAt(_random.nextInt(boardSize), _random.nextInt(boardSize));
    }

    if (_isSolved()) {
      _toggleAt(boardSize ~/ 2, boardSize ~/ 2);
    }
  }

  void tick() {
    final leftPressed = _left && !_prevLeft;
    final rightPressed = _right && !_prevRight;
    final upPressed = _up && !_prevUp;
    final downPressed = _down && !_prevDown;
    final actionPressed = _action && !_prevAction;

    if (_phase != PuzzlePhase.playing) {
      if (actionPressed) {
        startOrRestart();
      }
      _capturePreviousState();
      return;
    }

    if (leftPressed) {
      _cursorCol = (_cursorCol - 1).clamp(0, boardSize - 1);
    }
    if (rightPressed) {
      _cursorCol = (_cursorCol + 1).clamp(0, boardSize - 1);
    }
    if (upPressed) {
      _cursorRow = (_cursorRow - 1).clamp(0, boardSize - 1);
    }
    if (downPressed) {
      _cursorRow = (_cursorRow + 1).clamp(0, boardSize - 1);
    }

    if (actionPressed) {
      _toggleAt(_cursorRow, _cursorCol);
      _moves += 1;
      if (_isSolved()) {
        _phase = PuzzlePhase.cleared;
        if (_bestMoves == null || _moves < _bestMoves!) {
          _bestMoves = _moves;
        }
      }
    }

    _capturePreviousState();
  }

  void _capturePreviousState() {
    _prevLeft = _left;
    _prevRight = _right;
    _prevUp = _up;
    _prevDown = _down;
    _prevAction = _action;
  }

  void _toggleAt(int row, int col) {
    const deltas = <(int, int)>[(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final (dr, dc) in deltas) {
      final r = row + dr;
      final c = col + dc;
      if (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
        _board[r][c] = !_board[r][c];
      }
    }
  }

  bool _isSolved() => litTiles == 0;

  void debugSetBoard(List<List<bool>> values) {
    if (values.length != boardSize) {
      throw ArgumentError.value(values, 'values', 'row count mismatch');
    }
    for (var r = 0; r < boardSize; r++) {
      if (values[r].length != boardSize) {
        throw ArgumentError.value(
          values[r],
          'values[$r]',
          'column count mismatch',
        );
      }
      for (var c = 0; c < boardSize; c++) {
        _board[r][c] = values[r][c];
      }
    }
  }

  void debugSetCursor(int row, int col) {
    _cursorRow = row.clamp(0, boardSize - 1);
    _cursorCol = col.clamp(0, boardSize - 1);
  }
}
