function out = nirs_run_writenirs(job)
%JT
fileout = job.FileOutput;
load(job.NIRSmat{1})     % Matrice NIRS
Session = job.NIRSsession; 
%Big loop over all subjects
if job.NIRS_exportoption == 1 %concatenate file together in one big file 
%% Loop over all nirs.mat file defined 
    for Idx=1:size(job.NIRSmat,1)      
        nbch = numel(NIRS.Cf.H.C.n);
        dall = [];
        if strcmp(Session,'end')
            Sessionid = numel(NIRS.Dt.fir.pp); %prendre la derni�re session
        else
            Sessionid = str2num(Session)
        end
        for i = 1:numel(NIRS.Dt.fir.pp(1,Sessionid).p)
           [pathstr, name, ext] = fileparts(NIRS.Dt.fir.pp(1,Sessionid).p{i});
           nbf = sprintf('%02.0f',i)%nom du fichier data .nir
           d = fopen_NIR([pathstr,filesep,name,ext],nbch);
           dall = [dall,d];
        end 
        fwrite_NIR_JT([pathstr,filesep,fileout,'.nirs'],dall,NIRS);
    end %end for  Big loop over subjects
elseif job.NIRS_exportoption == 2 
    for Idx=1:size(job.NIRSmat,1)      
    nbch = numel(NIRS.Cf.H.C.n);
    dall = [];
    if strcmp(Session,'end')
        Sessionid = numel(NIRS.Dt.fir.pp); %prendre la derni�re session
    else
        Sessionid = str2num(Session)
    end
    for i = 1:numel(NIRS.Dt.fir.pp(1,Sessionid).p)
       [pathstr, name, ext] = fileparts(NIRS.Dt.fir.pp(1,Sessionid).p{i});
       nbf = sprintf('%02.0f',i)%nom du fichier data .nir
       d = fopen_NIR([pathstr,filesep,name,ext],nbch);       
       fwrite_NIR_JT([pathstr,filesep,name,'.nirs'],d,NIRS);
    end 
   
end %end for  Big loop over subjects
end

out.NIRSmat = job.NIRSmat;