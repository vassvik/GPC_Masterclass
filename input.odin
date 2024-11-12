package masterclass 

import "core:fmt"
import "core:math/linalg"
import "core:c"
import "base:runtime"
import glfw "vendor:glfw";
import gl "vendor:OpenGL";

// Input

input_get_time :: proc() -> f64 {
    return glfw.GetTime();
}

Input_State :: enum i32 {
    DOWN        = 0,
    RELEASE     = 1,
    PRESS       = 2,
    DOUBLEPRESS = 3,
}

Input_States :: bit_set[Input_State; i32]

Input :: struct {
    buttons:                  [5]Input_States,
    buttons_clicked_time:     [5]f32,

    keys:                     #sparse [Key]Input_States, 
    input_runes:              [dynamic]rune,
    keys_clicked_time:        #sparse [Key]f32,
    modifiers:                i32,

    mouse_position:           [2]f32,
    mouse_position_prev:      [2]f32,
    mouse_position_delta:     [2]f32,
    mouse_position_click:     [5][2]f32,

    mousewheel:               f32,
    mousewheel_prev:          f32,
    mousewheel_delta:         f32,
};

double_click_time := f32(0.5);
double_click_deadzone := f32(5.0);

get_input :: proc(window: glfw.WindowHandle) -> ^Input {
    if window == ctx.main_window.handle {
        return &ctx.main_window.input
    }
    return nil
}

clear_input :: proc() {
    ctx.main_window.input.mousewheel_delta = 0.0;
    ctx.main_window.input.mouse_position_delta = [2]f32{};

    for _, i in ctx.main_window.input.buttons do ctx.main_window.input.buttons[i] &= {.DOWN}
    for key in Key                            do ctx.main_window.input.keys[key]  &= {.DOWN}
    clear(&ctx.main_window.input.input_runes)
}

set_input_callbacks :: proc(window: glfw.WindowHandle) {
    glfw.SetCharCallback(window, char_callback);
    glfw.SetKeyCallback(window, key_callback);
    glfw.SetMouseButtonCallback(window, button_callback);
    glfw.SetCursorPosCallback(window, mouse_callback);
    glfw.SetScrollCallback(window, mousewheel_callback);
}


char_callback :: proc"c"(window: glfw.WindowHandle, c: rune) {
    context = runtime.default_context();
    input := get_input(window)
    append(&input.input_runes, rune(c));
    //fmt.println("Runes:", input.input_runes)
}

key_callback :: proc"c"(window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = runtime.default_context();
    input := get_input(window)

    if action == i32(glfw.REPEAT) do return;
    if key < 0 || key >= 512 do return;
    key := Key(key)

    // calc new state based on old state
    old_state := input.keys[key] & {.DOWN}
    new_state := transmute(Input_States)action
    input.keys[key] = new_state | (.DOWN in new_state ? {.PRESS} : {.RELEASE})

    // double press
    current_time := f32(input_get_time());
    last_time := input.keys_clicked_time[key];
    if .PRESS in input.keys[key] && current_time - last_time < double_click_time {
        input.keys[key] |= {.DOUBLEPRESS}
    } 

    if .DOUBLEPRESS in input.keys[key] {
        input.keys_clicked_time[key] = -1.0e5;
    } else if .PRESS in input.keys[key] {
        input.keys_clicked_time[key] = current_time;
    }

    input.modifiers = mods;
    
    //fmt.println("Key Changed:", window, key, scancode, action, mods, input.keys[key], input.keys_clicked_time[key])
}

button_callback :: proc"c"(window: glfw.WindowHandle, button, action, mods: i32) {
    context = runtime.default_context();
    input := get_input(window)

    if action == i32(glfw.REPEAT) do return;
    if button < 0 || button >= 5 do return;

    // calc new state based on old state
    old_state := input.buttons[button] & {.DOWN}
    new_state := transmute(Input_States)action
    input.buttons[button] = new_state | (.DOWN in new_state ? {.PRESS} : {.RELEASE})

    // double press
    current_time := f32(input_get_time());

    clicked_in_time := current_time - input.buttons_clicked_time[button] < double_click_time
    inside_deadzone := linalg.length(input.mouse_position - input.mouse_position_click[button]) < double_click_deadzone

    if .PRESS in input.buttons[button] && clicked_in_time && inside_deadzone {
        input.buttons[button] |= {.DOUBLEPRESS}
    } 

    if .DOUBLEPRESS in input.buttons[button] {
        input.buttons_clicked_time[button] = -1.0e5;
    } else if .PRESS in input.buttons[button] {
        input.buttons_clicked_time[button] = current_time;
        input.mouse_position_click[button] = input.mouse_position;
    }
    //fmt.println("Mouse Button Clicked:", window, button, action, mods, input.buttons[button], input.buttons_clicked_time[button])
}

mouse_callback :: proc"c"(window: glfw.WindowHandle, xpos, ypos: f64) {
    context = runtime.default_context();
    input := get_input(window)

    input.mouse_position_prev = input.mouse_position;
    input.mouse_position = [2]f32{f32(xpos), f32(ypos)};
    input.mouse_position_delta += input.mouse_position - input.mouse_position_prev;
    //fmt.println("Mouse Moved:", window, input.mouse_position_prev, xpos, ypos, input.mouse_position, input.mouse_position_delta)
}

mousewheel_callback :: proc"c"(window: glfw.WindowHandle, dx, dy: f64) {
    context = runtime.default_context();
    input := get_input(window)

    input.mousewheel_prev = input.mousewheel;
    input.mousewheel += f32(dy);
    input.mousewheel_delta += f32(dy);
    //fmt.println("Mouse Wheel Moved:", input.mousewheel, input.mousewheel_delta)
}

Key :: enum u16 {
    /* Named printable keys */
    SPACE         = 32,
    APOSTROPHE    = 39,  /* ' */
    COMMA         = 44,  /* , */
    MINUS         = 45,  /* - */
    PERIOD        = 46,  /* . */
    SLASH         = 47,  /* / */
    SEMICOLON     = 59,  /* ; */
    EQUAL         = 61,  /* :: */
    LEFT_BRACKET  = 91,  /* [ */
    BACKSLASH     = 92,  /* \ */
    RIGHT_BRACKET = 93,  /* ] */
    GRAVE_ACCENT  = 96,  /* ` */
    WORLD_1       = 161, /* non-US #1 */
    WORLD_2       = 162, /* non-US #2 */

    /* Alphanumeric characters */
    NUM_0 = 48,
    NUM_1 = 49,
    NUM_2 = 50,
    NUM_3 = 51,
    NUM_4 = 52,
    NUM_5 = 53,
    NUM_6 = 54,
    NUM_7 = 55,
    NUM_8 = 56,
    NUM_9 = 57,

    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,


    /** Function keys **/

    /* Named non-printable keys */
    ESCAPE       = 256,
    ENTER        = 257,
    TAB          = 258,
    BACKSPACE    = 259,
    INSERT       = 260,
    DELETE       = 261,
    RIGHT        = 262,
    LEFT         = 263,
    DOWN         = 264,
    UP           = 265,
    PAGE_UP      = 266,
    PAGE_DOWN    = 267,
    HOME         = 268,
    END          = 269,
    CAPS_LOCK    = 280,
    SCROLL_LOCK  = 281,
    NUM_LOCK     = 282,
    PRINT_SCREEN = 283,
    PAUSE        = 284,

    /* Function keys */
    F1  = 290,
    F2  = 291,
    F3  = 292,
    F4  = 293,
    F5  = 294,
    F6  = 295,
    F7  = 296,
    F8  = 297,
    F9  = 298,
    F10 = 299,
    F11 = 300,
    F12 = 301,
    F13 = 302,
    F14 = 303,
    F15 = 304,
    F16 = 305,
    F17 = 306,
    F18 = 307,
    F19 = 308,
    F20 = 309,
    F21 = 310,
    F22 = 311,
    F23 = 312,
    F24 = 313,
    F25 = 314,

    /* Keypad numbers */
    KP_0 = 320,
    KP_1 = 321,
    KP_2 = 322,
    KP_3 = 323,
    KP_4 = 324,
    KP_5 = 325,
    KP_6 = 326,
    KP_7 = 327,
    KP_8 = 328,
    KP_9 = 329,

    /* Keypad named function keys */
    KP_DECIMAL  = 330,
    KP_DIVIDE   = 331,
    KP_MULTIPLY = 332,
    KP_SUBTRACT = 333,
    KP_ADD      = 334,
    KP_ENTER    = 335,
    KP_EQUAL    = 336,

    /* Modifier keys */
    LEFT_SHIFT    = 340,
    LEFT_CONTROL  = 341,
    LEFT_ALT      = 342,
    LEFT_SUPER    = 343,
    RIGHT_SHIFT   = 344,
    RIGHT_CONTROL = 345,
    RIGHT_ALT     = 346,
    RIGHT_SUPER   = 347,
    MENU          = 348,
}