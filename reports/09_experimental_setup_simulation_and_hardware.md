# Experimental Setup: Concert Venue Acoustic Simulation & ESP32-S3 Hardware Integration

* **Project**: Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments
* **Institution**: University of the Witwatersrand, School of Electrical & Information Engineering
* **Researchers**: Ryan Jammy & Raphael Alsfine
* **Audio Specification**: $f_s = 16\,000\text{ Hz}$, 16-bit Linear PCM, Little-Endian Signed Integer
* **Target Hardware Stack**:
  * **MCU**: Espressif ESP32-S3-WROOM-1U-N8R8 (240 MHz Xtensa LX7 dual-core, 8MB Flash, 8MB Octal PSRAM)
  * **Microphones**: 2x Adafruit I2S MEMS Microphone Breakouts (Knowles SPH0645LM4H / equivalent)
  * **DAC**: Adafruit PCM5102 I2S Stereo DAC Breakout
  * **Headphone Driver**: NJM4556AD High-Current Dual Operational Amplifier
  * **External Sources**: Dual-loudspeaker lab playback (Speech near-field @ $0.3 - 0.5\text{ m}$, Music far-field @ $1 - 2\text{ m}$)

---

## 1. System Architecture Overview

The experimental framework bridges **software acoustic simulation** of live concert venues with **physical laboratory hardware integration**:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       EXPERIMENTAL ARCHITECTURE OVERVIEW                                        │
├────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────┤
│ 1. SOFTWARE CONCERT SIMULATION SUITE                   │ 2. PHYSICAL LAB HARDWARE-IN-THE-LOOP INTEGRATION        │
│                                                        │                                                        │
│  [IUS Human Speech]     [Acoustic Triad Music]         │   [Audio Interface / PC Multi-Channel DAC]             │
│    (50M / 50F)           (Jazz, Rock, Techno)          │       │                                │                │
│         │                          │                   │       ▼                                ▼                │
│         ▼                          ▼                   │   [Loudspeaker 1: Speech]      [Loudspeaker 2: Music]      │
│  ┌───────────────────────────────────────────────┐     │    (Near-field @ 0.3-0.5m)      (Far-field @ 1-2m)     │
│  │   CONCERT VENUE ACOUSTIC SIMULATOR (ISM)      │     │       │                                │                │
│  │  - Nightclub (12x15x4m, RT60 ~0.7s, bass modes│     │       └────────────────┬───────────────┘                │
│  │  - Concert Arena (25x30x8m, RT60 ~1.4s reverb)│     │                        ▼ Acoustic Air Propagation      │
│  │  - Open-Air Festival Stage (RT60 ~0.2s ground)│     │         ┌──────────────────────────────┐                │
│  └──────────────────────┬────────────────────────┘     │         │ ESP32-S3 Endfire Dual-Mic Rig│                │
│                         ▼                              │         │  - Primary: Front-facing mic │                │
│         ┌──────────────────────────────┐               │         │  - Reference: Rear-facing mic│                │
│         │ Simulated Primary d[n] &     │               │         └──────────────┬───────────────┘                │
│         │ Reference x[n] Microphone    │               │                        ▼ Dual I2S Stream (16 kHz)       │
│         └──────────────┬───────────────┘               │         ┌──────────────────────────────┐                │
│                        │                               │         │ ESP32-S3-WROOM-1U-N8R8 Engine│                │
│                        ▼                               │         │  Core 1: Real-Time DSP       │                │
│         ┌──────────────────────────────┐               │         │  Mode 0: Bypass              │                │
│         │ MATLAB / Python Benchmark    │               │         │  Mode 1: Parametric Notch    │                │
│         │  - STOI Prediction           │               │         │  Mode 2: NLMS (N=256, μ=0.05)│                │
│         │  - Physical ΔSNR Calculation │               │         │  Mode 3: Hybrid (Notch+NLMS) │                │
│         └──────────────┬───────────────┘               │         └──────────────┬───────────────┘                │
│                        │                               │                        │                                │
│                        │                               │         ┌──────────────┴───────────────┐                │
│                        │                               │         ▼                              ▼                │
│                        │                               │  [USB Data Stream]             [Adafruit PCM5102A DAC]  │
│                        │                               │  (d[n], x[n], e[n] logging)             │               │
│                        │                               │         │                               ▼               │
│                        │                               │         │                      [NJM4556AD Headphone Amp]│
│                        │                               │         │                               │               │
│                        │                               │         ▼                               ▼               │
│                        │                               │  [Automated PC Analysis]       [Live Listener Audition] │
│                        ▼                               ▼         ▼                               ▼               │
│         ┌────────────────────────────────────────────────────────────────────────────────────────┐               │
│         │                      PAIRED SIMULATION-TO-HARDWARE CROSS VALIDATION                    │               │
│         │       (Direct STOI, ΔSNR, Active Speech Level & Spectral Divergence Comparison)       │               │
│         └────────────────────────────────────────────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Concert Venue Acoustic Simulation Suite

To reflect the real-world operational environment of speech enhancement in music, the simulation models three distinct **live concert venue archetypes** using the Image Source Method (ISM):

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     CONCERT VENUE SIMULATION ARCHETYPES                                 │
├─────────┬──────────────────────┬─────────────┬───────────┬──────────────────────┬───────────────────────┤
│ Venue   │ Dimensions (L x W x H│ RT60 Target │ Wall Mat. │ Stage PA Position    │ Talker / Mic Location │
├─────────┼──────────────────────┼─────────────┼───────────┼──────────────────────┼───────────────────────┤
│ 1. Club │ 12 m x 15 m x 4.0 m  │ ~0.70 s     │ Concrete, │ Left: (2.0, 1.0, 2.5)│ Crowd: (6.0, 9.0, 1.6)│
│ (Indoor)│                      │             │ dry-wall  │ Right:(10.0, 1.0, 2.5│ Headset @ talker mouth│
├─────────┼──────────────────────┼─────────────┼───────────┼──────────────────────┼───────────────────────┤
│ 2. Arena│ 25 m x 30 m x 8.0 m  │ ~1.40 s     │ Hard brick│ Left: (4.0, 2.0, 5.0)│ FOH: (12.5, 18.0, 1.6)│
│ (Hall)  │                      │             │ & ceiling │ Right:(21.0, 2.0, 5.0│ Heavy diffuse reverb  │
├─────────┼──────────────────────┼─────────────┼───────────┼──────────────────────┼───────────────────────┤
│ 3. Open │ 40 m x 50 m x 15.0 m │ ~0.20 s     │ Free-field│ Left: (8.0, 3.0, 4.0)│ Audience: (20, 15, 1.6│
│ (Fest.) │ (Semi-infinite roof) │             │ boundary  │ Right:(32.0, 3.0, 4.0│ Direct PA + ground ref│
└─────────┴──────────────────────┴─────────────┴───────────┴──────────────────────┴───────────────────────┘
```

### Acoustic Transfer Path Formulation
For each venue, four multi-path Room Impulse Responses (RIRs) are computed:

$$\begin{aligned}
d[n] &= s[n] * h_{\text{speech} \to \text{mic1}}[n] + n_{\text{music}}[n] * h_{\text{PA} \to \text{mic1}}[n] \\
x[n] &= s[n] * h_{\text{speech} \to \text{mic2}}[n] + n_{\text{music}}[n] * h_{\text{PA} \to \text{mic2}}[n]
\end{aligned}$$

* **Primary Microphone ($\text{Mic}_1$)**: Near-field to speech source ($r_s = 0.3\text{ m}$); far-field to stage PA ($r_{\text{PA}} = 8 - 18\text{ m}$).
* **Reference Microphone ($\text{Mic}_2$)**: Rear-facing, spaced $d_{\text{mic}} = 4.0\text{ cm}$ behind $\text{Mic}_1$.
  * Acoustic delay differential: $\Delta \tau = \frac{d_{\text{mic}}}{c} = \frac{0.04\text{ m}}{343\text{ m/s}} \approx 116.6\,\mu\text{s}$ ($\approx 1.86\text{ samples}$ at $16\text{ kHz}$).
  * Speech leakage attenuation: The head shadow and inverse-square distance ratio attenuate speech into $\text{Mic}_2$ by $\ge 12\text{ dB}$, preventing the catastrophic vocal cancellation identified in Scenario 2.

---

## 3. Physical Laboratory Setup & Hardware Integration

### Physical Equipment & Geometric Placement

```
                                  LABORATORY PHYSICAL LAYOUT
                                  
                                    [Loudspeaker 2: Music]
                                    (Far-field: ~1.5 m away)
                                               │
                                               │ Ambient Concert Music Wavefront
                                               ▼
                                   ┌───────────────────────┐
                                   │  (Rear / Mic 2 Ref)   │
                                   │           ▼           │
                                   │     [ESP32-S3 RIG]    │
                                   │    (Endfire: 4 cm)    │
                                   │           ▲           │
                                   │  (Front / Mic 1 Prim) │
                                   └───────────────────────┘
                                               ▲
                                               │ Near-field Speech Wavefront
                                               │
                                    [Loudspeaker 1: Speech]
                                    (Near-field: 0.35 m away)
```

1. **Loudspeaker 1 (Speech Source)**:
   * Positioned on a desktop stand at ear/mouth height ($z = 1.2\text{ m}$), $0.35\text{ m}$ directly in front of the ESP32-S3 primary microphone.
   * Plays clean, phonetically balanced Harvard sentences from the IUS corpus ($f_s = 16\text{ kHz}$).
2. **Loudspeaker 2 (Music Noise Interference)**:
   * Positioned $1.50\text{ m}$ away, facing the rear reference microphone.
   * Plays uncompressed 30-second stems of the Acoustic Triad (Jazz, Rock, Techno).
3. **Sound Pressure Level Calibration**:
   * Speech Loudspeaker calibrated to nominal **$70\text{ dBA SPL}$** at $0.35\text{ m}$ (normal to raised conversational vocal effort).
   * Music Loudspeaker calibrated to **$70\text{ dBA}$ ($0\text{ dB}$ SNR)**, **$75\text{ dBA}$ ($-5\text{ dB}$ SNR)**, **$80\text{ dBA}$ ($-10\text{ dB}$ SNR)**, and **$85\text{ dBA}$ ($-15\text{ dB}$ SNR)** using a Type 2 sound level meter placed at the microphone fixture.

---

## 4. Hardware Component Pinout & Electrical Interfacing

### Microcontroller: ESP32-S3-WROOM-1U-N8R8
* Dual-Core Xtensa 32-bit LX7 @ $240\text{ MHz}$, 8MB Quad-SPI Flash, 8MB Octal PSRAM.
* Core 0 handles FreeRTOS system management, button polling, and USB-CDC streaming.
* Core 1 is pinned exclusively to the high-priority real-time audio DSP interrupt handler.

### Schematic Wiring Table

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     ESP32-S3 HARDWARE INTERCONNECTION PINOUT                            │
├──────────────────────┬──────────────────────┬─────────────┬─────────────────────────────────────────────┤
│ Component            │ Component Pin        │ ESP32-S3 Pin│ Functional Description                      │
├──────────────────────┼──────────────────────┼─────────────┼─────────────────────────────────────────────┤
│ Adafruit I2S MEMS 1  │ 3V / GND             │ 3V3 / GND   │ Power Supply (3.3V Clean Rail)              │
│ (Primary Mic - Front)│ BCLK (Bit Clock)     │ GPIO 4      │ I2S0 Serial Bit Clock (512 kHz @ 16k/16-bit)│
│                      │ LRCL (Word Select)   │ GPIO 5      │ I2S0 Left/Right Clock (16 kHz Frame Clock)  │
│                      │ DOUT (Data Output)   │ GPIO 6      │ I2S0 Serial Data Input (Left Channel)       │
│                      │ SEL (Channel Select) │ GND         │ Configures Mic 1 as LEFT Channel            │
├──────────────────────┼──────────────────────┼─────────────┼─────────────────────────────────────────────┤
│ Adafruit I2S MEMS 2  │ 3V / GND             │ 3V3 / GND   │ Power Supply (Shared 3.3V)                  │
│ (Ref Mic - Rear)     │ BCLK (Bit Clock)     │ GPIO 4      │ Shared I2S0 Serial Bit Clock                │
│                      │ LRCL (Word Select)   │ GPIO 5      │ Shared I2S0 Left/Right Clock                │
│                      │ DOUT (Data Output)   │ GPIO 6      │ Shared I2S0 Serial Data Bus                 │
│                      │ SEL (Channel Select) │ 3V3         │ Configures Mic 2 as RIGHT Channel           │
├──────────────────────┼──────────────────────┼─────────────┼─────────────────────────────────────────────┤
│ Adafruit PCM5102A    │ VIN / GND            │ 5V (VBUS)/GND│ High-PSR Analog Power Supply (5V)          │
│ I2S Stereo DAC       │ SCK (System Clock)   │ GND         │ Internal PLL clock generation               │
│                      │ BCK (Bit Clock)      │ GPIO 15     │ I2S1 Output Bit Clock                       │
│                      │ LRCK (Word Select)   │ GPIO 16     │ I2S1 Output Word Select (16 kHz)            │
│                      │ DIN (Data Input)     │ GPIO 7      │ I2S1 Output Serial Audio Data               │
│                      │ XMT (Soft Mute)      │ 3V3         │ High = Unmute                               │
├──────────────────────┼──────────────────────┼─────────────┼─────────────────────────────────────────────┤
│ NJM4556AD Headphone  │ V+ (Pin 8) / V- (P4) │ +5V / GND   │ Single-Supply Rail (AC Coupled Out)         │
│ Driver Buffer        │ In A+ / In B+        │ DAC L / R   │ AC-coupled line input via 10uF film caps    │
│                      │ Out A / Out B        │ 3.5mm Jack  │ Drives 16-64 ohm monitoring headphones      │
├──────────────────────┼──────────────────────┼─────────────┼─────────────────────────────────────────────┤
│ UI & State Control   │ Mode Toggle Button   │ GPIO 0 / 14 │ Active-low momentary switch (debounced)     │
│                      │ Mode Status LEDs     │ GPIO 10,11,12│ Red (Bypass), Blue (Notch), Green (NLMS)    │
└──────────────────────┴──────────────────────┴─────────────┴─────────────────────────────────────────────┘
```

> [!NOTE]
> **Stereo I2S Microphone Time-Multiplexing**: The two Adafruit I2S MEMS breakouts share the exact same 3-wire bus (`BCLK` on GPIO 4, `LRCL` on GPIO 5, `DOUT` on GPIO 6). By tying `SEL` to `GND` on Mic 1 and `SEL` to `3V3` on Mic 2, the Knowles MEMS chips automatically time-multiplex their 16-bit transmissions into a single stereo I2S frame (Left = Primary, Right = Reference), requiring only one I2S peripheral inside the ESP32-S3.

---

## 5. Firmware Architecture & State Machine

The firmware executes as an ultra-low-latency real-time DSP loop inside ESP-IDF / FreeRTOS:

```
                                  ESP32-S3 FIRMWARE PIPELINE
   I2S0 Dual-Mic DMA Buffer (32 samples @ 16 kHz = 2.0 ms)
        │
        ├──► Deinterleave: Left = d[n] (Primary), Right = x[n] (Reference)
        │
        ├──► Mode Dispatcher (Switchable via GPIO 14 Button):
        │    ├─ Mode 0: Raw Bypass       ──► y[n] = d[n]
        │    ├─ Mode 1: Parametric Notch ──► y[n] = process_parametric_notch_cascade(d[n])
        │    ├─ Mode 2: Adaptive NLMS    ──► y[n] = nlms_filter(d[n], x[n])
        │    └─ Mode 3: Hybrid           ──► w[n] = Notch(d[n]) ──► y[n] = NLMS(w[n], x[n])
        │
        ├──► Stream to Dual Sinks:
        │    ├─ Sink A (Demo): Write y[n] to I2S1 DMA Buffer ──► PCM5102A ──► NJM4556AD (Live Audio)
        │    └─ Sink B (Test): Packetize {d[n], x[n], y[n]}  ──► USB-CDC FIFO ──► PC Host Logger
```

### Direct Form II Transposed (TDF-II) Realization
The single-channel and hybrid stages execute using the optimized C implementation in [`firmware/iir_coefficients.h`](file:///Users/macairm1/Documents/antigravity/blissful-bose/firmware/iir_coefficients.h):

```c
static inline float process_biquad_sample(const BiquadSection* s, float* state, float w) {
    float y = s->b0 * w + state[0];
    state[0] = s->b1 * w - s->a1 * y + state[1];
    state[1] = s->b2 * w - s->a2 * y;
    return y;
}
```

### Real-Time NLMS Core (`N = 256, μ = 0.05, ε = 1e-2`)
```c
static inline float process_nlms_sample(float d, float x, float* w_vec, float* x_circ, int* ptr) {
    /* Insert sample into circular delay line */
    x_circ[*ptr] = x;
    
    /* Dot product y = w^T * x */
    float y = 0.0f;
    float norm_x = 0.0f;
    for (int i = 0; i < 256; i++) {
        int idx = (*ptr - i + 256) & 255;
        float xi = x_circ[idx];
        y += w_vec[i] * xi;
        norm_x += xi * xi;
    }
    
    float e = d - y;
    
    /* Weight vector adaptation */
    float step = 0.05f / (norm_x + 0.01f) * e;
    for (int i = 0; i < 256; i++) {
        int idx = (*ptr - i + 256) & 255;
        w_vec[i] += step * x_circ[idx];
    }
    
    *ptr = (*ptr + 1) & 255;
    return e;
}
```

---

## 6. Progressive 3-Stage Testing & Validation Protocol

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   PROGRESSIVE 3-STAGE CALIBRATION & TESTING                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ STAGE 1: ACOUSTIC SPL & LEVEL CALIBRATION                                                               │
│  - Mount microphone rig at 1.2 m height.                                                                │
│  - Play 1 kHz reference tone from Speech Speaker; adjust amplifier to 70.0 dBA at 0.35 m.               │
│  - Play pink noise from Music Speaker; adjust amplifier to 70.0 dBA (0 dB), 75.0 dBA (-5 dB),          │
│    80.0 dBA (-10 dB), and 85.0 dBA (-15 dB) at microphone position.                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ STAGE 2: TRANSDUCER & TRANSFER FUNCTION CALIBRATION                                                     │
│  - Emit a logarithmic sine-sweep chirp (20 Hz - 8000 Hz, 5 seconds) from Speech Loudspeaker.            │
│  - Emit identical chirp from Music Loudspeaker.                                                         │
│  - Deconvolve impulse responses to extract physical H_speech(z), H_music(z), and inter-microphone       │
│    coupling ratio C_leak(ω) = |X_speech(ω)| / |D_speech(ω)| to verify speech isolation >= 12 dB.       │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ STAGE 3: PAIRED SIMULATION-TO-HARDWARE BENCHMARK                                                        │
│  - Execute 30 test sentences (10 Male, 10 Female, 10 Combined) across Jazz, Rock, and Techno.          │
│  - Run through Concert Simulation Suite (Nightclub, Arena, Open-Air) in software.                       │
│  - Simultaneously play through lab loudspeakers and capture on ESP32-S3 via USB-CDC.                    │
│  - Compute STOI, physical ΔSNR, Active Speech Level (ITU-T P.56), and divergence Δ_error = |STOI_hw -   │
│    STOI_sim| to validate that hardware closely tracks theoretical performance.                          │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Deliverables & Integration Plan

1. **Simulation Engine**: `scripts/simulate_concert_venues.py` implementing the 3 concert venue archetypes via the Image Source Method.
2. **Hardware Calibration Script**: `scripts/hardware_spl_chirp_calibration.py` to automate the logarithmic sine-sweep deconvolution and inter-mic crosstalk verification over USB.
3. **Firmware Source Code**: ESP-IDF project under `firmware/esp32_audio_firmware/` implementing dual-I2S streaming, runtime mode selection (Bypass, Notch, NLMS, Hybrid), USB-CDC frame logging, and PCM5102A/NJM4556AD headphone output.
4. **Comprehensive Vault Document**: Indexed in [`reports/00_master_index_and_vault_map.md`](file:///Users/macairm1/Documents/antigravity/blissful-bose/reports/00_master_index_and_vault_map.md) as **Report 09**.
