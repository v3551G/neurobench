function benchdata = benchmark_plot(varargin)
%BENCHMARK_PLOT Display optimization benchmark results.
%
%   BENCHMARK_PLOT(PROBSET,PROB,SUBPROB,NOISE,ALGO,ALGOSET,ORDER) 
%   factorially plots optimization benchmark results for the following 
%   factors: problem set PROBSET, problem(s) PROB, subproblem(s) SUBPROB, 
%   noise level NOISE, algorithm(s) ALGO, algorithm setting(s) ALGOSET. 
%   PROBSET, PROB, SUBPROB, NOISE, ALGO, and ALGOSET can be strings or cell 
%   arrays of strings. ORDER is a cell array of string such that: ORDER{1} 
%   is the factor expanded across rows, ORDER{2} is the factor expanded 
%   across columns, and ORDER{3} (if present) is the factor expanded across
%   figures. Unassigned factors are plotted in the same panel. The factors
%   are 'probset', 'prob', 'subprob', 'noise', 'algo', and 'algoset'.
%
%   BENCHMARK_PLOT(PROBSET,PROB,SUBPROB,NOISE,ALGO,ALGOSET,ORDER,BESTOUTOF) 
%   plots an estimate of the 'minimum out of BESTOUTOF runs'. By default
%   BESTOUTOF is 1.
%
%   Example
%      A typical usage of BENCHMARK_PLOT:
%         benchmark_plot('ccn15',{'trevor_unimodal','trevor_bimodal'},...
%         {'S1','S3','S6','S9','S12'},[],{'fminseach','fmincon'},'base',{'prob','subprob'})
%      plots 'trevor_unimodal' benchmark on the first row and 
%      'trevor_bimodal' on the second row, each column is a different 
%      subject in {'S1','S3','S6','S9','S12'}, and each panel compares 
%      'fminsearch' and 'fmincon'.
%
%   See also BENCHMARK_RUN.

% Luigi Acerbi 2016

% Base options
defopts.BestOutOf = 1;
defopts.ErrorBar = [];
defopts.NumZero = 1e-8;
defopts.Method = 'IR';          % Immediate regret (IR) or fraction solved (FS)
defopts.SolveThreshold = 1e-6;  
defopts.FileName = ['.' filesep 'benchdata.mat'];
defopts.Noisy = [];
defopts.Nsamp = 5e3;            % Samples for ERT computation
defopts.TwoRows = 0;
defopts.EnhanceLine = 'last';   % Enhance one plotted line
defopts.UnknownMin = false;     % Force minimum being unknown
defopts.BadLogLikelihood = 5e3; % Arbitrary score for bad log likelihood
defopts.FunEvalsPerD = 500;

% Plotting options
defopts.YlimMax = 1e3;
defopts.AbsolutePlot = 0;
defopts.DisplayFval = 0;

StatMismatch = 0;

defaults = benchmark_defaults('options');
linstyle = defaults.LineStyle;
lincol = defaults.LineColor;

if isstruct(varargin{end}); options = varargin{end}; else options = []; end

% Assign default values to OPTIONS struct
for f = fieldnames(defopts)'
    if ~isfield(options,f{:}) || isempty(options.(f{:}))
        options.(f{:}) = defopts.(f{:});
    end
end

BestOutOf = options.BestOutOf;
NumZero = options.NumZero;

labels = {'probset','prob','subprob','noise','algo','algoset'};
for i = 1:length(labels); varargin{i} = cellify(varargin{i}); end

% Check if noisy optimization
% if isempty(options.Noisy)
%     options.Noisy = ~isempty(varargin{4});
% end
% if ~isempty(varargin{4}) && ~options.Noisy
%     warning('NOISE is empty but OPTIONS.Noisy is set to 0.');
%     pause(1);
% end

% linstyle = {'k-','b-','r-','g-','m:','r:','c:','g:','k-.','r-.'};

order = varargin{7};

% Find out what to plot on rows, columns and figures
dimrows = order{1};
if ischar(dimrows); dimrows = find(strcmp(labels,dimrows),1); end
nrows = numel(varargin{dimrows});

dimcols = order{2};
if ischar(dimcols); dimcols = find(strcmp(labels,dimcols),1); end
ncols = numel(varargin{dimcols});

if length(order) > 2
    dimfig = order{3};
    if ischar(dimfig); dimfig = find(strcmp(labels,dimfig),1); end
    nfigs = numel(varargin{dimfig});
else
    nfigs = 1;
    dimfig = [];
end

for i = 1:numel(labels); benchlist{i} = []; end

dimlayers = [];

% Load data from file
data = [];
try
    if exist(options.FileName,'file') == 2
        load(options.FileName,'data');
        fprintf('Loaded stored data from file.\n');
        LoadedData_flag = true;
    end
catch
    % Did not work
end
if isempty(data)
    fprintf('Stored data file does not exist. Loading raw data...\n');
    LoadedData_flag = false;
end

% Loop over figures
for iFig = 1:nfigs
    if nfigs > 1; benchlist{dimfig} = varargin{dimfig}{iFig}; end

    % Loop over rows
    for iRow = 1:nrows
        benchlist{dimrows} = varargin{dimrows}{iRow};
        if isempty(benchlist{dimrows}); continue; end
        
        % Loop over columns
        for iCol = 1:ncols 
            benchlist{dimcols} = varargin{dimcols}{iCol};
            if isempty(benchlist{dimcols}); continue; end
            
            if nrows == 1 && options.TwoRows
                index = iCol + (iCol > ceil(ncols/2));
                subplot(2,ceil(ncols/2)+1,index);
            else
                subplot(nrows,ncols+1,(iRow-1)*(ncols+1) + iCol);
            end
            cla(gca,'reset');
            
            % Find data dimension to be plotted in each panel
            for i = 1:length(labels)
                if isempty(benchlist{i})
                    benchlist{i} = varargin{i}; 
                    if numel(benchlist{i}) > 1 && isempty(dimlayers)
                        dimlayers = i;
                    else
                        benchlist{i} = varargin{i}{1};
                    end
                end
            end
            if isempty(dimlayers)
                dims = setdiff(1:length(labels),[dimfig dimrows dimcols]);
                dimlayers = dims(1); 
            end
                                    
            IsMinKnown = true;
            MinFvalNew = Inf;
            
            % Initialize summary statistics (load from file if present)
            [benchdata,MinFval,MinBag] = ...
                loadSummaryStats(options.FileName,benchlist,varargin{dimlayers},dimlayers,options.Noisy);
            if options.Noisy; NewMinBag.fval = []; NewMinBag.fsd = []; end
            if options.Noisy
                if ~isempty(MinBag.fval)
                    LoadedMinBag_flag = true;
                else
                    LoadedMinBag_flag = false;
                end                
            end
            
            
%             if options.Noisy
%                 [benchdata,MinFval,MinBag] = ...
%                     loadSummaryStats(options.FileName,benchlist,varargin{dimlayers},dimlayers,1);
%             else
%                 [benchdata,MinFval] = ...
%                     loadSummaryStats(options.FileName,benchlist,varargin{dimlayers},dimlayers,0);
%             end
                        
            if IsMinKnown; MinPlot = NumZero; end
            
                        
            % Loop over layers within panel
            for iLayer = 1:numel(varargin{dimlayers})
                
                % Collect history structs from data files
                benchlist{dimlayers} = varargin{dimlayers}{iLayer};
                fieldname = [benchlist{dimrows} '_' benchlist{dimcols} '_' benchlist{dimlayers}];
                fieldname(fieldname == '@') = '_';
                fieldname(fieldname == '-') = '_';
                flags = 0;
                if LoadedData_flag && isfield(data,fieldname)
                    history = data.(fieldname).history;
                    algo = data.(fieldname).algo;
                    algoset = data.(fieldname).algoset;
                    if numel(algoset) > 9 && strcmp(algoset(end-8:end), '_overhead')
                        flags(1) = 1;                        
                    end
                else
                    fprintf('Collecting files: %s@%s@%s\n', benchlist{dimrows}, benchlist{dimcols}, benchlist{dimlayers});
                    [history,algo,algoset,flags] = collectHistoryFiles(benchlist);
                    data.(fieldname).history = history;
                    data.(fieldname).algo = algo;
                    data.(fieldname).algoset = algoset;
                end
                algoset(algoset == '-') = '_';
                                
                if flags(1)
                    overhead_flag = true;
                else
                    overhead_flag = false;
                end
                
                if isempty(history); continue; end
        
                x = []; y = []; D = []; FunCallsPerIter = [];
                AverageOverhead = zeros(1,numel(history));
                FractionOverhead = [];
                Zscores = [];   Errs = [];
                TotalElapsedTime = 0;
                TotalFunctionTime = 0;
                TotalTrials = 0;
                
                % Loop over histories
                for i = 1:numel(history)
                    
                    D = [D; history{i}.D];  % Number of variables
                    
                    if strcmpi(options.Method,'ert')
                        
                        x = [1:1:10, 12:2:50, 55:5:100, 110:10:300, 320:20:1000, 1050:50:2500, 2600:100:10000];
                        
                        % For ERT (expected running time) get the matrix
                        % of thresholds hit (get only thresholds of interest)
                        idx = history{i}.Thresholds >= min(options.SolveThreshold) ...
                            & history{i}.Thresholds <= max(options.SolveThreshold);  
                        % Append run duration at the end
                        if isfield(history{i},'ThresholdsHitPerIter')
                            y = [y; history{i}.ThresholdsHitPerIter(:,idx), ...
                                history{i}.FunCallsPerIter(:)];
                        else
                            continue;
                        end
                    else
                        if isfield(history{1},'SavePeriod')                    
                            x = [x; history{1}.SavePeriod*(1:length(history{i}.MinScores))];
                        else
                            x = [x; history{1}.SaveTicks];
                        end
                        
                        % Get valid time ticks
                        idx_valid = history{i}.SaveTicks <= history{i}.TotalMaxFunEvals;                        
                        ynew = history{i}.MinScores(idx_valid);                        
                        
                        if isnan(history{i}.TrueMinFval) || options.UnknownMin
                            IsMinKnown = false;
                        else
                            ynew = ynew - history{i}.TrueMinFval;
                        end
                        ynew(isnan(ynew)) = min(ynew);
                        ynew(ynew == options.BadLogLikelihood) = Inf;
                        if options.Noisy
                            [~,index] = min(history{i}.Output.fval);
                            if IsMinKnown
                                y = [y; history{i}.Output.fval(index) - history{i}.TrueMinFval, history{i}.Output.fsd(index)];
                            else
                                y = [y; history{i}.Output.fval(index), history{i}.Output.fsd(index)];
                            end
                        else
                            y = [y; ynew];
                        end
                    end
                                                            
                    if ~isempty(history{i})
                        
                        % Update minimum function value
                        if ~strcmpi(options.Method,'ert')
                            if options.Noisy
                                if IsMinKnown
                                    NewMinBag.fval = 0;                                    
                                    NewMinBag.fsd = 0;
%                                    NewMinBag.fval = [NewMinBag.fval; history{i}.Output.fval(:) - history{i}.TrueMinFval];                                    
                                else
                                    NewMinBag.fval = [NewMinBag.fval; history{i}.Output.fval(:)];
                                    NewMinBag.fsd = [NewMinBag.fsd; history{i}.Output.fsd(:)];
                                end
                            else
                                MinFvalNew = min(MinFvalNew,min(y(:)));
                            end
                        else
                            MinFvalNew = MinFval;
                        end
                        if isfield(history{i},'FunCallsPerIter')
                            FunCallsPerIter{i} = history{i}.FunCallsPerIter;
                        else
                            FunCallsPerIter{i} = NaN;                        
                        end
                        if isfield(history{i},'SaveTicks')
                            % Take only until it resets (one run)
                            last = find(isfinite(history{i}.ElapsedTime),1,'last');
                            last_first = find(diff(history{i}.ElapsedTime(1:last)) < 0,1);
                            if ~isempty(last_first); last = last_first; end
                            try
                                AverageOverhead(i) = ...
                                    (history{i}.ElapsedTime(last) - sum(history{i}.FuncTime(1:last)))/history{1}.SaveTicks(last);
                            catch
                                pause
                            end
                        end
                        
                        speedfactor = 8.2496/history{i}.speedtest;
                        
                        TotalElapsedTime = TotalElapsedTime + history{i}.ElapsedTime(last)*speedfactor;
                        TotalFunctionTime = TotalFunctionTime + sum(history{i}.FuncTime(1:last))*speedfactor;
                        TotalTrials = TotalTrials + history{i}.SaveTicks(last);
                        FractionOverhead = [FractionOverhead, (history{i}.ElapsedTime(last)/sum(history{i}.FuncTime(1:last))-1)];
                        if isfield(history{i}.Output,'zscore')
                            Zscores = [Zscores, history{i}.Output.zscore(:)'];
                            Errs = [Errs, history{i}.Output.err(:)'];
                        end
                        
%                         Noisy = 0;
%                         if isfield(history{i},'Output')
%                             if any(history{1}.Output.fsd(:) > 0); Noisy = 1; end
%                         end                                
%                         if Noisy   % Account for the extra function evaluations (obsolete)
%                             TotalElapsedTime = TotalElapsedTime ...
%                                 - 10*(numel(history{i}.FunCallsPerIter)-1)*TotalFunctionTime/TotalTrials;
%                         end
                    end
                    
                end
                                
                % Save summary statistics
                if isempty(benchlist{4}); noise = [];
                else noise = ['_' benchlist{4} 'noise']; end                
                field1 = ['f1_' benchlist{1} '_' benchlist{2}];
                field2 = ['f2_' upper(benchlist{3}) noise];
                field3 = ['f3_' algo '_' algoset];
                
                if options.Noisy
                    % benchdatanew.(field1).(field2).(field3).MinBag = MinBag;
                else
                    if MinFvalNew ~= options.BadLogLikelihood
                        benchdatanew.(field1).(field2).(field3).MinFval = MinFvalNew;
                    else
                        benchdatanew.(field1).(field2).(field3).MinFval = Inf;
                    end
                end
                                                
                % Check if summary statistics match with loaded ones
                if ~isempty(benchdata)
                    try
                        if benchdata.(field1).(field2).(field3).MinFval ~= MinFvalNew
                            StatMismatch = StatMismatch + 1;
                        end
                    catch
                        StatMismatch = StatMismatch + 1;
                    end
                end
                
                if isempty(benchdata) || StatMismatch && (MinFvalNew ~= options.BadLogLikelihood)
                    MinFval = MinFvalNew;
                end
                
                itersPerRun = cellfun(@length,FunCallsPerIter);
                display(['Average # of algorithm starts per run: ' num2str(mean(itersPerRun)) ' � ' num2str(std(itersPerRun)) '.']);                
                display(['Average overhead per function call: ' num2str(mean(AverageOverhead),'%.3f') ' � ' num2str(std(AverageOverhead),'%.3f') '.']);                
                
%                 if any(AverageOverhead < 0)
%                     pause
%                 end
                
                if ~isempty(history)

                    if options.Noisy
                        if ~isempty(MinBag.fval)
                            [xx,yy,yyerr,MeanMinFval] = plotNoisy(y,MinBag,iLayer,varargin{dimlayers},options);
                        else
                            [xx,yy,yyerr,MeanMinFval] = plotNoisy(y,NewMinBag,iLayer,varargin{dimlayers},options);
                        end
                    else
                        if overhead_flag
                            for iRun = 1:size(x,1)
                                y(iRun,:) = interp1(x(iRun,:),y(iRun,:),x(iRun,:)/(1+FractionOverhead(iRun)));
                            end
                            fprintf('Fraction overhead: %.3f +/- %.3f.\n', mean(FractionOverhead), std(FractionOverhead));
                        end
                        [xx,yy,yyerr] =  plotIterations(x,y,D,MinFval,IsMinKnown,iLayer,varargin{dimlayers},options);
                    end
                    
                    % Save summary information
                    benchdatanew.(field1).(field2).(field3).xx = xx;
                    benchdatanew.(field1).(field2).(field3).yy = yy;
                    if exist('yerr','var')
                        benchdatanew.(field1).(field2).(field3).yerr = yerr;
                    end
                    try
                        benchdatanew.(field1).(field2).(field3).MaxFunEvals = ...
                            history{1}.TotalMaxFunEvals;
                    catch
                        benchdatanew.(field1).(field2).(field3).MaxFunEvals = ...
                            history{1}.D*500;
                    end 
                    
                    benchdatanew.(field1).(field2).(field3).AverageAlgTime = ...
                        (TotalElapsedTime - TotalFunctionTime)/TotalTrials;
                    benchdatanew.(field1).(field2).(field3).AverageFunTime = ...
                        TotalFunctionTime/TotalTrials;
                    benchdatanew.(field1).(field2).(field3).FractionOverhead = mean(FractionOverhead);
                    if ~isempty(Zscores)
                        benchdatanew.(field1).(field2).(field3).Zscores = Zscores(:);
                        benchdatanew.(field1).(field2).(field3).Errs = Errs(:);
                    end
                end
                
            end
            
            if options.Noisy
                benchdatanew.(field1).(field2).MinBag = NewMinBag;                
                if any(size(MinBag.fval) ~= size(NewMinBag.fval)) || ...
                    any(MinBag.fval ~= NewMinBag.fval)
                    StatMismatch = StatMismatch + 1;
                end
            end
            
            if options.Noisy
                [xlims,ylims] = panelNoisy(iRow,iCol,nrows,dimrows,dimcols,xx,MeanMinFval,benchlist,options);                
            else
                [xlims,ylims] = panelIterations(iRow,iCol,nrows,ncols,dimrows,dimcols,xx,MinFval,benchlist,IsMinKnown,options);
            end
            
        end
    end
    
    % Add legend
    if nrows == 1 && options.TwoRows
        subplot(nrows,ceil(ncols/2)+1,ceil(ncols/2)+1);
    else
        subplot(nrows,ncols+1,ncols+1);
    end
    
    cla(gca,'reset');
    for iLayer = 1:length(varargin{dimlayers})
        temp = varargin{dimlayers}{iLayer};
        index = find(temp == '@',1);
        if isempty(index)
            legendlist{iLayer} = temp;
        else
            first = temp(1:index-1);
            second = temp(index+1:end);
            if ~strcmpi(second,'base')
                legendlist{iLayer} = [first, ' (', second, ')'];
            else
                legendlist{iLayer} = first;                
            end
        end
        if options.Noisy
            linstyle{iLayer} = '-';
            lw = 5;
        else
            enhance = enhanceline(length(varargin{dimlayers}),options);
            if any(iLayer == enhance); lw = 4; else lw = 2; end
        end
        % h = shadedErrorBar(min(xlims)*[1 1],min(ylims)*[1 1],[0 0],{linstyle{iLayer},'Color',lincol(iLayer,:),'LineWidth',lw},1); hold on;
        h = plot(min(xlims)*[1 1],min(ylims)*[1 1],linstyle{iLayer},'Color',lincol(iLayer,:),'LineWidth',lw); hold on;
        hlines(iLayer) = h;
    end
    hl = legend(hlines,legendlist{:});
    set(hl,'Box','off','Location','NorthWest','FontSize',14);

    %if BestOutOf > 1
    %    text(0.5,0.1,['Min f(x*) out of ' num2str(BestOutOf) ' runs'],'Units','Normalized','HorizontalAlignment','Center');
    %end
    
    if 0
        axis([xlims, NumZero 1e3]);
        xlabel('Func evaluations');
        ylabel('Min value');
        set(gca,'TickDir','out','Xscale','log','Yscale','log','TickLength',3*get(gca,'TickLength'));
        %set(gca,'Xlim',xlims);
        %set(gca,'Ylim',ylims);
        set(gca,'XTick',xtick);
        set(gca,'YTick',ytick,'YTickLabel',yticklabel);
        box off;
    else
        axis off;
    end

    set(gcf,'Color','w');
end

if StatMismatch == 1 || isempty(benchdata)
    warning('Summary statistics are not up to date. Replot to have the correct graphs.');
end

benchdata = benchdatanew;
benchdata.options = options;

save(options.FileName,'benchdata','data');

%--------------------------------------------------------------------------
function [xx,yy,yyerr] = plotIterations(x,y,D,MinFval,IsMinKnown,iLayer,arglayer,options)
%PLOTITERATIONS Plot time series of IR or FS

    NumZero = options.NumZero;
    BestOutOf = options.BestOutOf;
    
    if IsMinKnown; MinFval = 0; end
    
    defaults = benchmark_defaults('options');
    linstyle = defaults.LineStyle;
    lincol = defaults.LineColor;
        
    if ~strcmpi(options.Method,'ert')
        if ~options.AbsolutePlot
            y = y - MinFval;
        end
        y(y < NumZero) = NumZero;
    end
    xx = median(x,1);
    if BestOutOf > 1
        nbest = floor(size(y,1)/BestOutOf);
        ymin = zeros(nbest,size(y,2));
        for ii = 1:nbest
            index = (1:BestOutOf) + (ii-1)*BestOutOf;
            temp = y(index,:);
            ymin(ii,:) = min(temp,[],1);
        end  
        switch lower(options.Method)
            case 'ir'
                yy = median(ymin,1);
                yyerr = abs(bsxfun(@minus,[quantile(ymin,0.75,1);quantile(ymin,0.25,1)],yy));
            case 'fs'
                xx = xx/max(D);
                yy = nanmean(abs(ymin - MinFval) < options.SolveThreshold, 1);
                yyerr = stderr(abs(ymin - MinFval) < options.SolveThreshold, 0, 1);
        end
    else
        switch lower(options.Method)
            case 'ir'                        
                yy = median(y,1);
                yyerr = abs(bsxfun(@minus,[quantile(y,0.75,1);quantile(y,0.25,1)],yy));
            case 'fs'
                xx = xx/max(D);
                SolveThreshold(1,1,:) = options.SolveThreshold;
                F = bsxfun(@lt, y, SolveThreshold);                
                yy = nanmean(nanmean(F,3),1);
                % yy = nanmean(y < options.SolveThreshold, 1);
                yyerr = stderr(nanmean(F,3), 0, 1);                
            case 'ert'
                % Compute empirical distribution of ERT's (divided by dimension)
                runlen = y(:,end);
                D = max(D);
                y = y(:,1:end-1);
                MaxLen = 1e4*D;
                DivideByDim = 1;
                if DivideByDim
                    runlen = runlen./D;
                    y = bsxfun(@rdivide,y,D);
                    MaxLen = MaxLen/max(D);
                end
                Nthres = size(y,2);
                Nsamp = options.Nsamp;
                ert = Inf(Nsamp, Nthres); 
                funcalls = zeros(Nsamp, Nthres);                
                while 1
                    idx = randi(size(y,1),[Nsamp,1]);
                    tnew = y(idx,:);
                    f = isinf(ert) & ~isinf(tnew);
                    ert(f) = tnew(f) + funcalls(f);
                    funcalls = bsxfun(@plus, funcalls, runlen(idx));
                    
                    if all(isfinite(ert(:))); break; end
                    if all(funcalls(:,1) > MaxLen); break; end                    
                end
                
                temp(:,1,:) = ert;                
                yy = nanmean(nanmean(bsxfun(@lt, temp, xx),1),3);
                yyerr = zeros(size(yy));                
        end
    end

    plotErrorBar = options.ErrorBar;
    if isempty(plotErrorBar)
        plotErrorBar = numel(arglayer) <= 3;
    end
        
    enhance = enhanceline(numel(arglayer),options);    
    if any(iLayer == enhance); lw = 4; else lw = 2; end
    if plotErrorBar && 0
        h = shadedErrorBar(xx,yy,yyerr,{linstyle{iLayer},'LineWidth',lw},1); hold on;
    else
        h = plot(xx,yy,linstyle{iLayer},'Color', lincol(iLayer,:), 'LineWidth',lw); hold on;
    end
    % MinFval = min(MinFval,min(y(:)));

%--------------------------------------------------------------------------
function [xlims,ylims] = panelIterations(iRow,iCol,nrows,ncols,dimrows,dimcols,xx,MinFval,benchlist,IsMinKnown,options)
%PANELITERATIONS Finalize panel for plotting iterations

    NumZero = options.NumZero;

    switch lower(options.Method)
        case 'ir'
            if options.BestOutOf > 1; 
                ystring = ['Median best-of-' num2str(options.BestOutOf) ' IR']; 
            else
                ystring = 'Median IR';
            end
        case 'fs'
            ystring = 'Fraction solved';
        case 'ert'
            ystring = 'Fraction solved';
    end

    if options.DisplayFval; string = [' (f_{min} = ' num2str(MinFval,'%.2f') ')']; 
    else string = []; end

    if iRow == 1; title([benchlist{dimcols} string]); end
    % if iCol == 1; ylabel(benchlist{dimrows}); end
    if iCol == 1; ylabel(ystring); end
    if iCol == 1
        textstr = benchlist{dimrows};
        textstr(textstr == '_') = ' ';
        text(-1/6*(dimcols+1),0.9,textstr,'Units','Normalized','Rotation',0,'FontWeight','bold','HorizontalAlignment','center');
    end
    xlims = [min(xx,[],2) max(xx,[],2)];
    xtick = [1e2,1e3,1e4,1e5];
    % xtick = [1e2,1e3,2e3,3e3,4e3,5e3,6e3,1e4,1e5];
    set(gca,'Xlim',xlims,'XTick',xtick)
    switch lower(options.Method)
        case 'ir'
            if IsMinKnown
                ylims = [NumZero,options.YlimMax];
                if NumZero < 1e-5
                    ytick = [NumZero,1e-5,0.1,1,10,1e5,1e10];
                    yticklabel = {'0','10^{-5}','0.1','1','10','10^5','10^{10}'};
                else
                    ytick = [NumZero,0.1,1,10,1e3];                    
                    yticklabel = {'10^{-3}','0.1','1','10','10^3'};
                end
                liney = [1 1];
            else
                YlimMax = options.YlimMax;
                if options.AbsolutePlot
                    ylims = [MinFval,MinFval + YlimMax];
                    ytick = [];
                else
                    ylims = [NumZero,YlimMax];
                    ytick = [0.001,0.01,0.1,1,10,100,1000];
                    yticklabel = {'0.001','0.01','0.1','1','10','100','1000'};
                end
                liney = MinFval*[1 1];                
            end
            if isempty(ytick)
                set(gca,'Ylim',ylims);                        
            else
                set(gca,'Ylim',ylims,'YTick',ytick,'YTickLabel',yticklabel);
            end
            set(gca,'TickDir','out','Xscale','log','Yscale','log','TickLength',3*get(gca,'TickLength'));
            xstring = 'Fun evals';

        case 'fs'
            ylims = [0,1];
            ytick = [0,0.5,1];
            yticklabel = {'0','0.5','1'};
            liney = [1 1];
            set(gca,'Ylim',ylims,'YTick',ytick,'YTickLabel',yticklabel);
            set(gca,'TickDir','out','Xscale','log','TickLength',3*get(gca,'TickLength'));
            xstring = 'Fun evals / Dim';
            
        case 'ert'
            ylims = [0,1];
            ytick = [0,0.5,1];
            yticklabel = {'0','0.5','1'};
            liney = [1 1];
            set(gca,'Ylim',ylims,'YTick',ytick,'YTickLabel',yticklabel);
            set(gca,'TickDir','out','Xscale','log','TickLength',3*get(gca,'TickLength'));
            xstring = 'ERT / D';
            
    end
    if options.TwoRows
        plotXlabel = (iCol > ceil(ncols/2));
    else
        plotXlabel = (iRow == nrows);
    end
    if plotXlabel; xlabel(xstring); end
    set(gca,'FontSize',12);
    box off;
    plot(xlims,liney,'k--','Linewidth',0.5);
    
%--------------------------------------------------------------------------
function [xx,yy,yyerr,MeanMinFval] = plotNoisy(y,MinBag,iLayer,arglayer,options)
%PLOTITERATIONS Plot time series of IR or FS

    NumZero = options.NumZero;
    BestOutOf = options.BestOutOf;
    
    defaults = benchmark_defaults('options');
    linstyle = defaults.LineStyle;
    lincol = defaults.LineColor;
        
    xx = iLayer;
    
    switch lower(options.Method)
        case 'ir'                        
            %yy = median(y,1);
            %yyerr = abs(bsxfun(@minus,[quantile(y,0.75,1);quantile(y,0.25,1)],yy));
        case 'fs'
            n = size(y,1);
            
            if all(MinBag.fsd == 0) && all(y(:,2) == 0)
                MeanMinFval = min(MinBag.fval);
                d = y(:,1) - MeanMinFval;                
            else            
                nn = 1000;
                Nsamples = numel(MinBag.fval);
                y = repmat(y, [ceil(Nsamples/n) 1]);
                y = y(randperm(Nsamples),:);
                fval = repmat(MinBag.fval,[1 nn]);
                fsd = repmat(MinBag.fsd,[1 nn]);
                f1 = bsxfun(@plus,y(:,1),bsxfun(@times,y(:,2),randn(size(y,1),nn)));
                fmin = min(fval + fsd.*randn(size(fsd)),[],1);
                MeanMinFval = nanmean(fmin);
                d = bsxfun(@minus, f1, fmin);
            end
            % target = nanmean(bsxfun(@lt, d(:), options.SolveThreshold(:)'),2);            
            target = bsxfun(@lt, d(:), options.SolveThreshold(:)');     
            yy = nanmean(target,1);
            yyerr = stderr(target,[],1);
    end

    plotErrorBar = options.ErrorBar;
    if isempty(plotErrorBar)
        plotErrorBar = numel(arglayer) <= 3;
    end
    if iLayer == numel(arglayer); lw = 4; else lw = 2; end
    
    if size(yy,2) == 1
        h = bar(xx,yy,'LineStyle','none','FaceColor',lincol(iLayer,:)); hold on;
    else
        xx = options.SolveThreshold;
        h = plot(xx,yy,'LineStyle','-','Color',lincol(iLayer,:)); hold on;
    end
    
    % h = errorbar(xx,yy,yyerr,linstyle{iLayer},'Color', lincol(iLayer,:),'LineWidth',lw); hold on;
    
    
    %if plotErrorBar && 0
    %    h = shadedErrorBar(xx,yy,yyerr,{linstyle{iLayer},'LineWidth',lw},1); hold on;
    %else
    %    h = plot(xx,yy,linstyle{iLayer},'Color', lincol(iLayer,:), 'LineWidth',lw); hold on;
    %end
    % MinFval = min(MinFval,min(y(:)));
    
%--------------------------------------------------------------------------
function [xlims,ylims] = panelNoisy(iRow,iCol,nrows,dimrows,dimcols,xx,MeanMinFval,benchlist,options)
%PANELITERATIONS Finalize panel for plotting iterations

    NumZero = options.NumZero;

    switch lower(options.Method)
        case 'ir'
            ystring = 'Median IR';
        case 'fs'
            ystring = 'Fraction solved';
    end

    if options.DisplayFval; string = [' (<f_{min}> = ' num2str(MeanMinFval,'%.2f') ')']; 
    else string = []; end

    if iRow == 1; title([benchlist{dimcols} string]); end
    % if iCol == 1; ylabel(benchlist{dimrows}); end
    if iCol == 1; ylabel(ystring); end
    if iRow == nrows; xlabel('Algorithms'); end
    if iCol == 1
        textstr = benchlist{dimrows};
        textstr(textstr == '_') = ' ';
        text(-1/6*(dimcols+1),0.9,textstr,'Units','Normalized','Rotation',0,'FontWeight','bold','HorizontalAlignment','center');
    end
    xlims = [0 10];
    xtick = [];
    set(gca,'Xlim',xlims,'XTick',xtick)
    switch lower(options.Method)
        case 'ir'
            YlimMax = options.YlimMax;
            if options.AbsolutePlot
                ylims = [MinFval,MinFval + YlimMax];
                ytick = [];
            else
                ylims = [NumZero,YlimMax];
                ytick = [0.001,0.01,0.1,1,10,100,1000];
                yticklabel = {'0.001','0.01','0.1','1','10','100','1000'};
            end
            liney = MinFval*[1 1];                
            if isempty(ytick)
                set(gca,'Ylim',ylims);                        
            else
                set(gca,'Ylim',ylims,'YTick',ytick,'YTickLabel',yticklabel);
            end
            set(gca,'TickDir','out','TickLength',3*get(gca,'TickLength'));

        case 'fs'
            ylims = [0,1];
            ytick = [0,0.5,1];
            yticklabel = {'0','0.5','1'};
            liney = [1 1];
            set(gca,'Ylim',ylims,'YTick',ytick,'YTickLabel',yticklabel);
            set(gca,'TickDir','out','TickLength',3*get(gca,'TickLength'));
    end
    set(gca,'FontSize',12);
    box off;
    % plot(xlims,liney,'k--','Linewidth',0.5);    

%--------------------------------------------------------------------------
function c = cellify(x)

    if ~iscell(x); c = {x}; else c = x; end 
