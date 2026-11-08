"""Reference implementation for the ELEC5305 final experiment.

The MATLAB script ``run_final_project.m`` is the primary submission code.
This Python version implements the same equations and is included as an
independent, reproducible cross-check for the reported tables and figures.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.io import wavfile


PROJECT_DIR = Path(__file__).resolve().parents[1]
AUDIO_DIR = PROJECT_DIR / "audio"
RESULTS_DIR = PROJECT_DIR / "results" / "final"
DEMO_DIR = RESULTS_DIR / "audio_demo"

PAIRS = [
    (
        "Traffic",
        268,
        "clean_fileid_268.wav",
        "clnsp102_traffic_248091_3_snr0_tl-21_fileid_268.wav",
    ),
    (
        "Babble",
        147,
        "clean_fileid_147.wav",
        "clnsp25_babble_188218_21_snr5_tl-25_fileid_147.wav",
    ),
    (
        "Wind",
        170,
        "clean_fileid_170.wav",
        "clnsp205_wind_407027_1_snr1_tl-24_fileid_170.wav",
    ),
    (
        "Vacuum",
        192,
        "clean_fileid_192.wav",
        "clnsp186_vacuum_353640_3_snr1_tl-27_fileid_192.wav",
    ),
    (
        "Birds",
        44,
        "clean_fileid_44.wav",
        "clnsp17_birds_413745_3_snr2_tl-23_fileid_44.wav",
    ),
    (
        "Bus",
        101,
        "clean_fileid_101.wav",
        "clnsp198_bus_56903_0_snr0_tl-32_fileid_101.wav",
    ),
    (
        "Air conditioner",
        17,
        "clean_fileid_17.wav",
        "clnsp426_air_conditioner_151977_1_snr3_tl-35_fileid_17.wav",
    ),
    (
        "Baby",
        72,
        "clean_fileid_72.wav",
        "clnsp146_baby_416657_0_snr9_tl-25_fileid_72.wav",
    ),
]

TARGET_SNRS = (-5, 0, 5, 10)
METHODS = ("Noisy input", "Spectral subtraction", "Wiener filter")
FRAME_DURATION = 0.032
SUBTRACTION_FACTOR = 1.0
SPECTRAL_FLOOR = 0.02
WIENER_GAIN_FLOOR = 0.05


def read_wav(path: Path) -> tuple[int, np.ndarray]:
    fs, signal = wavfile.read(path)
    if signal.ndim > 1:
        signal = signal.mean(axis=1)
    if np.issubdtype(signal.dtype, np.integer):
        scale = max(abs(np.iinfo(signal.dtype).min), np.iinfo(signal.dtype).max)
        signal = signal.astype(np.float64) / scale
    else:
        signal = signal.astype(np.float64)
    return int(fs), signal.reshape(-1)


def periodic_hamming(length: int) -> np.ndarray:
    n = np.arange(length, dtype=np.float64)
    return 0.54 - 0.46 * np.cos(2 * np.pi * n / length)


def local_stft(
    signal: np.ndarray, window: np.ndarray, hop: int, nfft: int
) -> tuple[np.ndarray, int]:
    frame_length = len(window)
    frames = max(1, int(np.ceil(max(0, len(signal) - frame_length) / hop)) + 1)
    padded_length = (frames - 1) * hop + frame_length
    padded = np.pad(signal, (0, padded_length - len(signal)))
    spectrum = np.empty((nfft, frames), dtype=np.complex128)
    for frame_index in range(frames):
        start = frame_index * hop
        frame = padded[start : start + frame_length] * window
        spectrum[:, frame_index] = np.fft.fft(frame, nfft)
    return spectrum, padded_length


def local_istft(
    spectrum: np.ndarray,
    window: np.ndarray,
    hop: int,
    nfft: int,
    padded_length: int,
    original_length: int,
) -> np.ndarray:
    frame_length = len(window)
    signal = np.zeros(padded_length, dtype=np.float64)
    normalisation = np.zeros(padded_length, dtype=np.float64)
    for frame_index in range(spectrum.shape[1]):
        start = frame_index * hop
        frame = np.fft.ifft(spectrum[:, frame_index], nfft).real[:frame_length]
        frame *= window
        signal[start : start + frame_length] += frame
        normalisation[start : start + frame_length] += window**2
    signal /= np.maximum(normalisation, np.finfo(float).eps)
    return signal[:original_length]


def mix_at_snr(
    clean: np.ndarray, noise: np.ndarray, target_snr: float
) -> tuple[np.ndarray, np.ndarray]:
    scale = np.sqrt(
        np.sum(clean**2)
        / (np.sum(noise**2) * 10 ** (target_snr / 10) + np.finfo(float).eps)
    )
    scaled_noise = scale * noise
    return clean + scaled_noise, scaled_noise


def snr(reference: np.ndarray, test: np.ndarray) -> float:
    error = reference - test
    return float(
        10
        * np.log10(
            np.sum(reference**2) / (np.sum(error**2) + np.finfo(float).eps)
        )
    )


def segmental_snr(reference: np.ndarray, test: np.ndarray, fs: int) -> float:
    frame_length = round(0.020 * fs)
    hop = round(frame_length / 2)
    frames = max(1, (len(reference) - frame_length) // hop + 1)
    energies = np.zeros(frames)
    scores = np.zeros(frames)
    for frame_index in range(frames):
        start = frame_index * hop
        ref_frame = reference[start : start + frame_length]
        test_frame = test[start : start + frame_length]
        energies[frame_index] = np.sum(ref_frame**2)
        score = 10 * np.log10(
            energies[frame_index]
            / (np.sum((ref_frame - test_frame) ** 2) + np.finfo(float).eps)
        )
        scores[frame_index] = np.clip(score, -10, 35)
    active = energies > energies.max() * 1e-4
    return float(scores[active].mean() if active.any() else scores.mean())


def log_spectral_distance(reference: np.ndarray, test: np.ndarray, fs: int) -> float:
    frame_length = round(FRAME_DURATION * fs)
    if frame_length % 2:
        frame_length += 1
    hop = frame_length // 2
    window = periodic_hamming(frame_length)
    reference_stft, _ = local_stft(reference, window, hop, frame_length)
    test_stft, _ = local_stft(test, window, hop, frame_length)
    positive = slice(0, frame_length // 2 + 1)
    reference_magnitude = np.abs(reference_stft[positive])
    test_magnitude = np.abs(test_stft[positive])
    floor = reference_magnitude.max() * 10 ** (-80 / 20) + np.finfo(float).eps
    reference_db = 20 * np.log10(np.maximum(reference_magnitude, floor))
    test_db = 20 * np.log10(np.maximum(test_magnitude, floor))
    energies = np.sum(reference_magnitude**2, axis=0)
    active = energies > energies.max() * 1e-4
    frame_lsd = np.sqrt(np.mean((reference_db[:, active] - test_db[:, active]) ** 2, axis=0))
    return float(frame_lsd.mean())


def enhance(
    clean: np.ndarray, noisy: np.ndarray, scaled_noise: np.ndarray, fs: int
) -> tuple[np.ndarray, np.ndarray]:
    frame_length = round(FRAME_DURATION * fs)
    if frame_length % 2:
        frame_length += 1
    hop = frame_length // 2
    window = periodic_hamming(frame_length)

    noisy_stft, padded_length = local_stft(noisy, window, hop, frame_length)
    noise_stft, _ = local_stft(scaled_noise, window, hop, frame_length)
    noise_power = np.mean(np.abs(noise_stft) ** 2, axis=1, keepdims=True)
    noisy_power = np.abs(noisy_stft) ** 2

    subtracted_power = noisy_power - SUBTRACTION_FACTOR * noise_power
    subtracted_power = np.maximum(subtracted_power, SPECTRAL_FLOOR * noisy_power)
    spectral_stft = np.sqrt(subtracted_power) * np.exp(1j * np.angle(noisy_stft))
    spectral_output = local_istft(
        spectral_stft, window, hop, frame_length, padded_length, len(clean)
    )

    speech_power = np.maximum(noisy_power - noise_power, 0)
    wiener_gain = speech_power / (speech_power + noise_power + np.finfo(float).eps)
    wiener_gain = np.maximum(wiener_gain, WIENER_GAIN_FLOOR)
    wiener_output = local_istft(
        wiener_gain * noisy_stft,
        window,
        hop,
        frame_length,
        padded_length,
        len(clean),
    )
    return spectral_output, wiener_output


def spectrogram_db(
    signal: np.ndarray, fs: int, common_reference: float
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    frame_length = round(FRAME_DURATION * fs)
    if frame_length % 2:
        frame_length += 1
    hop = frame_length // 2
    window = periodic_hamming(frame_length)
    spectrum, _ = local_stft(signal, window, hop, frame_length)
    positive = slice(0, frame_length // 2 + 1)
    magnitude_db = 20 * np.log10(
        np.abs(spectrum[positive]) / common_reference + np.finfo(float).eps
    )
    frequency = np.arange(frame_length // 2 + 1) * fs / frame_length
    time = (np.arange(spectrum.shape[1]) * hop + frame_length / 2) / fs
    return time, frequency, magnitude_db


def save_wav(path: Path, signal: np.ndarray, fs: int) -> None:
    clipped = np.clip(signal, -1, 1)
    wavfile.write(path, fs, np.round(clipped * 32767).astype(np.int16))


def main() -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    DEMO_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, float | int | str]] = []
    representative: tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, int] | None = None

    for noise_type, file_id, clean_name, noisy_name in PAIRS:
        fs_clean, clean = read_wav(AUDIO_DIR / clean_name)
        fs_noisy, original_noisy = read_wav(AUDIO_DIR / noisy_name)
        if fs_clean != fs_noisy:
            raise ValueError(f"Sample-rate mismatch for file ID {file_id}")
        length = min(len(clean), len(original_noisy))
        clean = clean[:length] - clean[:length].mean()
        original_noisy = original_noisy[:length] - original_noisy[:length].mean()
        reference_noise = original_noisy - clean
        reference_noise -= reference_noise.mean()

        for target_snr in TARGET_SNRS:
            noisy, scaled_noise = mix_at_snr(clean, reference_noise, target_snr)
            spectral, wiener = enhance(clean, noisy, scaled_noise, fs_clean)
            measured_input_snr = snr(clean, noisy)
            condition_id = f"{noise_type.lower().replace(' ', '_')}_{target_snr:+d}dB"
            for method, signal in zip(METHODS, (noisy, spectral, wiener), strict=True):
                output_snr = snr(clean, signal)
                rows.append(
                    {
                        "conditionID": condition_id,
                        "noiseType": noise_type,
                        "fileID": file_id,
                        "targetInputSNR_dB": target_snr,
                        "measuredInputSNR_dB": measured_input_snr,
                        "method": method,
                        "outputSNR_dB": output_snr,
                        "snrImprovement_dB": output_snr - measured_input_snr,
                        "segmentalSNR_dB": segmental_snr(clean, signal, fs_clean),
                        "logSpectralDistance_dB": log_spectral_distance(
                            clean, signal, fs_clean
                        ),
                    }
                )
            if noise_type == "Traffic" and target_snr == 0:
                representative = (clean, noisy, spectral, wiener, fs_clean)

        print(f"Completed {noise_type}")

    metrics = pd.DataFrame(rows)
    metrics.to_csv(RESULTS_DIR / "final_metrics.csv", index=False)

    enhanced = metrics[metrics["method"].isin(METHODS[1:])]
    summary = (
        enhanced.groupby(["method", "targetInputSNR_dB"], sort=False)
        .agg(
            meanOutputSNR_dB=("outputSNR_dB", "mean"),
            meanSNRImprovement_dB=("snrImprovement_dB", "mean"),
            stdSNRImprovement_dB=("snrImprovement_dB", "std"),
            meanSegmentalSNR_dB=("segmentalSNR_dB", "mean"),
            meanLogSpectralDistance_dB=("logSpectralDistance_dB", "mean"),
        )
        .reset_index()
        .rename(
            columns={
                "method": "summaryMethod",
                "targetInputSNR_dB": "summaryInputSNR_dB",
            }
        )
    )
    summary.to_csv(RESULTS_DIR / "final_summary.csv", index=False)

    colours = {"Spectral subtraction": "#1f77b4", "Wiener filter": "#ff7f0e"}
    fig, ax = plt.subplots(figsize=(8.2, 5.1))
    for method in METHODS[1:]:
        selected = summary[summary["summaryMethod"] == method]
        ax.errorbar(
            selected["summaryInputSNR_dB"],
            selected["meanSNRImprovement_dB"],
            yerr=selected["stdSNRImprovement_dB"],
            marker="o",
            linewidth=2,
            capsize=4,
            label=method,
            color=colours[method],
        )
    ax.axhline(0, color="black", linestyle="--", linewidth=1)
    ax.set(
        xlabel="Target input SNR (dB)",
        ylabel="Mean SNR improvement (dB)",
        title="Speech enhancement across eight DNS noise conditions",
        xticks=TARGET_SNRS,
    )
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(RESULTS_DIR / "mean_snr_improvement.png", dpi=220)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.2, 5.1))
    lsd_colours = {
        "Noisy input": "#666666",
        "Spectral subtraction": "#1f77b4",
        "Wiener filter": "#ff7f0e",
    }
    for method in METHODS:
        selected = metrics[metrics["method"] == method]
        means = selected.groupby("targetInputSNR_dB")["logSpectralDistance_dB"].mean()
        ax.plot(
            list(TARGET_SNRS),
            means.reindex(TARGET_SNRS),
            marker="o",
            linewidth=2,
            label=method,
            color=lsd_colours[method],
        )
    ax.set(
        xlabel="Target input SNR (dB)",
        ylabel="Mean log-spectral distance (dB)",
        title="Spectral distortion relative to clean speech (lower is better)",
        xticks=TARGET_SNRS,
    )
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(RESULTS_DIR / "mean_log_spectral_distance.png", dpi=220)
    plt.close(fig)

    fig, axes = plt.subplots(1, 2, figsize=(11.2, 6.4), constrained_layout=True)
    noise_order = [pair[0] for pair in PAIRS]
    image = None
    for ax, method in zip(axes, METHODS[1:], strict=True):
        selected = metrics[metrics["method"] == method]
        heat = (
            selected.pivot(index="noiseType", columns="targetInputSNR_dB", values="snrImprovement_dB")
            .reindex(index=noise_order, columns=TARGET_SNRS)
            .to_numpy()
        )
        image = ax.imshow(heat, aspect="auto", origin="lower", cmap="turbo", vmin=-2, vmax=12)
        ax.set_xticks(range(len(TARGET_SNRS)), TARGET_SNRS)
        ax.set_yticks(range(len(noise_order)), noise_order)
        ax.set(xlabel="Target input SNR (dB)", ylabel="DNS noise type", title=method)
    fig.suptitle("SNR improvement by method and test condition (dB)")
    assert image is not None
    fig.colorbar(image, ax=axes, shrink=0.82)
    fig.savefig(RESULTS_DIR / "snr_improvement_heatmaps.png", dpi=220)
    plt.close(fig)

    if representative is None:
        raise RuntimeError("Representative traffic condition was not saved")
    clean, noisy, spectral, wiener, representative_fs = representative
    frame_length = round(FRAME_DURATION * representative_fs)
    if frame_length % 2:
        frame_length += 1
    noisy_spectrum, _ = local_stft(
        noisy, periodic_hamming(frame_length), frame_length // 2, frame_length
    )
    common_reference = np.abs(noisy_spectrum).max() + np.finfo(float).eps
    representative_signals = (clean, noisy, spectral, wiener)
    representative_titles = (
        "Clean reference",
        "Noisy speech (0 dB)",
        "Spectral subtraction",
        "Wiener filter",
    )
    fig, axes = plt.subplots(2, 2, figsize=(11.5, 8.1), constrained_layout=True)
    image = None
    for ax, signal, title in zip(
        axes.flat, representative_signals, representative_titles, strict=True
    ):
        time, frequency, magnitude_db = spectrogram_db(
            signal, representative_fs, common_reference
        )
        image = ax.pcolormesh(time, frequency, magnitude_db, shading="auto", cmap="turbo", vmin=-80, vmax=0)
        ax.set(xlabel="Time (s)", ylabel="Frequency (Hz)", title=title, ylim=(0, 8000))
    fig.suptitle("Representative DNS traffic-noise condition at 0 dB input SNR")
    assert image is not None
    fig.colorbar(image, ax=axes, shrink=0.82, label="Magnitude (dB)")
    fig.savefig(RESULTS_DIR / "representative_spectrograms.png", dpi=220)
    plt.close(fig)

    shared_peak = max(np.max(np.abs(signal)) for signal in representative_signals)
    shared_scale = min(1.0, 0.99 / (shared_peak + np.finfo(float).eps))
    for filename, signal in zip(
        (
            "clean_reference.wav",
            "noisy_traffic_0dB.wav",
            "spectral_subtraction_traffic_0dB.wav",
            "wiener_filter_traffic_0dB.wav",
        ),
        representative_signals,
        strict=True,
    ):
        save_wav(DEMO_DIR / filename, signal * shared_scale, representative_fs)

    spectral_rows = metrics[metrics["method"] == "Spectral subtraction"]
    wiener_rows = metrics[metrics["method"] == "Wiener filter"]
    spectral_improvement = spectral_rows["snrImprovement_dB"].to_numpy()
    wiener_improvement = wiener_rows["snrImprovement_dB"].to_numpy()
    wiener_wins = int(np.sum(wiener_improvement > spectral_improvement))
    spectral_wins = int(np.sum(spectral_improvement > wiener_improvement))
    conditions = len(PAIRS) * len(TARGET_SNRS)
    summary_text = f"""ELEC5305 Final Project - Controlled Benchmark
Student: Zhizhong Chen (530668932)

Test design: 8 DNS noise conditions x 4 target SNRs = 32 cases
Input SNRs: -5, 0, 5 and 10 dB
STFT: 32 ms periodic Hamming window, 50 percent overlap

Overall mean SNR improvement
  Spectral subtraction: {spectral_improvement.mean():.3f} dB
  Wiener filtering:     {wiener_improvement.mean():.3f} dB

Overall mean log-spectral distance (lower is better)
  Spectral subtraction: {spectral_rows['logSpectralDistance_dB'].mean():.3f} dB
  Wiener filtering:     {wiener_rows['logSpectralDistance_dB'].mean():.3f} dB

Condition wins by SNR improvement
  Wiener filtering:     {wiener_wins} of {conditions}
  Spectral subtraction: {spectral_wins} of {conditions}
  Ties:                 {conditions - wiener_wins - spectral_wins} of {conditions}

Important limitation: both methods use the same oracle noise PSD estimated
from the aligned DNS noise residual. This controlled benchmark isolates the
gain-rule comparison but is not a causal real-time speech-enhancement system.
"""
    (RESULTS_DIR / "final_summary.txt").write_text(summary_text, encoding="utf-8")
    print(summary_text)


if __name__ == "__main__":
    main()
