/**
 * @file iir_coefficients.h
 * @brief Cascaded Second-Order Sections (SOS / Biquad) IIR filter coefficients.
 * Genres: Country, Rock, Techno, Control (fs = 16 kHz, Chebyshev Type II).
 * Structure: Direct Form II Transposed for optimal numerical stability on ESP32-S3.
 */

#ifndef IIR_COEFFICIENTS_H
#define IIR_COEFFICIENTS_H

#define IIR_BIQUADS_COUNT 4

typedef struct {
    float b0, b1, b2;
    float a1, a2;
} BiquadSection;

/* COUNTRY IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04175856f */
static const float g_country_iir = 0.04175856f;
static const BiquadSection sos_country_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.46601151f, .b2 =    1.00000000f, .a1 =   -0.68735139f, .a2 =    0.17837704f },
    { .b0 =    1.00000000f, .b1 =    0.14963292f, .b2 =    1.00000000f, .a1 =   -0.89647083f, .a2 =    0.62069427f },
    { .b0 =    1.00000000f, .b1 =   -1.99946519f, .b2 =    1.00000000f, .a1 =   -1.80907618f, .a2 =    0.82104798f },
    { .b0 =    1.00000000f, .b1 =   -1.99701377f, .b2 =    1.00000000f, .a1 =   -1.92863125f, .a2 =    0.94030267f }
};

/* ROCK IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.03675800f */
static const float g_rock_iir = 0.03675800f;
static const BiquadSection sos_rock_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.38488348f, .b2 =    1.00000000f, .a1 =   -0.77422804f, .a2 =    0.21030325f },
    { .b0 =    1.00000000f, .b1 =   -0.00859291f, .b2 =    1.00000000f, .a1 =   -0.98409868f, .a2 =    0.64058717f },
    { .b0 =    1.00000000f, .b1 =   -1.99938666f, .b2 =    1.00000000f, .a1 =   -1.79641057f, .a2 =    0.81026216f },
    { .b0 =    1.00000000f, .b1 =   -1.99659812f, .b2 =    1.00000000f, .a1 =   -1.92550757f, .a2 =    0.93854493f }
};

/* TECHNO IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04000891f */
static const float g_techno_iir = 0.04000891f;
static const BiquadSection sos_techno_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.45482075f, .b2 =    1.00000000f, .a1 =   -0.72837980f, .a2 =    0.20558169f },
    { .b0 =    1.00000000f, .b1 =    0.14584361f, .b2 =    1.00000000f, .a1 =   -0.87716626f, .a2 =    0.63935724f },
    { .b0 =    1.00000000f, .b1 =   -1.99882106f, .b2 =    1.00000000f, .a1 =   -1.72373702f, .a2 =    0.75003929f },
    { .b0 =    1.00000000f, .b1 =   -1.99355306f, .b2 =    1.00000000f, .a1 =   -1.89830479f, .a2 =    0.92186971f }
};

/* CONTROL IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04050001f */
static const float g_control_iir = 0.04050001f;
static const BiquadSection sos_control_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.45804799f, .b2 =    1.00000000f, .a1 =   -0.71721802f, .a2 =    0.19756005f },
    { .b0 =    1.00000000f, .b1 =    0.14691858f, .b2 =    1.00000000f, .a1 =   -0.88279730f, .a2 =    0.63424505f },
    { .b0 =    1.00000000f, .b1 =   -1.99903250f, .b2 =    1.00000000f, .a1 =   -1.74753489f, .a2 =    0.76917557f },
    { .b0 =    1.00000000f, .b1 =   -1.99467736f, .b2 =    1.00000000f, .a1 =   -1.90686527f, .a2 =    0.92668782f }
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

#endif /* IIR_COEFFICIENTS_H */
