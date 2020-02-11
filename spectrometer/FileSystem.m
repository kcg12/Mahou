classdef FileSystem < handle

  properties (SetAccess = private)
    DateString;
    DatePath;
    FileIndex;
    dataDirLocal='C:/data';
    dataDirRemote='c:/Users/INFRARED/Box/data/2dir_data';
    eln;
  end
  properties
    flagSaveLocal=true;
    flagSaveRemote=false;
    flagSaveELN=false;
  end
  
  %hold the instance as a persistent variable
  methods (Static)
    function singleObj = getInstance
      persistent localObj
      if isempty(localObj) || ~isvalid(localObj)
        localObj = FileSystem;
      end
      singleObj = localObj;
    end
  end

  methods (Access = private)

   function obj = FileSystem
      obj.updateParameters;
      try
          obj.eln = labarchivesCallObj('page',obj.DateString);
      catch
          obj.flagSaveELN=false;
      end
          
    end
  end
  
  methods (Access = public)
    
    function Save(obj, data)
        if obj.flagSaveLocal
            obj.SaveLocal(data);
        end
        if obj.flagSaveRemote
            obj.SaveRemote(data);
        end
        if obj.flagSaveELN
            obj.SaveELN(data);
        end
        
        %after saving update the file directory and file count
        %this has the side effect of moving into a new directory after the
        %first save after midnight (sorry)
        obj.updateParameters;
    end
    
    function SaveLocal(obj,data)
        file_name_and_path = sprintf('%s/%3.3d.mat', obj.DatePath, obj.FileIndex);
        save(file_name_and_path, 'data');
    end
    
    function SaveRemote(obj,data)
        file_name_and_path = sprintf('%s/%s/%3.3d.mat',...
            obj.dataDirRemote, obj.DateString, obj.FileIndex);
        dirname =  sprintf('%s/%s',obj.dataDirRemote, obj.DateString);
        if ~exist(dirname, 'file')
            mkdir(dirname);
        end
        
        save(file_name_and_path, 'data');
    end
    
    function SaveELN(obj,data)
        %make sure we are on the right page. If not then udate the page
        if ~strcmp(obj.DateString,obj.eln.page_name)
            %if they are not the same, update
            obj.eln = labarchivesCallObj('page',obj.DateString);
        end
            
        filename = sprintf('%s/%3.3d.mat', obj.DatePath, obj.FileIndex);
        obj.eln=obj.eln.addAttachment(filename);
    end
    
    function SaveTemp(obj, data, counter)
      path = sprintf([obj.dataDirLocal,'/%s/temp/%3.3d-%4.4d.mat'], obj.DateString, obj.FileIndex, counter);
      save(path, 'data');
    end
    
  end
 
  methods (Access = private)
    
    % Note problem: if an exception occurs after some temp files are
    % written but before final files, there will be orphan files.
    % in the temp folder.
    function updateParameters(obj)
      
      % Verify that root data directory structure exists.
      
      if ~exist(obj.dataDirLocal, 'file')
        mkdir(obj.dataDirLocal)
      end
      
      % Verify that folder for today exists

      obj.DateString = datestr(now, 'yyyy-mm-dd');
      obj.DatePath = [obj.dataDirLocal '/' obj.DateString];
      if ~exist(obj.DatePath, 'file')
        mkdir(obj.DatePath);
      end
      dateTmpPath = [obj.DatePath '/temp/'];
      if ~exist(dateTmpPath, 'file')
        mkdir(dateTmpPath);
      end
 
      % Get next file index (run number)
      
      files = dir(obj.DatePath);
      files = {files.name};
      matches = regexp(files, '(^\d+)\.mat', 'tokens');
      matches = matches(~cellfun('isempty',matches));
      
      if isempty(matches)
        obj.FileIndex = 1;
      else
        
        % As to what is going on here.  regexp returns a cell array of
        % cells containing strings, and it was a bit of a bitch to figure
        % out how to get them out of there without resorting to a clumsy
        % for loop.  the cat function indexes each item of the cell array
        % and puts the contents into a string array.  The following line
        % converts them to integers, finds the maximum, and adds one for
        % the next run.
        values = cat(2, matches{1,:});
        values = cat(2, values{1,:});
        obj.FileIndex = max(str2double(values))+1;
      end
      
    end
    
  end
end
