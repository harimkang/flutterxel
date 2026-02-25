use std::collections::HashSet;
use std::ffi::CStr;
use std::os::raw::{c_char, c_void};
use std::sync::{Mutex, OnceLock};

const ABI_VERSION_MAJOR: u32 = 0;
const ABI_VERSION_MINOR: u32 = 2;
const ABI_VERSION_PATCH: u32 = 0;
const OPTIONAL_I32_NONE: i32 = i32::MIN;

#[allow(dead_code)]
#[derive(Debug, Clone)]
enum PlaySource {
    Index(i32),
    Sequence(Vec<i32>),
    Mml(String),
}

#[allow(dead_code)]
#[derive(Debug, Clone)]
struct PlayCall {
    ch: i32,
    source: PlaySource,
    sec: Option<f64>,
    loop_opt: Option<bool>,
    resume_opt: Option<bool>,
}

#[allow(dead_code)]
#[derive(Debug, Clone)]
struct BltCall {
    x: f64,
    y: f64,
    img: i32,
    u: f64,
    v: f64,
    w: f64,
    h: f64,
    colkey: Option<i32>,
    rotate: Option<f64>,
    scale: Option<f64>,
}

#[derive(Debug, Default)]
struct RuntimeState {
    initialized: bool,
    width: i32,
    height: i32,
    frame_count: u64,
    title: Option<String>,
    fps: Option<i32>,
    quit_key: Option<i32>,
    display_scale: Option<i32>,
    capture_scale: Option<i32>,
    capture_sec: Option<i32>,
    clear_color: i32,
    pressed_keys: HashSet<i32>,
    last_blt: Option<BltCall>,
    last_play: Option<PlayCall>,
    last_loaded: Option<String>,
    last_saved: Option<String>,
}

type FrameCallback = Option<extern "C" fn(*mut c_void)>;

fn runtime_state() -> &'static Mutex<RuntimeState> {
    static STATE: OnceLock<Mutex<RuntimeState>> = OnceLock::new();
    STATE.get_or_init(|| Mutex::new(RuntimeState::default()))
}

fn decode_optional_i32(value: i32) -> Option<i32> {
    if value == OPTIONAL_I32_NONE {
        None
    } else {
        Some(value)
    }
}

fn decode_optional_f64(value: f64) -> Option<f64> {
    if value.is_nan() {
        None
    } else {
        Some(value)
    }
}

fn decode_optional_bool(value: i8) -> Option<Option<bool>> {
    match value {
        -1 => Some(None),
        0 => Some(Some(false)),
        1 => Some(Some(true)),
        _ => None,
    }
}

fn decode_optional_string(ptr: *const c_char) -> Option<Option<String>> {
    if ptr.is_null() {
        return Some(None);
    }

    let c_str = unsafe { CStr::from_ptr(ptr) };
    match c_str.to_str() {
        Ok(value) => Some(Some(value.to_string())),
        Err(_) => None,
    }
}

#[no_mangle]
pub extern "C" fn flutterxel_core_version_major() -> u32 {
    ABI_VERSION_MAJOR
}

#[no_mangle]
pub extern "C" fn flutterxel_core_version_minor() -> u32 {
    ABI_VERSION_MINOR
}

#[no_mangle]
pub extern "C" fn flutterxel_core_version_patch() -> u32 {
    ABI_VERSION_PATCH
}

#[no_mangle]
pub extern "C" fn flutterxel_core_init(
    width: i32,
    height: i32,
    title: *const c_char,
    fps: i32,
    quit_key: i32,
    display_scale: i32,
    capture_scale: i32,
    capture_sec: i32,
) -> bool {
    if width <= 0 || height <= 0 {
        return false;
    }

    let Some(title) = decode_optional_string(title) else {
        return false;
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    state.initialized = true;
    state.width = width;
    state.height = height;
    state.frame_count = 0;
    state.title = title;
    state.fps = decode_optional_i32(fps);
    state.quit_key = decode_optional_i32(quit_key);
    state.display_scale = decode_optional_i32(display_scale);
    state.capture_scale = decode_optional_i32(capture_scale);
    state.capture_sec = decode_optional_i32(capture_sec);
    state.clear_color = 0;
    state.pressed_keys.clear();
    state.last_blt = None;
    state.last_play = None;
    state.last_loaded = None;
    state.last_saved = None;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_run(
    update: FrameCallback,
    update_user_data: *mut c_void,
    draw: FrameCallback,
    draw_user_data: *mut c_void,
) -> bool {
    {
        let mut state = runtime_state().lock().expect("runtime state poisoned");
        if !state.initialized {
            return false;
        }
        state.frame_count = state.frame_count.saturating_add(1);
    }

    if let Some(callback) = update {
        callback(update_user_data);
    }
    if let Some(callback) = draw {
        callback(draw_user_data);
    }

    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_btn(key: i32) -> bool {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.pressed_keys.contains(&key)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_cls(col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.clear_color = col;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_blt(
    x: f64,
    y: f64,
    img: i32,
    u: f64,
    v: f64,
    w: f64,
    h: f64,
    colkey: i32,
    rotate: f64,
    scale: f64,
) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    state.last_blt = Some(BltCall {
        x,
        y,
        img,
        u,
        v,
        w,
        h,
        colkey: decode_optional_i32(colkey),
        rotate: decode_optional_f64(rotate),
        scale: decode_optional_f64(scale),
    });
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_play(
    ch: i32,
    snd_kind: i32,
    snd_value: i32,
    snd_sequence_ptr: *const i32,
    snd_sequence_len: usize,
    snd_string: *const c_char,
    sec: f64,
    loop_opt: i8,
    resume_opt: i8,
) -> bool {
    let Some(loop_opt) = decode_optional_bool(loop_opt) else {
        return false;
    };
    let Some(resume_opt) = decode_optional_bool(resume_opt) else {
        return false;
    };

    let source = match snd_kind {
        0 => PlaySource::Index(snd_value),
        1 => {
            if snd_sequence_len == 0 {
                PlaySource::Sequence(Vec::new())
            } else if snd_sequence_ptr.is_null() {
                return false;
            } else {
                let slice =
                    unsafe { std::slice::from_raw_parts(snd_sequence_ptr, snd_sequence_len) };
                PlaySource::Sequence(slice.to_vec())
            }
        }
        2 => {
            if snd_string.is_null() {
                return false;
            }
            let c_str = unsafe { CStr::from_ptr(snd_string) };
            let Ok(text) = c_str.to_str() else {
                return false;
            };
            PlaySource::Mml(text.to_string())
        }
        _ => return false,
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.last_play = Some(PlayCall {
        ch,
        source,
        sec: decode_optional_f64(sec),
        loop_opt,
        resume_opt,
    });
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_load(
    filename: *const c_char,
    _exclude_images: i8,
    _exclude_tilemaps: i8,
    _exclude_sounds: i8,
    _exclude_musics: i8,
) -> bool {
    if filename.is_null() {
        return false;
    }

    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.last_loaded = Some(path.to_string());
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_save(
    filename: *const c_char,
    _exclude_images: i8,
    _exclude_tilemaps: i8,
    _exclude_sounds: i8,
    _exclude_musics: i8,
) -> bool {
    if filename.is_null() {
        return false;
    }

    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.last_saved = Some(path.to_string());
    true
}
