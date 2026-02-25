use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

const ABI_VERSION_MAJOR: u32 = 0;
const ABI_VERSION_MINOR: u32 = 1;
const ABI_VERSION_PATCH: u32 = 0;

#[derive(Debug)]
struct Engine {
    width: u32,
    height: u32,
    fps: u32,
    frame_count: u64,
    rgba: Vec<u8>,
}

impl Engine {
    fn new(width: u32, height: u32, fps: u32) -> Self {
        let mut engine = Self {
            width,
            height,
            fps: fps.max(1),
            frame_count: 0,
            rgba: vec![0; width as usize * height as usize * 4],
        };
        engine.render_test_pattern();
        engine
    }

    fn tick(&mut self, _delta_ms: f32) {
        self.frame_count = self.frame_count.saturating_add(1);
        self.render_test_pattern();
    }

    fn render_test_pattern(&mut self) {
        // Temporary visual pattern used until the full renderer is integrated.
        let t = (self.frame_count % 256) as u8;
        let width = self.width as usize;
        let height = self.height as usize;
        let brightness = (self.fps.min(240) as u8).saturating_add(15);

        for y in 0..height {
            for x in 0..width {
                let i = (y * width + x) * 4;
                self.rgba[i] = x as u8 ^ t;
                self.rgba[i + 1] = y as u8 ^ (t / 2);
                self.rgba[i + 2] = brightness;
                self.rgba[i + 3] = 255;
            }
        }
    }
}

fn engines() -> &'static Mutex<HashMap<u64, Engine>> {
    static ENGINES: OnceLock<Mutex<HashMap<u64, Engine>>> = OnceLock::new();
    ENGINES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_engine_handle() -> u64 {
    static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);
    NEXT_HANDLE.fetch_add(1, Ordering::Relaxed)
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
pub extern "C" fn flutterxel_core_engine_new(width: u32, height: u32, fps: u32) -> u64 {
    if width == 0 || height == 0 {
        return 0;
    }

    let handle = next_engine_handle();
    let engine = Engine::new(width, height, fps);
    let mut engines = engines().lock().expect("engine map poisoned");
    engines.insert(handle, engine);
    handle
}

#[no_mangle]
pub extern "C" fn flutterxel_core_engine_free(handle: u64) -> bool {
    if handle == 0 {
        return false;
    }
    let mut engines = engines().lock().expect("engine map poisoned");
    engines.remove(&handle).is_some()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_engine_tick(handle: u64, delta_ms: f32) -> bool {
    let mut engines = engines().lock().expect("engine map poisoned");
    let Some(engine) = engines.get_mut(&handle) else {
        return false;
    };
    engine.tick(delta_ms);
    true
}

#[no_mangle]
pub extern "C" fn flutterxel_core_engine_frame_ptr(handle: u64) -> *const u8 {
    let engines = engines().lock().expect("engine map poisoned");
    let Some(engine) = engines.get(&handle) else {
        return std::ptr::null();
    };
    engine.rgba.as_ptr()
}

#[no_mangle]
pub extern "C" fn flutterxel_core_engine_frame_len(handle: u64) -> usize {
    let engines = engines().lock().expect("engine map poisoned");
    engines.get(&handle).map_or(0, |engine| engine.rgba.len())
}

#[no_mangle]
pub extern "C" fn flutterxel_core_engine_frame_count(handle: u64) -> u64 {
    let engines = engines().lock().expect("engine map poisoned");
    engines.get(&handle).map_or(0, |engine| engine.frame_count)
}
