use std::collections::{HashMap, HashSet, VecDeque};
use std::f64::consts::PI;
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
const TILE_SIZE: i32 = 8;
const MIN_FONT_CODE: u32 = 32;
const MAX_FONT_CODE: u32 = 127;
const FONT_WIDTH: usize = 4;
const FONT_HEIGHT: usize = 6;
const FONT_DATA: [u32; (MAX_FONT_CODE - MIN_FONT_CODE + 1) as usize] = [
    0x000000, 0x444040, 0xaa0000, 0xaeaea0, 0x6c6c40, 0x824820, 0x4a4ac0, 0x440000, 0x244420,
    0x844480, 0xa4e4a0, 0x04e400, 0x000480, 0x00e000, 0x000040, 0x224880, 0x6aaac0, 0x4c4440,
    0xc248e0, 0xc242c0, 0xaae220, 0xe8c2c0, 0x68eae0, 0xe24880, 0xeaeae0, 0xeae2c0, 0x040400,
    0x040480, 0x248420, 0x0e0e00, 0x842480, 0xe24040, 0x4aa860, 0x4aeaa0, 0xcacac0, 0x688860,
    0xcaaac0, 0xe8e8e0, 0xe8e880, 0x68ea60, 0xaaeaa0, 0xe444e0, 0x222a40, 0xaacaa0, 0x8888e0,
    0xaeeaa0, 0xcaaaa0, 0x4aaa40, 0xcac880, 0x4aae60, 0xcaeca0, 0x6842c0, 0xe44440, 0xaaaa60,
    0xaaaa40, 0xaaeea0, 0xaa4aa0, 0xaa4440, 0xe248e0, 0x644460, 0x884220, 0xc444c0, 0x4a0000,
    0x0000e0, 0x840000, 0x06aa60, 0x8caac0, 0x068860, 0x26aa60, 0x06ac60, 0x24e440, 0x06ae24,
    0x8caaa0, 0x404440, 0x2022a4, 0x8acca0, 0xc444e0, 0x0eeea0, 0x0caaa0, 0x04aa40, 0x0caac8,
    0x06aa62, 0x068880, 0x06c6c0, 0x4e4460, 0x0aaa60, 0x0aaa40, 0x0aaee0, 0x0a44a0, 0x0aa624,
    0x0e24e0, 0x64c460, 0x444440, 0xc464c0, 0x6c0000, 0xeeeee0,
];
const RNG_DEFAULT_STATE: u64 = 0xA3C5_9AC3_D12B_9E5D;
const NOISE_DEFAULT_SEED: u32 = 0;
const MOUSE_KEY_START_INDEX: i32 = 0x5000_0100;
const MOUSE_POS_X_KEY: i32 = MOUSE_KEY_START_INDEX;
const MOUSE_POS_Y_KEY: i32 = MOUSE_KEY_START_INDEX + 1;

#[allow(dead_code)]
#[derive(Debug, Clone)]
enum PlaySource {
    Index(i32),
    Sequence(Vec<i32>),
    Mml(String),
}

fn play_source_index(source: &PlaySource) -> i32 {
    match source {
        PlaySource::Index(index) => *index,
        PlaySource::Sequence(seq) => seq.first().copied().unwrap_or(0),
        PlaySource::Mml(_) => 0,
    }
}

#[allow(dead_code)]
#[derive(Debug, Clone)]
struct PlayCall {
    ch: i32,
    source: PlaySource,
    sec: Option<f64>,
    loop_opt: Option<bool>,
    resume_opt: Option<bool>,
    started_frame: u64,
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

#[derive(Debug, Clone)]
struct TilemapResource {
    width: u32,
    height: u32,
    imgsrc: i32,
    data: Vec<(i32, i32)>,
}

#[derive(Debug, Clone)]
struct SoundResource {
    notes: Vec<i32>,
    tones: Vec<i32>,
    volumes: Vec<i32>,
    effects: Vec<i32>,
    speed: i32,
}

#[derive(Debug, Clone)]
struct MusicResource {
    seqs: Vec<Vec<i32>>,
}

fn default_sound_resource() -> SoundResource {
    SoundResource {
        notes: Vec::new(),
        tones: Vec::new(),
        volumes: Vec::new(),
        effects: Vec::new(),
        speed: 30,
    }
}

fn default_music_resource() -> MusicResource {
    MusicResource { seqs: Vec::new() }
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
    perf_monitor_enabled: bool,
    integer_scale_enabled: bool,
    screen_mode: i32,
    fullscreen_enabled: bool,
    icon_data: Option<String>,
    icon_scale: i32,
    icon_colkey: Option<i32>,
    dither_alpha: f64,
    last_screenshot_scale: Option<i32>,
    screencast_scale: Option<i32>,
    screencast_enabled: bool,
    clear_color: i32,
    camera_x: i32,
    camera_y: i32,
    clip_x: i32,
    clip_y: i32,
    clip_w: i32,
    clip_h: i32,
    palette_map: [i32; 16],
    pressed_keys: HashSet<i32>,
    pressed_key_frame: HashMap<i32, u64>,
    released_key_frame: HashMap<i32, u64>,
    input_values: HashMap<i32, i32>,
    mouse_visible: bool,
    frame_buffer: Vec<i32>,
    image_banks: HashMap<i32, Vec<i32>>,
    image_bank_size: i32,
    tilemaps: HashMap<i32, TilemapResource>,
    sounds: HashMap<i32, SoundResource>,
    musics: HashMap<i32, MusicResource>,
    channel_playback: HashMap<i32, PlayCall>,
    rng_state: u64,
    noise_seed: u32,
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
            perf_monitor_enabled: false,
            integer_scale_enabled: true,
            screen_mode: 0,
            fullscreen_enabled: false,
            icon_data: None,
            icon_scale: 1,
            icon_colkey: None,
            dither_alpha: 1.0,
            last_screenshot_scale: None,
            screencast_scale: None,
            screencast_enabled: false,
            clear_color: 0,
            camera_x: 0,
            camera_y: 0,
            clip_x: 0,
            clip_y: 0,
            clip_w: 0,
            clip_h: 0,
            palette_map: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
            pressed_keys: HashSet::new(),
            pressed_key_frame: HashMap::new(),
            released_key_frame: HashMap::new(),
            input_values: HashMap::new(),
            mouse_visible: true,
            frame_buffer: Vec::new(),
            image_banks: HashMap::new(),
            image_bank_size: 16,
            tilemaps: HashMap::new(),
            sounds: HashMap::new(),
            musics: HashMap::new(),
            channel_playback: HashMap::new(),
            rng_state: RNG_DEFAULT_STATE,
            noise_seed: NOISE_DEFAULT_SEED,
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

fn runtime_fps(state: &RuntimeState) -> f64 {
    f64::from(state.fps.unwrap_or(30).max(1))
}

fn playback_elapsed_sec(state: &RuntimeState, call: &PlayCall) -> f64 {
    let elapsed_frames = state.frame_count.saturating_sub(call.started_frame);
    elapsed_frames as f64 / runtime_fps(state)
}

fn playback_pos_sec(state: &RuntimeState, call: &PlayCall) -> f64 {
    let elapsed = playback_elapsed_sec(state, call);
    match (call.sec, call.loop_opt.unwrap_or(false)) {
        (Some(sec), false) if sec > 0.0 => elapsed.min(sec),
        (Some(sec), true) if sec > 0.0 => elapsed % sec,
        _ => elapsed,
    }
}

fn is_playback_completed(state: &RuntimeState, call: &PlayCall) -> bool {
    if call.loop_opt.unwrap_or(false) {
        return false;
    }
    let Some(sec) = call.sec else {
        return false;
    };
    playback_elapsed_sec(state, call) >= sec
}

fn update_channel_playback_state(state: &mut RuntimeState) {
    let completed: Vec<i32> = state
        .channel_playback
        .iter()
        .filter_map(|(channel, call)| {
            if is_playback_completed(state, call) {
                Some(*channel)
            } else {
                None
            }
        })
        .collect();
    for channel in completed {
        state.channel_playback.remove(&channel);
    }
}

fn seed_to_rng_state(seed: i32) -> u64 {
    let unsigned_seed = u64::from(seed as u32);
    unsigned_seed ^ RNG_DEFAULT_STATE
}

fn next_random_u32(state: &mut RuntimeState) -> u32 {
    state.rng_state = state
        .rng_state
        .wrapping_mul(6364136223846793005)
        .wrapping_add(1);
    (state.rng_state >> 32) as u32
}

fn noise_fade(t: f64) -> f64 {
    t * t * (3.0 - 2.0 * t)
}

fn noise_lerp(a: f64, b: f64, t: f64) -> f64 {
    a + (b - a) * t
}

fn noise_hash(seed: u32, x: i32, y: i32, z: i32) -> f64 {
    let mut n = i64::from(x)
        .wrapping_mul(374_761_393)
        .wrapping_add(i64::from(y).wrapping_mul(668_265_263))
        .wrapping_add(i64::from(z).wrapping_mul(2_147_483_647))
        .wrapping_add(i64::from(seed).wrapping_mul(1_274_126_177));
    n = (n ^ (n >> 13)).wrapping_mul(1_274_126_177);
    let value = (n ^ (n >> 16)) as u32;
    (f64::from(value) / f64::from(u32::MAX)) * 2.0 - 1.0
}

fn sample_noise(seed: u32, x: f64, y: f64, z: f64) -> f64 {
    let x0 = x.floor() as i32;
    let y0 = y.floor() as i32;
    let z0 = z.floor() as i32;
    let tx = x - f64::from(x0);
    let ty = y - f64::from(y0);
    let tz = z - f64::from(z0);
    let fx = noise_fade(tx);
    let fy = noise_fade(ty);
    let fz = noise_fade(tz);

    let c000 = noise_hash(seed, x0, y0, z0);
    let c100 = noise_hash(seed, x0 + 1, y0, z0);
    let c010 = noise_hash(seed, x0, y0 + 1, z0);
    let c110 = noise_hash(seed, x0 + 1, y0 + 1, z0);
    let c001 = noise_hash(seed, x0, y0, z0 + 1);
    let c101 = noise_hash(seed, x0 + 1, y0, z0 + 1);
    let c011 = noise_hash(seed, x0, y0 + 1, z0 + 1);
    let c111 = noise_hash(seed, x0 + 1, y0 + 1, z0 + 1);

    let x00 = noise_lerp(c000, c100, fx);
    let x10 = noise_lerp(c010, c110, fx);
    let x01 = noise_lerp(c001, c101, fx);
    let x11 = noise_lerp(c011, c111, fx);
    let y0v = noise_lerp(x00, x10, fy);
    let y1v = noise_lerp(x01, x11, fy);
    noise_lerp(y0v, y1v, fz)
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

fn parse_palette_line(line: &str) -> Option<i32> {
    let trimmed = line.trim();
    if trimmed.is_empty() {
        return None;
    }

    if let Some(hex) = trimmed
        .strip_prefix("0x")
        .or_else(|| trimmed.strip_prefix("0X"))
    {
        return i32::from_str_radix(hex, 16).ok();
    }

    let is_hex_like = trimmed.chars().all(|ch| ch.is_ascii_hexdigit());
    if is_hex_like && (trimmed.len() == 6 || trimmed.len() == 8) {
        return i32::from_str_radix(trimmed, 16).ok();
    }

    trimmed.parse::<i32>().ok().or_else(|| {
        is_hex_like
            .then(|| i32::from_str_radix(trimmed, 16).ok())
            .flatten()
    })
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

fn ensure_default_tilemap(state: &mut RuntimeState) {
    if state.tilemaps.contains_key(&0) {
        return;
    }

    state.tilemaps.insert(
        0,
        TilemapResource {
            width: 1,
            height: 1,
            imgsrc: 0,
            data: vec![(0, 0)],
        },
    );
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

fn parse_i32_list(value: &toml::Value) -> Option<Vec<i32>> {
    let values = value.as_array()?;
    values.iter().map(parse_i32_value).collect()
}

fn parse_vec_i32_list(value: &toml::Value) -> Option<Vec<Vec<i32>>> {
    let rows = value.as_array()?;
    rows.iter().map(parse_i32_list).collect()
}

fn frame_buffer_len(width: i32, height: i32) -> Option<usize> {
    let width = usize::try_from(width).ok()?;
    let height = usize::try_from(height).ok()?;
    width.checked_mul(height)
}

fn image_bank_to_rows(bank: &[i32], bank_size: usize) -> Option<Vec<Vec<i32>>> {
    let required_len = bank_size.checked_mul(bank_size)?;
    if bank.len() < required_len {
        return None;
    }

    let mut rows = Vec::with_capacity(bank_size);
    for y in 0..bank_size {
        let from = y * bank_size;
        let to = from + bank_size;
        rows.push(bank[from..to].to_vec());
    }
    Some(rows)
}

fn parse_image_data(data_value: &toml::Value, width: usize, height: usize) -> Option<Vec<i32>> {
    let rows = data_value.as_array()?;
    let mut parsed_rows = Vec::new();

    for row_value in rows {
        let row_entries = row_value.as_array()?;
        let mut row = Vec::new();
        for color in row_entries {
            row.push(parse_i32_value(color)?);
        }
        if row.is_empty() {
            row.push(0);
        }
        parsed_rows.push(row);
    }

    if parsed_rows.is_empty() {
        parsed_rows.push(vec![0]);
    }

    for row in &mut parsed_rows {
        let fill = *row.last().unwrap_or(&0);
        if row.len() < width {
            row.resize(width, fill);
        }
        if row.len() > width {
            row.truncate(width);
        }
    }

    while parsed_rows.len() < height {
        let last_row = parsed_rows
            .last()
            .cloned()
            .unwrap_or_else(|| vec![0; width.max(1)]);
        parsed_rows.push(last_row);
    }
    if parsed_rows.len() > height {
        parsed_rows.truncate(height);
    }

    Some(parsed_rows.into_iter().flatten().collect())
}

fn tilemap_to_rows(tilemap: &TilemapResource) -> Option<Vec<Vec<i32>>> {
    let width = usize::try_from(tilemap.width).ok()?;
    let height = usize::try_from(tilemap.height).ok()?;
    if width == 0 || height == 0 {
        return None;
    }

    let cell_count = width.checked_mul(height)?;
    let mut data = tilemap.data.clone();
    if data.is_empty() {
        data.push((0, 0));
    }
    let fill = *data.last().unwrap_or(&(0, 0));
    if data.len() < cell_count {
        data.resize(cell_count, fill);
    }
    if data.len() > cell_count {
        data.truncate(cell_count);
    }

    let mut rows = Vec::with_capacity(height);
    for y in 0..height {
        let mut row = Vec::with_capacity(width * 2);
        for x in 0..width {
            let (tx, ty) = data[y * width + x];
            row.push(tx);
            row.push(ty);
        }
        rows.push(row);
    }
    Some(rows)
}

fn parse_tilemap_data(
    data_value: &toml::Value,
    width: usize,
    height: usize,
) -> Option<Vec<(i32, i32)>> {
    let rows = data_value.as_array()?;
    let mut parsed_rows = Vec::new();

    for row_value in rows {
        let row_entries = row_value.as_array()?;
        let mut row = Vec::new();
        for value in row_entries {
            row.push(parse_i32_value(value)?);
        }
        if row.is_empty() {
            row.push(0);
        }
        parsed_rows.push(row);
    }

    if parsed_rows.is_empty() {
        parsed_rows.push(vec![0]);
    }

    let expected_row_len = width.checked_mul(2)?;
    for row in &mut parsed_rows {
        let fill = *row.last().unwrap_or(&0);
        if row.len() < expected_row_len {
            row.resize(expected_row_len, fill);
        }
        if row.len() > expected_row_len {
            row.truncate(expected_row_len);
        }
    }

    while parsed_rows.len() < height {
        let last_row = parsed_rows
            .last()
            .cloned()
            .unwrap_or_else(|| vec![0; expected_row_len.max(1)]);
        parsed_rows.push(last_row);
    }
    if parsed_rows.len() > height {
        parsed_rows.truncate(height);
    }

    let flat: Vec<i32> = parsed_rows.into_iter().flatten().collect();
    let mut cells = Vec::with_capacity(width * height);
    for pair in flat.chunks_exact(2) {
        cells.push((pair[0], pair[1]));
    }
    Some(cells)
}

fn build_resource_images_value(state: &RuntimeState, exclude_images: bool) -> Option<toml::Value> {
    if exclude_images {
        return Some(toml::Value::Array(Vec::new()));
    }

    let bank_size = usize::try_from(state.image_bank_size.max(1)).ok()?;
    let bank_len = bank_size.checked_mul(bank_size)?;
    let max_image_index = state
        .image_banks
        .keys()
        .copied()
        .filter(|index| *index >= 0)
        .max()
        .unwrap_or(-1);

    if max_image_index < 0 {
        return Some(toml::Value::Array(Vec::new()));
    }

    let mut images = Vec::new();
    for image_index in 0..=max_image_index {
        let bank = state
            .image_banks
            .get(&image_index)
            .cloned()
            .unwrap_or_else(|| vec![0; bank_len]);

        let mut padded_bank = bank;
        if padded_bank.len() < bank_len {
            padded_bank.resize(bank_len, 0);
        }
        let rows = image_bank_to_rows(&padded_bank, bank_size)?;

        let mut image_table = toml::map::Map::new();
        image_table.insert("width".to_string(), toml::Value::Integer(bank_size as i64));
        image_table.insert("height".to_string(), toml::Value::Integer(bank_size as i64));
        image_table.insert(
            "data".to_string(),
            toml::Value::Array(
                rows.into_iter()
                    .map(|row| {
                        toml::Value::Array(
                            row.into_iter()
                                .map(|color| toml::Value::Integer(color as i64))
                                .collect(),
                        )
                    })
                    .collect(),
            ),
        );
        images.push(toml::Value::Table(image_table));
    }

    Some(toml::Value::Array(images))
}

fn load_resource_images(
    state: &mut RuntimeState,
    manifest: &toml::Value,
    exclude_images: bool,
) -> bool {
    if exclude_images {
        return true;
    }
    let Some(images_value) = manifest.get("images") else {
        return true;
    };
    let Some(images) = images_value.as_array() else {
        return false;
    };
    if images.is_empty() {
        return true;
    }

    let mut parsed_banks = Vec::<(usize, Vec<i32>, usize)>::new();
    let mut max_bank_size = 0usize;

    for (image_index, image_value) in images.iter().enumerate() {
        let Some(image_table) = image_value.as_table() else {
            return false;
        };
        let Some(width) = image_table.get("width").and_then(parse_u32_value) else {
            return false;
        };
        let Some(height) = image_table.get("height").and_then(parse_u32_value) else {
            return false;
        };
        if width == 0 || height == 0 {
            return false;
        }

        let width = width as usize;
        let height = height as usize;
        let Some(data_value) = image_table.get("data") else {
            return false;
        };
        let Some(flat_data) = parse_image_data(data_value, width, height) else {
            return false;
        };

        let bank_size = width.max(height);
        let Some(bank_len) = bank_size.checked_mul(bank_size) else {
            return false;
        };
        let mut square_bank = vec![0; bank_len];
        for y in 0..height {
            for x in 0..width {
                square_bank[y * bank_size + x] = flat_data[y * width + x];
            }
        }

        max_bank_size = max_bank_size.max(bank_size);
        parsed_banks.push((image_index, square_bank, bank_size));
    }

    if max_bank_size == 0 {
        return true;
    }

    let Some(max_bank_len) = max_bank_size.checked_mul(max_bank_size) else {
        return false;
    };
    state.image_banks.clear();
    for (image_index, bank, bank_size) in parsed_banks {
        let normalized_bank = if bank_size == max_bank_size {
            bank
        } else {
            let mut normalized = vec![0; max_bank_len];
            for y in 0..bank_size {
                let src_from = y * bank_size;
                let src_to = src_from + bank_size;
                let dst_from = y * max_bank_size;
                let dst_to = dst_from + bank_size;
                normalized[dst_from..dst_to].copy_from_slice(&bank[src_from..src_to]);
            }
            normalized
        };
        state
            .image_banks
            .insert(image_index as i32, normalized_bank);
    }
    state.image_bank_size = max_bank_size as i32;
    true
}

fn build_resource_tilemaps_value(
    state: &RuntimeState,
    exclude_tilemaps: bool,
) -> Option<toml::Value> {
    if exclude_tilemaps {
        return Some(toml::Value::Array(Vec::new()));
    }

    let max_tilemap_index = state
        .tilemaps
        .keys()
        .copied()
        .filter(|index| *index >= 0)
        .max()
        .unwrap_or(-1);
    if max_tilemap_index < 0 {
        return Some(toml::Value::Array(Vec::new()));
    }

    let mut tilemaps = Vec::new();
    for tilemap_index in 0..=max_tilemap_index {
        let tilemap = state
            .tilemaps
            .get(&tilemap_index)
            .cloned()
            .unwrap_or(TilemapResource {
                width: 1,
                height: 1,
                imgsrc: 0,
                data: vec![(0, 0)],
            });
        let rows = tilemap_to_rows(&tilemap)?;

        let mut table = toml::map::Map::new();
        table.insert(
            "width".to_string(),
            toml::Value::Integer(tilemap.width as i64),
        );
        table.insert(
            "height".to_string(),
            toml::Value::Integer(tilemap.height as i64),
        );
        table.insert(
            "imgsrc".to_string(),
            toml::Value::Integer(tilemap.imgsrc as i64),
        );
        table.insert(
            "data".to_string(),
            toml::Value::Array(
                rows.into_iter()
                    .map(|row| {
                        toml::Value::Array(
                            row.into_iter()
                                .map(|value| toml::Value::Integer(value as i64))
                                .collect(),
                        )
                    })
                    .collect(),
            ),
        );
        tilemaps.push(toml::Value::Table(table));
    }

    Some(toml::Value::Array(tilemaps))
}

fn load_resource_tilemaps(
    state: &mut RuntimeState,
    manifest: &toml::Value,
    exclude_tilemaps: bool,
) -> bool {
    if exclude_tilemaps {
        return true;
    }
    let Some(tilemaps_value) = manifest.get("tilemaps") else {
        return true;
    };
    let Some(tilemaps) = tilemaps_value.as_array() else {
        return false;
    };
    if tilemaps.is_empty() {
        return true;
    }

    let mut parsed_tilemaps = HashMap::new();
    for (tilemap_index, tilemap_value) in tilemaps.iter().enumerate() {
        let Some(table) = tilemap_value.as_table() else {
            return false;
        };
        let Some(width) = table.get("width").and_then(parse_u32_value) else {
            return false;
        };
        let Some(height) = table.get("height").and_then(parse_u32_value) else {
            return false;
        };
        let Some(imgsrc) = table.get("imgsrc").and_then(parse_i32_value) else {
            return false;
        };
        if width == 0 || height == 0 {
            return false;
        }

        let width_usize = width as usize;
        let height_usize = height as usize;
        let Some(data_value) = table.get("data") else {
            return false;
        };
        let Some(data) = parse_tilemap_data(data_value, width_usize, height_usize) else {
            return false;
        };

        parsed_tilemaps.insert(
            tilemap_index as i32,
            TilemapResource {
                width,
                height,
                imgsrc,
                data,
            },
        );
    }

    state.tilemaps = parsed_tilemaps;
    true
}

fn build_resource_sounds_value(state: &RuntimeState, exclude_sounds: bool) -> Option<toml::Value> {
    if exclude_sounds {
        return Some(toml::Value::Array(Vec::new()));
    }

    let max_sound_index = state
        .sounds
        .keys()
        .copied()
        .filter(|index| *index >= 0)
        .max()
        .unwrap_or(-1);
    if max_sound_index < 0 {
        return Some(toml::Value::Array(Vec::new()));
    }

    let mut sounds = Vec::new();
    for sound_index in 0..=max_sound_index {
        let sound = state
            .sounds
            .get(&sound_index)
            .cloned()
            .unwrap_or_else(default_sound_resource);

        let mut table = toml::map::Map::new();
        table.insert(
            "notes".to_string(),
            toml::Value::Array(
                sound
                    .notes
                    .iter()
                    .map(|value| toml::Value::Integer(*value as i64))
                    .collect(),
            ),
        );
        table.insert(
            "tones".to_string(),
            toml::Value::Array(
                sound
                    .tones
                    .iter()
                    .map(|value| toml::Value::Integer(*value as i64))
                    .collect(),
            ),
        );
        table.insert(
            "volumes".to_string(),
            toml::Value::Array(
                sound
                    .volumes
                    .iter()
                    .map(|value| toml::Value::Integer(*value as i64))
                    .collect(),
            ),
        );
        table.insert(
            "effects".to_string(),
            toml::Value::Array(
                sound
                    .effects
                    .iter()
                    .map(|value| toml::Value::Integer(*value as i64))
                    .collect(),
            ),
        );
        table.insert(
            "speed".to_string(),
            toml::Value::Integer(sound.speed as i64),
        );
        sounds.push(toml::Value::Table(table));
    }

    Some(toml::Value::Array(sounds))
}

fn load_resource_sounds(
    state: &mut RuntimeState,
    manifest: &toml::Value,
    exclude_sounds: bool,
) -> bool {
    if exclude_sounds {
        return true;
    }
    let Some(sounds_value) = manifest.get("sounds") else {
        return true;
    };
    let Some(sounds) = sounds_value.as_array() else {
        return false;
    };
    if sounds.is_empty() {
        return true;
    }

    let mut parsed_sounds = HashMap::new();
    for (sound_index, sound_value) in sounds.iter().enumerate() {
        let Some(table) = sound_value.as_table() else {
            return false;
        };
        let Some(notes) = table.get("notes").and_then(parse_i32_list) else {
            return false;
        };
        let Some(tones) = table.get("tones").and_then(parse_i32_list) else {
            return false;
        };
        let Some(volumes) = table.get("volumes").and_then(parse_i32_list) else {
            return false;
        };
        let Some(effects) = table.get("effects").and_then(parse_i32_list) else {
            return false;
        };
        let Some(speed) = table.get("speed").and_then(parse_i32_value) else {
            return false;
        };

        parsed_sounds.insert(
            sound_index as i32,
            SoundResource {
                notes,
                tones,
                volumes,
                effects,
                speed,
            },
        );
    }

    state.sounds = parsed_sounds;
    true
}

fn build_resource_musics_value(state: &RuntimeState, exclude_musics: bool) -> Option<toml::Value> {
    if exclude_musics {
        return Some(toml::Value::Array(Vec::new()));
    }

    let max_music_index = state
        .musics
        .keys()
        .copied()
        .filter(|index| *index >= 0)
        .max()
        .unwrap_or(-1);
    if max_music_index < 0 {
        return Some(toml::Value::Array(Vec::new()));
    }

    let mut musics = Vec::new();
    for music_index in 0..=max_music_index {
        let music = state
            .musics
            .get(&music_index)
            .cloned()
            .unwrap_or_else(default_music_resource);

        let mut table = toml::map::Map::new();
        table.insert(
            "seqs".to_string(),
            toml::Value::Array(
                music
                    .seqs
                    .iter()
                    .map(|seq| {
                        toml::Value::Array(
                            seq.iter()
                                .map(|value| toml::Value::Integer(*value as i64))
                                .collect(),
                        )
                    })
                    .collect(),
            ),
        );
        musics.push(toml::Value::Table(table));
    }

    Some(toml::Value::Array(musics))
}

fn load_resource_musics(
    state: &mut RuntimeState,
    manifest: &toml::Value,
    exclude_musics: bool,
) -> bool {
    if exclude_musics {
        return true;
    }
    let Some(musics_value) = manifest.get("musics") else {
        return true;
    };
    let Some(musics) = musics_value.as_array() else {
        return false;
    };
    if musics.is_empty() {
        return true;
    }

    let mut parsed_musics = HashMap::new();
    for (music_index, music_value) in musics.iter().enumerate() {
        let Some(table) = music_value.as_table() else {
            return false;
        };
        let Some(seqs) = table.get("seqs").and_then(parse_vec_i32_list) else {
            return false;
        };

        parsed_musics.insert(music_index as i32, MusicResource { seqs });
    }

    state.musics = parsed_musics;
    true
}

fn build_resource_toml(
    state: &RuntimeState,
    exclude_images: bool,
    exclude_tilemaps: bool,
    exclude_sounds: bool,
    exclude_musics: bool,
) -> Option<String> {
    let mut root = toml::map::Map::new();
    root.insert(
        "format_version".to_string(),
        toml::Value::Integer(RESOURCE_FORMAT_VERSION as i64),
    );
    root.insert(
        "images".to_string(),
        build_resource_images_value(state, exclude_images)?,
    );
    root.insert(
        "tilemaps".to_string(),
        build_resource_tilemaps_value(state, exclude_tilemaps)?,
    );
    root.insert(
        "sounds".to_string(),
        build_resource_sounds_value(state, exclude_sounds)?,
    );
    root.insert(
        "musics".to_string(),
        build_resource_musics_value(state, exclude_musics)?,
    );

    let mut runtime_table = toml::map::Map::new();
    runtime_table.insert(
        "width".to_string(),
        toml::Value::Integer(state.width as i64),
    );
    runtime_table.insert(
        "height".to_string(),
        toml::Value::Integer(state.height as i64),
    );
    runtime_table.insert(
        "frame_count".to_string(),
        toml::Value::Integer(state.frame_count as i64),
    );
    runtime_table.insert(
        "clear_color".to_string(),
        toml::Value::Integer(state.clear_color as i64),
    );
    root.insert(
        RESOURCE_RUNTIME_SECTION.to_string(),
        toml::Value::Table(runtime_table),
    );

    toml::to_string(&toml::Value::Table(root)).ok()
}

fn draw_blt(state: &mut RuntimeState, call: &BltCall) -> bool {
    let Some(source) = state.image_banks.get(&call.img).cloned() else {
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
            set_frame_pixel(state, dst_x, dst_y, color);
        }
    }

    true
}

fn draw_bltm(
    state: &mut RuntimeState,
    x: f64,
    y: f64,
    tm: i32,
    u: f64,
    v: f64,
    w: f64,
    h: f64,
    colkey: Option<i32>,
) -> bool {
    let Some(tilemap) = state.tilemaps.get(&tm).cloned() else {
        return false;
    };
    let Some(source_bank) = state.image_banks.get(&tilemap.imgsrc).cloned() else {
        return false;
    };
    let source_size = state.image_bank_size;
    if source_size <= 0 {
        return false;
    }

    let tilemap_width = i32::try_from(tilemap.width).ok().unwrap_or(0);
    let tilemap_height = i32::try_from(tilemap.height).ok().unwrap_or(0);
    if tilemap_width <= 0 || tilemap_height <= 0 {
        return true;
    }

    let tiles_w = w.abs().round() as i32;
    let tiles_h = h.abs().round() as i32;
    if tiles_w <= 0 || tiles_h <= 0 {
        return true;
    }

    let flip_x = w < 0.0;
    let flip_y = h < 0.0;
    let base_dx = x.round() as i32;
    let base_dy = y.round() as i32;
    let base_tx = u.round() as i32;
    let base_ty = v.round() as i32;
    let source_size_usize = source_size as usize;

    for dy in 0..tiles_h {
        for dx in 0..tiles_w {
            let src_tx = base_tx + if flip_x { tiles_w - 1 - dx } else { dx };
            let src_ty = base_ty + if flip_y { tiles_h - 1 - dy } else { dy };
            if src_tx < 0 || src_tx >= tilemap_width || src_ty < 0 || src_ty >= tilemap_height {
                continue;
            }

            let tile_index = src_ty as usize * tilemap_width as usize + src_tx as usize;
            if tile_index >= tilemap.data.len() {
                continue;
            }
            let (tile_x, tile_y) = tilemap.data[tile_index];

            for py in 0..TILE_SIZE {
                for px in 0..TILE_SIZE {
                    let src_x = tile_x * TILE_SIZE + px;
                    let src_y = tile_y * TILE_SIZE + py;
                    if src_x < 0 || src_x >= source_size || src_y < 0 || src_y >= source_size {
                        continue;
                    }

                    let src_index = src_y as usize * source_size_usize + src_x as usize;
                    let color = source_bank[src_index];
                    if colkey == Some(color) {
                        continue;
                    }

                    let dst_x = base_dx + dx * TILE_SIZE + px;
                    let dst_y = base_dy + dy * TILE_SIZE + py;
                    set_frame_pixel(state, dst_x, dst_y, color);
                }
            }
        }
    }

    true
}

fn apply_palette(state: &RuntimeState, col: i32) -> i32 {
    if let Ok(index) = usize::try_from(col) {
        if index < state.palette_map.len() {
            return state.palette_map[index];
        }
    }
    col
}

fn set_frame_pixel(state: &mut RuntimeState, x: i32, y: i32, col: i32) {
    let sx = x - state.camera_x;
    let sy = y - state.camera_y;

    if sx < 0 || sx >= state.width || sy < 0 || sy >= state.height {
        return;
    }
    if sx < state.clip_x || sy < state.clip_y {
        return;
    }
    if sx >= state.clip_x + state.clip_w || sy >= state.clip_y + state.clip_h {
        return;
    }

    let index = sy as usize * state.width as usize + sx as usize;
    state.frame_buffer[index] = apply_palette(state, col);
}

fn get_frame_pixel(state: &RuntimeState, x: i32, y: i32) -> i32 {
    if x < 0 || x >= state.width || y < 0 || y >= state.height {
        return 0;
    }
    let index = y as usize * state.width as usize + x as usize;
    state.frame_buffer[index]
}

fn draw_line(state: &mut RuntimeState, mut x1: i32, mut y1: i32, x2: i32, y2: i32, col: i32) {
    let dx = (x2 - x1).abs();
    let sx = if x1 < x2 { 1 } else { -1 };
    let dy = -(y2 - y1).abs();
    let sy = if y1 < y2 { 1 } else { -1 };
    let mut err = dx + dy;

    loop {
        set_frame_pixel(state, x1, y1, col);
        if x1 == x2 && y1 == y2 {
            break;
        }
        let e2 = 2 * err;
        if e2 >= dy {
            err += dy;
            x1 += sx;
        }
        if e2 <= dx {
            err += dx;
            y1 += sy;
        }
    }
}

fn draw_rect(state: &mut RuntimeState, x: i32, y: i32, w: i32, h: i32, col: i32) {
    if w <= 0 || h <= 0 {
        return;
    }
    for py in y..(y + h) {
        for px in x..(x + w) {
            set_frame_pixel(state, px, py, col);
        }
    }
}

fn draw_rectb(state: &mut RuntimeState, x: i32, y: i32, w: i32, h: i32, col: i32) {
    if w <= 0 || h <= 0 {
        return;
    }

    let right = x + w - 1;
    let bottom = y + h - 1;
    for px in x..=right {
        set_frame_pixel(state, px, y, col);
        set_frame_pixel(state, px, bottom, col);
    }
    if bottom > y {
        for py in (y + 1)..bottom {
            set_frame_pixel(state, x, py, col);
            set_frame_pixel(state, right, py, col);
        }
    }
}

fn draw_circle_outline_points(
    state: &mut RuntimeState,
    cx: i32,
    cy: i32,
    x: i32,
    y: i32,
    col: i32,
) {
    set_frame_pixel(state, cx + x, cy + y, col);
    set_frame_pixel(state, cx - x, cy + y, col);
    set_frame_pixel(state, cx + x, cy - y, col);
    set_frame_pixel(state, cx - x, cy - y, col);
    set_frame_pixel(state, cx + y, cy + x, col);
    set_frame_pixel(state, cx - y, cy + x, col);
    set_frame_pixel(state, cx + y, cy - x, col);
    set_frame_pixel(state, cx - y, cy - x, col);
}

fn draw_circ(state: &mut RuntimeState, x: i32, y: i32, r: i32, col: i32) {
    if r < 0 {
        return;
    }

    let rr = i64::from(r) * i64::from(r);
    for dy in -r..=r {
        let remain = rr - i64::from(dy) * i64::from(dy);
        let max_dx = (remain as f64).sqrt().floor() as i32;
        for dx in -max_dx..=max_dx {
            set_frame_pixel(state, x + dx, y + dy, col);
        }
    }
}

fn draw_circb(state: &mut RuntimeState, x: i32, y: i32, r: i32, col: i32) {
    if r < 0 {
        return;
    }

    let mut px = r;
    let mut py = 0;
    let mut err = 1 - px;
    while px >= py {
        draw_circle_outline_points(state, x, y, px, py, col);
        py += 1;
        if err < 0 {
            err += 2 * py + 1;
        } else {
            px -= 1;
            err += 2 * (py - px + 1);
        }
    }
}

fn ellipse_contains(px: i32, py: i32, w: i32, h: i32) -> bool {
    if w <= 0 || h <= 0 {
        return false;
    }

    let dx = i128::from(px) * 2 + 1 - i128::from(w);
    let dy = i128::from(py) * 2 + 1 - i128::from(h);
    let w_sq = i128::from(w) * i128::from(w);
    let h_sq = i128::from(h) * i128::from(h);
    let lhs = dx * dx * h_sq + dy * dy * w_sq;
    let rhs = w_sq * h_sq;
    lhs <= rhs
}

fn draw_elli(state: &mut RuntimeState, x: i32, y: i32, w: i32, h: i32, col: i32) {
    if w <= 0 || h <= 0 {
        return;
    }

    for py in 0..h {
        for px in 0..w {
            if ellipse_contains(px, py, w, h) {
                set_frame_pixel(state, x + px, y + py, col);
            }
        }
    }
}

fn draw_ellib(state: &mut RuntimeState, x: i32, y: i32, w: i32, h: i32, col: i32) {
    if w <= 0 || h <= 0 {
        return;
    }

    for py in 0..h {
        for px in 0..w {
            if !ellipse_contains(px, py, w, h) {
                continue;
            }

            let is_edge = !ellipse_contains(px - 1, py, w, h)
                || !ellipse_contains(px + 1, py, w, h)
                || !ellipse_contains(px, py - 1, w, h)
                || !ellipse_contains(px, py + 1, w, h);
            if is_edge {
                set_frame_pixel(state, x + px, y + py, col);
            }
        }
    }
}

fn draw_fill(state: &mut RuntimeState, x: i32, y: i32, col: i32) {
    let sx = x - state.camera_x;
    let sy = y - state.camera_y;

    if sx < 0 || sx >= state.width || sy < 0 || sy >= state.height {
        return;
    }
    if sx < state.clip_x || sy < state.clip_y {
        return;
    }
    if sx >= state.clip_x + state.clip_w || sy >= state.clip_y + state.clip_h {
        return;
    }

    let width = state.width as usize;
    let start_index = sy as usize * width + sx as usize;
    let target_color = state.frame_buffer[start_index];
    let fill_color = apply_palette(state, col);
    if target_color == fill_color {
        return;
    }

    let mut queue = VecDeque::new();
    queue.push_back((sx, sy));

    while let Some((cx, cy)) = queue.pop_front() {
        if cx < 0 || cx >= state.width || cy < 0 || cy >= state.height {
            continue;
        }
        if cx < state.clip_x || cy < state.clip_y {
            continue;
        }
        if cx >= state.clip_x + state.clip_w || cy >= state.clip_y + state.clip_h {
            continue;
        }

        let index = cy as usize * width + cx as usize;
        if state.frame_buffer[index] != target_color {
            continue;
        }
        state.frame_buffer[index] = fill_color;

        queue.push_back((cx - 1, cy));
        queue.push_back((cx + 1, cy));
        queue.push_back((cx, cy - 1));
        queue.push_back((cx, cy + 1));
    }
}

fn edge_function(ax: i32, ay: i32, bx: i32, by: i32, px: i32, py: i32) -> i64 {
    i64::from(px - ax) * i64::from(by - ay) - i64::from(py - ay) * i64::from(bx - ax)
}

fn draw_tri(
    state: &mut RuntimeState,
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    x3: i32,
    y3: i32,
    col: i32,
) {
    let min_x = x1.min(x2).min(x3);
    let max_x = x1.max(x2).max(x3);
    let min_y = y1.min(y2).min(y3);
    let max_y = y1.max(y2).max(y3);

    for py in min_y..=max_y {
        for px in min_x..=max_x {
            let w1 = edge_function(x1, y1, x2, y2, px, py);
            let w2 = edge_function(x2, y2, x3, y3, px, py);
            let w3 = edge_function(x3, y3, x1, y1, px, py);
            let all_non_negative = w1 >= 0 && w2 >= 0 && w3 >= 0;
            let all_non_positive = w1 <= 0 && w2 <= 0 && w3 <= 0;
            if all_non_negative || all_non_positive {
                set_frame_pixel(state, px, py, col);
            }
        }
    }
}

fn draw_trib(
    state: &mut RuntimeState,
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    x3: i32,
    y3: i32,
    col: i32,
) {
    draw_line(state, x1, y1, x2, y2, col);
    draw_line(state, x2, y2, x3, y3, col);
    draw_line(state, x3, y3, x1, y1, col);
}

fn draw_text(state: &mut RuntimeState, x: i32, y: i32, text: &str, col: i32) {
    fn builtin_font_pixel_on(code: u32, x: usize, y: usize) -> bool {
        if !(MIN_FONT_CODE..=MAX_FONT_CODE).contains(&code) {
            return false;
        }
        if x >= FONT_WIDTH || y >= FONT_HEIGHT {
            return false;
        }
        let glyph = FONT_DATA[(code - MIN_FONT_CODE) as usize];
        let bit_index = FONT_WIDTH * FONT_HEIGHT - 1 - (y * FONT_WIDTH + x);
        (glyph & (1_u32 << bit_index)) != 0
    }

    let mut cursor_x = x;
    let mut cursor_y = y;
    let line_start_x = x;
    for ch in text.chars() {
        if ch == '\n' {
            cursor_x = line_start_x;
            cursor_y += FONT_HEIGHT as i32;
            continue;
        }

        let code = ch as u32;
        if !(MIN_FONT_CODE..=MAX_FONT_CODE).contains(&code) {
            continue;
        }

        for dy in 0..FONT_HEIGHT {
            for dx in 0..FONT_WIDTH {
                if builtin_font_pixel_on(code, dx, dy) {
                    set_frame_pixel(state, cursor_x + dx as i32, cursor_y + dy as i32, col);
                }
            }
        }
        cursor_x += FONT_WIDTH as i32;
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
    state.perf_monitor_enabled = false;
    state.integer_scale_enabled = true;
    state.screen_mode = 0;
    state.fullscreen_enabled = false;
    state.icon_data = None;
    state.icon_scale = 1;
    state.icon_colkey = None;
    state.dither_alpha = 1.0;
    state.last_screenshot_scale = None;
    state.screencast_scale = None;
    state.screencast_enabled = false;
    state.clear_color = 0;
    state.camera_x = 0;
    state.camera_y = 0;
    state.clip_x = 0;
    state.clip_y = 0;
    state.clip_w = width;
    state.clip_h = height;
    state.palette_map = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    state.pressed_keys.clear();
    state.pressed_key_frame.clear();
    state.released_key_frame.clear();
    state.input_values.clear();
    state.mouse_visible = true;
    let Some(frame_buffer_len) = frame_buffer_len(width, height) else {
        return false;
    };
    state.frame_buffer = vec![0; frame_buffer_len];
    state.image_banks.clear();
    state.tilemaps.clear();
    state.sounds.clear();
    state.musics.clear();
    state.channel_playback.clear();
    state.rng_state = RNG_DEFAULT_STATE;
    state.noise_seed = NOISE_DEFAULT_SEED;
    state.last_blt = None;
    state.last_play = None;
    state.last_loaded = None;
    state.last_saved = None;
    ensure_default_image_bank(&mut state);
    ensure_default_tilemap(&mut state);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_quit() -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    state.initialized = false;
    state.width = 0;
    state.height = 0;
    state.frame_count = 0;
    state.title = None;
    state.fps = None;
    state.quit_key = None;
    state.display_scale = None;
    state.capture_scale = None;
    state.capture_sec = None;
    state.perf_monitor_enabled = false;
    state.integer_scale_enabled = true;
    state.screen_mode = 0;
    state.fullscreen_enabled = false;
    state.icon_data = None;
    state.icon_scale = 1;
    state.icon_colkey = None;
    state.dither_alpha = 1.0;
    state.last_screenshot_scale = None;
    state.screencast_scale = None;
    state.screencast_enabled = false;
    state.clear_color = 0;
    state.camera_x = 0;
    state.camera_y = 0;
    state.clip_x = 0;
    state.clip_y = 0;
    state.clip_w = 0;
    state.clip_h = 0;
    state.palette_map = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    state.pressed_keys.clear();
    state.pressed_key_frame.clear();
    state.released_key_frame.clear();
    state.input_values.clear();
    state.mouse_visible = true;
    state.frame_buffer.clear();
    state.image_banks.clear();
    state.image_bank_size = 16;
    state.tilemaps.clear();
    state.sounds.clear();
    state.musics.clear();
    state.channel_playback.clear();
    state.rng_state = RNG_DEFAULT_STATE;
    state.noise_seed = NOISE_DEFAULT_SEED;
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
        update_channel_playback_state(&mut state);
        let current_frame = state.frame_count;
        state
            .released_key_frame
            .retain(|_, released_frame| *released_frame == current_frame);
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
pub extern "C" fn flutterxel_core_flip() -> bool {
    flutterxel_core_run(None, std::ptr::null_mut(), None, std::ptr::null_mut())
}

#[no_mangle]
pub extern "C" fn flutterxel_core_show() -> bool {
    flutterxel_core_flip()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_title(title: *const c_char) -> bool {
    if title.is_null() {
        return false;
    }
    let c_str = unsafe { CStr::from_ptr(title) };
    let Ok(value) = c_str.to_str() else {
        return false;
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.title = Some(value.to_string());
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_icon(data: *const c_char, scale: i32, colkey: i32) -> bool {
    if data.is_null() || scale <= 0 {
        return false;
    }
    let decoded_colkey = decode_optional_i32(colkey);
    let c_str = unsafe { CStr::from_ptr(data) };
    let Ok(value) = c_str.to_str() else {
        return false;
    };
    if value.is_empty() {
        return false;
    }

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.icon_data = Some(value.to_string());
    state.icon_scale = scale;
    state.icon_colkey = decoded_colkey;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_reset() -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    state.initialized = false;
    state.width = 0;
    state.height = 0;
    state.frame_count = 0;
    state.title = None;
    state.fps = None;
    state.quit_key = None;
    state.display_scale = None;
    state.capture_scale = None;
    state.capture_sec = None;
    state.perf_monitor_enabled = false;
    state.integer_scale_enabled = true;
    state.screen_mode = 0;
    state.fullscreen_enabled = false;
    state.icon_data = None;
    state.icon_scale = 1;
    state.icon_colkey = None;
    state.dither_alpha = 1.0;
    state.last_screenshot_scale = None;
    state.screencast_scale = None;
    state.screencast_enabled = false;
    state.clear_color = 0;
    state.camera_x = 0;
    state.camera_y = 0;
    state.clip_x = 0;
    state.clip_y = 0;
    state.clip_w = 0;
    state.clip_h = 0;
    state.palette_map = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    state.pressed_keys.clear();
    state.pressed_key_frame.clear();
    state.released_key_frame.clear();
    state.input_values.clear();
    state.mouse_visible = true;
    state.frame_buffer.clear();
    state.image_banks.clear();
    state.image_bank_size = 16;
    state.tilemaps.clear();
    state.sounds.clear();
    state.musics.clear();
    state.channel_playback.clear();
    state.rng_state = RNG_DEFAULT_STATE;
    state.noise_seed = NOISE_DEFAULT_SEED;
    state.last_blt = None;
    state.last_play = None;
    state.last_loaded = None;
    state.last_saved = None;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_perf_monitor(enabled: bool) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.perf_monitor_enabled = enabled;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_integer_scale(enabled: bool) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.integer_scale_enabled = enabled;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_screen_mode(scr: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.screen_mode = scr;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_fullscreen(enabled: bool) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.fullscreen_enabled = enabled;
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
        if state.pressed_keys.insert(key) {
            let frame = state.frame_count;
            state.pressed_key_frame.insert(key, frame);
        }
        state.released_key_frame.remove(&key);
        state.input_values.insert(key, 1);
    } else {
        if state.pressed_keys.remove(&key) {
            state.pressed_key_frame.remove(&key);
            let frame = state.frame_count;
            state.released_key_frame.insert(key, frame);
        }
        state.input_values.insert(key, 0);
    }
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_btnp(key: i32, hold: i32, period: i32) -> bool {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    if !state.pressed_keys.contains(&key) {
        return false;
    }

    let Some(pressed_frame) = state.pressed_key_frame.get(&key) else {
        return false;
    };
    let elapsed = state.frame_count.saturating_sub(*pressed_frame);
    if elapsed == 0 {
        return true;
    }

    if hold <= 0 || period <= 0 {
        return false;
    }

    let hold = hold as u64;
    let period = period as u64;
    if elapsed < hold {
        return false;
    }

    (elapsed - hold) % period == 0
}

#[no_mangle]
pub extern "C" fn flutterxel_core_btnr(key: i32) -> bool {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    state.released_key_frame.get(&key).copied() == Some(state.frame_count)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_btnv(key: i32) -> i32 {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0;
    }
    state.input_values.get(&key).copied().unwrap_or(0)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_mouse(visible: bool) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.mouse_visible = visible;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_warp_mouse(x: f64, y: f64) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    let clamped_x = x.round().clamp(f64::from(i32::MIN), f64::from(i32::MAX)) as i32;
    let clamped_y = y.round().clamp(f64::from(i32::MIN), f64::from(i32::MAX)) as i32;
    state.input_values.insert(MOUSE_POS_X_KEY, clamped_x);
    state.input_values.insert(MOUSE_POS_Y_KEY, clamped_y);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_set_btn_value(key: i32, value: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.input_values.insert(key, value);
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
pub extern "C" fn flutterxel_core_camera(x: i32, y: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.camera_x = x;
    state.camera_y = y;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_clip(x: i32, y: i32, w: i32, h: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    let mut x0 = x;
    let mut y0 = y;
    let mut x1 = x.saturating_add(w);
    let mut y1 = y.saturating_add(h);
    x0 = x0.clamp(0, state.width);
    y0 = y0.clamp(0, state.height);
    x1 = x1.clamp(0, state.width);
    y1 = y1.clamp(0, state.height);

    if x1 < x0 {
        std::mem::swap(&mut x0, &mut x1);
    }
    if y1 < y0 {
        std::mem::swap(&mut y0, &mut y1);
    }

    state.clip_x = x0;
    state.clip_y = y0;
    state.clip_w = x1.saturating_sub(x0);
    state.clip_h = y1.saturating_sub(y0);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_pal(col1: i32, col2: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    let opt_col1 = decode_optional_i32(col1);
    let opt_col2 = decode_optional_i32(col2);
    match (opt_col1, opt_col2) {
        (None, None) => {
            state.palette_map = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
            true
        }
        (Some(src), None) => {
            if let Ok(index) = usize::try_from(src) {
                if index < state.palette_map.len() {
                    state.palette_map[index] = src;
                }
            }
            true
        }
        (Some(src), Some(dst)) => {
            if let Ok(index) = usize::try_from(src) {
                if index < state.palette_map.len() {
                    state.palette_map[index] = dst;
                }
            }
            true
        }
        (None, Some(_)) => false,
    }
}

#[no_mangle]
pub extern "C" fn flutterxel_core_dither(alpha: f64) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.dither_alpha = alpha.clamp(0.0, 1.0);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_pset(x: i32, y: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    set_frame_pixel(&mut state, x, y, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_pget(x: i32, y: i32) -> i32 {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0;
    }
    get_frame_pixel(&state, x, y)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_line(x1: i32, y1: i32, x2: i32, y2: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_line(&mut state, x1, y1, x2, y2, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_rect(x: i32, y: i32, w: i32, h: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_rect(&mut state, x, y, w, h, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_rectb(x: i32, y: i32, w: i32, h: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_rectb(&mut state, x, y, w, h, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_circ(x: i32, y: i32, r: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_circ(&mut state, x, y, r, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_circb(x: i32, y: i32, r: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_circb(&mut state, x, y, r, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_elli(x: i32, y: i32, w: i32, h: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_elli(&mut state, x, y, w, h, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_ellib(x: i32, y: i32, w: i32, h: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_ellib(&mut state, x, y, w, h, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_tri(
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    x3: i32,
    y3: i32,
    col: i32,
) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_tri(&mut state, x1, y1, x2, y2, x3, y3, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_trib(
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    x3: i32,
    y3: i32,
    col: i32,
) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_trib(&mut state, x1, y1, x2, y2, x3, y3, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_fill(x: i32, y: i32, col: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_fill(&mut state, x, y, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_text(x: i32, y: i32, text: *const c_char, col: i32) -> bool {
    if text.is_null() {
        return false;
    }
    let c_str = unsafe { CStr::from_ptr(text) };
    let Ok(text) = c_str.to_str() else {
        return false;
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    draw_text(&mut state, x, y, text, col);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_bltm(
    x: f64,
    y: f64,
    tm: i32,
    u: f64,
    v: f64,
    w: f64,
    h: f64,
    colkey: i32,
) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    draw_bltm(
        &mut state,
        x,
        y,
        tm,
        u,
        v,
        w,
        h,
        decode_optional_i32(colkey),
    )
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
pub extern "C" fn flutterxel_core_sound_set_notes(
    snd: i32,
    notes_ptr: *const i32,
    notes_len: usize,
) -> bool {
    let notes = if notes_len == 0 {
        &[][..]
    } else {
        if notes_ptr.is_null() {
            return false;
        }
        unsafe { std::slice::from_raw_parts(notes_ptr, notes_len) }
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || snd < 0 {
        return false;
    }

    let sound = state
        .sounds
        .entry(snd)
        .or_insert_with(default_sound_resource);
    sound.notes = notes.to_vec();
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sound_set_tones(
    snd: i32,
    tones_ptr: *const i32,
    tones_len: usize,
) -> bool {
    let tones = if tones_len == 0 {
        &[][..]
    } else {
        if tones_ptr.is_null() {
            return false;
        }
        unsafe { std::slice::from_raw_parts(tones_ptr, tones_len) }
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || snd < 0 {
        return false;
    }

    let sound = state
        .sounds
        .entry(snd)
        .or_insert_with(default_sound_resource);
    sound.tones = tones.to_vec();
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sound_set_volumes(
    snd: i32,
    volumes_ptr: *const i32,
    volumes_len: usize,
) -> bool {
    let volumes = if volumes_len == 0 {
        &[][..]
    } else {
        if volumes_ptr.is_null() {
            return false;
        }
        unsafe { std::slice::from_raw_parts(volumes_ptr, volumes_len) }
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || snd < 0 {
        return false;
    }

    let sound = state
        .sounds
        .entry(snd)
        .or_insert_with(default_sound_resource);
    sound.volumes = volumes.to_vec();
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sound_set_effects(
    snd: i32,
    effects_ptr: *const i32,
    effects_len: usize,
) -> bool {
    let effects = if effects_len == 0 {
        &[][..]
    } else {
        if effects_ptr.is_null() {
            return false;
        }
        unsafe { std::slice::from_raw_parts(effects_ptr, effects_len) }
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || snd < 0 {
        return false;
    }

    let sound = state
        .sounds
        .entry(snd)
        .or_insert_with(default_sound_resource);
    sound.effects = effects.to_vec();
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sound_set_speed(snd: i32, speed: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || snd < 0 || speed < 0 {
        return false;
    }

    let sound = state
        .sounds
        .entry(snd)
        .or_insert_with(default_sound_resource);
    sound.speed = speed;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_music_set_seq(
    msc: i32,
    ch: i32,
    seq_ptr: *const i32,
    seq_len: usize,
) -> bool {
    if !(0..4).contains(&ch) || msc < 0 {
        return false;
    }
    let seq = if seq_len == 0 {
        &[][..]
    } else {
        if seq_ptr.is_null() {
            return false;
        }
        unsafe { std::slice::from_raw_parts(seq_ptr, seq_len) }
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    let music = state
        .musics
        .entry(msc)
        .or_insert_with(default_music_resource);
    let channel_index = ch as usize;
    while music.seqs.len() <= channel_index {
        music.seqs.push(Vec::new());
    }
    music.seqs[channel_index] = seq.to_vec();
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

    let mut call = PlayCall {
        ch,
        source,
        sec: decode_optional_f64(sec),
        loop_opt,
        resume_opt,
        started_frame: 0,
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    call.started_frame = state.frame_count;
    state.channel_playback.insert(ch, call.clone());
    state.last_play = Some(call);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_playm(msc: i32, loop_opt: bool) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized || msc < 0 {
        return false;
    }
    let started_frame = state.frame_count;

    // pyxel music playback controls channels 0..3.
    for channel in 0..4 {
        state.channel_playback.remove(&(channel as i32));
    }

    if let Some(music) = state.musics.get(&msc).cloned() {
        let mut applied = false;
        for (channel, seq) in music.seqs.iter().enumerate() {
            if seq.is_empty() {
                continue;
            }
            let call = PlayCall {
                ch: channel as i32,
                source: PlaySource::Sequence(seq.clone()),
                sec: None,
                loop_opt: Some(loop_opt),
                resume_opt: None,
                started_frame,
            };
            state.channel_playback.insert(channel as i32, call.clone());
            state.last_play = Some(call);
            applied = true;
        }
        if applied {
            return true;
        }
    }

    // Keep skeleton behavior deterministic when no music resource is present.
    let call = PlayCall {
        ch: 0,
        source: PlaySource::Index(msc),
        sec: None,
        loop_opt: Some(loop_opt),
        resume_opt: None,
        started_frame,
    };
    state.channel_playback.insert(0, call.clone());
    state.last_play = Some(call);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_stop(ch: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    match decode_optional_i32(ch) {
        Some(channel) => {
            state.channel_playback.remove(&channel);
        }
        None => {
            state.channel_playback.clear();
        }
    }
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
pub extern "C" fn flutterxel_core_play_pos(ch: i32, snd: *mut i32, pos: *mut f64) -> bool {
    if snd.is_null() || pos.is_null() {
        return false;
    }

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    update_channel_playback_state(&mut state);

    let Some(call) = state.channel_playback.get(&ch) else {
        return false;
    };

    unsafe {
        *snd = play_source_index(&call.source);
        *pos = playback_pos_sec(&state, call);
    }
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_rseed(seed: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.rng_state = seed_to_rng_state(seed);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_rndi(a: i32, b: i32) -> i32 {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0;
    }

    let (lo, hi) = if a <= b { (a, b) } else { (b, a) };
    let range = (i64::from(hi) - i64::from(lo) + 1) as u64;
    if range == 0 {
        return lo;
    }

    let value = u64::from(next_random_u32(&mut state)) % range;
    (i64::from(lo) + value as i64) as i32
}

#[no_mangle]
pub extern "C" fn flutterxel_core_rndf(a: f64, b: f64) -> f64 {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0.0;
    }

    let (lo, hi) = if a <= b { (a, b) } else { (b, a) };
    if (hi - lo).abs() <= f64::EPSILON {
        return lo;
    }

    let unit = f64::from(next_random_u32(&mut state)) / f64::from(u32::MAX);
    lo + (hi - lo) * unit
}

#[no_mangle]
pub extern "C" fn flutterxel_core_nseed(seed: i32) -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.noise_seed = seed as u32;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_noise(x: f64, y: f64, z: f64) -> f64 {
    let state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return 0.0;
    }
    sample_noise(state.noise_seed, x, y, z)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_ceil(x: f64) -> i32 {
    x.ceil() as i32
}

#[no_mangle]
pub extern "C" fn flutterxel_core_floor(x: f64) -> i32 {
    x.floor() as i32
}

#[no_mangle]
pub extern "C" fn flutterxel_core_clamp_i64(x: i64, lower: i64, upper: i64) -> i64 {
    let (lo, hi) = if lower <= upper {
        (lower, upper)
    } else {
        (upper, lower)
    };
    x.clamp(lo, hi)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_clamp_f64(x: f64, lower: f64, upper: f64) -> f64 {
    let (lo, hi) = if lower <= upper {
        (lower, upper)
    } else {
        (upper, lower)
    };
    x.clamp(lo, hi)
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sgn_i64(x: i64) -> i32 {
    if x > 0 {
        1
    } else if x < 0 {
        -1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sgn_f64(x: f64) -> f64 {
    if x > 0.0 {
        1.0
    } else if x < 0.0 {
        -1.0
    } else {
        0.0
    }
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sqrt(x: f64) -> f64 {
    x.sqrt()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_sin(deg: f64) -> f64 {
    (deg * PI / 180.0).sin()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_cos(deg: f64) -> f64 {
    (deg * PI / 180.0).cos()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_atan2(y: f64, x: f64) -> f64 {
    y.atan2(x) * 180.0 / PI
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
    let Some(exclude_images) = decode_optional_bool(exclude_images) else {
        return false;
    };
    let Some(exclude_tilemaps) = decode_optional_bool(exclude_tilemaps) else {
        return false;
    };
    let Some(exclude_sounds) = decode_optional_bool(exclude_sounds) else {
        return false;
    };
    let Some(exclude_musics) = decode_optional_bool(exclude_musics) else {
        return false;
    };
    let exclude_images = exclude_images.unwrap_or(false);
    let exclude_tilemaps = exclude_tilemaps.unwrap_or(false);
    let exclude_sounds = exclude_sounds.unwrap_or(false);
    let exclude_musics = exclude_musics.unwrap_or(false);

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
    if !load_resource_images(&mut state, &manifest, exclude_images) {
        return false;
    }
    if !load_resource_tilemaps(&mut state, &manifest, exclude_tilemaps) {
        return false;
    }
    if !load_resource_sounds(&mut state, &manifest, exclude_sounds) {
        return false;
    }
    if !load_resource_musics(&mut state, &manifest, exclude_musics) {
        return false;
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
    let Some(exclude_images) = decode_optional_bool(exclude_images) else {
        return false;
    };
    let Some(exclude_tilemaps) = decode_optional_bool(exclude_tilemaps) else {
        return false;
    };
    let Some(exclude_sounds) = decode_optional_bool(exclude_sounds) else {
        return false;
    };
    let Some(exclude_musics) = decode_optional_bool(exclude_musics) else {
        return false;
    };
    let exclude_images = exclude_images.unwrap_or(false);
    let exclude_tilemaps = exclude_tilemaps.unwrap_or(false);
    let exclude_sounds = exclude_sounds.unwrap_or(false);
    let exclude_musics = exclude_musics.unwrap_or(false);

    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let payload = {
        let state = runtime_state().lock().expect("runtime state poisoned");
        if !state.initialized {
            return false;
        }
        let Some(toml_text) = build_resource_toml(
            &state,
            exclude_images,
            exclude_tilemaps,
            exclude_sounds,
            exclude_musics,
        ) else {
            return false;
        };
        toml_text
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

#[no_mangle]
pub extern "C" fn flutterxel_core_load_pal(filename: *const c_char) -> bool {
    if filename.is_null() {
        return false;
    }
    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let Ok(text) = fs::read_to_string(path) else {
        return false;
    };

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }

    for (index, line) in text.lines().take(state.palette_map.len()).enumerate() {
        if let Some(value) = parse_palette_line(line) {
            state.palette_map[index] = value;
        }
    }
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_save_pal(filename: *const c_char) -> bool {
    if filename.is_null() {
        return false;
    }
    let c_str = unsafe { CStr::from_ptr(filename) };
    let Ok(path) = c_str.to_str() else {
        return false;
    };

    let palette = {
        let state = runtime_state().lock().expect("runtime state poisoned");
        if !state.initialized {
            return false;
        }
        state.palette_map
    };

    let Ok(mut file) = File::create(path) else {
        return false;
    };
    for value in palette {
        if writeln!(file, "{value}").is_err() {
            return false;
        }
    }
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_screenshot(scale: i32) -> bool {
    let decoded_scale = decode_optional_i32(scale);
    if let Some(value) = decoded_scale {
        if value <= 0 {
            return false;
        }
    }

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.last_screenshot_scale = decoded_scale;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_screencast(scale: i32) -> bool {
    let decoded_scale = decode_optional_i32(scale);
    if let Some(value) = decoded_scale {
        if value <= 0 {
            return false;
        }
    }

    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.screencast_enabled = true;
    state.screencast_scale = decoded_scale;
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_reset_screencast() -> bool {
    let mut state = runtime_state().lock().expect("runtime state poisoned");
    if !state.initialized {
        return false;
    }
    state.screencast_enabled = false;
    state.screencast_scale = None;
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

    fn tmp_palette_path(label: &str) -> PathBuf {
        let mut path = std::env::temp_dir();
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("valid system time")
            .as_nanos();
        path.push(format!("flutterxel_core_{label}_{stamp}.pyxpal"));
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
    fn drawing_primitives_update_expected_pixels() {
        let _guard = test_lock();
        init_runtime(8, 8);
        assert!(flutterxel_core_cls(0));

        assert!(flutterxel_core_pset(1, 1, 3));
        assert_eq!(flutterxel_core_pget(1, 1), 3);

        assert!(flutterxel_core_line(0, 0, 3, 0, 4));
        assert_eq!(flutterxel_core_pget(0, 0), 4);
        assert_eq!(flutterxel_core_pget(3, 0), 4);

        assert!(flutterxel_core_rect(2, 2, 2, 2, 5));
        assert_eq!(flutterxel_core_pget(2, 2), 5);
        assert_eq!(flutterxel_core_pget(3, 3), 5);

        assert!(flutterxel_core_rectb(0, 4, 3, 3, 6));
        assert_eq!(flutterxel_core_pget(0, 4), 6);
        assert_eq!(flutterxel_core_pget(2, 6), 6);
        assert_eq!(flutterxel_core_pget(1, 5), 0);
    }

    #[test]
    fn circle_primitives_update_expected_pixels() {
        let _guard = test_lock();
        init_runtime(10, 10);
        assert!(flutterxel_core_cls(0));

        assert!(flutterxel_core_circ(4, 4, 2, 7));
        assert_eq!(flutterxel_core_pget(4, 4), 7);
        assert_eq!(flutterxel_core_pget(4, 2), 7);
        assert_eq!(flutterxel_core_pget(6, 4), 7);
        assert_eq!(flutterxel_core_pget(4, 6), 7);
        assert_eq!(flutterxel_core_pget(2, 4), 7);

        assert!(flutterxel_core_cls(0));
        assert!(flutterxel_core_circb(4, 4, 2, 8));
        assert_eq!(flutterxel_core_pget(4, 2), 8);
        assert_eq!(flutterxel_core_pget(6, 4), 8);
        assert_eq!(flutterxel_core_pget(4, 6), 8);
        assert_eq!(flutterxel_core_pget(2, 4), 8);
        assert_eq!(flutterxel_core_pget(4, 4), 0);
    }

    #[test]
    fn ellipse_primitives_update_expected_pixels() {
        let _guard = test_lock();
        init_runtime(12, 12);
        assert!(flutterxel_core_cls(0));

        assert!(flutterxel_core_elli(2, 2, 5, 5, 9));
        assert_eq!(flutterxel_core_pget(4, 4), 9);
        assert_eq!(flutterxel_core_pget(4, 2), 9);

        assert!(flutterxel_core_cls(0));
        assert!(flutterxel_core_ellib(2, 2, 5, 5, 10));
        assert_eq!(flutterxel_core_pget(4, 2), 10);
        assert_eq!(flutterxel_core_pget(4, 4), 0);
    }

    #[test]
    fn triangle_primitives_update_expected_pixels() {
        let _guard = test_lock();
        init_runtime(10, 10);
        assert!(flutterxel_core_cls(0));

        assert!(flutterxel_core_tri(1, 1, 5, 1, 3, 4, 9));
        assert_eq!(flutterxel_core_pget(3, 2), 9);

        assert!(flutterxel_core_cls(0));
        assert!(flutterxel_core_trib(1, 1, 5, 1, 3, 4, 10));
        assert_eq!(flutterxel_core_pget(1, 1), 10);
        assert_eq!(flutterxel_core_pget(3, 1), 10);
        assert_eq!(flutterxel_core_pget(3, 2), 0);
    }

    #[test]
    fn fill_flood_fills_enclosed_region() {
        let _guard = test_lock();
        init_runtime(8, 8);
        assert!(flutterxel_core_cls(0));

        assert!(flutterxel_core_rectb(1, 1, 6, 6, 3));
        assert!(flutterxel_core_fill(2, 2, 5));
        assert_eq!(flutterxel_core_pget(2, 2), 5);
        assert_eq!(flutterxel_core_pget(1, 1), 3);
        assert_eq!(flutterxel_core_pget(0, 0), 0);
    }

    #[test]
    fn camera_clip_and_pal_affect_drawing() {
        let _guard = test_lock();
        init_runtime(8, 8);
        assert!(flutterxel_core_cls(0));

        assert!(flutterxel_core_camera(2, 1));
        assert!(flutterxel_core_pset(2, 1, 3));
        assert_eq!(flutterxel_core_pget(0, 0), 3);
        assert!(flutterxel_core_camera(0, 0));

        assert!(flutterxel_core_clip(1, 1, 2, 2));
        assert!(flutterxel_core_pset(0, 0, 4));
        assert_eq!(flutterxel_core_pget(0, 0), 3);
        assert!(flutterxel_core_pset(1, 1, 5));
        assert_eq!(flutterxel_core_pget(1, 1), 5);
        assert!(flutterxel_core_clip(0, 0, 8, 8));

        assert!(flutterxel_core_pal(2, 7));
        assert!(flutterxel_core_pset(2, 2, 2));
        assert_eq!(flutterxel_core_pget(2, 2), 7);
        assert!(flutterxel_core_pal(OPTIONAL_I32_NONE, OPTIONAL_I32_NONE));
        assert!(flutterxel_core_pset(3, 2, 2));
        assert_eq!(flutterxel_core_pget(3, 2), 2);
    }

    #[test]
    fn text_draws_builtin_glyph_shape_instead_of_filled_block() {
        let _guard = test_lock();
        init_runtime(20, 10);
        assert!(flutterxel_core_cls(0));

        let text_a = CString::new("A").expect("valid cstring");
        assert!(flutterxel_core_text(1, 1, text_a.as_ptr(), 11));
        // Built-in 4x6 'A' glyph starts with an empty top-left pixel.
        assert_eq!(flutterxel_core_pget(1, 1), 0);
        assert_eq!(flutterxel_core_pget(2, 1), 11);
        assert_eq!(flutterxel_core_pget(3, 1), 0);

        let text_space = CString::new(" ").expect("valid cstring");
        assert!(flutterxel_core_text(6, 1, text_space.as_ptr(), 12));
        assert_eq!(flutterxel_core_pget(6, 1), 0);
    }

    #[test]
    fn text_skips_non_ascii_without_advancing_cursor() {
        let _guard = test_lock();
        init_runtime(20, 10);
        assert!(flutterxel_core_cls(0));

        let text = CString::new("한A").expect("valid cstring");
        assert!(flutterxel_core_text(1, 1, text.as_ptr(), 12));

        // Non-ASCII glyph is skipped, so 'A' starts immediately at x=1.
        assert_eq!(flutterxel_core_pget(1, 1), 0);
        assert_eq!(flutterxel_core_pget(2, 1), 12);
    }

    #[test]
    fn bltm_draws_tilemap_region_using_image_bank_tiles() {
        let _guard = test_lock();
        init_runtime(16, 16);
        assert!(flutterxel_core_cls(0));
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.image_bank_size = 16;
            let mut bank = vec![0; 16 * 16];
            for y in 0..16 {
                for x in 0..16 {
                    bank[y * 16 + x] = ((x + y) % 16) as i32;
                }
            }
            state.image_banks.insert(0, bank);
            state.tilemaps.insert(
                0,
                TilemapResource {
                    width: 1,
                    height: 1,
                    imgsrc: 0,
                    data: vec![(0, 0)],
                },
            );
        }

        assert!(flutterxel_core_bltm(
            0.0,
            0.0,
            0,
            0.0,
            0.0,
            1.0,
            1.0,
            OPTIONAL_I32_NONE
        ));
        assert_eq!(flutterxel_core_pget(1, 0), 1);
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
    fn quit_resets_runtime_state_and_is_idempotent() {
        let _guard = test_lock();
        init_runtime(4, 4);
        assert!(flutterxel_core_set_btn_state(32, true));
        assert!(flutterxel_core_play(
            0,
            0,
            1,
            std::ptr::null(),
            0,
            std::ptr::null(),
            f64::NAN,
            -1,
            -1
        ));

        assert!(flutterxel_core_quit());
        assert_eq!(flutterxel_core_frame_count(), 0);
        assert_eq!(flutterxel_core_framebuffer_len(), 0);
        assert!(!flutterxel_core_btn(32));
        assert!(!flutterxel_core_is_channel_playing(0));
        assert!(!flutterxel_core_run(
            None,
            std::ptr::null_mut(),
            None,
            std::ptr::null_mut()
        ));
        assert!(flutterxel_core_quit());
    }

    #[test]
    fn btnp_and_btnr_follow_press_repeat_and_release_frames() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(!flutterxel_core_btnp(32, 0, 0));
        assert!(!flutterxel_core_btnr(32));

        assert!(flutterxel_core_set_btn_state(32, true));
        assert!(flutterxel_core_btnp(32, 0, 0));
        assert!(!flutterxel_core_btnr(32));

        assert!(flutterxel_core_run(
            None,
            std::ptr::null_mut(),
            None,
            std::ptr::null_mut()
        ));
        assert!(!flutterxel_core_btnp(32, 0, 0));
        assert!(!flutterxel_core_btnp(32, 2, 2));

        assert!(flutterxel_core_run(
            None,
            std::ptr::null_mut(),
            None,
            std::ptr::null_mut()
        ));
        assert!(flutterxel_core_btnp(32, 2, 2));

        assert!(flutterxel_core_run(
            None,
            std::ptr::null_mut(),
            None,
            std::ptr::null_mut()
        ));
        assert!(!flutterxel_core_btnp(32, 2, 2));

        assert!(flutterxel_core_run(
            None,
            std::ptr::null_mut(),
            None,
            std::ptr::null_mut()
        ));
        assert!(flutterxel_core_btnp(32, 2, 2));

        assert!(flutterxel_core_set_btn_state(32, false));
        assert!(flutterxel_core_btnr(32));

        assert!(flutterxel_core_run(
            None,
            std::ptr::null_mut(),
            None,
            std::ptr::null_mut()
        ));
        assert!(!flutterxel_core_btnr(32));
    }

    #[test]
    fn flip_advances_frame_and_clears_single_frame_release_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert_eq!(flutterxel_core_frame_count(), 0);
        assert!(flutterxel_core_set_btn_state(33, true));
        assert!(flutterxel_core_set_btn_state(33, false));
        assert!(flutterxel_core_btnr(33));

        assert!(flutterxel_core_flip());
        assert_eq!(flutterxel_core_frame_count(), 1);
        assert!(!flutterxel_core_btnr(33));
    }

    #[test]
    fn show_advances_frame_and_title_updates_runtime_title() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert_eq!(flutterxel_core_frame_count(), 0);
        assert!(flutterxel_core_show());
        assert_eq!(flutterxel_core_frame_count(), 1);

        let title = CString::new("Flutterxel Game").expect("valid cstring");
        assert!(flutterxel_core_title(title.as_ptr()));
        let state = runtime_state().lock().expect("runtime state poisoned");
        assert_eq!(state.title.as_deref(), Some("Flutterxel Game"));
    }

    #[test]
    fn runtime_control_apis_update_flags_and_reset_clears_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_perf_monitor(true));
        assert!(flutterxel_core_integer_scale(false));
        assert!(flutterxel_core_screen_mode(2));
        assert!(flutterxel_core_fullscreen(true));

        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert!(state.perf_monitor_enabled);
            assert!(!state.integer_scale_enabled);
            assert_eq!(state.screen_mode, 2);
            assert!(state.fullscreen_enabled);
        }

        assert!(flutterxel_core_reset());
        assert_eq!(flutterxel_core_frame_count(), 0);
        assert!(!flutterxel_core_show());
    }

    #[test]
    fn icon_and_dither_apis_update_runtime_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        let icon = CString::new("0123\n4567").expect("valid icon cstring");
        assert!(flutterxel_core_icon(icon.as_ptr(), 2, 3));
        assert!(flutterxel_core_dither(0.5));
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert_eq!(state.icon_data.as_deref(), Some("0123\n4567"));
            assert_eq!(state.icon_scale, 2);
            assert_eq!(state.icon_colkey, Some(3));
            assert_eq!(state.dither_alpha, 0.5);
        }

        assert!(flutterxel_core_dither(-1.0));
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert_eq!(state.dither_alpha, 0.0);
        }
        assert!(flutterxel_core_dither(2.0));
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert_eq!(state.dither_alpha, 1.0);
        }
    }

    #[test]
    fn screenshot_and_screencast_apis_update_runtime_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_screenshot(2));
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert_eq!(state.last_screenshot_scale, Some(2));
        }

        assert!(flutterxel_core_screencast(OPTIONAL_I32_NONE));
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert!(state.screencast_enabled);
            assert_eq!(state.screencast_scale, None);
        }

        assert!(flutterxel_core_screencast(3));
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert!(state.screencast_enabled);
            assert_eq!(state.screencast_scale, Some(3));
        }

        assert!(flutterxel_core_reset_screencast());
        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            assert!(!state.screencast_enabled);
            assert_eq!(state.screencast_scale, None);
        }
    }

    #[test]
    fn btnv_reads_value_state_and_set_btn_value_bridge() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert_eq!(flutterxel_core_btnv(1000), 0);
        assert!(flutterxel_core_set_btn_value(1000, 42));
        assert_eq!(flutterxel_core_btnv(1000), 42);

        assert!(flutterxel_core_set_btn_state(1000, true));
        assert_eq!(flutterxel_core_btnv(1000), 1);
        assert!(flutterxel_core_set_btn_state(1000, false));
        assert_eq!(flutterxel_core_btnv(1000), 0);
    }

    #[test]
    fn warp_mouse_updates_mouse_position_values() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_mouse(false));
        assert!(flutterxel_core_warp_mouse(3.0, 4.0));
        assert_eq!(flutterxel_core_btnv(MOUSE_POS_X_KEY), 3);
        assert_eq!(flutterxel_core_btnv(MOUSE_POS_Y_KEY), 4);
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
    fn save_pal_then_load_pal_roundtrips_palette_map() {
        let _guard = test_lock();
        init_runtime(4, 4);
        assert!(flutterxel_core_pal(0, 6));
        assert!(flutterxel_core_pal(1, 9));

        let path = tmp_palette_path("palette_roundtrip");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save_pal(c_path.as_ptr()));

        assert!(flutterxel_core_pal(0, 1));
        assert!(flutterxel_core_pal(1, 2));
        assert!(flutterxel_core_load_pal(c_path.as_ptr()));

        let state = runtime_state().lock().expect("runtime state poisoned");
        assert_eq!(state.palette_map[0], 6);
        assert_eq!(state.palette_map[1], 9);

        let _ = fs::remove_file(path);
    }

    #[test]
    fn save_then_load_roundtrips_image_bank_data() {
        let _guard = test_lock();
        init_runtime(2, 2);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.image_bank_size = 2;
            state.image_banks.insert(0, vec![1, 2, 3, 4]);
        }

        let path = tmp_resource_path("image_roundtrip");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save(c_path.as_ptr(), -1, -1, -1, -1));

        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.image_banks.insert(0, vec![9, 9, 9, 9]);
        }

        assert!(flutterxel_core_load(c_path.as_ptr(), -1, -1, -1, -1));
        assert!(flutterxel_core_cls(0));
        assert!(flutterxel_core_blt(
            0.0,
            0.0,
            0,
            0.0,
            0.0,
            2.0,
            2.0,
            OPTIONAL_I32_NONE,
            f64::NAN,
            f64::NAN
        ));

        let frame_buffer = {
            let state = runtime_state().lock().expect("runtime state poisoned");
            state.frame_buffer.clone()
        };
        assert_eq!(frame_buffer, vec![1, 2, 3, 4]);
        let _ = fs::remove_file(path);
    }

    #[test]
    fn load_with_exclude_images_keeps_existing_image_data() {
        let _guard = test_lock();
        init_runtime(2, 2);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.image_bank_size = 2;
            state.image_banks.insert(0, vec![1, 2, 3, 4]);
        }

        let path = tmp_resource_path("exclude_images");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save(c_path.as_ptr(), -1, -1, -1, -1));

        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.image_banks.insert(0, vec![9, 9, 9, 9]);
        }

        assert!(flutterxel_core_load(c_path.as_ptr(), 1, -1, -1, -1));
        assert!(flutterxel_core_cls(0));
        assert!(flutterxel_core_blt(
            0.0,
            0.0,
            0,
            0.0,
            0.0,
            2.0,
            2.0,
            OPTIONAL_I32_NONE,
            f64::NAN,
            f64::NAN
        ));

        let frame_buffer = {
            let state = runtime_state().lock().expect("runtime state poisoned");
            state.frame_buffer.clone()
        };
        assert_eq!(frame_buffer, vec![9, 9, 9, 9]);
        let _ = fs::remove_file(path);
    }

    #[test]
    fn save_then_load_roundtrips_tilemaps_sounds_and_musics() {
        let _guard = test_lock();
        init_runtime(2, 2);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.tilemaps.insert(
                0,
                TilemapResource {
                    width: 2,
                    height: 2,
                    imgsrc: 1,
                    data: vec![(1, 2), (3, 4), (5, 6), (7, 8)],
                },
            );
            state.sounds.insert(
                0,
                SoundResource {
                    notes: vec![28, 30, -1],
                    tones: vec![1],
                    volumes: vec![6, 5],
                    effects: vec![2, 3],
                    speed: 25,
                },
            );
            state.musics.insert(
                0,
                MusicResource {
                    seqs: vec![vec![0, 1, 2], vec![3]],
                },
            );
        }

        let path = tmp_resource_path("resource_roundtrip");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save(c_path.as_ptr(), -1, -1, -1, -1));

        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.tilemaps.insert(
                0,
                TilemapResource {
                    width: 2,
                    height: 2,
                    imgsrc: 9,
                    data: vec![(9, 9), (9, 9), (9, 9), (9, 9)],
                },
            );
            state.sounds.insert(
                0,
                SoundResource {
                    notes: vec![1, 1, 1],
                    tones: vec![3],
                    volumes: vec![1],
                    effects: vec![1],
                    speed: 40,
                },
            );
            state.musics.insert(
                0,
                MusicResource {
                    seqs: vec![vec![9, 9]],
                },
            );
        }

        assert!(flutterxel_core_load(c_path.as_ptr(), -1, -1, -1, -1));

        let state = runtime_state().lock().expect("runtime state poisoned");
        let tilemap = state.tilemaps.get(&0).expect("tilemap should exist");
        assert_eq!(tilemap.width, 2);
        assert_eq!(tilemap.height, 2);
        assert_eq!(tilemap.imgsrc, 1);
        assert_eq!(tilemap.data, vec![(1, 2), (3, 4), (5, 6), (7, 8)]);

        let sound = state.sounds.get(&0).expect("sound should exist");
        assert_eq!(sound.notes, vec![28, 30, -1]);
        assert_eq!(sound.tones, vec![1]);
        assert_eq!(sound.volumes, vec![6, 5]);
        assert_eq!(sound.effects, vec![2, 3]);
        assert_eq!(sound.speed, 25);

        let music = state.musics.get(&0).expect("music should exist");
        assert_eq!(music.seqs, vec![vec![0, 1, 2], vec![3]]);

        let _ = fs::remove_file(path);
    }

    #[test]
    fn load_with_exclude_resource_flags_keeps_existing_tilemaps_sounds_musics() {
        let _guard = test_lock();
        init_runtime(2, 2);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.tilemaps.insert(
                0,
                TilemapResource {
                    width: 2,
                    height: 2,
                    imgsrc: 1,
                    data: vec![(1, 2), (3, 4), (5, 6), (7, 8)],
                },
            );
            state.sounds.insert(
                0,
                SoundResource {
                    notes: vec![28, 30, -1],
                    tones: vec![1],
                    volumes: vec![6, 5],
                    effects: vec![2, 3],
                    speed: 25,
                },
            );
            state.musics.insert(
                0,
                MusicResource {
                    seqs: vec![vec![0, 1, 2], vec![3]],
                },
            );
        }

        let path = tmp_resource_path("resource_exclude");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save(c_path.as_ptr(), -1, -1, -1, -1));

        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.tilemaps.insert(
                0,
                TilemapResource {
                    width: 2,
                    height: 2,
                    imgsrc: 9,
                    data: vec![(9, 9), (9, 9), (9, 9), (9, 9)],
                },
            );
            state.sounds.insert(
                0,
                SoundResource {
                    notes: vec![1, 1, 1],
                    tones: vec![3],
                    volumes: vec![1],
                    effects: vec![1],
                    speed: 40,
                },
            );
            state.musics.insert(
                0,
                MusicResource {
                    seqs: vec![vec![9, 9]],
                },
            );
        }

        assert!(flutterxel_core_load(c_path.as_ptr(), -1, 1, 1, 1));

        let state = runtime_state().lock().expect("runtime state poisoned");
        let tilemap = state.tilemaps.get(&0).expect("tilemap should exist");
        assert_eq!(tilemap.imgsrc, 9);
        assert_eq!(tilemap.data, vec![(9, 9), (9, 9), (9, 9), (9, 9)]);

        let sound = state.sounds.get(&0).expect("sound should exist");
        assert_eq!(sound.notes, vec![1, 1, 1]);
        assert_eq!(sound.tones, vec![3]);
        assert_eq!(sound.volumes, vec![1]);
        assert_eq!(sound.effects, vec![1]);
        assert_eq!(sound.speed, 40);

        let music = state.musics.get(&0).expect("music should exist");
        assert_eq!(music.seqs, vec![vec![9, 9]]);

        let _ = fs::remove_file(path);
    }

    #[test]
    fn save_with_exclude_resource_flags_writes_empty_sections() {
        let _guard = test_lock();
        init_runtime(2, 2);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.tilemaps.insert(
                0,
                TilemapResource {
                    width: 2,
                    height: 2,
                    imgsrc: 1,
                    data: vec![(1, 2), (3, 4), (5, 6), (7, 8)],
                },
            );
            state.sounds.insert(
                0,
                SoundResource {
                    notes: vec![28, 30, -1],
                    tones: vec![1],
                    volumes: vec![6, 5],
                    effects: vec![2, 3],
                    speed: 25,
                },
            );
            state.musics.insert(
                0,
                MusicResource {
                    seqs: vec![vec![0, 1, 2], vec![3]],
                },
            );
        }

        let path = tmp_resource_path("save_exclude_sections");
        let c_path = CString::new(path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_save(c_path.as_ptr(), -1, 1, 1, 1));

        let manifest_text = read_resource_archive_toml(&path);
        let manifest = toml::from_str::<toml::Value>(&manifest_text).expect("valid toml manifest");
        let tilemaps_len = manifest
            .get("tilemaps")
            .and_then(toml::Value::as_array)
            .map(|value| value.len())
            .unwrap_or(usize::MAX);
        let sounds_len = manifest
            .get("sounds")
            .and_then(toml::Value::as_array)
            .map(|value| value.len())
            .unwrap_or(usize::MAX);
        let musics_len = manifest
            .get("musics")
            .and_then(toml::Value::as_array)
            .map(|value| value.len())
            .unwrap_or(usize::MAX);
        assert_eq!(tilemaps_len, 0);
        assert_eq!(sounds_len, 0);
        assert_eq!(musics_len, 0);

        let _ = fs::remove_file(path);
    }

    #[test]
    fn load_accepts_reference_sample_pyxres_when_available() {
        let _guard = test_lock();
        init_runtime(8, 8);

        let sample_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../reference/pyxel/python/pyxel/examples/assets/sample.pyxres");
        if !sample_path.exists() {
            return;
        }

        let c_path =
            CString::new(sample_path.to_string_lossy().to_string()).expect("valid cstring");
        assert!(flutterxel_core_load(c_path.as_ptr(), -1, -1, -1, -1));

        let state = runtime_state().lock().expect("runtime state poisoned");
        assert!(!state.image_banks.is_empty());
        assert!(!state.tilemaps.is_empty());
        assert!(!state.sounds.is_empty());
        assert!(!state.musics.is_empty());
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

    #[test]
    fn play_pos_reports_none_when_idle_and_value_when_playing() {
        let _guard = test_lock();
        init_runtime(4, 4);

        let mut snd = -1;
        let mut pos = -1.0;
        assert!(!flutterxel_core_play_pos(0, &mut snd, &mut pos));

        assert!(flutterxel_core_play(
            0,
            0,
            7,
            std::ptr::null(),
            0,
            std::ptr::null(),
            f64::NAN,
            -1,
            -1
        ));
        snd = -1;
        pos = -1.0;
        assert!(flutterxel_core_play_pos(0, &mut snd, &mut pos));
        assert_eq!(snd, 7);
        assert_eq!(pos, 0.0);
        assert!(flutterxel_core_flip());
        assert!(flutterxel_core_play_pos(0, &mut snd, &mut pos));
        assert!(pos > 0.0);

        assert!(flutterxel_core_stop(0));
        assert!(!flutterxel_core_play_pos(0, &mut snd, &mut pos));
    }

    #[test]
    fn play_with_sec_stops_after_elapsed_duration_without_loop() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_play(
            0,
            0,
            2,
            std::ptr::null(),
            0,
            std::ptr::null(),
            0.01,
            0,
            -1
        ));
        assert!(flutterxel_core_is_channel_playing(0));
        assert!(flutterxel_core_flip());
        assert!(!flutterxel_core_is_channel_playing(0));
    }

    #[test]
    fn random_api_is_seeded_and_range_bounded() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_rseed(1234));
        let int1 = flutterxel_core_rndi(10, 20);
        let float1 = flutterxel_core_rndf(-1.0, 1.0);

        assert!(flutterxel_core_rseed(1234));
        let int2 = flutterxel_core_rndi(10, 20);
        let float2 = flutterxel_core_rndf(-1.0, 1.0);

        assert_eq!(int1, int2);
        assert_eq!(float1, float2);
        assert!((10..=20).contains(&int1));
        assert!((-1.0..=1.0).contains(&float1));
    }

    #[test]
    fn noise_api_is_seeded_and_range_bounded() {
        let _guard = test_lock();
        init_runtime(4, 4);

        assert!(flutterxel_core_nseed(77));
        let value1 = flutterxel_core_noise(0.25, 0.5, 0.75);
        let value2 = flutterxel_core_noise(0.25, 0.5, 0.75);
        assert_eq!(value1, value2);

        assert!(flutterxel_core_nseed(77));
        let value3 = flutterxel_core_noise(0.25, 0.5, 0.75);
        assert_eq!(value1, value3);
        assert!((-1.0..=1.0).contains(&value1));
    }

    #[test]
    fn math_api_matches_pyxel_numeric_behavior() {
        let _guard = test_lock();
        assert_eq!(flutterxel_core_ceil(1.2), 2);
        assert_eq!(flutterxel_core_floor(-1.2), -2);

        assert_eq!(flutterxel_core_clamp_i64(10, 0, 5), 5);
        assert_eq!(flutterxel_core_clamp_i64(10, 5, 0), 5);
        assert_eq!(flutterxel_core_clamp_f64(0.25, 0.5, -0.5), 0.25);

        assert_eq!(flutterxel_core_sgn_i64(-12), -1);
        assert_eq!(flutterxel_core_sgn_i64(0), 0);
        assert_eq!(flutterxel_core_sgn_i64(9), 1);
        assert_eq!(flutterxel_core_sgn_f64(-0.1), -1.0);

        assert_eq!(flutterxel_core_sqrt(9.0), 3.0);
        assert!((flutterxel_core_sin(30.0) - 0.5).abs() < 1e-12);
        assert!((flutterxel_core_cos(60.0) - 0.5).abs() < 1e-12);
        assert!((flutterxel_core_atan2(1.0, 0.0) - 90.0).abs() < 1e-12);
    }

    #[test]
    fn playm_uses_music_sequences_or_falls_back_to_channel_zero() {
        let _guard = test_lock();
        init_runtime(4, 4);
        {
            let mut state = runtime_state().lock().expect("runtime state poisoned");
            state.musics.insert(
                0,
                MusicResource {
                    seqs: vec![vec![10, 11], Vec::new(), vec![12], vec![13, 14]],
                },
            );
        }

        assert!(flutterxel_core_playm(0, true));
        assert!(flutterxel_core_is_channel_playing(0));
        assert!(!flutterxel_core_is_channel_playing(1));
        assert!(flutterxel_core_is_channel_playing(2));
        assert!(flutterxel_core_is_channel_playing(3));

        assert!(flutterxel_core_playm(9, false));
        assert!(flutterxel_core_is_channel_playing(0));
    }

    #[test]
    fn stop_clears_single_channel_or_all_channels() {
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
        assert!(flutterxel_core_play(
            2,
            0,
            4,
            std::ptr::null(),
            0,
            std::ptr::null(),
            f64::NAN,
            1,
            -1
        ));

        assert!(flutterxel_core_is_channel_playing(1));
        assert!(flutterxel_core_is_channel_playing(2));

        assert!(flutterxel_core_stop(1));
        assert!(!flutterxel_core_is_channel_playing(1));
        assert!(flutterxel_core_is_channel_playing(2));

        assert!(flutterxel_core_stop(OPTIONAL_I32_NONE));
        assert!(!flutterxel_core_is_channel_playing(1));
        assert!(!flutterxel_core_is_channel_playing(2));
    }

    #[test]
    fn sound_resource_mutation_abi_updates_runtime_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        let notes = [12, 24, -1];
        let tones = [0, 1, 2];
        let volumes = [7, 6, 5];
        let effects = [0, 2, 3];
        assert!(flutterxel_core_sound_set_notes(
            5,
            notes.as_ptr(),
            notes.len()
        ));
        assert!(flutterxel_core_sound_set_tones(
            5,
            tones.as_ptr(),
            tones.len()
        ));
        assert!(flutterxel_core_sound_set_volumes(
            5,
            volumes.as_ptr(),
            volumes.len()
        ));
        assert!(flutterxel_core_sound_set_effects(
            5,
            effects.as_ptr(),
            effects.len()
        ));
        assert!(flutterxel_core_sound_set_speed(5, 42));

        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            let sound = state.sounds.get(&5).expect("sound should exist");
            assert_eq!(sound.notes, notes);
            assert_eq!(sound.tones, tones);
            assert_eq!(sound.volumes, volumes);
            assert_eq!(sound.effects, effects);
            assert_eq!(sound.speed, 42);
        }

        assert!(!flutterxel_core_sound_set_notes(5, std::ptr::null(), 1));
    }

    #[test]
    fn music_resource_mutation_abi_updates_runtime_state() {
        let _guard = test_lock();
        init_runtime(4, 4);

        let seq0 = [1, 3, 5];
        let seq2 = [2, 4];
        assert!(flutterxel_core_music_set_seq(
            2,
            0,
            seq0.as_ptr(),
            seq0.len()
        ));
        assert!(flutterxel_core_music_set_seq(
            2,
            2,
            seq2.as_ptr(),
            seq2.len()
        ));
        assert!(flutterxel_core_music_set_seq(2, 3, std::ptr::null(), 0));

        {
            let state = runtime_state().lock().expect("runtime state poisoned");
            let music = state.musics.get(&2).expect("music should exist");
            assert_eq!(music.seqs.len(), 4);
            assert_eq!(music.seqs[0], seq0);
            assert_eq!(music.seqs[1], Vec::<i32>::new());
            assert_eq!(music.seqs[2], seq2);
            assert_eq!(music.seqs[3], Vec::<i32>::new());
        }

        assert!(!flutterxel_core_music_set_seq(2, 1, std::ptr::null(), 2));
    }
}
