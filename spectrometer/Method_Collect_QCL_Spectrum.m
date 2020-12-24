 classdef Method_Collect_QCL_Spectrum < Method
    %inherits from Method superclass
    
    properties (Hidden,SetAccess = immutable)
        Tag = 'Method2Signals2Pixels_65_66';
    end
    
    properties (SetAccess = protected)
        %define specific values for Abstract properties listed in superclass
        
        %our result is a one dimensional spectrum of the intensity on the
        %detector (this should be some generic constructor...)
        result = struct('data',[],...
            'freq',[],...
            'noise',[], 'abs', []);
        %ScanIsRunning and ScanIsStopping are inherited
    end
    
    properties (SetAccess = protected)
        sample;
        sorted;
        aux;
        ext; %testing external channels for uitable
        signal = struct('data',[],'std',[],'freq',[]);
        
        PARAMS = struct('initFreq', 1600, 'finalFreq', 2100, 'dFreq', 2, 'nShots',500,'nScans',1);
        
        source = struct('sampler',[],'gate',[],'spect',[],'motors',[]);
        
        %TODO: split source to separate objects
        %   sampler;
        %   gate;
        %   spect;
        %   motors;
        
        freq;
        abs;
        
        nSignals = 2;
        nPixels = 2;
        nExtInputs = 16;
        nChan = 80;
        ind_array1 = 66;
        ind_array2 = 65;
        %ind_igram = 65;
        %ind_hene_x = 79;
        %ind_hene_y = 80
        ind_ext = 65:80;
        
        ind_sig = 66;
        ind_ref = 65;
        
        ind_freq = 1;
        
        nShotsSorted;
        i_scan;
    end
    
    properties (Dependent, SetAccess = protected)
        Raw_data;
        Diagnostic_data;
        Noise;
    end
    
    %
    % public methods
    %
    methods
        function obj = Method_Collect_QCL_Spectrum(sampler,gate,spect,motors,handles,hParamsPanel,hMainAxes,hRawDataAxes,hDiagnosticsPanel)
            global QCLLaser qclgui
            %constructor
            
            if nargin == 0
                %put actions here for when constructor is called with no arguments,
                %which will serve as defaults.
                obj.sample = 1;
                return
            elseif nargin == 1
                %If item in is a method class object, just return that object.
                if isa(obj,'Method_Collect_QCL_Spectrum')
                    return
                elseif isa(obj,'Method')
                    %what to do if it is a different class but still a Method? How does
                    %that work? take FPAS and IO values and handles, delete input object,
                    %and call constructor with those input arguments (one level of
                    %recursion I guess). Will that work?
                    return
                end
            end
            
            obj.source.sampler = sampler; %is there a better way?
            obj.source.gate = gate;
            obj.source.spect = spect;
            obj.source.motors = motors;
            obj.hMainAxes = hMainAxes;
            obj.hParamsPanel = hParamsPanel;
            obj.hRawDataAxes = hRawDataAxes;
            obj.hDiagnosticsPanel = hDiagnosticsPanel;
            obj.handles = handles;
            obj.saveData=true;
            
            %obj.freq = obj.PARAMS.initFreq:obj.PARAMS.dFreq:obj.PARAMS.finalFreq;
            %obj.abs = zeros(1, length(obj.freq));
            
            if isempty(QCLLaser) || ~isvalid(QCLLaser)
                set(obj.handles.pumLaserSource, 'Value', 2)
                qclgui = QCLGUI;
            end
            obj.source.laser = QCLLaser;
            
            if ~obj.source.laser.isArmed
                obj.source.laser.armLaser;
            end
            
            Initialize(obj);
            
            %     InitializeFreqAxis(obj);
            %     InitializeParameters(obj,hParamsPanel);
            %     ReadParameters(obj);
            %     InitializeData(obj);
            %     InitializeMainPlot(obj);
            %     InitializeRawData(obj);
            %     InitializeDiagnostics(obj);
            
            %inherited public methods:
            %ScanStop
        end
    end
    
    methods (Access = protected)
        %initialize sample, signal, background, and result. Called at the
        %beginning of a scan
        function InitializeData(obj)
            
            nfreq = length(obj.freq);
            obj.abs = zeros(1, nfreq);
            
            obj.sample = zeros(obj.nChan,obj.PARAMS.nShots);
            obj.nShotsSorted = obj.nArrays*obj.PARAMS.nShots/obj.nSignals;
            obj.sorted = zeros(nfreq,obj.nShotsSorted,obj.nSignals);
            obj.signal.data = zeros(obj.nSignals,nfreq);
            obj.signal.std = zeros(obj.nSignals,nfreq);
            obj.LoadBackground;
            if isempty(obj.background.data) || any(size(obj.background.data)~=[obj.nSignals 1])
                obj.background.data = zeros(obj.nSignals,1);
                obj.background.std = zeros(obj.nSignals,1);
            end
            obj.result.data = zeros(1,nfreq);
            obj.result.noise = zeros(1,nfreq);
            
            obj.ext = zeros(obj.nExtInputs,1);
            %obj.aux.igram = zeros(1,obj.PARAMS.nShots);
            %obj.aux.hene_x = zeros(1,obj.PARAMS.nShots);
            %obj.aux.hene_y = zeros(1,obj.PARAMS.nShots);
        end
        
        function InitializeFreqAxis(obj)
            obj.freq = obj.PARAMS.initFreq:obj.PARAMS.dFreq:obj.PARAMS.finalFreq;
            obj.result.freq = obj.freq;
%             obj.abs = zeros(1, length(obj.freq));
            set(obj.hMainAxes,'Xlim',[obj.freq(1) obj.freq(end)]);
        end
        
        %set up the plot for the main output. Called by the class constructor.
        function InitializeMainPlot(obj)
            %attach signal.data(1,:) and signal.data(2,:) to the main plot
            obj.hPlotMain = zeros(1,obj.nSignals);
            
            % !!! Important note: Cannot use 'hold off' here because of side
            % effects.  This is equivalent.
            set(obj.hMainAxes,'Nextplot','replacechildren');
            %hold(obj.hMainAxes,'off');
            
            for i = 1:obj.nSignals
                obj.hPlotMain(i) = plot(obj.hMainAxes,obj.freq,zeros(1, length(obj.freq)));
                hold(obj.hMainAxes,'all');
                set(obj.hPlotMain(i),'XDataSource','obj.freq',...
                    'YDataSource', 'obj.abs')
            end
            %set(obj.hMainAxes,'Xlim',[obj.freq(1) obj.freq(end)]);
            
        end
        
        function InitializeUITable(obj)
            set(obj.handles.uitableExtChans,'Data',obj.ext,'columnformat',{'short g'});
        end
        
        function RefreshUITable(obj)
            set(obj.handles.uitableExtChans,'Data',obj.ext);
        end
        
        %set up the ADC task(s)
        function InitializeTask(obj)
            %close gate
            obj.source.gate.CloseClockGate;
            
            %configure task
            obj.source.sampler.ConfigureTask(obj.PARAMS);
        end
        
        
        %initialize the data acquisition event and move motors to their
        %starting positions
        function ScanInitialize(obj)
            global qclgui QCLLaser
            
            if isempty(QCLLaser) || ~isvalid(QCLLaser)
                set(obj.handles.pumLaserSource, 'Value', 2)
                qclgui = QCLGUI;
            end
            
            obj.source.laser = QCLLaser;           
            
            if ~obj.source.laser.isArmed
                obj.source.laser.armLaser;
            end
            
            while ~obj.source.laser.areTECsAtTemp
                pause(0.25)
            end
            
            ReadParameters(obj);
            
            InitializeFreqAxis(obj);
            InitializeData(obj);
            InitializeMainPlot(obj);
            InitializeRawDataPlot(obj);
            InitializeTask(obj);
            %just leave motors where they are
            
            obj.source.laser.tuneTo(obj.freq(1), 'cm-1', obj.source.laser.whichQCL(obj.freq(1), 'cm-1'));
            while ~obj.source.laser.isTuned
                pause(0.25)
            end
            
            if ~obj.source.laser.isEmitting
                obj.source.laser.turnEmissionOn
            end
            
            while ~obj.source.laser.isEmitting
                pause(0.25)
            end
        end
        
        %start first sample. This code is executed before the scan loop starts
        function ScanFirst(obj)
            %start the data acquisition task
            obj.source.sampler.Start;
            obj.source.gate.OpenClockGate;
            obj.ind_freq = 1;
            
            for ii = 2:length(obj.freq)
                
                obj.sample = obj.source.sampler.Read; %this will wait until the required points have been transferred (ie it will finish)
                obj.source.gate.CloseClockGate;
                %any other reading can happen next
                
                obj.source.laser.tuneTo(obj.freq(ii), 'cm-1',...
                    obj.source.laser.whichQCL(obj.freq(ii), 'cm-1'));
                
                while ~obj.source.laser.isTuned
                    pause(0.25)
                end
                
                % break
                if strcmpi(obj.handles.pbGo.String,'Stopping'),return,end
                
                %no need to move motors
                
                %start the data acquisition task
                obj.source.sampler.Start;
                obj.source.gate.OpenClockGate;
                
                %process the previous results
                ProcessSample(obj);
                
                %no averaging
                %obj.AverageSample(obj);
                
                %update freq axis if it changed
                %InitializeFreqAxis(obj);
                
                %plot results
                RefreshPlots(obj,obj.hPlotMain)
                RefreshPlots(obj,obj.hPlotRaw)
                UpdateDiagnostics(obj);
                RefreshUITable(obj);
                drawnow
                obj.ind_freq = ii;
            end
        end
        
        %This code is executed inside the scan loop. This is different from
        %ScanFirst for efficiency. It allows us to read data from ScanFirst
        %(making sure it is finished), then immediately start the second, and
        %process the first while the second is acquiring. It is also the place
        %to put code to save temporary files
        function ScanMiddle(obj)
            obj.sample = obj.source.sampler.Read; %this will wait until the required points have been transferred (ie it will finish)
            obj.source.gate.CloseClockGate;
            
            obj.source.laser.tuneTo(obj.freq(1), 'cm-1',...
                obj.source.laser.whichQCL(obj.freq(1), 'cm-1'));
            
            obj.ind_freq = 1;
            
            obj.source.sampler.Start;
            obj.source.gate.OpenClockGate;
            
            for ii = 2:length(obj.freq)
                
                obj.sample = obj.source.sampler.Read; %this will wait until the required points have been transferred (ie it will finish)
                obj.source.gate.CloseClockGate;
                %any other reading can happen next
                
                obj.source.laser.tuneTo(obj.freq(ii), 'cm-1',...
                    obj.source.laser.whichQCL(obj.freq(ii), 'cm-1'));
                
                while ~obj.source.laser.isTuned
                    pause(0.25)
                end
                
                % break
                if strcmpi(obj.handles.pbGo.String,'Stopping'),return,end
                
                %no need to move motors
                
                %start the data acquisition task
                obj.source.sampler.Start;
                obj.source.gate.OpenClockGate;
                
                %process the previous results
                ProcessSample(obj);
                
                %no averaging
                %obj.AverageSample(obj);
                
                %update freq axis if it changed
                %InitializeFreqAxis(obj);
                
                %plot results
                RefreshPlots(obj,obj.hPlotMain)
                RefreshPlots(obj,obj.hPlotRaw)
                UpdateDiagnostics(obj);
                RefreshUITable(obj);
                drawnow
                
            end
            
            %no saving
        end
        
        %This code executes after the scan loop. It should read but not start a
        %new scan. It should usually save the final results.
        function ScanLast(obj)
            
            obj.sample = obj.source.sampler.Read; %this will wait until the required points have been transferred (ie it will finish)
            obj.source.gate.CloseClockGate;
            %any other reading can happen next
            
            %no need to move motors
            
            %process the previous results
            ProcessSample(obj); %this is a public method of the Method superclass
            
            %no averaging
            %obj.AverageScan(obj);
            
            %plot results
            RefreshPlots(obj,obj.hPlotMain)
            RefreshPlots(obj,obj.hPlotRaw)
            UpdateDiagnostics(obj);
            RefreshUITable(obj);
            drawnow
            %no saving
            
        end
        
        %move the motors back to their zero positions. Clear the ADC tasks.
        function ScanCleanup(obj)
            global isManualTuneEnabled
            obj.source.gate.CloseClockGate;
            obj.source.sampler.ClearTask;
            
            obj.source.laser.turnEmissionOff;
            obj.source.laser.cancelManualTune;
            
            isManualTuneEnabled = false;
                        
        end
        
        function ProcessSampleSort(obj)
            %the easy thing
            
            obj.sorted(obj.ind_freq,:,1) = obj.sample(obj.ind_array1,1:obj.nShotsSorted);
            obj.sorted(obj.ind_freq,:,2) = obj.sample(obj.ind_array2,1:obj.nShotsSorted);
            
            %obj.aux.igram = obj.sample(obj.ind_igram,:);
            %obj.aux.hene_x = obj.sample(obj.ind_hene_x,:);
            %obj.aux.hene_y = obj.sample(obj.ind_hene_y,:);
            obj.ext = obj.sample(obj.ind_ext,:);
            
            %unfinished:
            %     rowInd1 = obj.ind_array1;
            %     rowInd2 = obj.ind_array2;
            %     chop = 0; %this is a vector nSignals/nArrays in length
            %
            %     colInd1 = (1:obj.nSignals/obj.nArrays:obj.PARAMS.nShots)+chop;
            %     colInd2 = (1:obj.nSignals/obj.nArrays:obj.PARAMS.nShots)+chop;
            %     count = 0;
            %     for ii = 1:2:obj.nSignals/2;
            %       count = count+1;
            %       obj.sorted(:,:,ii) = obj.sample(rowInd1,obj.nShotsSorted);
            %       obj.sorted(:,:,ii+1) = obj.sample(obj.nPixelsPerArray+1:2*obj.nPixelsPerArray,obj.nShotsSorted);
            %     end
        end
        
        function ProcessSampleAvg(obj)
            obj.signal.data(:,obj.ind_freq) = squeeze(mean(obj.sorted(obj.ind_freq,:,:),2))';
            obj.signal.std(:,obj.ind_freq) = squeeze(std(obj.sorted(obj.ind_freq,:,:),0,2))';
            obj.ext = mean(obj.ext,2);
        end
        
        function ProcessSampleBackAvg(obj)
            obj.background.data(:,1) = (obj.background.data(:,1).*(obj.i_scan-1) + obj.signal.data(:,1))./obj.i_scan;
            %check this might not be right
            obj.background.std(:,1) = sqrt((obj.background.std(:,1).^2.*(obj.i_scan-1) + obj.signal.std(:,1).^2)./obj.i_scan);
        end
        
        function ProcessSampleSubtBack(obj)
            %obj.signal.data = obj.signal.data - obj.background.data;
            %obj.signal.std = sqrt(obj.signal.std.^2 + obj.background.std.^2);
            
            %here we are going to subtract the background from every shot we have
            %measured. Note that the backgrounds for different signals may be
            %different so we must do this after sorting the data. Normally one
            %would do this with a nested for loop, but that is slow in Matlab, so
            %we will use the fancy function bsxfun (binary function (ie two
            %operands) with singleton dimension expansion) to acheive this. We are
            %subtracting the sorted data (size nPixels, nShots, nSignals) minus the
            %bg which has size nPixels 1 nSignals). The bsxfun realizes that the
            %middle dimension 1 needs to match nShots so it expands the size of the
            %array automatically.
            
            %So we first transpose the background from (nSignals x nPixels) to
            %(nPixels x nSignals). Reshape expands that to be (nPixels x 1 x
            %nSignals).
            bg = reshape(obj.background.data',[1 1 obj.nSignals]);
            
            %now bsxfun does the subtraction
            obj.sorted = bsxfun(@minus,obj.sorted,bg);
        end
        
        function ProcessSampleResult(obj)
            %calculate the effective delta absorption (though we are plotting the
            %signals directly)
            obj.result.signal = obj.signal.data(1,:);
            obj.result.ref = obj.signal.data(2,:);
            obj.result.data = -log10(obj.signal.data(1,:)./obj.signal.data(2,:));
            %sampleShots = obj.sample(obj.ind_sig,:);
            %refShots = obj.sample(obj.ind_ref,:);
            %obj.abs(obj.ind_freq) = mean(-log10(sampleShots./refShots));
            obj.result.abs = obj.result.data;
            obj.abs = real(obj.result.data);
            
        end
        
        function ProcessSampleNoise(obj)
            %calculate the signal from each shot for an estimate of the error
            obj.result.noise = 1000 * std(log10(obj.sorted(:,:,1)./obj.sorted(:,:,2)),0,2)'/sqrt(obj.PARAMS.nShots);
            
            %the other option would be a propagation of error calculation but I
            %haven't worked through that yet. See wikipedia Propagation of
            %Uncertainty
        end
    end
        
    methods %public methods
        
        function out = get.Raw_data(obj)
            out = obj.signal.data;
        end
        function out = get.Noise(obj)
            out = obj.result.noise;
        end
        
        function InitializeRawDataPlot(obj)
            
%             nShots = obj.PARAMS.nShots;
%             hold(obj.hRawDataAxes, 'all');
%             obj.hPlotRaw = zeros(1,2);
%             
%             obj.hPlotRaw(1) = plot(obj.hRawDataAxes, 1:nShots, zeros(1,nShots));
%             set(obj.hPlotRaw(1),'Color',[mod(1-(1-1)*0.1,1) 0 0]);
%             set(obj.hPlotRaw(1),'YDataSource','obj.sample(obj.ind_sig,:)');
%             hold(obj.hRawDataAxes, 'on');
%             
%             obj.hPlotRaw(2) = plot(obj.hRawDataAxes, 1:nShots, zeros(1, nShots));
%             set(obj.hPlotRaw(2),'Color',[mod(1-(2-1)*0.1,1) 0 0]);
%             set(obj.hPlotRaw(2),'YDataSource','obj.sample(obj.ind_ref,:)');
%             hold(obj.hRawDataAxes, 'on');
%             
%             set(obj.hRawDataAxes,'XLim',[1 nShots],'Ylim',[0 2^16*1.05]);
            
%             nfreq = length(obj.freq);
            
            n_plots = size(obj.Raw_data,1);
            hold(obj.hRawDataAxes, 'off');
            obj.hPlotRaw = zeros(1,n_plots);
            for i = 1:n_plots
                % The Raw Data plot is the same for every method.
                obj.hPlotRaw(i) = plot(obj.hRawDataAxes, obj.freq, ones(1,length(obj.freq)));
                set(obj.hPlotRaw(i),'Color',[mod(1-(i-1)*0.1,1) 0 0]);
                set(obj.hPlotRaw(i),'YDataSource',['obj.Raw_data(',num2str(i),',:)']);
                hold(obj.hRawDataAxes, 'on');
            end
            
            % plot noise
            i=i+1;
            obj.hPlotRaw(i) = plot(obj.hRawDataAxes, obj.freq, ones(1,length(obj.freq)), 'b');
            set(obj.hPlotRaw(i),'YDataSource','obj.Noise.*obj.noiseGain');
            set(obj.hRawDataAxes,'XLim',[obj.freq(1) obj.freq(end)],'Ylim',[0 2^16*1.05]);

        end
        %acquire a background (might need to be public)
        function BackgroundAcquire(obj)
            obj.ScanIsRunning = true;
            obj.ScanIsStopping = false;
            obj.BackgroundReset;
            obj.ReadParameters;
            %obj.InitializeTask;
            obj.ScanInitialize;
            obj.ind_freq = 1;
            
            for ni_scan = 1            % @@@ is there some reason we can't assign obj.i_scan directly?
                obj.i_scan = ni_scan;
                set(obj.handles.textScanNumber,'String',sprintf('Scan # %i',obj.i_scan));
                drawnow;
                
                obj.source.sampler.Start;
                obj.source.gate.OpenClockGate;
                obj.sample = obj.source.sampler.Read;
                obj.source.gate.CloseClockGate;
                
                obj.ProcessSampleSort;
                obj.ProcessSampleAvg;
                obj.ProcessSampleBackAvg;
                
                obj.ProcessLaserBackAvg;
                
            end
            obj.source.sampler.ClearTask;
            obj.SaveBackground;
            obj.ScanIsRunning = false;
            
        end
        function delete(obj)
            DeleteParameters(obj);
        end 
    end    
end
