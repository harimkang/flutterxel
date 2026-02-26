use std::collections::{HashMap, HashSet};
use std::ffi::CStr;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::os::raw::{c_char, c_void};
use std::sync::{Mutex, OnceLock};
use zip::write::FileOptions;
use zip::{ZipArchive, ZipWriter};

const ABI_VERSION_MAJOR: u32 = 0;
const ABI_VERSION_MINOR: u32 = 3;
const ABI_VERSION_PATCH: u32 = 0;
const OPTIONAL_I32_NONE: i32 = i32::MIN;
const RESOURCE_ARCHIVE_NAME: &str = "pyxel_resource.toml";
const RESOURCE_FORMAT_VERSION: u32 = 4;
const RESOURCE_RUNTIME_SECTION: &str = "runtime";

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

#[derive(Debug)]
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
    frame_buffer: Vec<i32>,
    image_banks: HashMap<i32, Vec<i32>>,
    image_bank_size: i32,
    channel_playback: HashMap<i32, PlayCall>,
    last_blt: Option<BltCall>,
    last_play: Option<PlayCall>,
    last_loaded: Option<String>,
    last_saved: Option<String>,
}

impl Default for RuntimeState {
    fn default() -> Self {
        Self {
            initialized: false,
            width: 0,
            height: 0,
            frame_count: 0,
            title: None,
            fps: None,
            quit_key: None,
            display_scale: None,
            capture_scale: None,
            capture_sec: None,
            clear_color: 0,
            pressed_keys: HashSet::new(),
            frame_buffer: Vec::new(),
            image_banks: HashMap::new(),
            image_bank_size: 16,
            channel_playback: HashMap::new(),
            last_blt: None,
            last_play: None,
            last_loaded: None,
            last_saved: None,
        }
    }
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

fn ensure_default_image_bank(state: &mut RuntimeState) {
    if state.image_banks.contains_key(&0) {
        return;
    }

    let size = state.image_bank_size.max(1) as usize;
    let mut bank = vec![0; size * size];
    for y in 0..size {
        for x in 0..size {
            bank[y * size + x] = ((x + y) % 16) as i32;
        }
    }

    state.image_banks.insert(0, bank);
}

fn validate_optional_resource_flags(
    exclude_images: i8,
    exclude_tilemaps: i8,
    exclude_sounds: i8,
    exclude_musics: i8,
) -> bool {
    decode_optional_bool(exclude_images).is_some()
        && decode_optional_bool(exclude_tilemaps).is_some()
        && decode_optional_bool(exclude_sounds).is_some()
        && decode_optional_bool(exclude_musics).is_some()
}

fn parse_i32_value(value: &toml::Value) -> Option<i32> {
    value.as_integer().and_then(|raw| i32::try_from(raw).ok())
}

fn parse_u64_value(value: &toml::Value) -> Option<u64> {
    value.as_integer().and_then(|raw| u64::try_from(raw).ok())
}

fn parse_u32_value(value: &toml::Value) -> Option<u32> {
    value.as_integer().and_then(|raw| u32::try_from(raw).ok())
}

fn frame_buffer_len(width: i32, height: i32) -> Option<usize> {
    let width = usize::try_from(width).ok()?;
    let height = usize::try_from(height).ok()?;
    width.checked_mul(height)
}

fn build_resource_toml(state: &RuntimeState) -> String {
    format!(
        "format_version = {RESOURCE_FORMAT_VERSION}\nimages = []\ntilemaps = []\nsounds = []\nmusics = []\n[{RESOURCE_RUNTIME_SECTION}]\nwidth = {width}\nheight = {height}\nframe_count = {frame_count}\nclear_color = {clear_color}\n",
        width = state.width,
        height = state.height,
        frame_count = state.frame_count,
        clear_color = state.clear_color,
    )
}

fn draw_blt(state: &mut RuntimeState, call: &BltCall) -> bool {
    let Some(source) = state.image_banks.get(&call.img) else {
        return false;
    };

    let source_size = state.image_bank_size;
    if source_size <= 0 {
        return false;
    }

    let source_size_usize = source_size as usize;
    if source.len() < source_size_usize * source_size_usize {
        return false;
    }

    let width = call.w.abs().round() as i32;
    let height = call.h.abs().round() as i32;
    if width <= 0 || height <= 0 {
        return true;
    }

    let flip_x = call.w < 0.0;
    let flip_y = call.h < 0.0;
    let base_dx = call.x.round() as i32;
    let base_dy = call.y.round() as i32;
    let base_sx = call.u.round() as i32;
    let base_sy = call.v.round() as i32;

    for dy in 0..height {
        for dx in 0..width {
            let src_x = base_sx + if flip_x { width - 1 - dx } else { dx };
            let src_y = base_sy + if flip_y { height - 1 - dy } else { dy };

            if src_x < 0 || src_x >= source_size || src_y < 0 || src_y >= source_size {
                continue;
            }

            let src_index = src_y as usize * source_size_usize + src_x as usize;
            let color = source[src_index];
            if call.colkey == Some(color) {
                continue;
            }

            let dst_x = base_dx + dx;
            let dst_y = base_dy + dy;
            if dst_x < 0 || dst_x >= state.width || dst_y < 0 || dst_y >= state.height {
                continue;
            }

            let dst_index = dst_y as usize * state.width as usize + dst_x as usize;
            state.frame_buffer[dst_index] = color;
        }
    }

    true
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
    let Some(frame_buffer_len) = frame_buffer_len(width, height) else {
        return false;
    };
    state.frame_buffer = vec![0; frame_buffer_len];
    state.image_banks.clear();
    state.channel_playback.clear();
    state.last_blt = None;
    state.last_play = None;
    state.last_loaded = None;
    state.last_saved = None;
    ensure_default_image_bank(&mut state);
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
pub extern "C" fn flutterxel_core_frame_count() -> u64 {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0;
    }
    state.frame_count
}

#[no_mangle]
pub extern "C" fn flutterxel_core_framebuffer_ptr() -> *const i32 {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || state.frame_buffer.is_empty() {
        return std::ptr::null();
    }
    state.frame_buffer.as_ptr()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_framebuffer_len() -> usize {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0;
    }
    state.frame_buffer.len()
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
pub extern "C" fn flutterxel_core_set_btn_state(key: i32, pressed: bool) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    if pressed {
        state.pressed_keys.insert(key);
    } else {
        state.pressed_keys.remove(&key);
    }
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_cls(col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.clear_color = col;
    state.frame_buffer.fill(col);
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

    let call = BltCall {
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
    };

    let ok = draw_blt(&mut state, &call);
    if ok {
        state.last_blt = Some(call);
    }
    ok
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

    let call = PlayCall {
        ch,
        source,
        sec: decode_optional_f64(sec),
        loop_opt,
        resume_opt,
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    state.channel_playback.insert(ch, call.clone());
    state.last_play = Some(call);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_is_channel_playing(ch: i32) -> bool {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.channel_playback.contains_key(&ch)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_load(
    filename: *const c_char,
    exclude_images: i8,
    exclude_tilemaps: i8,
    exclude_sounds: i8,
    exclude_musics: i8,
) -> bool {
    if filename.is_null() {
        return false;
    }
    if !validate_optional_resource_flags(
        exclude_images,
        exclude_tilemaps,
        exclude_sounds,
        exclude_musics,
    ) {
        return false;
    }

    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let Ok(file) = File::open(path) else {
        return false;
    };
    let Ok(mut archive) = ZipArchive::new(file) else {
        return false;
    };
    let Ok(mut manifest_entry) = archive.by_name(RESOURCE_ARCHIVE_NAME) else {
        return false;
    };
    let mut toml_text = String::new();
    if manifest_entry.read_to_string(&mut toml_text).is_err() {
        return false;
    }

    let Ok(manifest) = toml::from_str::<toml::Value>(&toml_text) else {
        return false;
    };
    let Some(format_version) = manifest.get("format_version").and_then(parse_u32_value) else {
        return false;
    };
    if format_version > RESOURCE_FORMAT_VERSION {
        return false;
    }

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    if let Some(runtime) = manifest
        .get(RESOURCE_RUNTIME_SECTION)
        .and_then(toml::Value::as_table)
    {
        let mut loaded_width = state.width;
        let mut loaded_height = state.height;

        if let Some(value) = runtime.get("width") {
            let Some(parsed_width) = parse_i32_value(value) else {
                return false;
            };
            loaded_width = parsed_width;
        }
        if let Some(value) = runtime.get("height") {
            let Some(parsed_height) = parse_i32_value(value) else {
                return false;
            };
            loaded_height = parsed_height;
        }
        if loaded_width <= 0 || loaded_height <= 0 {
            return false;
        }

        if let Some(value) = runtime.get("frame_count") {
            let Some(parsed_frame_count) = parse_u64_value(value) else {
                return false;
            };
            state.frame_count = parsed_frame_count;
        }
        if let Some(value) = runtime.get("clear_color") {
            let Some(parsed_clear_color) = parse_i32_value(value) else {
                return false;
            };
            state.clear_color = parsed_clear_color;
        }

        let Some(buffer_len) = frame_buffer_len(loaded_width, loaded_height) else {
            return false;
        };
        state.width = loaded_width;
        state.height = loaded_height;
        state.frame_buffer = vec![state.clear_color; buffer_len];
    }

    state.last_loaded = Some(path.to_string());
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_save(
    filename: *const c_char,
    exclude_images: i8,
    exclude_tilemaps: i8,
    exclude_sounds: i8,
    exclude_musics: i8,
) -> bool {
    if filename.is_null() {
        return false;
    }
    if !validate_optional_resource_flags(
        exclude_images,
        exclude_tilemaps,
        exclude_sounds,
        exclude_musics,
    ) {
        return false;
    }

    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let payload = {
        let state = runtime_state().lock().expect("runtime state poisoned");
        if !state.initialized {
            return false;
        }
        build_resource_toml(&state)
    };

    let Ok(file) = File::create(path) else {
        return false;
    };
    let mut zip = ZipWriter::new(file);
    if zip
        .start_file(RESOURCE_ARCHIVE_NAME, FileOptions::default())
        .is_err()
    {
        return false;
    }
    if zip.write_all(payload.as_bytes()).is_err() {
        return false;
    }
    if zip.finish().is_err() {
        return false;
    }

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.last_saved = Some(path.to_string());
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;
    use std::fs::File;
    use std::io::{Read, Write};
    use std::path::PathBuf;
    use std::sync::{Mutex, OnceLock};
    use std::time::{SystemTime, UNIX_EPOCH};

    fn test_lock() -> std::sync::MutexGuard<'static, ()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
            .lock()
            .expect("test lock poisoned")
    }

    fn init_runtime(width: i32, height: i32) {
        let title = CString::new("test").expect("valid cstring");
        let ok = flutterxel_core_init(
            width,
            height,
            title.as_ptr(),
            OPTIONAL_I32_NONE,
            OPTIONAL_I32_NONE,
            OPTIONAL_I32_NONE,
            OPTIONAL_I32_NONE,
            OPTIONAL_I32_NONE,
        );
        assert!(ok);
    }

    fn tmp_resource_path(label: &str) -> PathBuf {
        let mut path = std::env::temp_dir();
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("valid system time")
            .as_nanos();
        path.push(format!("flutterxel_core_{label}_{stamp}.pyxres"));
        path
    }

    fn write_resource_archive(path: &PathBuf, toml_text: &str) {
        let file = File::create(path).expect("create resource archive");
        let mut zip = zip::ZipWriter::new(file);
        zip.start_file(RESOURCE_ARCHIVE_NAME, zip::write::FileOptions::default())
            .expect("start resource archive entry");
        zip.write_all(toml_text.as_bytes())
            .expect("write resource archive entry");
        zip.finish().expect("finish resource archive");
    }

    fn read_resource_archive_toml(path: &PathBuf) -> String {
        let file = File::open(path).expect("open resource archive");
        let mut archive = zip::ZipArchive::new(file).expect("read zip archive");
        let mut entry = archive
            .by_name(RESOURCE_ARCHIVE_NAME)
            .expect("find resource manifest");
        let mut text = String::new();
        entry.read_to_string(&mut text).expect("read manifest text");
        text
    }

    #[test]
    fn cls_fills_entire_framebuffer_with_color_index() {
        let _guard = test_lock();
        init_runtime(4, 4);
        assert!(flutterxel_core_cls(7));

        let frame_buffer = {
            let state = runtime_state().lock().expect("runtime state poisoned");
            state.frame_buffer.clone()
        };
        assert_eq!(frame_buffer.len(), 16);
        assert!(frame_buffer.iter().all(|pixel| *pixel == 7));
    }

    #[test]
    fn blt_copies_from_image_bank_and_respects_colkey() {
        let _guard = test_lock();
        init_runtime(4, 4);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.image_banks.insert(0, vec![1, 2, 3, 4, 5, 6, 7, 8, 9]);
            state.image_bank_size = 3;
        }

        assert!(flutterxel_core_cls(0));
        assert!(flutterxel_core_blt(
            1.0,
            1.0,
            0,
            0.0,
            0.0,
            2.0,
            2.0,
            2,
            f64::NAN,
            f64::NAN
        ));

        let frame_buffer = {
            let state = runtime_state().lock().expect("runtime state poisoned");
            state.frame_buffer.clone()
        };
        // Drawn block at (1,1) with source [1,2;4,5], with colkey=2 skipped.
        let expected = [
            0, 0, 0, 0, //
            0, 1, 0, 0, //
            0, 4, 5, 0, //
            0, 0, 0, 0,
        ];
        assert_eq!(frame_buffer, expected);
    }

    #[test]
    fn btn_state_can_be_updated_from_bridge_api() {
        let _guard = test_lock();
        init_runtime(4, 4);
        assert!(!flutterxel_core_btn(32));

        assert!(flutterxel_core_set_btn_state(32, true));
        assert!(flutterxel_core_btn(32));

        assert!(flutterxel_core_set_btn_state(32, false));
        assert!(!flutterxel_core_btn(32));
    }

    #[test]
    fn save_then_load_accepts_zip_resource_archive() {
        let _guard = test_lock();
        init_runtime(4, 4);
        assert!(flutterxel_core_cls(9));

        let path = tmp_resource_path("save_load");
        let path_string = path.to_string_lossy().to_string();
        let c_path = CString::new(path_string.clone()).expect("valid cstring");

        assert!(flutterxel_core_save(c_path.as_ptr(), -1, -1, -1, -1));
        assert!(flutterxel_core_load(c_path.as_ptr(), -1, -1, -1, -1));

        let (last_saved, last_loaded) = {
            let state = runtime_state().lock().expect("runtime state poisoned");
            (state.last_saved.clone(), state.last_loaded.clone())
        };
        assert_eq!(last_saved.as_deref(), Some(path_string.as_str()));
        assert_eq!(last_loaded.as_deref(), Some(path_string.as_str()));
        let _ = fs::remove_file(path);
    }

    #[test]
    fn save_writes_resource_manifest_toml_into_zip_archive() {
        let _guard = test_lock();
        init_runtime(8, 6);
        assert!(flutterxel_core_cls(11));

        let path = tmp_resource_path("zip_save");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save(c_path.as_ptr(), -1, -1, -1, -1));

        let toml_text = read_resource_archive_toml(&path);
        assert!(toml_text.contains(&format!("format_version = {}", RESOURCE_FORMAT_VERSION)));
        assert!(toml_text.contains("[runtime]"));
        assert!(toml_text.contains("width = 8"));
        assert!(toml_text.contains("height = 6"));
        assert!(toml_text.contains("clear_color = 11"));

        let _ = fs::remove_file(path);
    }

    #[test]
    fn load_rejects_future_resource_format_version() {
        let _guard = test_lock();
        init_runtime(4, 4);

        let path = tmp_resource_path("future_version");
        write_resource_archive(
            &path,
            &format!(
                "format_version = {}\n[runtime]\nwidth = 4\nheight = 4\nframe_count = 0\nclear_color = 0\n",
                RESOURCE_FORMAT_VERSION + 1
            ),
        );

        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(!flutterxel_core_load(c_path.as_ptr(), -1, -1, -1, -1));

        let _ = fs::remove_file(path);
    }

    #[test]
    fn load_accepts_pyxel_style_manifest_without_runtime_section() {
        let _guard = test_lock();
        init_runtime(4, 4);

        let path = tmp_resource_path("pyxel_style");
        write_resource_archive(
            &path,
            &format!(
                "format_version = {}\nimages = []\ntilemaps = []\nsounds = []\nmusics = []\n",
                RESOURCE_FORMAT_VERSION
            ),
        );

        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_load(c_path.as_ptr(), -1, -1, -1, -1));

        let state = runtime_state().lock().expect("runtime state poisoned");
        assert_eq!(state.width, 4);
        assert_eq!(state.height, 4);
        assert_eq!(state.frame_buffer.len(), 16);

        let _ = fs::remove_file(path);
    }

    #[test]
    fn play_updates_channel_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_play(
            1,
            0,
            3,
            std::ptr::null(),
            0,
            std::ptr::null(),
            f64::NAN,
            1,
            -1
        ));

        assert!(flutterxel_core_is_channel_playing(1));
    }
}
