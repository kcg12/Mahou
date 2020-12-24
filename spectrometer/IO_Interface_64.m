classdef IO_Interface_64 < handle
    
    properties (SetAccess = private)
        dio;
        active;
    end
    
    methods
        
        function obj = IO_Interface_64
            obj.active = 0;
            try 
%                 obj.dio = digitalio('nidaq', 'Dev2');
                obj.dio = daq.createSession('ni');
                obj.active = 1;
            catch
                warning('Spectrometer:DIO', 'Digital I/O module not found.  Entering simulation mode');
            end
            if obj.active
                addDigitalChannel(obj.dio,'Dev2','Port1/Line0','OutputOnly');
%                 addline(obj.dio, 7, 1, 'out');      % Port 1 bit 7
            end
        end
        
        function delete(obj)
            CloseClockGate(obj);
            if obj.active
                delete(obj.dio);
            end
        end

        function OpenClockGate(obj)
            if obj.active
                outputSingleScan(obj.dio, 1)
%                 putvalue(obj.dio.Line(1), 1);
            end
        end
        
        function CloseClockGate(obj)
            if obj.active
                outputSingleScan(obj.dio, 0)
%                 putvalue(obj.dio.Line(1), 0);
            end
        end
        
    end
    
end
            
            
            