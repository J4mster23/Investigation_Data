/**
 * @file iir_coefficients.h
 * @brief Cascaded Second-Order Sections (SOS / Biquad) IIR filter coefficients.
 * Designed via Chebyshev Type II (Inverse Chebyshev) algorithm (fs = 16 kHz).
 * Structure: Direct Form II Transposed for optimal numerical stability on ESP32-S3.
 */

#ifndef IIR_COEFFICIENTS_H
#define IIR_COEFFICIENTS_H

#define IIR_BIQUADS_COUNT 4

/* Biquad coefficient structure: [b0, b1, b2, a0(1.0), a1, a2] */
typedef struct {
    float b0, b1, b2;
    float a1, a2;
} BiquadSection;

/* HOUSE IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04099809f */
static const float g_house_iir = 0.04099809f;
static const BiquadSection sos_house_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.46125119f, .b2 =    1.00000000f, .a1 =   -0.70556006f, .a2 =    0.18972129f },
    { .b0 =    1.00000000f, .b1 =    0.14799966f, .b2 =    1.00000000f, .a1 =   -0.88834388f, .a2 =    0.62896237f },
    { .b0 =    1.00000000f, .b1 =   -1.99922179f, .b2 =    1.00000000f, .a1 =   -1.77184805f, .a2 =    0.78927563f },
    { .b0 =    1.00000000f, .b1 =   -1.99569309f, .b2 =    1.00000000f, .a1 =   -1.91550139f, .a2 =    0.93184959f }
};

/* TECHNO IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.04000891f */
static const float g_techno_iir = 0.04000891f;
static const BiquadSection sos_techno_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.45482075f, .b2 =    1.00000000f, .a1 =   -0.72837980f, .a2 =    0.20558169f },
    { .b0 =    1.00000000f, .b1 =    0.14584361f, .b2 =    1.00000000f, .a1 =   -0.87716626f, .a2 =    0.63935724f },
    { .b0 =    1.00000000f, .b1 =   -1.99882106f, .b2 =    1.00000000f, .a1 =   -1.72373702f, .a2 =    0.75003929f },
    { .b0 =    1.00000000f, .b1 =   -1.99355306f, .b2 =    1.00000000f, .a1 =   -1.89830479f, .a2 =    0.92186971f }
};

/* DNB IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = 0.03675800f */
static const float g_dnb_iir = 0.03675800f;
static const BiquadSection sos_dnb_iir[4] = {
    { .b0 =    1.00000000f, .b1 =    1.38488348f, .b2 =    1.00000000f, .a1 =   -0.77422804f, .a2 =    0.21030325f },
    { .b0 =    1.00000000f, .b1 =   -0.00859291f, .b2 =    1.00000000f, .a1 =   -0.98409868f, .a2 =    0.64058717f },
    { .b0 =    1.00000000f, .b1 =   -1.99938666f, .b2 =    1.00000000f, .a1 =   -1.79641057f, .a2 =    0.81026216f },
    { .b0 =    1.00000000f, .b1 =   -1.99659812f, .b2 =    1.00000000f, .a1 =   -1.92550757f, .a2 =    0.93854493f }
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
