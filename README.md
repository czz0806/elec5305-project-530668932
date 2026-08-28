# Comparison of Wiener Filtering and Spectral Subtraction for Speech Noise Reduction

- **Course:** ELEC5305
- **Student ID:** 530668932
- **Project Status:** Proposal Stage
- **Project Website:** https://czz0806.github.io/elec5305-project-530668932/

## Project Overview

Background noise can significantly reduce the clarity and intelligibility of recorded speech. This project will investigate and compare two traditional speech enhancement methods: Wiener filtering and spectral subtraction. Both methods will be applied to speech signals containing real recorded environmental noise to evaluate their ability to reduce noise while preserving the original speech.

## Project Objectives

* Download real clean speech and recorded noise samples from the Microsoft DNS Challenge dataset.
* Create test signals by mixing the downloaded clean speech and noise at controlled signal-to-noise ratio (SNR) levels.
* Implement Wiener filtering for speech noise reduction.
* Implement spectral subtraction for speech noise reduction.
* Compare the performance of the two methods using objective measurements and visual analysis.

## Proposed Methodology

A small selection of clean speech and recorded environmental noise samples will be downloaded from the Microsoft DNS Challenge dataset. AI-generated speech and self-recorded audio will not be used. The selected audio files will be converted to the same sampling rate, changed to mono where necessary and normalised before processing.

Noisy test signals will then be created by mixing the downloaded clean speech and noise samples at several controlled input SNR levels. Wiener filtering and spectral subtraction will be implemented separately in MATLAB. The original clean speech, noisy speech and enhanced speech produced by each method will then be compared.

## Data Source

The audio data will be obtained from the official Microsoft DNS Challenge dataset:

https://github.com/microsoft/DNS-Challenge

Only a small subset of appropriate clean speech and environmental noise recordings will be used to keep the project feasible.

## Evaluation

The two methods will be evaluated using:

* SNR improvement
* Waveform comparison
* Spectrogram comparison
* Mean squared error where appropriate
* Listening-based assessment of speech quality

## Expected Outcomes

The project is expected to demonstrate the strengths and limitations of both noise-reduction methods when applied to real recorded noise. Wiener filtering may provide smoother enhancement when the noise characteristics can be estimated accurately, while spectral subtraction may offer a simpler implementation but introduce musical noise.

## Software and Resources

* MATLAB
* GitHub
* Microsoft DNS Challenge dataset
* Audio and signal-processing tools

## Project Timeline

* **Weeks 1–3:** Background research and project planning
* **Weeks 4–5:** Download and prepare DNS Challenge audio samples
* **Weeks 6–7:** Implement spectral subtraction
* **Weeks 8–9:** Implement Wiener filtering
* **Weeks 10–11:** Conduct experiments and compare results
* **Weeks 12–13:** Complete the final report and project website

## Preliminary References

1. Boll, S. F. (1979). Suppression of acoustic noise in speech using spectral subtraction. *IEEE Transactions on Acoustics, Speech, and Signal Processing, 27*(2), 113–120.
2. Loizou, P. C. (2013). *Speech Enhancement: Theory and Practice* (2nd ed.). CRC Press.
3. Dubey, H., et al. (2023). ICASSP 2023 Deep Noise Suppression Challenge. *IEEE International Conference on Acoustics, Speech and Signal Processing*.
4. Scalart, P., and Filho, J. V. (1996). Speech enhancement based on a priori signal-to-noise estimation. *Proceedings of the IEEE International Conference on Acoustics, Speech, and Signal Processing, 2*, 629–632. https://doi.org/10.1109/ICASSP.1996.543199

## Project Proposal

The full project proposal is available here: [Download the Project Proposal PDF](ELEC5305_Project_Proposal_Zhizhong_Chen.pdf).

