# ELEC5305 Final Project Video Script

Target length: 4–5 minutes. Record the screen and speak the English lines below.

## Before recording（录制前）

1. Open the repository folder in MATLAB.
2. Open `code/run_final_project.m`.
3. Make sure the script has already run successfully once.
4. Open these files so they are easy to show:
   - `results/final/mean_snr_improvement.png`
   - `results/final/snr_improvement_heatmaps.png`
   - `results/final/mean_log_spectral_distance.png`
   - `results/final/representative_spectrograms.png`
5. Put the four demonstration WAV files in `results/final/audio_demo/` where they can be played.

## 0:00–0:25 — Title and research question

**Screen:** Show the GitHub project page or the first page of the report.

**Say:**

> Hello, my name is Zhizhong Chen, and my student ID is 530668932. This project compares Wiener filtering and spectral subtraction for single-channel speech noise reduction. My research question is: how do the two methods differ in noise reduction and speech distortion across several real-world noise types and input SNRs when they use the same STFT and noise estimate?

## 0:25–1:10 — Experimental design

**Screen:** Show the “Experimental design” section in `README.md`, then show the `audio` folder.

**Say:**

> I used eight aligned clean and noisy pairs from the Microsoft DNS Challenge. The noise types are traffic, babble, wind, vacuum, birds, bus, air conditioner and baby sounds. Each noise residual was mixed with clean speech at minus five, zero, five and ten decibels, producing thirty-two paired test conditions. Both algorithms use sixteen kilohertz mono audio, a thirty-two millisecond periodic Hamming window and fifty percent overlap.

> To make the comparison controlled, both methods use the same oracle noise power spectral density. This isolates the difference between the two gain rules, but it is an upper-bound experiment rather than a deployable real-time system.

## 1:10–2:05 — Demonstrate the working code

**Screen:** Show the top of `code/run_final_project.m`, then slowly scroll through the parameter section and the main experiment loop. Run the script by clicking **Run**, or show this command in the Command Window:

```matlab
run('code/run_final_project.m')
```

**Say:**

> This is the main MATLAB implementation. It validates the required audio, constructs all thirty-two mixtures, performs the common short-time Fourier transform, applies both enhancement algorithms, reconstructs the signals by overlap-add, and calculates global SNR, segmental SNR and log-spectral distance. It then writes detailed CSV files, summary tables, figures and demonstration audio to the results folder.

> Spectral subtraction removes an estimated noise power and applies a floor. The Wiener method applies a smooth power-ratio gain with a small gain floor. The parameters remain fixed for every noise type and input SNR.

## 2:05–3:10 — Main results

**Screen:** Show `mean_snr_improvement.png`, followed by `snr_improvement_heatmaps.png`.

**Say:**

> Wiener filtering achieved the larger global SNR improvement in every one of the thirty-two conditions. Its overall mean improvement was two point nine four five decibels, compared with two point zero nine zero decibels for spectral subtraction. The heatmaps also show that stationary or slowly varying air-conditioner, bus and vacuum noise was easier than baby, birds, babble and wind noise.

**Screen:** Show `mean_log_spectral_distance.png`.

**Say:**

> However, spectral subtraction achieved the slightly lower mean log-spectral distance: ten point three three four decibels compared with ten point seven seven two decibels for Wiener filtering. Lower is better for this measure. Therefore, the method with the strongest energy reduction did not preserve the short-time spectrum most closely.

## 3:10–4:00 — Qualitative example

**Screen:** Show `representative_spectrograms.png`. If possible, play short portions of the noisy, spectral-subtraction and Wiener WAV files.

**Say:**

> This figure shows the representative zero-decibel traffic condition. Both methods reduce the broadband background and retain the main speech bands. The Wiener output is darker in many low-energy regions, which agrees with its larger SNR improvement. The spectral-subtraction output retains more low-level structure, which is consistent with its slightly lower average spectral distance.

> The audio examples allow the outputs to be compared directly, but this project did not conduct a formal listening test.

## 4:00–4:40 — Conclusion and limitations

**Screen:** Return to the report conclusion or the “Key limitations” section in `README.md`.

**Say:**

> In conclusion, there is no single winner for every objective. Wiener filtering is preferred when global SNR improvement is the priority, while spectral subtraction has a small aggregate advantage in log-spectral distance. The main limitations are the oracle noise estimate, the small eight-utterance corpus and the absence of perceptual testing. Future work should add causal noise estimation, more speakers and noise examples, parameter sweeps, intelligibility measures and a blinded listening test. Thank you.

## Recording checklist（录完以后检查）

- Your name and student ID are spoken.
- The MATLAB code is visible and shown running.
- At least three result figures are visible.
- The main numerical findings are stated.
- Limitations are stated honestly.
- The video is easy to hear and under about five minutes.

