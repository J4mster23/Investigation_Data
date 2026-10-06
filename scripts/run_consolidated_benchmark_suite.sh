#!/usr/bin/env bash
# ==============================================================================
# run_consolidated_benchmark_suite.sh
#
# Master automation script for the Concert Speech Enhancement Research Suite.
# Consolidates:
#   1. MATLAB Multi-Venue Room Acoustic & DSP Experiment (5 venues, 3 genres, 5 SNRs, 8 filters)
#   2. High-Resolution Publication Plot Generation (STOI, PESQ, ViSQOL, dSNR, Reverb Penalty)
#   3. Multi-Sentence Audio Generation for ASR Intelligibility Benchmarks
#   4. Faster-Whisper Local ASR Word Error Rate & Confidence Benchmark
#   5. Google Cloud Speech-to-Text ASR Word Error Rate & Confidence Benchmark
#   6. Side-by-Side ASR Comparison Matrix & Joint Metric Fusion
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Resolve MATLAB Binary
if command -v matlab &> /dev/null; then
    MATLAB_BIN="matlab"
elif [ -f "/Applications/MATLAB_R2025a.app/bin/matlab" ]; then
    MATLAB_BIN="/Applications/MATLAB_R2025a.app/bin/matlab"
elif [ -f "/Applications/MATLAB_R2024b.app/bin/matlab" ]; then
    MATLAB_BIN="/Applications/MATLAB_R2024b.app/bin/matlab"
else
    echo "WARNING: MATLAB binary not found in standard paths. Falling back to 'matlab'."
    MATLAB_BIN="matlab"
fi

# Resolve Python Binary
if [ -f "/opt/anaconda3/bin/python3" ]; then
    PYTHON_BIN="/opt/anaconda3/bin/python3"
elif command -v python3 &> /dev/null; then
    PYTHON_BIN="python3"
else
    echo "ERROR: Python 3 not found."
    exit 1
fi

# Styling
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
NC="\033[0m"

echo -e "${BOLD}${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${CYAN}     CONSOLIDATED DSP & ASR AUTOMATION PIPELINE (MATLAB + WHISPER + GOOGLE)   ${NC}"
echo -e "${BOLD}${CYAN}==============================================================================${NC}"
echo -e "${BLUE}Base Directory:${NC}   ${BASE_DIR}"
echo -e "${BLUE}MATLAB Binary:${NC}    ${MATLAB_BIN}"
echo -e "${BLUE}Python Binary:${NC}    ${PYTHON_BIN}"
echo ""

RUN_DSP=true
RUN_PLOTS=true
RUN_SAMPLES=true
RUN_WHISPER=true
RUN_GOOGLE=true
RUN_MERGE=true

# Parse flags if arguments provided
if [ $# -gt 0 ]; then
    RUN_DSP=false
    RUN_PLOTS=false
    RUN_SAMPLES=false
    RUN_WHISPER=false
    RUN_GOOGLE=false
    RUN_MERGE=false
    for arg in "$@"; do
        case $arg in
            --all)
                RUN_DSP=true
                RUN_PLOTS=true
                RUN_SAMPLES=true
                RUN_WHISPER=true
                RUN_GOOGLE=true
                RUN_MERGE=true
                ;;
            --dsp)
                RUN_DSP=true
                ;;
            --plots)
                RUN_PLOTS=true
                ;;
            --samples)
                RUN_SAMPLES=true
                ;;
            --whisper)
                RUN_WHISPER=true
                ;;
            --google)
                RUN_GOOGLE=true
                ;;
            --merge)
                RUN_MERGE=true
                ;;
            --asr)
                RUN_WHISPER=true
                RUN_GOOGLE=true
                RUN_MERGE=true
                ;;
            *)
                echo "Unknown option: $arg"
                echo "Usage: $0 [--all] [--dsp] [--plots] [--samples] [--whisper] [--google] [--merge] [--asr]"
                exit 1
                ;;
        esac
    done
fi

# Step 1: MATLAB Room Experiment
if [ "$RUN_DSP" = true ]; then
    echo -e "${BOLD}${YELLOW}[Step 1/6] Running MATLAB Multi-Venue Room Acoustic Experiment...${NC}"
    echo "Venues: Free-Field, Damped Stage, Festival, Nightclub, Arena"
    echo "Genres: Techno, Jazz, Rock | SNRs: -20, -15, -10, -5, 0 dB | Filters: 8 Pipelines"
    "${MATLAB_BIN}" -batch "addpath(genpath('${BASE_DIR}/NLMS')); run_concert_venue_room_experiment; exit;"
    echo -e "${GREEN}✓ MATLAB Room Experiment Completed.${NC}\n"
fi

# Step 2: MATLAB Publication Plots
if [ "$RUN_PLOTS" = true ]; then
    echo -e "${BOLD}${YELLOW}[Step 2/6] Generating High-Resolution Publication Figures...${NC}"
    "${MATLAB_BIN}" -batch "addpath(genpath('${BASE_DIR}/NLMS')); plot_room_experiment_results; exit;"
    echo -e "${GREEN}✓ Publication Figures Generated.${NC}\n"
fi

# Step 3: Multi-Sentence Audio Sample Generation
if [ "$RUN_SAMPLES" = true ]; then
    echo -e "${BOLD}${YELLOW}[Step 3/6] Generating Multi-Sentence Audio Samples for ASR Testing...${NC}"
    "${MATLAB_BIN}" -batch "addpath(genpath('${BASE_DIR}/NLMS')); generate_multi_sentence_stt_samples; exit;"
    echo -e "${GREEN}✓ Audio Samples Generated in NLMS/output_audio/room_experiment/samples_multi_sentence/.${NC}\n"
fi

# Step 4: Faster-Whisper Evaluation
if [ "$RUN_WHISPER" = true ]; then
    echo -e "${BOLD}${YELLOW}[Step 4/6] Running Faster-Whisper ASR Intelligibility Benchmark...${NC}"
    "${PYTHON_BIN}" "${BASE_DIR}/scripts/evaluate_faster_whisper_intelligibility.py"
    echo -e "${GREEN}✓ Faster-Whisper Benchmark Completed.${NC}\n"
fi

# Step 5: Google Speech-to-Text Evaluation
if [ "$RUN_GOOGLE" = true ]; then
    echo -e "${BOLD}${YELLOW}[Step 5/6] Running Google Cloud Speech-to-Text Benchmark...${NC}"
    "${PYTHON_BIN}" "${BASE_DIR}/scripts/evaluate_google_stt_multi_sentence.py"
    echo -e "${GREEN}✓ Google Cloud STT Benchmark Completed.${NC}\n"
fi

# Step 6: Side-by-Side Matrix Merge
if [ "$RUN_MERGE" = true ]; then
    echo -e "${BOLD}${YELLOW}[Step 6/6] Generating Side-by-Side ASR Comparison Matrix...${NC}"
    "${PYTHON_BIN}" "${BASE_DIR}/scripts/generate_asr_comparison_matrix.py"
    echo -e "${GREEN}✓ Side-by-Side Matrix Generated.${NC}\n"
fi

echo -e "${BOLD}${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN}            ALL PIPELINE STAGES COMPLETED SUCCESSFULLY!                       ${NC}"
echo -e "${BOLD}${GREEN}==============================================================================${NC}"
