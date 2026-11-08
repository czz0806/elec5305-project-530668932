%% ELEC5305 Final Project - Controlled Multi-condition Experiment
% Comparison of Wiener filtering and spectral subtraction for speech noise
% reduction.
%
% Student: Zhizhong Chen
% Student ID: 530668932
%
% This script evaluates both algorithms on eight aligned clean/noisy pairs
% from the Microsoft DNS Challenge. The noise residual from each pair is
% remixed with its clean utterance at -5, 0, 5 and 10 dB. Both algorithms
% use the same STFT and the same oracle noise-power estimate so that the
% experiment isolates differences between their spectral gain rules.
%
% Run this file from any folder in MATLAB R2024b. All tables, figures and
% listening examples are written to the project's results/final folder.

clear;
clc;
close all;
rng(530668932);

%% 1. Project folders
codeDirectory = fileparts(mfilename('fullpath'));
projectDirectory = fileparts(codeDirectory);
audioDirectory = fullfile(projectDirectory,'audio');
resultsDirectory = fullfile(projectDirectory,'results','final');
demoDirectory = fullfile(resultsDirectory,'audio_demo');

if ~isfolder(resultsDirectory)
    mkdir(resultsDirectory);
end
if ~isfolder(demoDirectory)
    mkdir(demoDirectory);
end

%% 2. DNS Challenge pairs used in the experiment
noiseLabels = ["Traffic";"Babble";"Wind";"Vacuum"; ...
    "Birds";"Bus";"Air conditioner";"Baby"];
fileIDs = [268;147;170;192;44;101;17;72];

cleanFiles = [ ...
    "clean_fileid_268.wav"; ...
    "clean_fileid_147.wav"; ...
    "clean_fileid_170.wav"; ...
    "clean_fileid_192.wav"; ...
    "clean_fileid_44.wav"; ...
    "clean_fileid_101.wav"; ...
    "clean_fileid_17.wav"; ...
    "clean_fileid_72.wav"];

noisyFiles = [ ...
    "clnsp102_traffic_248091_3_snr0_tl-21_fileid_268.wav"; ...
    "clnsp25_babble_188218_21_snr5_tl-25_fileid_147.wav"; ...
    "clnsp205_wind_407027_1_snr1_tl-24_fileid_170.wav"; ...
    "clnsp186_vacuum_353640_3_snr1_tl-27_fileid_192.wav"; ...
    "clnsp17_birds_413745_3_snr2_tl-23_fileid_44.wav"; ...
    "clnsp198_bus_56903_0_snr0_tl-32_fileid_101.wav"; ...
    "clnsp426_air_conditioner_151977_1_snr3_tl-35_fileid_17.wav"; ...
    "clnsp146_baby_416657_0_snr9_tl-25_fileid_72.wav"];

targetInputSNRs = [-5 0 5 10];

% Shared processing settings.
frameDuration = 0.032;       % 32 ms
overlapFraction = 0.50;     % 50 percent overlap
subtractionFactor = 1.0;
spectralFloor = 0.02;
wienerGainFloor = 0.05;

%% 3. Preallocate the detailed result table
numberOfPairs = numel(noiseLabels);
numberOfConditions = numberOfPairs*numel(targetInputSNRs);
numberOfRows = 3*numberOfConditions;

conditionID = strings(numberOfRows,1);
noiseType = strings(numberOfRows,1);
fileID = zeros(numberOfRows,1);
targetInputSNR_dB = zeros(numberOfRows,1);
measuredInputSNR_dB = zeros(numberOfRows,1);
method = strings(numberOfRows,1);
outputSNR_dB = zeros(numberOfRows,1);
snrImprovement_dB = zeros(numberOfRows,1);
segmentalSNR_dB = zeros(numberOfRows,1);
logSpectralDistance_dB = zeros(numberOfRows,1);

rowIndex = 0;
representativeAvailable = false;

%% 4. Run all 32 controlled test conditions
for pairIndex = 1:numberOfPairs
    cleanPath = fullfile(audioDirectory,cleanFiles(pairIndex));
    noisyPath = fullfile(audioDirectory,noisyFiles(pairIndex));

    assert(isfile(cleanPath),'Missing clean file: %s',cleanPath);
    assert(isfile(noisyPath),'Missing noisy file: %s',noisyPath);

    [cleanSpeech,fsClean] = audioread(cleanPath);
    [originalNoisy,fsNoisy] = audioread(noisyPath);
    cleanSpeech = localToMono(cleanSpeech);
    originalNoisy = localToMono(originalNoisy);

    assert(fsClean == fsNoisy,'Sample-rate mismatch for file ID %d.', ...
        fileIDs(pairIndex));
    fs = fsClean;
    signalLength = min(length(cleanSpeech),length(originalNoisy));
    cleanSpeech = cleanSpeech(1:signalLength);
    originalNoisy = originalNoisy(1:signalLength);

    cleanSpeech = cleanSpeech-mean(cleanSpeech);
    originalNoisy = originalNoisy-mean(originalNoisy);
    referenceNoise = originalNoisy-cleanSpeech;
    referenceNoise = referenceNoise-mean(referenceNoise);
    assert(sum(referenceNoise.^2) > eps,'Recovered noise is empty.');

    frameLength = round(frameDuration*fs);
    if mod(frameLength,2) ~= 0
        frameLength = frameLength+1;
    end
    hopLength = round(frameLength*(1-overlapFraction));
    nfft = frameLength;
    sampleIndex = (0:frameLength-1).';
    analysisWindow = 0.54-0.46*cos(2*pi*sampleIndex/frameLength);

    for snrIndex = 1:numel(targetInputSNRs)
        targetSNR = targetInputSNRs(snrIndex);
        [noisyTest,scaledNoise] = localMixAtSNR( ...
            cleanSpeech,referenceNoise,targetSNR);

        [cleanSTFT,numberOfFrames,paddedLength] = localSTFT( ...
            cleanSpeech,analysisWindow,hopLength,nfft);
        [noisySTFT,~,~] = localSTFT( ...
            noisyTest,analysisWindow,hopLength,nfft);
        [noiseSTFT,~,~] = localSTFT( ...
            scaledNoise,analysisWindow,hopLength,nfft);

        % Oracle noise PSD. It is shared by both methods to isolate the
        % effect of the two gain rules in this controlled benchmark.
        noisePower = mean(abs(noiseSTFT).^2,2);
        noisePowerMatrix = repmat(noisePower,1,numberOfFrames);
        noisyPower = abs(noisySTFT).^2;

        % Spectral subtraction.
        subtractedPower = noisyPower-subtractionFactor*noisePowerMatrix;
        subtractedPower = max(subtractedPower,spectralFloor*noisyPower);
        spectralSTFT = sqrt(subtractedPower).*exp(1j*angle(noisySTFT));
        spectralOutput = localISTFT(spectralSTFT,analysisWindow, ...
            hopLength,nfft,paddedLength,signalLength);

        % Wiener filter.
        estimatedSpeechPower = max(noisyPower-noisePowerMatrix,0);
        wienerGain = estimatedSpeechPower ./ ...
            (estimatedSpeechPower+noisePowerMatrix+eps);
        wienerGain = max(wienerGain,wienerGainFloor);
        wienerSTFT = wienerGain.*noisySTFT;
        wienerOutput = localISTFT(wienerSTFT,analysisWindow, ...
            hopLength,nfft,paddedLength,signalLength);

        measuredInputSNR = localSNR(cleanSpeech,noisyTest);
        testSignals = {noisyTest,spectralOutput,wienerOutput};
        methodNames = ["Noisy input";"Spectral subtraction";"Wiener filter"];

        for methodIndex = 1:numel(methodNames)
            rowIndex = rowIndex+1;
            currentSignal = testSignals{methodIndex};
            currentOutputSNR = localSNR(cleanSpeech,currentSignal);

            conditionID(rowIndex) = sprintf('%s_%+ddB', ...
                lower(strrep(noiseLabels(pairIndex),' ','_')),targetSNR);
            noiseType(rowIndex) = noiseLabels(pairIndex);
            fileID(rowIndex) = fileIDs(pairIndex);
            targetInputSNR_dB(rowIndex) = targetSNR;
            measuredInputSNR_dB(rowIndex) = measuredInputSNR;
            method(rowIndex) = methodNames(methodIndex);
            outputSNR_dB(rowIndex) = currentOutputSNR;
            snrImprovement_dB(rowIndex) = currentOutputSNR-measuredInputSNR;
            segmentalSNR_dB(rowIndex) = localSegmentalSNR( ...
                cleanSpeech,currentSignal,fs);
            logSpectralDistance_dB(rowIndex) = localLSD( ...
                cleanSpeech,currentSignal,fs);
        end

        % Save one representative 0 dB traffic example for figures/audio.
        if noiseLabels(pairIndex) == "Traffic" && targetSNR == 0
            representativeClean = cleanSpeech;
            representativeNoisy = noisyTest;
            representativeSpectral = spectralOutput;
            representativeWiener = wienerOutput;
            representativeFs = fs;
            representativeWindow = analysisWindow;
            representativeHop = hopLength;
            representativeNfft = nfft;
            representativeAvailable = true;
        end
    end

    fprintf('Completed %s noise (%d/%d).\n', ...
        noiseLabels(pairIndex),pairIndex,numberOfPairs);
end

resultsTable = table(conditionID,noiseType,fileID,targetInputSNR_dB, ...
    measuredInputSNR_dB,method,outputSNR_dB,snrImprovement_dB, ...
    segmentalSNR_dB,logSpectralDistance_dB);
writetable(resultsTable,fullfile(resultsDirectory,'final_metrics.csv'));

%% 5. Aggregate results by method and target input SNR
enhancementMethods = ["Spectral subtraction";"Wiener filter"];
summaryRows = numel(enhancementMethods)*numel(targetInputSNRs);
summaryMethod = strings(summaryRows,1);
summaryInputSNR_dB = zeros(summaryRows,1);
meanOutputSNR_dB = zeros(summaryRows,1);
meanSNRImprovement_dB = zeros(summaryRows,1);
stdSNRImprovement_dB = zeros(summaryRows,1);
meanSegmentalSNR_dB = zeros(summaryRows,1);
meanLogSpectralDistance_dB = zeros(summaryRows,1);

summaryIndex = 0;
for methodIndex = 1:numel(enhancementMethods)
    for snrIndex = 1:numel(targetInputSNRs)
        summaryIndex = summaryIndex+1;
        currentMethod = enhancementMethods(methodIndex);
        currentSNR = targetInputSNRs(snrIndex);
        selection = resultsTable.method == currentMethod & ...
            resultsTable.targetInputSNR_dB == currentSNR;

        summaryMethod(summaryIndex) = currentMethod;
        summaryInputSNR_dB(summaryIndex) = currentSNR;
        meanOutputSNR_dB(summaryIndex) = mean( ...
            resultsTable.outputSNR_dB(selection));
        meanSNRImprovement_dB(summaryIndex) = mean( ...
            resultsTable.snrImprovement_dB(selection));
        stdSNRImprovement_dB(summaryIndex) = std( ...
            resultsTable.snrImprovement_dB(selection));
        meanSegmentalSNR_dB(summaryIndex) = mean( ...
            resultsTable.segmentalSNR_dB(selection));
        meanLogSpectralDistance_dB(summaryIndex) = mean( ...
            resultsTable.logSpectralDistance_dB(selection));
    end
end

summaryTable = table(summaryMethod,summaryInputSNR_dB, ...
    meanOutputSNR_dB,meanSNRImprovement_dB,stdSNRImprovement_dB, ...
    meanSegmentalSNR_dB,meanLogSpectralDistance_dB);
writetable(summaryTable,fullfile(resultsDirectory,'final_summary.csv'));

%% 6. Figure: mean SNR improvement with between-noise variability
figureSNR = figure('Name','Mean SNR improvement','Color','w', ...
    'Position',[120 120 900 560]);
hold on;
plotColours = lines(2);
for methodIndex = 1:numel(enhancementMethods)
    selection = summaryTable.summaryMethod == enhancementMethods(methodIndex);
    errorbar(summaryTable.summaryInputSNR_dB(selection), ...
        summaryTable.meanSNRImprovement_dB(selection), ...
        summaryTable.stdSNRImprovement_dB(selection),'-o', ...
        'Color',plotColours(methodIndex,:),'LineWidth',1.8, ...
        'MarkerFaceColor',plotColours(methodIndex,:),'MarkerSize',7);
end
yline(0,'k--','LineWidth',1.0);
grid on;
xlabel('Target input SNR (dB)');
ylabel('Mean SNR improvement (dB)');
title('Speech enhancement across eight DNS noise conditions');
legend(enhancementMethods,'Location','best');
exportgraphics(figureSNR,fullfile(resultsDirectory, ...
    'mean_snr_improvement.png'),'Resolution',220);

%% 7. Figure: mean log-spectral distance
figureLSD = figure('Name','Mean log-spectral distance','Color','w', ...
    'Position',[150 140 900 560]);
hold on;
allMethods = ["Noisy input";enhancementMethods];
allColours = [0.35 0.35 0.35;lines(2)];
for methodIndex = 1:numel(allMethods)
    meanLSD = zeros(size(targetInputSNRs));
    for snrIndex = 1:numel(targetInputSNRs)
        selection = resultsTable.method == allMethods(methodIndex) & ...
            resultsTable.targetInputSNR_dB == targetInputSNRs(snrIndex);
        meanLSD(snrIndex) = mean( ...
            resultsTable.logSpectralDistance_dB(selection));
    end
    plot(targetInputSNRs,meanLSD,'-o','LineWidth',1.8, ...
        'Color',allColours(methodIndex,:), ...
        'MarkerFaceColor',allColours(methodIndex,:),'MarkerSize',7);
end
grid on;
xlabel('Target input SNR (dB)');
ylabel('Mean log-spectral distance (dB)');
title('Spectral distortion relative to clean speech (lower is better)');
legend(allMethods,'Location','best');
exportgraphics(figureLSD,fullfile(resultsDirectory, ...
    'mean_log_spectral_distance.png'),'Resolution',220);

%% 8. Figure: noise-type heatmaps
figureHeatmap = figure('Name','SNR improvement heatmaps','Color','w', ...
    'Position',[100 80 1120 680]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
heatLimits = [-2 12];
for methodIndex = 1:numel(enhancementMethods)
    heatData = zeros(numberOfPairs,numel(targetInputSNRs));
    for pairIndex = 1:numberOfPairs
        for snrIndex = 1:numel(targetInputSNRs)
            selection = resultsTable.method == enhancementMethods(methodIndex) & ...
                resultsTable.noiseType == noiseLabels(pairIndex) & ...
                resultsTable.targetInputSNR_dB == targetInputSNRs(snrIndex);
            heatData(pairIndex,snrIndex) = ...
                resultsTable.snrImprovement_dB(selection);
        end
    end
    nexttile;
    imagesc(targetInputSNRs,1:numberOfPairs,heatData);
    axis xy;
    caxis(heatLimits);
    xticks(targetInputSNRs);
    yticks(1:numberOfPairs);
    yticklabels(noiseLabels);
    xlabel('Target input SNR (dB)');
    ylabel('DNS noise type');
    title(enhancementMethods(methodIndex));
    colorbar;
end
colormap turbo;
sgtitle('SNR improvement by method and test condition (dB)');
exportgraphics(figureHeatmap,fullfile(resultsDirectory, ...
    'snr_improvement_heatmaps.png'),'Resolution',220);

%% 9. Representative 0 dB traffic spectrograms and audio
assert(representativeAvailable,'Representative traffic condition was not saved.');
representativeSignals = {representativeClean,representativeNoisy, ...
    representativeSpectral,representativeWiener};
representativeTitles = ["Clean reference";"Noisy speech (0 dB)"; ...
    "Spectral subtraction";"Wiener filter"];

[noisySpectrum,~,~] = localSTFT(representativeNoisy, ...
    representativeWindow,representativeHop,representativeNfft);
commonReference = max(abs(noisySpectrum(:)))+eps;

figureSpectrogram = figure('Name','Representative spectrograms', ...
    'Color','w','Position',[100 70 1150 820]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for signalIndex = 1:numel(representativeSignals)
    [plotTime,plotFrequency,plotDB] = localSpectrogramDB( ...
        representativeSignals{signalIndex},representativeFs, ...
        representativeWindow,representativeHop,representativeNfft, ...
        commonReference);
    nexttile;
    imagesc(plotTime,plotFrequency,plotDB);
    axis xy;
    ylim([0 8000]);
    caxis([-80 0]);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(representativeTitles(signalIndex));
end
colormap turbo;
colorbar;
sgtitle('Representative DNS traffic-noise condition at 0 dB input SNR');
exportgraphics(figureSpectrogram,fullfile(resultsDirectory, ...
    'representative_spectrograms.png'),'Resolution',220);

sharedPeak = max(abs(vertcat(representativeSignals{:})));
sharedScale = min(1,0.99/(sharedPeak+eps));
audiowrite(fullfile(demoDirectory,'clean_reference.wav'), ...
    representativeClean*sharedScale,representativeFs);
audiowrite(fullfile(demoDirectory,'noisy_traffic_0dB.wav'), ...
    representativeNoisy*sharedScale,representativeFs);
audiowrite(fullfile(demoDirectory,'spectral_subtraction_traffic_0dB.wav'), ...
    representativeSpectral*sharedScale,representativeFs);
audiowrite(fullfile(demoDirectory,'wiener_filter_traffic_0dB.wav'), ...
    representativeWiener*sharedScale,representativeFs);

%% 10. Text summary for the README and report
spectralRows = resultsTable.method == "Spectral subtraction";
wienerRows = resultsTable.method == "Wiener filter";
overallSpectralImprovement = mean( ...
    resultsTable.snrImprovement_dB(spectralRows));
overallWienerImprovement = mean( ...
    resultsTable.snrImprovement_dB(wienerRows));
overallSpectralLSD = mean( ...
    resultsTable.logSpectralDistance_dB(spectralRows));
overallWienerLSD = mean( ...
    resultsTable.logSpectralDistance_dB(wienerRows));

spectralImprovementValues = resultsTable.snrImprovement_dB(spectralRows);
wienerImprovementValues = resultsTable.snrImprovement_dB(wienerRows);
wienerWinCount = sum(wienerImprovementValues > spectralImprovementValues);
spectralWinCount = sum(spectralImprovementValues > wienerImprovementValues);

summaryPath = fullfile(resultsDirectory,'final_summary.txt');
summaryFile = fopen(summaryPath,'w');
assert(summaryFile >= 0,'Could not open final_summary.txt for writing.');
fprintf(summaryFile,'ELEC5305 Final Project - Controlled Benchmark\n');
fprintf(summaryFile,'Student: Zhizhong Chen (530668932)\n\n');
fprintf(summaryFile,'Test design: 8 DNS noise conditions x 4 target SNRs = 32 cases\n');
fprintf(summaryFile,'Input SNRs: -5, 0, 5 and 10 dB\n');
fprintf(summaryFile,'STFT: 32 ms periodic Hamming window, 50 percent overlap\n\n');
fprintf(summaryFile,'Overall mean SNR improvement\n');
fprintf(summaryFile,'  Spectral subtraction: %.3f dB\n',overallSpectralImprovement);
fprintf(summaryFile,'  Wiener filtering:     %.3f dB\n\n',overallWienerImprovement);
fprintf(summaryFile,'Overall mean log-spectral distance (lower is better)\n');
fprintf(summaryFile,'  Spectral subtraction: %.3f dB\n',overallSpectralLSD);
fprintf(summaryFile,'  Wiener filtering:     %.3f dB\n\n',overallWienerLSD);
fprintf(summaryFile,'Condition wins by SNR improvement\n');
fprintf(summaryFile,'  Wiener filtering:     %d of %d\n', ...
    wienerWinCount,numberOfConditions);
fprintf(summaryFile,'  Spectral subtraction: %d of %d\n', ...
    spectralWinCount,numberOfConditions);
fprintf(summaryFile,'  Ties:                 %d of %d\n\n', ...
    numberOfConditions-wienerWinCount-spectralWinCount,numberOfConditions);
fprintf(summaryFile,'Important limitation: both methods use the same oracle noise PSD\n');
fprintf(summaryFile,'estimated from the aligned DNS noise residual. This controlled\n');
fprintf(summaryFile,'benchmark isolates the gain-rule comparison but is not a causal\n');
fprintf(summaryFile,'real-time speech-enhancement system.\n');
fclose(summaryFile);

disp(summaryTable);
fprintf('\nFinal experiment completed successfully.\n');
fprintf('Results were saved in:\n%s\n',resultsDirectory);

%% Local functions
function monoSignal = localToMono(inputSignal)
if size(inputSignal,2) > 1
    monoSignal = mean(inputSignal,2);
else
    monoSignal = inputSignal;
end
monoSignal = monoSignal(:);
end

function [mixedSignal,scaledNoise] = localMixAtSNR(cleanSignal,noiseSignal,targetSNR)
cleanEnergy = sum(cleanSignal.^2);
noiseEnergy = sum(noiseSignal.^2);
scale = sqrt(cleanEnergy/(noiseEnergy*10^(targetSNR/10)+eps));
scaledNoise = scale*noiseSignal;
mixedSignal = cleanSignal+scaledNoise;
end

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

function segmentalValue = localSegmentalSNR(referenceSignal,testSignal,fs)
frameLength = round(0.020*fs);
hopLength = round(frameLength/2);
numberOfFrames = max(1,floor((length(referenceSignal)-frameLength)/hopLength)+1);
referenceEnergy = zeros(numberOfFrames,1);
frameScores = zeros(numberOfFrames,1);

for frameIndex = 1:numberOfFrames
    firstSample = (frameIndex-1)*hopLength+1;
    sampleRange = firstSample:firstSample+frameLength-1;
    referenceFrame = referenceSignal(sampleRange);
    testFrame = testSignal(sampleRange);
    referenceEnergy(frameIndex) = sum(referenceFrame.^2);
    frameScore = 10*log10(referenceEnergy(frameIndex) / ...
        (sum((referenceFrame-testFrame).^2)+eps));
    frameScores(frameIndex) = min(35,max(-10,frameScore));
end

activeFrames = referenceEnergy > max(referenceEnergy)*1e-4;
if any(activeFrames)
    segmentalValue = mean(frameScores(activeFrames));
else
    segmentalValue = mean(frameScores);
end
end

function lsdValue = localLSD(referenceSignal,testSignal,fs)
frameLength = round(0.032*fs);
if mod(frameLength,2) ~= 0
    frameLength = frameLength+1;
end
hopLength = frameLength/2;
nfft = frameLength;
sampleIndex = (0:frameLength-1).';
window = 0.54-0.46*cos(2*pi*sampleIndex/frameLength);

[referenceSTFT,~,~] = localSTFT(referenceSignal,window,hopLength,nfft);
[testSTFT,~,~] = localSTFT(testSignal,window,hopLength,nfft);
positiveBins = 1:(nfft/2+1);
referenceMagnitude = abs(referenceSTFT(positiveBins,:));
testMagnitude = abs(testSTFT(positiveBins,:));

referenceMaximum = max(referenceMagnitude(:))+eps;
magnitudeFloor = referenceMaximum*10^(-80/20);
referenceDB = 20*log10(max(referenceMagnitude,magnitudeFloor));
testDB = 20*log10(max(testMagnitude,magnitudeFloor));
frameEnergy = sum(referenceMagnitude.^2,1);
activeFrames = frameEnergy > max(frameEnergy)*1e-4;

frameLSD = sqrt(mean((referenceDB(:,activeFrames)- ...
    testDB(:,activeFrames)).^2,1));
lsdValue = mean(frameLSD);
end

function [timeAxis,frequencyAxis,magnitudeDB] = localSpectrogramDB( ...
    signal,fs,window,hopLength,nfft,referenceMagnitude)
[spectrum,numberOfFrames,~] = localSTFT(signal,window,hopLength,nfft);
positiveBins = 1:(nfft/2+1);
frequencyAxis = (positiveBins-1).'*fs/nfft;
timeAxis = ((0:numberOfFrames-1)*hopLength+length(window)/2)/fs;
magnitudeDB = 20*log10(abs(spectrum(positiveBins,:))/ ...
    referenceMagnitude+eps);
end
