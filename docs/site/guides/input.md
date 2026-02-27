# Input

## Polling APIs

Use these runtime functions in your update loop:

- `btn(key)`: key is currently pressed
- `btnp(key, hold: ..., repeat: ...)`: pressed/repeat trigger
- `btnr(key)`: key released in current frame
- `btnv(key)`: integer value channel (mouse position, wheel, etc.)

Useful getters:

- `mouseX`, `mouseY`, `mouseWheel`
- `inputKeys`, `inputText`, `droppedFiles`

## Default `FlutterxelView` Keyboard Mapping

When `captureInput` is enabled, default mappings are:

- Arrow keys -> `KEY_LEFT`, `KEY_RIGHT`, `KEY_UP`, `KEY_DOWN`
- Space -> `KEY_SPACE`
- Enter -> `KEY_RETURN`
- Escape -> `KEY_ESCAPE`

You can override mappings with `keyboardMapping`.

## Pointer and Mouse

`FlutterxelView` maps pointer data to runtime keys/values:

- Left pointer down/up -> `MOUSE_BUTTON_LEFT`
- Pointer position -> `MOUSE_POS_X`, `MOUSE_POS_Y`
- Scroll delta -> `MOUSE_WHEEL_X`, `MOUSE_WHEEL_Y`

Utility API:

- `warpMouse(x, y)`

## Programmatic Input (Testing / External Integration)

These helpers are public and useful for tests/tools:

- `setBtnState(key, pressed)`
- `setBtnValue(key, value)`
- `setInputText(text)`
- `setDroppedFiles(files)`
