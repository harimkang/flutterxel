# Audio

## Playback APIs

Global playback entry points:

- `play(ch, snd, sec: ..., loop: ..., resume: ...)`
- `playm(msc, loop: ...)`
- `stop([ch])`
- `playing(ch)`
- `playPos(ch)` / `play_pos(ch)`

`play` accepts:

- `int` (sound index)
- `Sound`
- `List<int>`
- `List<Sound>`
- `String` (MML-like input)

## Channel Objects

`channels` exposes per-channel control:

- `channels[i].play(...)`
- `channels[i].stop()`
- `channels[i].playPos()`

## Sound, Music, Tone Resources

Global resources:

- `tones`
- `sounds`
- `musics`

Important `Sound` operations:

- `set(notes, tones, volumes, effects, speed)`
- `set_notes`, `set_tones`, `set_volumes`, `set_effects`
- `mml(...)`
- `pcm(...)`
- `save(filename, sec, ffmpeg: ...)`

Important `Music` operation:

- `set(seq1, [seq2, seq3, seq4])`

## Utility

- `gen_bgm(preset, instr, seed: ..., play: ...)` generates lightweight BGM patterns.
