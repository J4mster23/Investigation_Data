/**
 * @file iir_coefficients.h
 * @brief Cascaded Second-Order Sections (SOS / Biquad) IIR filter coefficients.
 * Genres: Jazz, Rock, Techno, Control (fs = 16 kHz, Chebyshev Type II).
 * Structure: Direct Form II Transposed for optimal numerical stability on ESP32-S3.
 * Also contains Phase 2 Parametric Notch Biquad coefficients.
 */

#ifndef IIR_COEFFICIENTS_H
#define IIR_COEFFICIENTS_H

#define IIR_BIQUADS_COUNT 4

typedef struct {
    float b0, b1, b2;
    float a1, a2;
} BiquadSection;

/* JAZZ IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04756331f */
static const float g_jazz_iir = 0.04756331f;
static const BiquadSection sos_jazz_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.53754412f, .b2 =    1.00000000f, .a1 =   -0.59925351f, .a2 =    0.14989479f },
    { .b0 =    1.00000000f, .b1 =    0.30587073f, .b2 =    1.00000000f, .a1 =   -0.80411875f, .a2 =    0.60162097f },
    { .b0 =    1.00000000f, .b1 =   -1.99953740f, .b2 =    1.00000000f, .a1 =   -1.82192736f, .a2 =    0.83219723f },
    { .b0 =    1.00000000f, .b1 =   -1.99740156f, .b2 =    1.00000000f, .a1 =   -1.93208936f, .a2 =    0.94243026f }
};

/* JAZZ Parametric Notch Biquad (f0 = 78.1 Hz, Q = 6.0) */
static const BiquadSection notch_jazz_biquad = {
    .b0 =    0.99745028f, .b1 =   -1.99396180f, .b2 =    0.99745028f, .a1 =   -1.99396180f, .a2 =    0.99490057f
};

/* ROCK IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.03675800f */
static const float g_rock_iir = 0.03675800f;
static const BiquadSection sos_rock_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.38488348f, .b2 =    1.00000000f, .a1 =   -0.77422804f, .a2 =    0.21030325f },
    { .b0 =    1.00000000f, .b1 =   -0.00859291f, .b2 =    1.00000000f, .a1 =   -0.98409868f, .a2 =    0.64058717f },
    { .b0 =    1.00000000f, .b1 =   -1.99938666f, .b2 =    1.00000000f, .a1 =   -1.79641057f, .a2 =    0.81026216f },
    { .b0 =    1.00000000f, .b1 =   -1.99659812f, .b2 =    1.00000000f, .a1 =   -1.92550757f, .a2 =    0.93854493f }
};

/* ROCK Parametric Notch Biquad (f0 = 109.4 Hz, Q = 6.0) */
static const BiquadSection notch_rock_biquad = {
    .b0 =    0.99643457f, .b1 =   -1.99103117f, .b2 =    0.99643457f, .a1 =   -1.99103117f, .a2 =    0.99286914f
};

/* TECHNO IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04000891f */
static const float g_techno_iir = 0.04000891f;
static const BiquadSection sos_techno_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.45482075f, .b2 =    1.00000000f, .a1 =   -0.72837980f, .a2 =    0.20558169f },
    { .b0 =    1.00000000f, .b1 =    0.14584361f, .b2 =    1.00000000f, .a1 =   -0.87716626f, .a2 =    0.63935724f },
    { .b0 =    1.00000000f, .b1 =   -1.99882106f, .b2 =    1.00000000f, .a1 =   -1.72373702f, .a2 =    0.75003929f },
    { .b0 =    1.00000000f, .b1 =   -1.99355306f, .b2 =    1.00000000f, .a1 =   -1.89830479f, .a2 =    0.92186971f }
};

/* TECHNO Parametric Notch Biquad (f0 = 62.5 Hz, Q = 8.0) */
static const BiquadSection notch_techno_biquad = {
    .b0 =    0.99846852f, .b1 =   -1.99633560f, .b2 =    0.99846852f, .a1 =   -1.99633560f, .a2 =    0.99693704f
};

/* CONTROL IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04050001f */
static const float g_control_iir = 0.04050001f;
static const BiquadSection sos_control_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.45804799f, .b2 =    1.00000000f, .a1 =   -0.71721802f, .a2 =    0.19756005f },
    { .b0 =    1.00000000f, .b1 =    0.14691858f, .b2 =    1.00000000f, .a1 =   -0.88279730f, .a2 =    0.63424505f },
    { .b0 =    1.00000000f, .b1 =   -1.99903250f, .b2 =    1.00000000f, .a1 =   -1.74753489f, .a2 =    0.76917557f },
    { .b0 =    1.00000000f, .b1 =   -1.99467736f, .b2 =    1.00000000f, .a1 =   -1.90686527f, .a2 =    0.92668782f }
};

/* CONTROL Parametric Notch Biquad (f0 = 100.0 Hz, Q = 5.0) */
static const BiquadSection notch_control_biquad = {
    .b0 =    0.99608937f, .b1 =   -1.99064285f, .b2 =    0.99608937f, .a1 =   -1.99064285f, .a2 =    0.99217874f
};

/**
 * @brief Cascaded Biquad Direct Form II Transposed filtering.
 * Requires 2 state floats per biquad (total 8 floats).
 */
static inline float process_iir_biquads(const BiquadSection* restrict sos, float* restrict state, float input, float gain) {
    float w = input * gain;
    for (int s = 0; s < IIR_BIQUADS_COUNT; s++) {
        float s1 = state[s * 2];
        float s2 = state[s * 2 + 1];
        float y = sos[s].b0 * w + s1;
        state[s * 2]     = sos[s].b1 * w - sos[s].a1 * y + s2;
        state[s * 2 + 1] = sos[s].b2 * w - sos[s].a2 * y;
        w = y;
    }
    return w;
}

/**
 * @brief Single Parametric Notch Biquad Direct Form II Transposed filtering.
 * Requires 2 state floats.
 */
static inline float process_single_biquad(const BiquadSection* restrict sec, float* restrict state, float input) {
    float s1 = state[0];
    float s2 = state[1];
    float y = sec->b0 * input + s1;
    state[0] = sec->b1 * input - sec->a1 * y + s2;
    state[1] = sec->b2 * input - sec->a2 * y;
    return y;
}

#endif /* IIR_COEFFICIENTS_H */
