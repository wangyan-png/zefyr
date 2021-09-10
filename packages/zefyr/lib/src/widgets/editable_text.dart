import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

......

  bool _listenerAttached = false;

  void _cancelSubscriptions() {
    _handleUpdateKeyEvent(false);
    _renderContext.removeListener(_handleRenderContextChange);
    widget.controller.removeListener(_handleLocalValueChange);
    _focusNode.removeListener(_handleFocusChange);
    _input.closeConnection();
    _cursorTimer.stop();
  }

  void _handleFocusChange() {
    _handleUpdateKeyEvent();
    _input.openOrCloseConnection(_focusNode,
        widget.controller.plainTextEditingValue, widget.keyboardAppearance);
    _cursorTimer.startOrStop(_focusNode, selection);
    updateKeepAlive();
  }

  void _handleUpdateKeyEvent([bool value]) {
    if (Platform.isAndroid || Platform.isWindows) {
      // 因为只发现 android 和 windows 会有问题
      if (_focusNode.hasFocus && (value == null || value == true)) {
        RawKeyboard.instance.addListener(_handleKeyEvent);
        _listenerAttached = true;
      } else if (_listenerAttached) {
        RawKeyboard.instance.removeListener(_handleKeyEvent);
        _listenerAttached = false;
      }
    }
  }

  // 主要增加的代码
    void _handleKeyEvent(RawKeyEvent keyEvent) {
    if (kIsWeb) {
      // On web platform, we should ignore the key because it's processed already.
      return;
    }

    if (keyEvent is! RawKeyDownEvent) {
      return;
    }
    final keysPressed = LogicalKeyboardKey.collapseSynonyms(RawKeyboard.instance.keysPressed);
    final key = keyEvent.logicalKey;

    final isMacOS = keyEvent.data is RawKeyEventDataMacOs;
    if (!_nonModifierKeys.contains(key) ||
        keysPressed.difference(isMacOS ? _macOsModifierKeys : _modifierKeys).length > 1 ||
        keysPressed.difference(_interestingKeys).isNotEmpty) {
      // If the most recently pressed key isn't a non-modifier key, or more than
      // one non-modifier key is down, or keys other than the ones we're interested in
      // are pressed, just ignore the keypress.
      return;
    }

    // 只管删除功能，方向键暂时不管，需要可以加上
    if (key == LogicalKeyboardKey.delete) {
      _handleDelete(forward: true);
    } else if (key == LogicalKeyboardKey.backspace) {
      _handleDelete(forward: false);
    }
  }

  void _handleDelete({ @required bool forward }) {
    final selection = widget.controller.plainTextEditingValue.selection;
    assert(selection != null);

    final text = widget.controller.plainTextEditingValue.text;
    if (text.isEmpty) return;
    var textBefore = selection.textBefore(text);
    var textAfter = selection.textAfter(text);
    var cursorPosition = math.min(selection.start, selection.end);

    if (selection.isCollapsed) {
      if (!forward && cursorPosition > 0) {
        // ignore: invalid_use_of_visible_for_testing_member
        final characterBoundary = RenderEditable.previousCharacter(cursorPosition, textBefore);
        final newSelection = TextSelection.collapsed(offset: characterBoundary);
        widget.controller.replaceText(characterBoundary, cursorPosition - characterBoundary, '', selection: newSelection);
      }
      if (forward && textAfter.isNotEmpty) {
        // ignore: invalid_use_of_visible_for_testing_member
        final deleteCount = RenderEditable.nextCharacter(0, textAfter);
        final newSelection = TextSelection.collapsed(offset: cursorPosition);
        widget.controller.replaceText(cursorPosition, deleteCount, '', selection: newSelection);
      }
    } else {
      final newSelection = TextSelection.collapsed(offset: cursorPosition);
      widget.controller.replaceText(cursorPosition, math.max(selection.start, selection.end) - cursorPosition, '', selection: newSelection);
    }
  }


  static final Set<LogicalKeyboardKey> _movementKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  };

  static final Set<LogicalKeyboardKey> _shortcutKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyV,
    LogicalKeyboardKey.keyX,
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.backspace,
  };

  static final Set<LogicalKeyboardKey> _nonModifierKeys = <LogicalKeyboardKey>{
    ..._shortcutKeys,
    ..._movementKeys,
  };

  static final Set<LogicalKeyboardKey> _modifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.alt,
  };

  static final Set<LogicalKeyboardKey> _macOsModifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.alt,
  };

  static final Set<LogicalKeyboardKey> _interestingKeys = <LogicalKeyboardKey>{
    ..._modifierKeys,
    ..._macOsModifierKeys,
    ..._nonModifierKeys,
  };
