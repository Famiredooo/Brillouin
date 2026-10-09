%% DSOS404A: records 4 and 6 = With control; record 5 = Without control
% CSV columns: time (s), green trace (V), blue trace (V).
% Keep each file's own time vector; no interpolation or normalization.
% Peaks are sampled global maxima within xRange, not fitted pulse centers.

dataFolder = uigetdir(pwd, 'Select the folder containing the CSV files');
if isequal(dataFolder, 0), return; end
xRange = [-200 40];                         % ns
saveResults = true;

% Numbering follows the previous six-panel figure, NOT directory order.
fileNames = ["lp119.32ghza.csv"; ...         % record 4
             "lp119.32ghz.csv"; ...          % record 5
             "lp1118b1129.32ghz.csv"];       % record 6
recordID = [4; 5; 6];
condition = ["With control"; "Without control"; "With control"];
planeLabels = compose('%d | %s', recordID, condition);
traceNames = ["Green (CSV column 2)", "Blue (CSV column 3)"];
colors = [0.23 0.69 0.21; 0.15 0.54 0.91];
nFiles = numel(fileNames);
D = struct([]);
peakTime = nan(nFiles, 2);
peakVoltage = nan(nFiles, 2);

%% Load each file ONCE
for k = 1:nFiles
    filePath = fullfile(dataFolder, fileNames(k));
    assert(isfile(filePath), 'File not found: %s', filePath);
    A = readmatrix(filePath, 'Delimiter', ',');
    assert(size(A,2) == 3, ...
        'Expected time + two voltage columns in %s.', fileNames(k));
    A(all(isnan(A),2), :) = [];              % ignore blank/header-only rows
    assert(~isempty(A) && all(isfinite(A(:))), ...
        'Empty or non-finite numeric data in %s.', fileNames(k));
    assert(all(diff(A(:,1)) > 0), ...
        'Time must increase strictly in %s.', fileNames(k));
    D(k).file = fileNames(k);
    D(k).condition = condition(k);
    D(k).time_ns = A(:,1) * 1e9;
    D(k).voltage_mV = A(:,2:3) * 1e3;        % retain raw DC baselines
    mask = D(k).time_ns >= xRange(1) & D(k).time_ns <= xRange(2);
    assert(any(mask), 'No samples inside xRange in %s.', fileNames(k));
    visibleRows = find(mask);
    for ch = 1:2
        [peakVoltage(k,ch), idx] = max(D(k).voltage_mV(mask,ch));
        peakTime(k,ch) = D(k).time_ns(visibleRows(idx));
    end
end

%% Shared voltage limits
allV = vertcat(D.voltage_mV);
vMin = min(allV(:)); vMax = max(allV(:));
vPad = 0.12 * max(vMax-vMin, 1);
vRange = [vMin-vPad, vMax+vPad];

%% Figure 1: three time-voltage planes stacked in 3D
fig3D = figure('Color','w','Position',[80 80 1250 760]);
ax3 = axes(fig3D); hold(ax3,'on');
h3 = gobjects(1,2);
for k = 1:nFiles
    t = D(k).time_ns;
    for ch = 1:2
        h = plot3(ax3, t, k*ones(size(t)), D(k).voltage_mV(:,ch), ...
            'Color',colors(ch,:), 'LineWidth',1.2);
        if k == 1, h3(ch) = h; end
        plot3(ax3,peakTime(k,ch),k,peakVoltage(k,ch),'o', ...
            'Color',colors(ch,:),'MarkerFaceColor',colors(ch,:), ...
            'HandleVisibility','off');
        text(ax3,peakTime(k,ch)+2,k,peakVoltage(k,ch)+vPad*0.25, ...
            sprintf('%.3f ns',peakTime(k,ch)), ...
            'Color',colors(ch,:),'FontSize',10);
    end
end
xlim(ax3,xRange); ylim(ax3,[0.6 nFiles+0.4]); zlim(ax3,vRange);
xticks(ax3,-200:40:40); yticks(ax3,1:nFiles); yticklabels(ax3,planeLabels);
xlabel(ax3,'Time (ns)'); ylabel(ax3,'Record / condition');
zlabel(ax3,'Voltage (mV)');
title(ax3,'With control / Without control');
legend(ax3,h3,traceNames,'Location','northeastoutside');
grid(ax3,'on'); box(ax3,'on'); view(ax3,[-60 25]);
pbaspect(ax3,[2 1.3 1]); set(ax3,'FontSize',11);
rotate3d(fig3D,'on');

%% Figure 2: one 2D subplot per file
fig2D = figure('Color','w','Position',[140 60 1150 900]);
tl = tiledlayout(fig2D,3,1,'TileSpacing','compact','Padding','compact');
ax2 = gobjects(nFiles,1);
for k = 1:nFiles
    ax2(k) = nexttile(tl); hold(ax2(k),'on');
    h2 = gobjects(1,2);
    for ch = 1:2
        h2(ch) = plot(ax2(k),D(k).time_ns,D(k).voltage_mV(:,ch), ...
            'Color',colors(ch,:),'LineWidth',1.2);
        plot(ax2(k),peakTime(k,ch),peakVoltage(k,ch),'o', ...
            'Color',colors(ch,:),'MarkerFaceColor',colors(ch,:), ...
            'HandleVisibility','off');
        text(ax2(k),peakTime(k,ch)+2,peakVoltage(k,ch)+vPad*0.25, ...
            sprintf('%.3f ns | %.3f mV',peakTime(k,ch),peakVoltage(k,ch)), ...
            'Color',colors(ch,:),'FontSize',10, ...
            'VerticalAlignment','bottom','BackgroundColor','w','Margin',1);
    end
    title(ax2(k),sprintf('%d | %s | %s',recordID(k),condition(k),fileNames(k)), ...
        'Interpreter','none');
    xlim(ax2(k),xRange); ylim(ax2(k),vRange); xticks(ax2(k),-200:40:40);
    ylabel(ax2(k),'Voltage (mV)'); grid(ax2(k),'on'); box(ax2(k),'on');
    set(ax2(k),'FontSize',11);
    if k == 1, legend(ax2(k),h2,traceNames,'Location','northeast'); end
end
xlabel(tl,'Time (ns)'); linkaxes(ax2,'xy');

%% Peak table and optional export
% For a nearly flat trace, its maximum can be noise rather than a pulse peak.
peakTable = table(recordID,fileNames,condition, ...
    peakTime(:,1),peakVoltage(:,1),peakTime(:,2),peakVoltage(:,2), ...
    'VariableNames',{'Record','File','Condition','GreenPeakTime_ns', ...
    'GreenPeak_mV','BluePeakTime_ns','BluePeak_mV'});
disp(peakTable);
if saveResults
    outFolder = fullfile(dataFolder,'control_comparison_output');
    if ~isfolder(outFolder), mkdir(outFolder); end
    exportgraphics(fig3D,fullfile(outFolder,'control_3D.png'),'Resolution',300);
    exportgraphics(fig2D,fullfile(outFolder,'control_2D.png'),'Resolution',300);
    savefig(fig3D,fullfile(outFolder,'control_3D.fig'));
    savefig(fig2D,fullfile(outFolder,'control_2D.fig'));
    writetable(peakTable,fullfile(outFolder,'peak_positions.csv'));
    save(fullfile(outFolder,'loaded_traces.mat'), ...
        'D','peakTable','xRange','recordID','condition');
    fprintf('Saved results to: %s\n',outFolder);
end
