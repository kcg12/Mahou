classdef ThorLabs_DCServoTranslationStage < handle
    
    properties(Constant, Hidden)
        % path to DLL files (edit as appropriate)
        MOTORPATHDEFAULT = 'C:\Program Files (x86)\Thorlabs\Kinesis\';
        
        % DLL files to be loaded
        CONTROLSDLL = 'Thorlabs.MotionControl.Controls.dll';
        DEVICEMANAGERDLL='Thorlabs.MotionControl.DeviceManagerCLI.dll';
        DEVICEMANAGERCLASSNAME='Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI';
        GENERICMOTORDLL='Thorlabs.MotionControl.GenericMotorCLI.dll';
        GENERICMOTORCLASSNAME='Thorlabs.MotionControl.GenericMotorCLI.GenericMotorCLI';
        DCSERVODLL='Thorlabs.MotionControl.KCube.DCServoCLI.dll';
        DCSERVOCLASSNAME='Thorlabs.MotionControl.KCube.DCServoCLI.KCubeDCServo';
        
        % Default intitial parameters
        DEFAULTVEL=10;           % Default velocity
        DEFAULTACC=10;           % Default acceleration
        TPOLLING=250;            % Default polling time
        TIMEOUTSETTINGS=7000;    % Default timeout time for settings change
        TIMEOUTMOVE=100000;      % Default time out time for motor move
    end
    
    properties 
       % These properties are within Matlab wrapper 
       isConnected=false;           % Flag set if device connected
       serialNumber;                % Device serial number
       controllerName;              % Controller Name
       controllerDescription        % Controller Description
       stageName;                   % Stage Name
       position;                    % Position
       acceleration;                % Acceleration
       maxVelocity;                 % Maximum velocity limit
       minVelocity;                 % Minimum velocity limit
       backlash;
       tag;
    end
    
    properties (Hidden)
       % These are properties within the .NET environment. 
       deviceNET;                   % Device object within .NET
       motorSettingsNET;            % motorSettings within .NET
       currentDeviceSettingsNET;    % currentDeviceSetings within .NET
       deviceInfoNET;               % deviceInfo within .NET
    end
    
    methods
        
        function obj = ThorLabs_DCServoTranslationStage(serialNumber, direction, tag)
            % START HERE
            try   % Load in DLLs if not already loaded
                NET.addAssembly([obj.MOTORPATHDEFAULT, obj.DEVICEMANAGERDLL]);                
                NET.addAssembly([obj.MOTORPATHDEFAULT, obj.DCSERVODLL]);
                genMot = NET.addAssembly([obj.MOTORPATHDEFAULT, obj.GENERICMOTORDLL]);
            catch % DLLs did not load
                error('Unable to load .NET assemblies')
            end
            
            obj.tag = tag;
            Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.BuildDeviceList();  % Build device list
            serialNumbersNet = Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.GetDeviceList(); % Get device list
            serialNumbers=cell(ToArray(serialNumbersNet)); % Convert serial numbers to cell array
            
            if ~any(strcmp(serialNumbers, serialNumber))
                error('Stage with specified serial number not found')
            end
            
            obj.serialNumber = serialNumber;
            obj.deviceNET = Thorlabs.MotionControl.KCube.DCServoCLI.KCubeDCServo.CreateKCubeDCServo(obj.serialNumber);
            
            try
                obj.deviceNET.Connect(obj.serialNumber);
            catch
                error('Failed to connect to stage: S/N %s', obj.serialNumber)
            end
            
            if ~obj.deviceNET.IsSettingsInitialized() % Wait for IsSettingsInitialized via .NET interface
                obj.deviceNET.WaitForSettingsInitialized(obj.TIMEOUTSETTINGS);
            end
            
            if ~obj.deviceNET.IsSettingsInitialized() % Cannot initialise device
                error('Unable to initialise device: S/N %s', obj.serialNumber);
            end
            
            obj.deviceNET.StartPolling(obj.TPOLLING);   % Start polling via .NET interface
            obj.motorSettingsNET = obj.deviceNET.LoadMotorConfiguration(obj.serialNumber); % Get motorSettings via .NET interface
            obj.currentDeviceSettingsNET = obj.deviceNET.MotorDeviceSettings;     % Get currentDeviceSettings via .NET interface
            obj.deviceInfoNET = obj.deviceNET.GetDeviceInfo();                    % Get deviceInfo via .NET interface
            
            enumHandle = genMot.AssemblyHandle.GetType('Thorlabs.MotionControl.GenericMotorCLI.Settings.RotationSettings+RotationDirections');
            if strcmp(direction, 'forward')
                MotDir = enumHandle.GetEnumValues().Get(1); % 1 stands for "Forwards"
            elseif strcmp(direction, 'backward')
                MotDir = enumHandle.GetEnumValues().Get(2); % 2 stands for "Forwards"
            else
                warning('SGRLAB:ThorLabs_DCServoTranslationStage:BadInputArgument','The input %s for direction is not supported. Using "forward"',direction);
                MotDir = enumHandle.GetEnumValues().Get(1); % 1 stands for "Forwards"
            end 
            obj.currentDeviceSettingsNET.Rotation.RotationDirection=MotDir;   % Set motor direction to be 'forwards'
        end
        
        function delete(obj) % Disconnect device     
%             obj.isConnected=obj.deviceNET.IsConnected(); % Update isconnected flag via .NET interface
%             if obj.isConnected
                try
                    obj.deviceNET.StopPolling();  % Stop polling device via .NET interface
                    obj.deviceNET.DisconnectTidyUp();
                    obj.deviceNET.Disconnect();   % Disconnect device via .NET interface
                catch
                    error(['Unable to delete device',obj.serialNumber]);
                end
                obj.isConnected = false;  % Update internal flag to say device is no longer connected
%             else % Cannot disconnect because device not connected
%                 error('Device not connected.')
%             end    
        end
        
        function reset(obj)    % Reset device
            obj.deviceNET.ClearDeviceExceptions();  % Clear exceptions vua .NET interface
            obj.deviceNET.ResetConnection(obj.serialNumber) % Reset connection via .NET interface
        end
        
        function home(obj)              % Home device (must be done before any device move
            workDone=obj.deviceNET.InitializeWaitHandler();     % Initialise Waithandler for timeout
            obj.deviceNET.Home(workDone);                       % Home devce via .NET interface
            obj.deviceNET.Wait(obj.TIMEOUTMOVE);                  % Wait for move to finish
        end
        
        function movetTo(obj,position)     % Move to absolute position
            try
                workDone=obj.deviceNET.InitializeWaitHandler(); % Initialise Waithandler for timeout
                obj.deviceNET.MoveTo(position, workDone);       % Move devce to position via .NET interface
                obj.deviceNET.Wait(obj.TIMEOUTMOVE);              % Wait for move to finish
            catch % Device faile to move
                error(['Unable to Move device ',obj.serialNumber,' to ',num2str(position)]);
            end
        end
        
        function stop(obj) % Stop the motor moving (needed if set motor to continous)
            obj.deviceNET.Stop(obj.TIMEOUTMOVE); % Stop motor movement via.NET interface
        end
        
        function setVelocity(obj, varargin)  % Set velocity and acceleration parameters
            velpars = obj.deviceNET.GetVelocityParams(); % Get existing velocity and acceleration parameters
            switch(nargin)
                case 1  % If no parameters specified, set both velocity and acceleration to default values
                    velpars.MaxVelocity = obj.DEFAULTVEL;
                    velpars.Acceleration = obj.DEFAULTACC;
                case 2  % If just one parameter, set the velocity  
                    velpars.MaxVelocity = varargin{1};
                case 3  % If two parameters, set both velocitu and acceleration
                    velpars.MaxVelocity = varargin{1};  % Set velocity parameter via .NET interface
                    velpars.Acceleration = varargin{2}; % Set acceleration parameter via .NET interface
            end
            if System.Decimal.ToDouble(velpars.MaxVelocity)>25  % Allow velocity to be outside range, but issue warning
                warning('Velocity >25 deg/sec outside specification')
            end
            if System.Decimal.ToDouble(velpars.Acceleration)>25 % Allow acceleration to be outside range, but issue warning
                warning('Acceleration >25 deg/sec2 outside specification')
            end
            obj.deviceNET.SetVelocityParams(velpars); % Set velocity and acceleration paraneters via .NET interface
        end
        
    end
    
    methods
        function isConnected = get.isConnected(obj)
            isConnected = boolean(obj.deviceNET.IsConnected());
        end
        
        function controllerName = get.controllerName(obj)
            controllerName = char(obj.deviceInfoNET.Name);        % update controleller name
        end
        
        function controllerDescription = get.controllerDescription(obj)
            controllerDescription = char(obj.deviceInfoNET.Description);  % update controller description
        end
        
        function stageName = get.stageName(obj)
            stageName = char(obj.motorSettingsNET.DeviceSettingsName);    % update stagename
        end
        
        function acceleration = get.acceleration(obj)
            velocityParams = obj.deviceNET.GetVelocityParams();             % update velocity parameter
            acceleration = System.Decimal.ToDouble(velocityParams.Acceleration); % update acceleration parameter
        end
        
        function maxVelocity = get.maxVelocity(obj)
            velocityParams = obj.deviceNET.GetVelocityParams();             % update velocity parameter
            maxVelocity = System.Decimal.ToDouble(velocityParams.MaxVelocity);   % update max velocit parameter
        end
        
        function minVelocity = get.minVelocity(obj)
            velocityParams = obj.deviceNET.GetVelocityParams();             % update velocity parameter
            minVelocity = System.Decimal.ToDouble(velocityParams.MinVelocity);   % update Min velocity parameter
        end
        
        function position = get.position(obj)
            position = System.Decimal.ToDouble(obj.deviceNET.Position);   % Read current device position
        end
        
        function backlash = get.backlash(obj)
            backlash = System.Decimal.ToDouble(obj.deviceNET.GetBacklash());
        end
    end
end