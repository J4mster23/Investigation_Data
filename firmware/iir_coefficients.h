/**
 * @file iir_coefficients.h
 * @brief Cascaded Second-Order Sections (SOS) Biquad IIR and Parametric Notch Coefficients.
 * Target: ESP32-S3 (16 kHz audio processing loop).
 * Genres: Jazz, Rock, Techno.
 */

#ifndef IIR_COEFFICIENTS_H
#define IIR_COEFFICIENTS_H

typedef struct {
    float b0, b1, b2;
    float a1, a2;
} BiquadSection;

/* JAZZ Parametric Notch Cascade (1 Biquad Stages, f0 = 78.1 Hz) */
#define NOTCH_JAZZ_STAGES 1
static const BiquadSection notch_jazz_cascade[1] = {
    { .b0 =    0.99745028f, .b1 =   -1.99396180f, .b2 =    0.99745028f, .a1 =   -1.99396180f, .a2 =    0.99490057f }
};

/* ROCK Parametric Notch Cascade (2 Biquad Stages, f0 = 109.4 Hz) */
#define NOTCH_ROCK_STAGES 2
static const BiquadSection notch_rock_cascade[2] = {
    { .b0 =    0.99643457f, .b1 =   -1.99103117f, .b2 =    0.99643457f, .a1 =   -1.99103117f, .a2 =    0.99286914f },
    { .b0 =    0.50118723f, .b1 =    0.19980915f, .b2 =    0.10014250f, .a1 =   -0.39867167f, .a2 =    0.19981056f }
};

/* TECHNO Parametric Notch Cascade (2 Biquad Stages, f0 = 62.5 Hz) */
#define NOTCH_TECHNO_STAGES 2
static const BiquadSection notch_techno_cascade[2] = {
    { .b0 =    0.99846852f, .b1 =   -1.99633560f, .b2 =    0.99846852f, .a1 =   -1.99633560f, .a2 =    0.99693704f },
    { .b0 =    0.99592768f, .b1 =   -1.98945608f, .b2 =    0.99592768f, .a1 =   -1.98945608f, .a2 =    0.99185536f }
};

/**
 * @brief Executes Parametric Notch Biquad Cascade in Direct Form II Transposed structure.
 * @param cascade Array of BiquadSection
 * @param num_stages Number of cascaded biquad stages
 * @param state State buffer (must have size: 2 * num_stages floats)
 * @param input Raw audio sample (float)
 * @return Filtered audio sample (float)
 */
static inline float process_parametric_notch_cascade(const BiquadSection* restrict cascade, int num_stages, float* restrict state, float input) {
    float w = input;
    for (int s = 0; s < num_stages; s++) {
        float s1 = state[s * 2];
        float s2 = state[s * 2 + 1];
        float y = cascade[s].b0 * w + s1;
        state[s * 2]     = cascade[s].b1 * w - cascade[s].a1 * y + s2;
        state[s * 2 + 1] = cascade[s].b2 * w - cascade[s].a2 * y;
        w = y;
    }
    return w;
}

#endif /* IIR_COEFFICIENTS_H */
