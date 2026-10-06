%% ELEC5305 Project Feedback Two - Preliminary Prototype
% Comparison of Wiener filtering and spectral subtraction for speech noise reduction
% Student: Zhizhong Chen | Student ID: 530668932
%
% This script uses one aligned clean/noisy pair from the official Microsoft
% DNS Challenge INTERSPEECH 2020 test set. The noisy file contains traffic
% noise at an input SNR of 0 dB. This is a preliminary verification using
% the known clean reference; the final project will use more files, noise
% types and input SNR values.

clear;
clc;
close all;

%% 1. Locate the project folders and input files
codeDirectory = fileparts(mfilename('fullpath'));
projectDirectory = fileparts(codeDirectory);
audioDirectory = fullfile(projectDirectory,'audio');
resultsDirectory = fullfile(projectDirectory,'results');

if ~isfolder(resultsDirectory)
    mkdir(resultsDirectory);
end

cleanFile = fullfile(audioDirectory,'clean_fileid_268.wav');
noisyFile = fullfile(audioDirectory, ...
    'clnsp102_traffic_248091_3_snr0_tl-21_fileid_268.wav');

assert(isfile(cleanFile), ...
    'Clean audio was not found. Put clean_fileid_268.wav in the audio folder.');
assert(isfile(noisyFile), ...
    'Noisy audio was not found. Put the DNS traffic-noise WAV in the audio folder.');

%% 2. Read and verify the aligned audio pair
[cleanSpeech,fsClean] = audioread(cleanFile);
[noisySpeech,fsNoisy] = audioread(noisyFile);

if size(cleanSpeech,2) > 1
    cleanSpeech = mean(cleanSpeech,2);
end
if size(noisySpeech,2) > 1
    noisySpeech = mean(noisySpeech,2);
end

assert(fsClean == fsNoisy,'The two input files must have the same sample rate.');
fs = fsClean;
signalLength = min(length(cleanSpeech),length(noisySpeech));
cleanSpeech = cleanSpeech(1:signalLength);
noisySpeech = noisySpeech(1:signalLength);

% Because this preliminary DNS test pair is aligned, the added noise can be
% recovered for controlled algorithm verification.
referenceNoise = noisySpeech - cleanSpeech;

%% 3. Common STFT settings for both enhancement methods
frameLength = round(0.032*fs);       % 32 ms at 16 kHz gives 512 samples
hopLength = frameLength/2;           % 50 percent overlap
nfft = frameLength;

assert(mod(frameLength,2) == 0,'The frame length must be even.');

% Periodic Hamming window, written explicitly to avoid extra dependencies.
sampleIndex = (0:frameLength-1).';
analysisWindow = 0.54 - 0.46*cos(2*pi*sampleIndex/frameLength);

[cleanSTFT,numberOfFrames,paddedLength] = localSTFT( ...
    cleanSpeech,analysisWindow,hopLength,nfft);
[noisySTFT,~,~] = localSTFT( ...
    noisySpeech,analysisWindow,hopLength,nfft);
[noiseSTFT,~,~] = localSTFT( ...
    referenceNoise,analysisWindow,hopLength,nfft);

% One frequency-dependent noise-power estimate shared by both methods.
noisePower = mean(abs(noiseSTFT).^2,2);
noisePowerMatrix = repmat(noisePower,1,numberOfFrames);
noisyPower = abs(noisySTFT).^2;

%% 4. Spectral subtraction
subtractionFactor = 1.0;
spectralFloor = 0.02;

subtractedPower = noisyPower - subtractionFactor*noisePowerMatrix;
subtractedPower = max(subtractedPower,spectralFloor*noisyPower);
spectralSubtractionSTFT = sqrt(subtractedPower).*exp(1j*angle(noisySTFT));

spectralSubtractionOutput = localISTFT( ...
    spectralSubtractionSTFT,analysisWindow,hopLength,nfft, ...
    paddedLength,signalLength);

%% 5. Wiener filtering
estimatedSpeechPower = max(noisyPower-noisePowerMatrix,0);
wienerGain = estimatedSpeechPower ./ ...
    (estimatedSpeechPower+noisePowerMatrix+eps);
wienerGainFloor = 0.05;
wienerGain = max(wienerGain,wienerGainFloor);
wienerSTFT = wienerGain.*noisySTFT;

wienerOutput = localISTFT( ...
    wienerSTFT,analysisWindow,hopLength,nfft, ...
    paddedLength,signalLength);

%% 6. Calculate preliminary objective results
inputSNR = localSNR(cleanSpeech,noisySpeech);
spectralSubtractionSNR = localSNR(cleanSpeech,spectralSubtractionOutput);
wienerSNR = localSNR(cleanSpeech,wienerOutput);

spectralSubtractionImprovement = spectralSubtractionSNR-inputSNR;
wienerImprovement = wienerSNR-inputSNR;

method = ["Noisy input";"Spectral subtraction";"Wiener filter"];
outputSNR_dB = [inputSNR;spectralSubtractionSNR;wienerSNR];
snrImprovement_dB = [0;spectralSubtractionImprovement;wienerImprovement];
resultsTable = table(method,outputSNR_dB,snrImprovement_dB);

disp(resultsTable);
writetable(resultsTable,fullfile(resultsDirectory,'preliminary_metrics.csv'));

%% 7. Save enhanced audio
audiowrite(fullfile(resultsDirectory,'spectral_subtraction_output.wav'), ...
    localPreventClipping(spectralSubtractionOutput),fs);
audiowrite(fullfile(resultsDirectory,'wiener_filter_output.wav'), ...
    localPreventClipping(wienerOutput),fs);

%% 8. Plot waveforms
time = (0:signalLength-1).'/fs;
waveformFigure = figure('Name','Waveform comparison','Color','w', ...
    'Position',[100 100 1100 760]);
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(time,cleanSpeech,'Color',[0.10 0.45 0.75]);
grid on;
ylabel('Amplitude');
title('Clean reference');

nexttile;
plot(time,noisySpeech,'Color',[0.45 0.45 0.45]);
grid on;
ylabel('Amplitude');
title(sprintf('Noisy speech: input SNR = %.2f dB',inputSNR));

nexttile;
plot(time,spectralSubtractionOutput,'Color',[0.85 0.33 0.10]);
grid on;
ylabel('Amplitude');
title(sprintf('Spectral subtraction: output SNR = %.2f dB', ...
    spectralSubtractionSNR));

nexttile;
plot(time,wienerOutput,'Color',[0.47 0.67 0.19]);
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Wiener filter: output SNR = %.2f dB',wienerSNR));

exportgraphics(waveformFigure, ...
    fullfile(resultsDirectory,'waveform_comparison.png'),'Resolution',200);

%% 9. Plot spectrograms using a common colour reference
[spectralSubtractionPlotSTFT,~,~] = localSTFT( ...
    spectralSubtractionOutput,analysisWindow,hopLength,nfft);
[wienerPlotSTFT,~,~] = localSTFT( ...
    wienerOutput,analysisWindow,hopLength,nfft);

positiveBins = 1:(nfft/2+1);
frequencyAxis = (positiveBins-1).'*fs/nfft;
frameTimeAxis = ((0:numberOfFrames-1)*hopLength+frameLength/2)/fs;
commonReference = max(abs(noisySTFT(:)))+eps;

cleanDB = 20*log10(abs(cleanSTFT(positiveBins,:))/commonReference+eps);
noisyDB = 20*log10(abs(noisySTFT(positiveBins,:))/commonReference+eps);
spectralSubtractionDB = 20*log10( ...
    abs(spectralSubtractionPlotSTFT(positiveBins,:))/commonReference+eps);
wienerDB = 20*log10( ...
    abs(wienerPlotSTFT(positiveBins,:))/commonReference+eps);

spectrogramFigure = figure('Name','Spectrogram comparison','Color','w', ...
    'Position',[120 80 1150 820]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

localPlotSpectrogram(frameTimeAxis,frequencyAxis,cleanDB,'Clean reference');
localPlotSpectrogram(frameTimeAxis,frequencyAxis,noisyDB,'Noisy speech');
localPlotSpectrogram(frameTimeAxis,frequencyAxis,spectralSubtractionDB, ...
    'Spectral subtraction');
localPlotSpectrogram(frameTimeAxis,frequencyAxis,wienerDB,'Wiener filter');

colormap turbo;
colorbar;
exportgraphics(spectrogramFigure, ...
    fullfile(resultsDirectory,'spectrogram_comparison.png'),'Resolution',200);

%% 10. Plot the preliminary SNR comparison
snrFigure = figure('Name','Preliminary SNR comparison','Color','w', ...
    'Position',[160 140 850 520]);
bar(outputSNR_dB,0.65,'FaceColor',[0.20 0.50 0.75]);
xticks(1:numel(method));
xticklabels(method);
grid on;
ylabel('SNR (dB)');
title('Preliminary result: one DNS traffic-noise pair');
for index = 1:numel(outputSNR_dB)
    text(index,outputSNR_dB(index)+0.12,sprintf('%.2f dB',outputSNR_dB(index)), ...
        'HorizontalAlignment','center','FontWeight','bold');
end
exportgraphics(snrFigure, ...
    fullfile(resultsDirectory,'snr_comparison.png'),'Resolution',200);

%% 11. Save a concise text summary
summaryFile = fullfile(resultsDirectory,'preliminary_summary.txt');
fileID = fopen(summaryFile,'w');
fprintf(fileID,'ELEC5305 Project Feedback Two - Preliminary Results\n');
fprintf(fileID,'Input: Microsoft DNS Challenge traffic-noise pair, file ID 268\n');
fprintf(fileID,'Sample rate: %d Hz\n',fs);
fprintf(fileID,'Duration: %.2f seconds\n',signalLength/fs);
fprintf(fileID,'Frame length: %d samples (%.1f ms)\n', ...
    frameLength,1000*frameLength/fs);
fprintf(fileID,'Hop length: %d samples (50 percent overlap)\n\n',hopLength);
fprintf(fileID,'Input SNR: %.3f dB\n',inputSNR);
fprintf(fileID,'Spectral-subtraction output SNR: %.3f dB\n', ...
    spectralSubtractionSNR);
fprintf(fileID,'Spectral-subtraction SNR improvement: %.3f dB\n', ...
    spectralSubtractionImprovement);
fprintf(fileID,'Wiener-filter output SNR: %.3f dB\n',wienerSNR);
fprintf(fileID,'Wiener-filter SNR improvement: %.3f dB\n\n', ...
    wienerImprovement);
fprintf(fileID,'Limitation: this preliminary prototype uses one aligned pair and\n');
fprintf(fileID,'the known reference noise to verify both implementations. The final\n');
fprintf(fileID,'project will test more utterances, noise types and input SNR values.\n');
fclose(fileID);

fprintf('\nFinished successfully. Results were saved in:\n%s\n',resultsDirectory);

%% Local functions
function [spectrum,numberOfFrames,paddedLength] = localSTFT( ...
    signal,window,hopLength,nfft)

signal = signal(:);
frameLength = length(window);
numberOfFrames = max(1,ceil(max(0,length(signal)-frameLength)/hopLength)+1);
paddedLength = (numberOfFrames-1)*hopLength+frameLength;
signal = [signal;zeros(paddedLength-length(signal),1)];
spectrum = zeros(nfft,numberOfFrames);

for frameIndex = 1:numberOfFrames
    firstSample = (frameIndex-1)*hopLength+1;
    sampleRange = firstSample:firstSample+frameLength-1;
    frame = signal(sampleRange).*window;
    spectrum(:,frameIndex) = fft(frame,nfft);
end
end

function signal = localISTFT(spectrum,window,hopLength,nfft, ...
    paddedLength,originalLength)

frameLength = length(window);
numberOfFrames = size(spectrum,2);
signal = zeros(paddedLength,1);
windowNormalisation = zeros(paddedLength,1);

for frameIndex = 1:numberOfFrames
    firstSample = (frameIndex-1)*hopLength+1;
    sampleRange = firstSample:firstSample+frameLength-1;
    frame = real(ifft(spectrum(:,frameIndex),nfft));
    frame = frame(1:frameLength).*window;
    signal(sampleRange) = signal(sampleRange)+frame;
    windowNormalisation(sampleRange) = ...
        windowNormalisation(sampleRange)+window.^2;
end

signal = signal./max(windowNormalisation,eps);
signal = signal(1:originalLength);
end

function snrValue = localSNR(referenceSignal,testSignal)
errorSignal = referenceSignal-testSignal;
snrValue = 10*log10(sum(referenceSignal.^2)/(sum(errorSignal.^2)+eps));
end

function signal = localPreventClipping(signal)
peak = max(abs(signal));
if peak > 0.99
    signal = 0.99*signal/peak;
end
end

function localPlotSpectrogram(timeAxis,frequencyAxis,magnitudeDB,plotTitle)
nexttile;
imagesc(timeAxis,frequencyAxis,magnitudeDB);
axis xy;
ylim([0 8000]);
caxis([-80 0]);
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title(plotTitle);
end
