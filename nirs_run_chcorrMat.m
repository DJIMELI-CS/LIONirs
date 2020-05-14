function out = nirs_run_chcorrMat(job)
%Look for the correlation matrix ch per ch if we use patch place over same
%brain area or use label per label zone if you brain area are under zone
%definition.


NIRS = []; 


for filenb=1:size(job.NIRSmat,1) %do it one by one for the associate name
    load(job.NIRSmat{filenb,1});
    ML_new= [NIRS.Cf.H.C.id(2:3,:)',...
        ones(size(NIRS.Cf.H.C.id,2),1),...
        [ones(size(NIRS.Cf.H.C.id,2)/2,1);ones(size(NIRS.Cf.H.C.id,2)./2,1).*2]];
    lst = length(NIRS.Dt.fir.pp);
    rDtp = NIRS.Dt.fir.pp(lst).p; % path for files to be processed
    NC = NIRS.Cf.H.C.N;
    filloutput = [job.I_ConnectivityMATName];
    %LOAD LIST CHANNEL
    if isfield(job.b_nodelist,'I_zonecorrlist')         %Zone list
        load(job.b_nodelist.I_zonecorrlist{1},'-mat');
        [bla,filezone,bla1]=fileparts(job.b_nodelist.I_zonecorrlist{1});
        ZoneList = zone.label;
        matcorr = nan(numel(ZoneList),numel(ZoneList),size(rDtp,1)); %zone nb here JT
        matcorrHbR = nan(numel(ZoneList),numel(ZoneList),size(rDtp,1));
    elseif isfield(job.b_nodelist,'I_chcorrlist')       %Channel list
        fid = fopen(job.b_nodelist.I_chcorrlist{1});
        chlist = textscan(fid, '%s%s');
        fclose(fid);
        DetL= chlist{1};
        SrsL= chlist{2};
        name =  DetL{1};
        if numel(name)>1
            if strcmp(name(1:2),'D0')
                Devicename = 'NIRx';
            else
                Devicename  = 'ISS Imagent';
            end
        else
            Devicename  = 'ISS Imagent';
        end
        
        list = zeros(numel(chlist{1}),1);
        for i=1:numel(chlist{1})
            SDdetL = StrBoxy2SDDet_ISS(DetL{i});
            SDsrsL = StrBoxy2SDPairs(SrsL{i});
            switch  Devicename
                case 'ISS Imagent'
                    SDdetL = StrBoxy2SDDet_ISS(DetL{i});
                    SDsrsL = StrBoxy2SDPairs(SrsL{i});
                case 'NIRx'
                    SDdetL = StrBoxy2SDDet(DetL{i});
                    tmp = SrsL{i};
                    SDsrsL =str2num(tmp(2:end));
                case 'NIRS FILE HOMER'
                    SDdetL = StrBoxy2SDDet(DetL{i});
                    tmp = SrsL{i};
                    SDsrsL =str2num(tmp(2:end));
                otherwise
                    SDdetL = StrBoxy2SDDet_ISS(DetL{i});
                    SDsrsL = StrBoxy2SDPairs(SrsL{i});
            end
            
            
            L1 = find(ML_new(:,1)==SDsrsL & ML_new(:,2)==SDdetL & ML_new(:,4)==1);
            L2 = find(ML_new(:,1)==SDsrsL & ML_new(:,2)==SDdetL & ML_new(:,4)==2);
            if isempty(L1)
                sprintf(['check ', DetL{i},' ', SrsL{i}]);
                listname{i,1} = [DetL{i} ' ' SrsL{i}];
                listHBOch(i,1)= 0;
                listHBRch(i,1)= 0;
                listname{i,1} = [DetL{i} ' ' SrsL{i}];
            else
                listHBOch(i,1)= L1;
                listHBRch(i,1)= L2;
                listname{i,1} = [DetL{i} ' ' SrsL{i}];
            end
        end
        %%%
        matcorr = nan(numel(listname),numel(listname),size(rDtp,1));
        matcorrHbR = nan(numel(listname),numel(listname),size(rDtp,1));
    end
    padtime = 0;
    for f=1:size(rDtp,1) %Loop over all files of a NIRS.mat
        d1 = fopen_NIR(rDtp{f,1},NC);
        
         %load the noise marker dnan
            mrk_type = 'bad_step';
            mrk_type_arr = cellstr(mrk_type);
            [dir1,fil1,~] = fileparts(rDtp{f});
            vmrk_path = fullfile(dir1,[fil1 '.vmrk']);
            [ind_dur_ch] = read_vmrk_find(vmrk_path,mrk_type_arr);
            dnan = d1;
            if ~isempty(ind_dur_ch)
                %hwaitbar = waitbar(0);
                for Idx = 1:NC %Loop over all channels
                   % waitbar(Idx/NC,hwaitbar,'Nullifying bad intervals...');
                    mrks = find(ind_dur_ch(:,3)==Idx | ind_dur_ch(:,3)==0);
                    
                    ind = ind_dur_ch(mrks,1);
                    indf = ind + ind_dur_ch(mrks,2);
                    
                    for i = 1:numel(ind)
                        if ind(i)-padtime < 1
                            ind(i) = padtime+1;
                        end
                        if indf(i)+padtime > size(d1,2)
                            indf(i) = size(d1,2)-padtime;
                        end
                        dnan(Idx,ind(i)-padtime:indf(i)+padtime) = NaN;
                    end
                end
                %close(hwaitbar);
             else
                disp(['Failed to nullify bad intervals for Subject ',int2str(filenb),', file ',int2str(f),'. No markers found in the .vmrk file. If you have already used the Step Detection function, your data may have no bad steps in it.']);
            end
        
        
        
        id = 1;
        correctplotLst = 0;
        if isfield(job.b_nodelist,'I_zonecorrlist')
            data = nan(numel(ZoneList)*2,size(d1,2));
            if size(ML_new,1) ~= size(zone.ml,1);
                disp(['List of channel from ', job.NIRSmat{filenb,1},' not concordant with the zone.'])
                correctplotLst = 1;
            else
                if ML_new ~=zone.ml
                    disp(['List of channel from ', job.NIRSmat{filenb,1},' not concordant with the zone.'])
                    correctplotLst = 1;
                end 
            end
            
           
            
            %ensure the zone are with the good channel for the subject it
            %mean always source a1b2 and detector A and the other of
            %channel
            if correctplotLst
                ML_new = ML_new;
                ML_old = zone.ml;
                zoneuse = zone;
                for i = 1:numel(zone.plotLst)
                    plotLst =  zone.plotLst{i};
                    plotLstnew = [];
                    plotold = zone.plot{i};
                    plotnew = [];
                    for indplot = 1:numel(plotLst)
                        a = plotLst(indplot);
                        lista = ML_old(a,:);
                        newid = find(ML_new(:,1) == lista(1) & ML_new(:,2) == lista(2) & ML_new(:,3) == lista(3) & ML_new(:,4) == lista(4));
                        if ~isempty(newid)
                            plotLstnew=[plotLstnew;newid];
                            plotnew = [plotnew;plotold(indplot,:)];
                        end
                    end
                    zoneuse.plotLst{i} = plotLstnew;
                    zoneuse.plot{i}=plotnew;
                end
                
            else
                zoneuse = zone;
            end
            %CHECK ML IN NIRS
            %ML_new %subject ml order must fit with zone ml
            %order
            for i_zone = 1:numel(ZoneList)
                list_izone = zoneuse.plotLst{i_zone};
                chok = NIRS.Cf.H.C.ok(:,f)';
                listtmp = chok(list_izone).*list_izone;
                idbad = find(listtmp==0);
                if ~isempty(idbad)
                    listtmp(idbad)=[];
                end
                if numel(listtmp) > 0
                    data(i_zone,:) = nanmean(d1(listtmp,:));
                    data(i_zone + numel(ZoneList),:) = nanmean(d1(listtmp+numel(ZoneList),:));
                end
                
            end
            d1 = data;
            listHBO  = (1:numel(ZoneList))';
            listHBR  = (listHBO+numel(ZoneList));
            
            
            
        elseif isfield(job.b_nodelist,'I_chcorrlist')       %Channel list  channel
            idabsent = find(listHBOch==0);
            listHBOtmp =listHBOch;
            listHBOtmp( idabsent) = 1;
            idokHBO = NIRS.Cf.H.C.ok(listHBOtmp,f);
            idokHBO(idabsent)=0;
            idabsent = find(listHBRch==0);
            listHBRtmp =listHBRch;
            listHBRtmp( idabsent) = 1;
            idokHBR = NIRS.Cf.H.C.ok(listHBRtmp,f);
            idokHBR(idabsent)=0;
            listHBO = listHBOch;%(idok);
            listHBR = listHBRch;%(idok);
        end
        
        
        
        if isfield(job.I_chcorrlist_type,'b_Pearson')
            if isfield(job.I_chcorrlist_type.b_Pearson.c_Pearson,'m_Pearson') %by segment
            for i=1:numel(listHBO)
                if listHBO(i)
                    j = 1;
                    while j<i %1:numel(listelectrode)
                        if listHBO(j)
                            d1ok = d1(listHBO(i,1),:);
                            d2ok = d1(listHBO(j,1),:);
                            matcorr(i,j,f)=corr(d1ok',d2ok');
                            matcorr(j,i,f)= matcorr(i,j,f);
                        end
                        j = j + 1;
                    end
                end
            end
            
            for i=1:numel(listHBR)
                if listHBR(i)
                    j = 1;
                    while j<i %1:numel(listelectrode)
                        if  listHBO(j)
                            d1ok = d1(listHBR(i,1),:);
                            d2ok = d1(listHBR(j,1),:);
                            matcorrHbR(i,j,f)=corr(d1ok',d2ok');
                            matcorrHbR(j,i,f)= matcorrHbR(i,j,f);
                        end
                        j = j + 1;
                    end
                end
            end
            elseif isfield(job.I_chcorrlist_type.b_Pearson.c_Pearson,'b_PearsonBootstrap') %by segment
                fs = NIRS.Cf.dev.fs;                         % Sample frequency (Hz)
                tseg = job.I_chcorrlist_type.b_Pearson.c_Pearson.b_PearsonBootstrap.i_TrialLenght_crossspectrum;
                t = 0:1/fs:tseg;
                Bsize = numel(t);
                n = size(d1',1);
                p =floor(n/Bsize);
                nb_random_sample = job.I_chcorrlist_type.b_Pearson.c_Pearson.b_PearsonBootstrap.i_RandomSample_crossspectrum;
                indbloc = 1:Bsize:n;
                maxval = n-Bsize;
                idstart=randi(maxval,nb_random_sample,1);
                %definition des blocs on arrete
                for ibloc = 1:numel(idstart)
                    %pstart and pstop for each bloc
                    Bloc(ibloc,:) = [idstart(ibloc), idstart(ibloc)+Bsize];
                end
                
                %donot compute for nanbloc...
            removetrial = [];            
            for ibloc = 1:size(Bloc,1)              
                datnan = dnan(:,Bloc(ibloc,1):Bloc(ibloc,2));
                if sum(isnan(datnan(:)))
                    removetrial = [removetrial,ibloc];    
                 end
            end
            if ~isempty(removetrial)
                Bloc(removetrial,:)=[];
                totaltrialgood = size(Bloc,1);
            else
                totaltrialgood = size(Bloc,1);
            end
                
         for ibloc = 1:size(Bloc,1)
                ibloc                 
                dat = d1(:,Bloc(ibloc,1):Bloc(ibloc,2));
           for i=1:numel(listHBO)
                if listHBO(i)
                    j = 1;
                    while j<i %1:numel(listelectrode)
                        if listHBO(j)
                            d1ok = dat(listHBO(i,1),:);
                            d2ok = dat(listHBO(j,1),:);
                            matcorr(i,j,ibloc)=corr(d1ok',d2ok');
                            matcorr(j,i,ibloc)= matcorr(i,j,ibloc);
                        end
                        j = j + 1;
                    end
                end
            end
            
            for i=1:numel(listHBR)
                if listHBR(i)
                    j = 1;
                    while j<i %1:numel(listelectrode)
                        if  listHBO(j)
                            d1ok = dat(listHBR(i,1),:);
                            d2ok = dat(listHBR(j,1),:);
                            matcorrHbR(i,j,ibloc)=corr(d1ok',d2ok');
                            matcorrHbR(j,i,ibloc)= matcorrHbR(i,j,ibloc);
                        end
                        j = j + 1;
                    end
                end
            end
         
         end
                
            end
                
         %zscore outlier on matcorr matcorrHbR trial distribution ensure no outlier due to forget artifact.            
         meantrial =  nanmean(matcorr(:,:,:),3);
         stdtrial =  nanstd(matcorr(:,:,:),0,3);
         ztrial = (matcorr- repmat( meantrial,1,1,size(matcorr,3)))./repmat( stdtrial,1,1,size(matcorr,3));
          idoutlier =  find(abs(ztrial)>job.I_chcorrlist_type.b_Pearson.c_Pearson.b_PearsonBootstrap.i_OutlierControl_crossspectrum);
         % zscore across trial to detect outlier trial and set them to nan. 
         if ~isempty(idoutlier)
            matcorr(idoutlier)=nan;
         end
         meantrial =  nanmean(matcorrHbR(:,:,:),3)
         stdtrial =  nanstd(matcorrHbR(:,:,:),0,3)
         ztrial = (matcorrHbR- repmat( meantrial,1,1,size(matcorrHbR,3)))./repmat( stdtrial,1,1,size(matcorrHbR,3));
         idoutlier =  find(abs(ztrial)>job.I_chcorrlist_type.b_Pearson.c_Pearson.b_PearsonBootstrap.i_OutlierControl_crossspectrum);
         % zscore across trial to detect outlier trial and set them to nan. 
         if ~isempty(idoutlier)
            matcorrHbR(idoutlier)=nan;
         end
         
         
        elseif isfield(job.I_chcorrlist_type,'b_Hilbert') %hilbert joint probability distribution
            if isfield(job.I_chcorrlist_type.b_Hilbert.c_Hilbert,'m_Hilbert') %by segment       
                hil = hilbert(d1);
                for i=1:numel(listHBO)
                    if listHBO(i)
                        j = 1;
                        while j<i %1:numel(listelectrode)
                            if listHBO(j)
                                z1 = hil(listHBO(i,1),:);
                                z2 = hil(listHBO(j,1),:);
                                % k for join phase distribution see Moldavi 2013
                                matcorr(i,j,f) = circ_kurtosis(angle(z1)'-angle(z2)');
                                matcorr(j,i,f) = matcorr(i,j,f);
                            end
                            j = j + 1;
                        end
                    end
                end
                for i=1:numel(listHBR)
                    if listHBO(i)
                        j = 1;
                        while j<i %1:numel(listelectrode)
                            if listHBO(j)
                                z1 = hil(listHBR(i,1),:);
                                z2 = hil(listHBR(j,1),:);
                                % k for join phase distribution see Moldavi 2013
                                matcorrHbR(i,j,f) = circ_kurtosis(angle(z1)'-angle(z2)');
                                matcorrHbR(j,i,f) = matcorrHbR(i,j,f);
                                j = j + 1;
                            end
                        end
                    end
                end
       
                
            elseif isfield(job.I_chcorrlist_type.b_Hilbert.c_Hilbert,'b_HilbertBootstrap')  %circular bootstrap
                fs = NIRS.Cf.dev.fs;                         % Sample frequency (Hz)
                tseg = job.I_chcorrlist_type.b_Hilbert.c_Hilbert.b_HilbertBootstrap.i_TrialLenght_crossspectrum;
                t = 0:1/fs:tseg;
                Bsize = numel(t);
                n = size(d1',1);
                p =floor(n/Bsize);
                nb_random_sample = job.I_chcorrlist_type.b_Hilbert.c_Hilbert.b_HilbertBootstrap.i_RandomSample_crossspectrum;
                indbloc = 1:Bsize:n;
                maxval = n-Bsize;
                idstart=randi(maxval,nb_random_sample,1);
                %definition des blocs on arrete
                for ibloc = 1:numel(idstart)
                    %pstart and pstop for each bloc
                    Bloc(ibloc,:) = [idstart(ibloc), idstart(ibloc)+Bsize];
                end
                   removetrial = [];            
            for ibloc = 1:size(Bloc,1)              
                datnan = dnan(:,Bloc(ibloc,1):Bloc(ibloc,2));
                if sum(isnan(datnan(:)))
                    removetrial = [removetrial,ibloc];    
                 end
            end
            if ~isempty(removetrial)
                Bloc(removetrial,:)=[];
                totaltrialgood = size(Bloc,1);
            else
                totaltrialgood = size(Bloc,1);
            end
                for ibloc = 1:size(Bloc,1)
                    ibloc
                    tic
                    dat = d1(:,Bloc(ibloc,1):Bloc(ibloc,2));
                   hil = hilbert(dat);
                    for i=1:numel(listHBO)
                        if listHBO(i)
                            j = 1;
                            while j<i %1:numel(listelectrode)
                                if listHBO(j)
                                    z1 = hil(listHBO(i,1),:);
                                    z2 = hil(listHBO(j,1),:);
                                    % k for join phase distribution see Moldavi 2013
                                    matcorr(i,j,ibloc) = circ_kurtosis(angle(z1)'-angle(z2)');
                                    matcorr(j,i,ibloc) = matcorr(i,j,ibloc);
                                end
                                j = j + 1;
                            end
                        end
                    end
                    for i=1:numel(listHBR)
                        if listHBR(i)
                            j = 1;
                            while j<i %1:numel(listelectrode)
                                if listHBO(j)
                                    z1 = hil(listHBR(i,1),:);
                                    z2 = hil(listHBR(j,1),:);
                                    % k for join phase distribution see Moldavi 2013
                                    matcorrHbR(i,j,ibloc) = circ_kurtosis(angle(z1)'-angle(z2)');
                                    matcorrHbR(j,i,ibloc) = matcorrHbR(i,j,ibloc);
                                    j = j + 1;
                                end
                            end
                        end
                    end
                    toc
                    clear dat                    
                end       
                
                %zscore outlier on matcorr matcorrHbR trial distribution ensure no outlier due to forget artifact.
                meantrial =  nanmean(matcorr(:,:,:),3);
                stdtrial =  nanstd(matcorr(:,:,:),0,3);
                ztrial = (matcorr- repmat( meantrial,1,1,size(matcorr,3)))./repmat( stdtrial,1,1,size(matcorr,3));
                idoutlier =  find(abs(ztrial)>job.I_chcorrlist_type.b_Pearson.c_Pearson.b_PearsonBootstrap.i_OutlierControl_crossspectrum);
                % zscore across trial to detect outlier trial and set them to nan.
                if ~isempty(idoutlier)
                    matcorr(idoutlier)=nan;
                end
                meantrial =  nanmean(matcorrHbR(:,:,:),3);
                stdtrial =  nanstd(matcorrHbR(:,:,:),0,3);
                ztrial = (matcorrHbR- repmat( meantrial,1,1,size(matcorrHbR,3)))./repmat( stdtrial,1,1,size(matcorrHbR,3));
                idoutlier =  find(abs(ztrial)>job.I_chcorrlist_type.b_Hilbert.c_Hilbert.b_b_HilbertBootstrap.i_OutlierControl_crossspectrum);
                % zscore across trial to detect outlier trial and set them to nan.
                if ~isempty(idoutlier)
                    matcorrHbR(idoutlier)=nan;
                end                        
            end
            
        elseif isfield(job.I_chcorrlist_type,'b_Granger') %Granger causality
            regmode   = 'OLS';  % VAR model estimation regression mode ('OLS', 'LWR' or empty for default)
            morder = str2num(job.I_chcorrlist_type.b_Granger.enb_Granger);
            ndownsample = str2num(job.I_chcorrlist_type.b_Granger.edownsample_Granger);
            dat = downsample(d1(listHBO,:)',ndownsample);
            [F,A,SIG,E] = GCCA_tsdata_to_pwcgc(dat', morder, regmode);
            matcorr(listHBO,listHBO,f) = F;
            dat = downsample(d1(listHBR,:)',ndownsample);
            [F,A,SIG,E] = GCCA_tsdata_to_pwcgc(dat', morder, regmode);
            matcorrHbR(listHBR,listHBR,f) = F;
            %                         figure
            %                         plot(d1')
            %                         for i=1:morder
            %                         figure
            %                         imagesc(A(:,:,i))
            %                         title(num2str(i))
            %                          caxis([0 1])
            %                         end
            %                         figure
            %                         imagesc(SIG<0.05)
            %                         caxis([0 1])
            %                         figure
            %                         imagesc(F)
            %                         matcorr(j,i,f)
            %                         figure;plot(d1')
            %                for i=1:numel(listHBO)
            %                     j = 1;
            %                     while j<i %1:numel(listelectrode)
            %                         option{id}.matposition = [i,j];
            %                         z1 = d1(listHBO(i,1),:);
            %                         z2 = d1(listHBO(j,1),:);
            %                         [F,c_v] = granger_cause(z1',z2',0.05, 10);
            %                         matcorr(i,j,f) = F;
            %                         matcorr(j,i,f) = F;
            %                         j = j + 1;
            %                         id = id+1;
            %                       end
            %                end
        elseif isfield(job.I_chcorrlist_type, 'b_Phase') %PHASE ISS
            trphase = str2num(job.I_chcorrlist_type.b_Phase.estd_Phase);
            id = find(listHBOch);
            HbObad = find(std(d1(listHBOch(id),:)')>trphase)';
            if ~isempty(HbObad)
                listHBO(id(HbObad)) = 0;
            end
            id = find(listHBRch);
            HbObad = find(std(d1(listHBRch(id),:)')>trphase)';
            if ~isempty( HbObad)
                listHBR(id(HbObad))= 0;
            end
            
            for i=1:numel(listHBO)
                if listHBO(i)
                    j = 1;
                    %figure;hist((z1'-z2')*pi/180)
                    while j<i
                        if listHBO(j)
                            z1 = d1(listHBO(i,1),:);
                            z2 = d1(listHBO(j,1),:);
                            matcorr(i,j,f) = circ_kurtosis((z1'-z2')*pi/180);
                            matcorr(j,i,f) = matcorr(i,j,f);
                        end
                        j = j + 1;
                    end
                end
            end
            
            for i=1:numel(listHBR)
                if listHBR(i)
                    j = 1;
                    while j<i
                        if listHBR(j)
                            z1 = d1(listHBR(i,1),:);
                            z2 = d1(listHBR(j,1),:);
                            matcorrHbR(i,j,f) = circ_kurtosis((z1'-z2')*pi/180);
                            matcorrHbR(j,i,f) = matcorr(i,j,f);
                        end
                        j = j + 1;
                    end
                end
            end
            
        elseif isfield(job.I_chcorrlist_type, 'b_crossspectrum') %FFT autocorelation as analyser...
            %first fft
            fs = NIRS.Cf.dev.fs;                         % Sample frequency (Hz)
            %             if 0 %Matlab fft
            %                 m = size(d1,2);          % Window length
            %                 n = pow2(nextpow2(m));  % Transform length
            %                 y = fft((d1-1)' ,n);           % DFT
            %                 f_fft = (0:n-1)*(fs/n);     % Frequency range
            %                 yfft(:,:,f) = y;
            %             else % Eduardo FFT
            %                 [y, f_fft]= fft_EEGseries(d1,fs);
            %                 yfft(:,:,f) = y;
            %                 n = numel(f_fft)
            %             end
            %            power = y.*conj(y)/n;   % Power of the DFT
            
            tseg = job.I_chcorrlist_type.b_crossspectrum.i_TrialLenght_crossspectrum;
            t = 0:1/fs:tseg;
            Bsize = numel(t);
            n = size(d1',1);
            p =floor(n/Bsize);
            nb_random_sample = job.I_chcorrlist_type.b_crossspectrum.i_RandomSample_crossspectrum;
            indbloc = 1:Bsize:n;
            maxval = n-Bsize;
            idstart=randi(maxval,nb_random_sample,1);
            %definition des blocs on arrete
            for ibloc = 1:numel(idstart)
                %pstart and pstop for each bloc
                Bloc(ibloc,:) = [idstart(ibloc), idstart(ibloc)+Bsize];
            end
            dat = d1(:,Bloc(1,1):Bloc(1,2));
            [y, f_fft]= fft_EEGseries(dat,fs);
            yall = zeros(size(y,1),size(y,2),size(Bloc,1));
            
            %could be more efficient but do the job for now ! 
            removetrial = [];

            for ibloc = 1:size(Bloc,1)
                dat = d1(:,Bloc(ibloc,1):Bloc(ibloc,2));
                dat=dat - mean(dat,2)*ones(1,Bsize+1) ;
                datnan = dnan(:,Bloc(ibloc,1):Bloc(ibloc,2));
                if sum(isnan(datnan(:)))
                    removetrial = [removetrial,ibloc];
                else
                    [y, f_fft]= fft_EEGseries(dat,fs);
                    yall(:,:,ibloc )=y;
                 end
            end
%             t= 1/fs:1/fs:1/fs*size(d1,2)
%             t(Bloc)
            if ~isempty(removetrial)
                yall(:,:,removetrial)=[];
                totaltrialgood = size(yall,3);
            else
                totaltrialgood = size(yall,3);
            end
            %Load zone for display spectrum
            load(job.I_chcorrlist_type.b_crossspectrum.i_ch_crossspectrum{1},'-mat');
            
            power = yall.*conj(yall)/n;
            
            matcorr= nan(numel(listname),numel(listname),1);
            matcorrHbR= nan(numel(listname),numel(listname),1);
            freq = job.I_chcorrlist_type.b_crossspectrum.i_Freq_crossspectrum;
            startF =sum(f_fft<=freq(1));
            stopF  =sum(f_fft<=freq(end));
            
            % Outlier zscore by ch and fr
            for ich = 1:size(power,2)%channel
                removetrial = zeros(size(power,3),1);
                for ifr=startF:stopF%freq
                    list =find(abs(zscore(power(ifr,ich,:)))>job.I_chcorrlist_type.b_crossspectrum.i_OutlierControl_crossspectrum );
                    if ~isempty(list)
                        removetrial(list)=1;
                    end
                end
                idbad = find(removetrial);
                yall(startF:stopF,ich, idbad)=nan;
            end
            
            ML_new = ML_new;
            ML_old = zone.ml;
            zoneuse = zone;
            for i = 1:numel(zone.plotLst)
                plotLst =  zone.plotLst{i};
                plotLstnew = [];
                plotold = zone.plot{i};
                plotnew = [];
                for indplot = 1:numel(plotLst)
                    a = plotLst(indplot);
                    lista = ML_old(a,:);
                    newid = find(ML_new(:,1) == lista(1) & ML_new(:,2) == lista(2) & ML_new(:,3) == lista(3) & ML_new(:,4) == lista(4));
                    if ~isempty(newid)
                        plotLstnew=[plotLstnew;newid];
                        plotnew = [plotnew;plotold(indplot,:)];
                    end
                end
                zoneuse.plotLst{i} = plotLstnew;
                zoneuse.plot{i}=plotnew;
            end
            maxval = max(max(nanmean(log10(power(2:end,:,:)),3)))+2;
            minval =  min(min(nanmean(log10(power(2:end,:,:)),3)))-2;
            power = yall.*conj(yall)/n;
            zonelist = 1:numel(zone.plotLst);
            hplot = figure;
            for izone=1:numel(zonelist)
                subplot(ceil(sqrt(numel(zone.plotLst))),ceil(sqrt(numel(zone.plotLst))),izone);hold on
                list =  zoneuse.plotLst{zonelist(izone)};
                colorlst= jet(numel(list));
                for i=1:numel(list)
                    sumnan = sum(sum(isnan(power(:,list(i),:)),3),1);
                    if strcmp(NIRS.Cf.dev.n,'ISS')
                        srs = SDPairs2strboxy_ISS(ML_new(list(i),1));
                        det = SDDet2strboxy_ISS(ML_new(list(i),2));
                    else
                        srs = SDPairs2strboxy(ML_new(list(i),1));
                        det = SDDet2strboxy(ML_new(list(i),2));
                    end
                    plot(f_fft,nanmean(log10(power(:,list(i),:)),3),'color',colorlst(i,:),'displayname',[srs,'_',det,' ',num2str(sumnan)]);
                    ylim([minval,maxval]);
                    plot([f_fft(startF),f_fft(startF)],[minval,maxval],'r')
                    plot([f_fft(stopF),f_fft(stopF)],[minval,maxval],'r')
                end
                title(zoneuse.label{zonelist(izone)})
            end
            avgfft = nanmean(nanmean(log10(power(startF:stopF,:,:)),3),2);
            interval  = startF:stopF;
            [val,id] = max(avgfft);
            tablepeak(f,1) = f_fft(interval(id));
            %             figure
            %
            %              plot(f_fft(startF:stopF),avgfft,'color',colorlst(i,:),'displayname',[srs,'_',det,' ',num2str(sumnan)]);
            %
            
            pathout = job.I_chcorrlistoutpath;
            if ~isdir(pathout)
                mkdir(pathout);
            end
            saveas(hplot,  [pathout,filloutput,sprintf('%03.0f', f),'FFTPLOT.fig'],'fig')
            saveas(hplot,  [pathout,filloutput,sprintf('%03.0f', f),'FFTPLOT.jpg'],'jpg')
            if job.I_chcorrlist_type.b_crossspectrum.m_savefft_crossspectrum
                save([pathout,filloutput,'ComplexFFT.mat'],'yall','f_fft','listHBOch','listHBRch','ML_new','Bloc','ZoneList')
            end
            %close(hplot)
            
            for i=1:numel(listHBO)
                if listHBO(i)
                    j = 1;
                    in1 =  nanmean(yall(startF:stopF,listHBO(i),:),1);
                    while j<i
                        if listHBO(j)
                            in2 = nanmean(yall(startF:stopF ,listHBO(j),:),1);
                            COVC1C2  = nansum(in1.*conj(in2),3);
                            COVC1 =nansum(in1.*conj(in1),3);
                            COVC2 =nansum(in2.*conj(in2),3);
                            matcorr(i,j,f) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                            matcorr(j,i,f) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                            id = id+1;
                            if 0% listHBO(i) ==3
                                figure;
                                subplot(2,2,1)
                                plot(squeeze(nanmean(yall(startF:stopF ,listHBO(i),:),1)),'x');
                                vallim = max([real(squeeze(nanmean(yall(startF:stopF ,listHBO(i),:),1)));imag(squeeze(nanmean(yall(startF:stopF ,listHBO(i),:),1)))]);
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                                title(['CH',num2str(listHBO(i))])
                                subplot(2,2,2)
                                plot(squeeze(nanmean(yall(startF:stopF ,listHBO(j),:),1)),'x');
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                                
                                title(['CH',num2str(listHBO(j))])
                                subplot(2,2,3);hold on
                                plot(squeeze(in1.*conj(in2)),'x')
                                vallim = max([real(squeeze(in1.*conj(in2)));imag(squeeze(in1.*conj(in2)))])
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                                subplot(2,2,4)
                                plot([0,real(COVC1C2)./ (COVC1.*COVC2)], [0, imag(COVC1C2)./ (COVC1.*COVC2)])
                                val = abs(COVC1C2).^2 ./ (COVC1.*COVC2)
                                title([ num2str(val)])
                                vallim = max(abs([0,real(COVC1C2)./ (COVC1.*COVC2),  imag(COVC1C2)./ (COVC1.*COVC2)]));
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                            end
                        end
                        j = j + 1;
                    end
                end
            end
            
            for i=1:numel(listHBR)
                if listHBR(i)
                    j = 1;
                    in1 =  nanmean(yall(startF:stopF,listHBR(i),:),1);
                    while j<i %1:numel(listelectrode)
                        if listHBR(j)
                            in2 = nanmean(yall(startF:stopF ,listHBR(j),:),1);
                            COVC1C2  = nansum(in1.*conj(in2),3);
                            COVC1 =nansum(in1.*conj(in1),3);
                            COVC2 =nansum(in2.*conj(in2),3);
                            matcorrHbR(i,j,f) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                            matcorrHbR(j,i,f) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                            id = id+1;
                        end
                        j = j + 1;
                    end
                end
            end
        elseif 0 %test fft by bloc....
            
            %first fft
            fs = NIRS.Cf.dev.fs;                         % Sample frequency (Hz)
            %             if 0 %Matlab fft
            %                 m = size(d1,2);          % Window length
            %                 n = pow2(nextpow2(m));  % Transform length
            %                 y = fft((d1-1)' ,n);           % DFT
            %                 f_fft = (0:n-1)*(fs/n);     % Frequency range
            %                 yfft(:,:,f) = y;
            %             else % Eduardo FFT
            %                 [y, f_fft]= fft_EEGseries(d1,fs);
            %                 yfft(:,:,f) = y;
            %                 n = numel(f_fft)
            %             end
            %            power = y.*conj(y)/n;   % Power of the DFT
            
            tseg = job.I_chcorrlist_type.b_crossspectrum.i_TrialLenght_crossspectrum;
            t = 0:1/fs:tseg;
            Bsize = numel(t);
            n = size(d1',1);
            p =floor(n/Bsize);
            nb_random_sample = job.I_chcorrlist_type.b_crossspectrum.i_RandomSample_crossspectrum;
            indbloc = 1:Bsize:n;
            maxval = n-Bsize;
            
            dat = d1; %whole bloc as is already segmented
            [y, f_fft]= fft_EEGseries(d1,fs);
            % yall = zeros(size(y,1),size(y,2));
            
            %             removetrial = [];
            %             for ibloc = 1:size(Bloc,1)
            %                 dat = d1(:,Bloc(ibloc,1):Bloc(ibloc,2));
            %                 dat=dat - mean(dat,2)*ones(1,Bsize+1) ;
            %                 if sum(isnan(dat(:)))
            %                     removetrial = [removetrial,ibloc];
            %                 else
            %                     [y, f_fft]= fft_EEGseries(dat,fs);
            %                     yall(:,:,ibloc)=y;
            %                 end
            %             end
            %             if ~isempty(removetrial)
            %                 yall(:,:,removetrial)=[];
            %                 totaltrialgood = size(yall,3);
            %             else
            %                 totaltrialgood = size(yall,3);
            %             end
            
            yall=y
            power = yall.*conj(yall)/n;
            
            matcorr= nan(numel(listname),numel(listname),1);
            matcorrHbR= nan(numel(listname),numel(listname),1);
            freq = job.I_chcorrlist_type.b_crossspectrum.i_Freq_crossspectrum;
            startF =sum(f_fft<=freq(1));
            stopF  =sum(f_fft<=freq(end));
            
            %             % Outlier zscore by ch and fr
            %             for ich = 1:size(power,2)%channel
            %                 removetrial = zeros(size(power,3),1);
            %                 for ifr=startF:stopF%freq
            %                     list =find(abs(zscore(power(ifr,ich,:)))>job.I_chcorrlist_type.b_crossspectrum.i_OutlierControl_crossspectrum );
            %                     if ~isempty(list)
            %                         removetrial(list)=1;
            %                     end
            %                 end
            %                 idbad = find(removetrial);
            %                 yall(startF:stopF,ich, idbad)=nan;
            %             end
            %Load zone for display spectrum
            load(job.I_chcorrlist_type.b_crossspectrum.i_ch_crossspectrum{1},'-mat');
            ML_new = ML_new;
            ML_old = zone.ml;
            zoneuse = zone;
            for i = 1:numel(zone.plotLst)
                plotLst =  zone.plotLst{i};
                plotLstnew = [];
                plotold = zone.plot{i};
                plotnew = [];
                for indplot = 1:numel(plotLst)
                    a = plotLst(indplot);
                    lista = ML_old(a,:);
                    newid = find(ML_new(:,1) == lista(1) & ML_new(:,2) == lista(2) & ML_new(:,3) == lista(3) & ML_new(:,4) == lista(4));
                    if ~isempty(newid)
                        plotLstnew=[plotLstnew;newid];
                        plotnew = [plotnew;plotold(indplot,:)];
                    end
                end
                zoneuse.plotLst{i} = plotLstnew;
                zoneuse.plot{i}=plotnew;
            end
            maxval = max(max(nanmean(log10(power(2:end,:,:)),3)))+2;
            minval =  min(min(nanmean(log10(power(2:end,:,:)),3)))-2;
            power = yall.*conj(yall)/n;
            
            zonelist = 1:numel(zone.plotLst);
            hplot = figure;
            for izone=1:numel(zonelist)
                subplot(ceil(sqrt(numel(zone.plotLst))),ceil(sqrt(numel(zone.plotLst))),izone);hold on
                list =  zoneuse.plotLst{zonelist(izone)};
                colorlst= jet(numel(list));
                for i=1:numel(list)
                    sumnan = sum(sum(isnan(power(:,list(i),:)),3),1);
                    if strcmp(NIRS.Cf.dev.n,'ISS')
                        srs = SDPairs2strboxy_ISS(ML_new(list(i),1));
                        det = SDDet2strboxy_ISS(ML_new(list(i),2));
                    else
                        srs = SDPairs2strboxy(ML_new(list(i),1));
                        det = SDDet2strboxy(ML_new(list(i),2));
                    end
                    plot(f_fft,nanmean(log10(power(:,list(i),:)),3),'color',colorlst(i,:),'displayname',[srs,'_',det,' ',num2str(sumnan)]);
                    %ylim([minval,maxval]);
                    plot([f_fft(startF),f_fft(startF)],[minval,maxval],'r')
                    plot([f_fft(stopF),f_fft(stopF)],[minval,maxval],'r')
                end
                title(zoneuse.label{zonelist(izone)})
            end
            
            pathout = job.I_chcorrlistoutpath;
            if ~isdir(pathout)
                mkdir(pathout);
            end
            saveas(hplot,  [pathout,filloutput,sprintf('03.0f', f),'FFTPLOT.fig'],'fig')
            saveas(hplot,  [pathout,filloutput,sprintf('03.0f', f),'FFTPLOT.jpg'],'jpg')
            if job.I_chcorrlist_type.b_crossspectrum.m_savefft_crossspectrum
                save([pathout,filloutput,'ComplexFFT.mat'],'yall','f_fft','listHBOch','listHBRch','ML_new','Bloc','ZoneList')
            end
            %close(hplot)
            figure
            subplot(2,1,1)
            plot(f_fft(3:end),abs(yall(3:end,listHBO(i),:)*1000  .* conj(yall(3:end,listHBO(25),:)))*1000.^2)
            subplot(2,1,2);hold on;plot(d1(listHBO(i),:),'r');plot(d1(listHBO(j),:),'b')
            for i=1:numel(listHBO)
                if listHBO(i)
                    j = 1;
                    in1 =  nanmean(yall(startF:stopF,listHBO(i),:),1)*1000;
                    while j<i
                        if listHBO(j)
                            in2 = nanmean(yall(startF:stopF ,listHBO(j),:),1)*1000;
                            if 0
                                figure;subplot(2,2,1);hold on; plot(real(in1),imag(in1),'xr'), plot(real(in2),imag(in2),'xb')
                                xlim([-1,1])
                                ylim([-1,1])
                                subplot(2,2,2);hold on
                                plot(d1(listHBO(i),:),'r')
                                plot(d1(listHBO(j),:),'b')
                            end
                            
                            COVC1C2  = nansum(in1.*conj(in2),3);
                            COVC1 =nansum(in1.*conj(in1),3);
                            COVC2 =nansum(in2.*conj(in2),3);
                            matcorr(i,j,:) = abs(COVC1C2).^2 % ./ (COVC1.*COVC2);
                            matcorr(j,i,:) = abs(COVC1C2).^2  %./ (COVC1.*COVC2);
                            id = id+1;
                            if 0% listHBO(i) ==3
                                figure;
                                subplot(2,2,1)
                                plot(squeeze(nanmean(yall(startF:stopF ,listHBO(i),:),1)),'x');
                                vallim = max([real(squeeze(nanmean(yall(startF:stopF ,listHBO(i),:),1)));imag(squeeze(nanmean(yall(startF:stopF ,listHBO(i),:),1)))]);
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                                title(['CH',num2str(listHBO(i))])
                                subplot(2,2,2)
                                plot(squeeze(nanmean(yall(startF:stopF ,listHBO(j),:),1)),'x');
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                                
                                title(['CH',num2str(listHBO(j))])
                                subplot(2,2,3);hold on
                                plot(squeeze(in1.*conj(in2)),'x')
                                vallim = max([real(squeeze(in1.*conj(in2)));imag(squeeze(in1.*conj(in2)))])
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                                subplot(2,2,4)
                                plot([0,real(COVC1C2)./ (COVC1.*COVC2)], [0, imag(COVC1C2)./ (COVC1.*COVC2)])
                                val = abs(COVC1C2).^2 ./ (COVC1.*COVC2)
                                title([ num2str(val)])
                                vallim = max(abs([0,real(COVC1C2)./ (COVC1.*COVC2),  imag(COVC1C2)./ (COVC1.*COVC2)]));
                                xlim([- vallim,  vallim])
                                ylim([- vallim,  vallim])
                            end
                        end
                        j = j + 1;
                    end
                end
            end
            subplot(2,2,3);imagesc(abs(matcorr))
            caxis([0,1])
            for i=1:numel(listHBR)
                if listHBR(i)
                    j = 1;
                    in1 =  nanmean(yall(startF:stopF,listHBR(i),:),1);
                    while j<i %1:numel(listelectrode)
                        if listHBR(j)
                            in2 = nanmean(yall(startF:stopF ,listHBR(j),:),1);
                            COVC1C2  = nansum(in1.*conj(in2),3);
                            COVC1 =nansum(in1.*conj(in1),3);
                            COVC2 =nansum(in2.*conj(in2),3);
                            matcorrHbR(i,j,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                            matcorrHbR(j,i,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                            id = id+1;
                        end
                        j = j + 1;
                    end
                end
            end
            
            
        elseif isfield(job.I_chcorrlist_type, 'b_waveletcluster')
            nmax = size(d1,2);
            fs = NIRS.Cf.dev.fs;
            t = 1/fs:1/fs:(1/fs*nmax);
            tstart = str2num(job.I_chcorrlist_type.b_waveletcluster.e_startwaveletcluster);
            tstop = str2num(job.I_chcorrlist_type.b_waveletcluster.e_stopwaveletcluster);
            idwindow = find(t> tstart & t<tstop);
            if 0
                St = d1(listHBO,idwindow); %prendre segment pour wavelet
                figure;plot(St')
                
                %from Thierry Beausoleil
                Args.dt = t(2)-t(1);
                Args.Pad = 1;
                Args.Dj = 0.0833;
                Args.J1 = 113;
                Args.Mother = 'Morlet';
                Args.S0 = 2*Args.dt;
                Args.tRatio = 1;
                TFR = zeros(Args.J1+1 ,size(St,2),size(St,1));
                sTFR = zeros(Args.J1+1 ,size(St,2),size(St,1));       %smoothwavelet and power
                %time x layer x ch
                for i=1:size(St,1)
                    i
                    Sig1Seg= St(i,:);
                    [TFR(:,:,i),period,scale,coix]  =wavelet(Sig1Seg,Args.dt ,Args.Pad,Args.Dj,Args.S0,Args.J1,Args.Mother);%#ok
                    if i==1
                        sinv=1./(scale');
                    end
                    [sTFR(:,:,i)] = smoothwavelet(sinv(:,ones(1,size(TFR,2))).*abs(TFR(:,:,i)).^2,Args.dt,period,Args.Dj,scale);
                end
                Args.period = period;
                Args.scale = scale;
                Args.coix = coix;
            else
                
                
                parameter.Fs = fs;
                parameter.width = 3;
                parameter.layer =job.I_chcorrlist_type.b_waveletcluster.i_Freq_crossspectrum;
                paddingsym = 1;
                if paddingsym
                    dtmp = [fliplr( d1(listHBO,idwindow)), d1(listHBO,idwindow),fliplr( d1(listHBO,idwindow))];
                    tstart = size( d1(listHBO,idwindow),2)+1;
                    tstop = size (d1(listHBO,idwindow),2)*2;
                    %figure;plot(dtmp')
                    d = dtmp;
                    St = dtmp;
                else
                    St =d1(listHBO,idwindow);
                end
                TFRtmp =  morletcwtEd(St',  parameter.layer ,parameter.Fs,  parameter.width);
                if paddingsym
                    TFR = TFRtmp(tstart:tstop,:,:);
                end
                id = 1;
                for i=1:size(TFR,3)
                    j = 1;
                    while j<i
                        Gxy(:,1,id) = TFR(:,1,i).*conj(TFR(:,1,j));
                        id = id + 1;
                        j = j+1;
                    end
                end
                %figure;plot(t(idwindow),abs(squeeze(Gxy(:,1,:))))
                hfig=figure;
                subplot(2,1,1)
                plot(t(idwindow),abs(squeeze(Gxy(:,1,:))))
                %figure;plot(squeeze(Gxy(:,1,:)))
                samplemat = 1:size(Gxy,1);
                %figure; imagesc(abs(TFR(:,:,3)))
                for i=1:size(TFR,3)
                    j = 1;
                    in1 =  TFR(samplemat ,:,i);
                    in1 = in1(:);
                    
                    while j<i
                        in2 =  TFR(samplemat ,:,j);
                        in2 = in2(:);
                        COVC1C2  = nansum(in1.*conj(in2),1);
                        COVC1 =nansum(in1.*conj(in1),1);
                        COVC2 =nansum(in2.*conj(in2),1);
                        matcorrHbO(i,j,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                        matcorrHbO(j,i,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                        if 0
                            figure;
                            subplot(2,2,1)
                            plot(squeeze(in1),'x');
                            vallim = max([real(squeeze(in1));imag(squeeze(in1))]);
                            xlim([- vallim,  vallim])
                            ylim([- vallim,  vallim])
                            title(['CH',num2str(i)])
                            subplot(2,2,2)
                            plot(squeeze(in2),'x');
                            xlim([- vallim,  vallim])
                            ylim([- vallim,  vallim])
                            
                            title(['CH',num2str(j)])
                            subplot(2,2,3);hold on
                            plot(squeeze(in1.*conj(in2)),'x')
                            vallim = max([real(squeeze(in1.*conj(in2)));imag(squeeze(in1.*conj(in2)))])
                            xlim([- vallim,  vallim])
                            ylim([- vallim,  vallim])
                            subplot(2,2,4)
                            plot([0,real(COVC1C2)./ (COVC1.*COVC2)], [0, imag(COVC1C2)./ (COVC1.*COVC2)])
                            val = abs(COVC1C2).^2 ./ (COVC1.*COVC2)
                            title([ num2str(val)])
                            vallim = max(abs([0,real(COVC1C2)./ (COVC1.*COVC2),  imag(COVC1C2)./ (COVC1.*COVC2)]));
                            xlim([- vallim,  vallim])
                            ylim([- vallim,  vallim])
                        end
                        j = j + 1;
                    end
                end
                subplot(2,2,3);imagesc(matcorrHbO)
                
                if paddingsym
                    dtmp = [fliplr( d1(listHBR,idwindow)), d1(listHBO,idwindow),fliplr( d1(listHBO,idwindow))];
                    tstart = size( d1(listHBR,idwindow),2)+1;
                    tstop = size (d1(listHBR,idwindow),2)*2;
                    %figure;plot(dtmp')
                    d = dtmp;
                    St = dtmp;
                else
                    St =d1(listHBR,idwindow);
                end
                TFR =  morletcwtEd(St',  parameter.layer ,parameter.Fs,  parameter.width);
                for i=1:size(TFR,3)
                    j = 1;
                    in1 =  TFR(:,:,i);
                    in1 = in1(:);
                    while j<i
                        in2 =  TFR(:,:,j);
                        in2 = in2(:);
                        COVC1C2  = nansum(in1.*conj(in2),1);
                        COVC1 =nansum(in1.*conj(in1),1);
                        COVC2 =nansum(in2.*conj(in2),1);
                        matcorrHbR(i,j,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                        matcorrHbR(j,i,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                        j = j + 1;
                    end
                end
                
            end
            % subplot(2,2,4);imagesc(matcorrHbR)
        end
        if 0 %isfield(job.I_chcorrlist_type, 'b_crossspectrum')
            matcorr =zeros(numel(listHBO),numel(listHBO),size(yfft,1));
            matcorrHBR =zeros(numel(listHBR),numel(listHBR),size(yfft,1));
            
            
            for i=1:numel(listHBO)
                j = 1;
                while j<i %1:numel(listelectrode)
                    option{id}.matposition = [i,j];
                    C1= squeeze(yfft(:,listHBO(i),:));
                    C2= squeeze(yfft(:,listHBO(j),:));
                    in1=C1-repmat(mean(C1,2),[1, size(C1,2)]) ;
                    in2=C2-repmat(mean(C2,2),[1, size(C2,2)]);
                    COVC1C2  = sum(in1.*conj(in2),2);
                    COVC1 =sum(in1.*conj(in1),2);
                    COVC2 =sum(in2.*conj(in2),2);
                    matcorr(i,j,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                    COVC2C1  = sum(in2.*conj(in1),2);
                    matcorr(j,i,:) =  abs(COVC2C1).^2 ./ (COVC1.*COVC2);
                    j = j + 1;
                    id = id+1;
                end
            end
            for i=1:numel(listHBR)
                j = 1;
                while j<i %1:numel(listelectrode)
                    option{id}.matposition = [i,j];
                    C1= squeeze(yfft(:,listHBR(i),:));
                    C2= squeeze(yfft(:,listHBR(j),:));
                    in1=C1-repmat(mean(C1,2),[1, size(C1,2)]) ;
                    in2=C2-repmat(mean(C2,2),[1, size(C2,2)]);
                    COVC1C2  = sum(in1.*conj(in2),2);
                    COVC1 =sum(in1.*conj(in1),2);
                    COVC2 =sum(in2.*conj(in2),2);
                    matcorrHBR(i,j,:) = abs(COVC1C2).^2 ./ (COVC1.*COVC2);
                    COVC2C1  = sum(in2.*conj(in1),2);
                    matcorrHBR(j,i,:) =  abs(COVC2C1).^2 ./ (COVC1.*COVC2);
                    j = j + 1;
                    id = id+1;
                end
            end
            
            
            LIST = job.I_chcorrlist_type.b_crossspectrum.i_Freq_crossspectrum;
            
            %PLOT MATRIX ON PEAK TO CHECK !
            %figure
            %idpeak= sum(f_fft<=0.39)
            %imagesc(matcorr(:,:,idpeak))
            %title(num2str(f_fft(idpeak)))
            %figure
            %imagesc(matcorr(:,:,128))
            %title(num2str(f_fft(128)))
            
            %PLOT POWER ONE EVENT ALL CHANNEL !
            
            
            y = yfft(:,:,1);
            power = y.*conj(y)/n;   % Power of the DFT
            figure
            subplot(3,1,1)
            plot(f_fft,power)
            title('FFT power')
            
            for ifreq=1:size(matcorr,3)
                tot(ifreq) = sum(sum(matcorr(:,:,ifreq)))/numel(matcorr(:,:,ifreq))
            end
            subplot(3,1,2)
            plot(f_fft,tot);hold on
            plot(f_fft(LIST),tot(LIST),'x','markersize',4,'color','r','linewidth',6)
            title('Autospectrum avg')
            subplot(3,1,3)
            plot(tot);hold on
            plot(LIST,tot(LIST),'x','markersize',4,'color','r','linewidth',6)
            
        end
    end
    
    
    
    %         %OUTLIER DETECTION PEARSON ONLY
    %         isfield(job.I_chcorrlist_type,'b_Pearson')
    %         if  option_menu==2 % zscore outlier automatic rejection.
    %             zscorematcorr = nan(size(matcorr));
    %             for i=1:size(matcorr,3)
    %                zscorematcorr(:,:,i) =  (matcorr(:,:,i) - nanmean(matcorr,3))./nanstd(matcorr,1,3);
    %             end
    %             idout = find(abs(zscorematcorr)>3.19);
    %             matcorr(idout) = nan;
    %         end
    [path, fname, extension]=fileparts(job.NIRSmat{filenb,1});
    pathout = job.I_chcorrlistoutpath;
    if ~isdir(pathout)
        mkdir(pathout)
    end
    
    
    if isfield(job.b_nodelist,'I_zonecorrlist')
        ZoneList = [];
        plottmp=[];
        plotLst = [];
        for izoneList = 1:size(matcorr,2)
            MLfake(izoneList,1) = izoneList;%source
            MLfake(izoneList,2) = 1; %detecteur
            MLfake(izoneList,3) = 1;
            MLfake(izoneList,4) = 1;
            strDet = SDDet2strboxy_ISS(MLfake(izoneList,2));
            strSrs = SDPairs2strboxy_ISS(MLfake(izoneList,1));
            ZoneLabel{izoneList,1}=zoneuse.label{izoneList};
            ZoneList{izoneList,1} = [strDet,' ', strSrs];
            plottmp{izoneList} = [izoneList,1];
            plotLst{izoneList} = [izoneList];
        end
        %save zone list associate
        zone.plot = plottmp;
        zone.plotLst = plotLst;
        zone.label = ZoneLabel;
        zone.color = zone.color;
        zone.ml = MLfake;
        zone.chMAT = plotLst;
        save(fullfile(pathout,['avg',filezone,'.zone']),'zone','-mat')
    elseif isfield(job.b_nodelist,'I_chcorrlist')       %Channel list
        ZoneList  = listname;
    end
    %add nan on row with rejected channel
    idbad = find( idokHBO==0);
    matcorr(idbad,:,:) = nan;
    matcorr(:,idbad,:) = nan;
    meancorr=nanmean(matcorr,3);
    idbad = find(idokHBR==0);
    matcorrHbR(idbad,:,:) = nan;
    matcorrHbR(:,idbad,:) = nan;
    meancorrHbR=nanmean(matcorrHbR,3);
    
    
    
    if isfield(job.I_chcorrlist_type,'b_Pearson')
        if 0 % job.I_chcorrlist_type.b_Pearson.m_Pearson == 2 %fisher transform on the data
            meancorr =  1/2*(log((1+nanmean(meancorr,3))./(1-nanmean(meancorr,3))));
            meancorrHbR =  1/2*(log((1+nanmean(meancorrHbR,3))./(1-nanmean(meancorrHbR,3))));
        end
        
        save(fullfile(pathout,[filloutput,'_HBO','_Pearson','.mat']),'ZoneList','matcorr','meancorr');
        matcorr = matcorrHbR; meancorr = meancorrHbR;
        save(fullfile(pathout,[filloutput,'_HBR','_Pearson','.mat']),'ZoneList','matcorr','meancorr');
    elseif isfield(job.I_chcorrlist_type,'b_Hilbert')
        save(fullfile(pathout,[filloutput,'_HBO','_Hilbert','.mat']),'ZoneList','matcorr','meancorr');
        matcorr = matcorrHbR; meancorr = meancorrHbR;
        save(fullfile(pathout,[filloutput,'_HBR','_Hilbert','.mat']),'ZoneList','matcorr','meancorr');
    elseif isfield(job.I_chcorrlist_type,'b_Granger')
        save(fullfile(pathout,[filloutput,'_HBO','_MVARGranger','.mat']),'ZoneList','matcorr','meancorr');
        matcorr = matcorrHbR; meancorr = meancorrHbR;
        save(fullfile(pathout,[filloutput,'_HBR','_MVARGranger','.mat']),'ZoneList','matcorr','meancorr');
    elseif isfield(job.I_chcorrlist_type, 'b_Phase')
        save(fullfile(pathout,[filloutput,'_HBO','_PH_ISS','.mat']),'ZoneList','matcorr','meancorr');
        matcorr = matcorrHbR; meancorr = meancorrHbR;
        save(fullfile(pathout,[filloutput,'_HBR','_PH_ISS','.mat']),'ZoneList','matcorr','meancorr');
    elseif  isfield(job.I_chcorrlist_type, 'b_crossspectrum')
        
        %         matcorrfft = matcorr;
        %         for i=1:numel(LIST)
        %             f_fft(LIST(i))
        %             matcorr = matcorrfft(:,:,LIST(i));
        %             meancorr = matcorrfft(:,:,LIST(i));
        %             save(fullfile(pathout,[filloutput,'_HBO','_COHERENCE FFT',  sprintf('%02.2f',f_fft(LIST(i))),'Hz.mat']),'ZoneList','matcorr','meancorr');
        %             matcorr = matcorrHBR(:,:,LIST(i));
        %             meancorr = matcorrHBR(:,:,LIST(i));
        %             save(fullfile(pathout,[filloutput,'_HBR','_COHERENCE FFT',  sprintf('%02.2f',f_fft(LIST(i))),'Hz.mat']),'ZoneList','matcorr','meancorr');
        %         end
        %                  if job.I_chcorrlist_type.b_Pearson.m_Pearson == 2 %fisher transform on the data
        %             meancorr =  1/2*(log((1+nanmean(meancorr,3))./(1-nanmean(meancorr,3))));
        %             meancorrHbR =  1/2*(log((1+nanmean(meancorrHbR,3))./(1-nanmean(meancorrHbR,3))));
        

        RecordDevice = NIRS.Cf.dev.n;
        save(fullfile(pathout,[filloutput,'_HBO','_COH FFT','.mat']),'ZoneList','matcorr','meancorr', 'totaltrialgood'  );
        matcorr = matcorrHbR; meancorr = meancorrHbR;
        save(fullfile(pathout,[filloutput,'_HBR','_COH FFT','.mat']),'ZoneList','matcorr','meancorr', 'totaltrialgood' );
        save(fullfile(pathout,[filloutput,'peakfft','.mat']), 'tablepeak', '-mat')
    elseif isfield(job.I_chcorrlist_type, 'b_waveletcluster')
        %CLUSTER MATHIEU  wavelet
        %         Args.ZoneList = ZoneList;
        %          Args.pathout = pathout;
        %          Args.filloutput = filloutput;
        %          TFR = TFR(:,:,listHBO);
        %          sTFR = sTFR(:,:,listHBO);
        %          save(fullfile(pathout,['WAV_' filloutput,'_HBO.mat']), 'TFR', 'sTFR','Args','job')
        
        %wavelet Eduardo sum...
        matcorr = matcorrHbO;
        meancorr = matcorrHbO;
        save(fullfile(pathout,[filloutput,'_HBO','_COH FFT','.mat']),'ZoneList','matcorr','meancorr', 'idwindow','fs'  );
        saveas(hfig,fullfile(pathout,[filloutput,'_WAV','.fig']))
        matcorr = matcorrHbR;
        meancorr = matcorrHbR;
        save(fullfile(pathout,[filloutput,'_HBR','_COH FFT','.mat']),'ZoneList','matcorr','meancorr', 'idwindow','fs'  );
        %msgbox('Wavelet decomposition is save, use checkcluster.m to create connectivity matrix for cluster window')
    end
    
    
    
    %     %fullfile(pathout,[filloutput,'HBO','Pearson','.mat'])
    %
    %
    %     matcorr = zeros(numel(listHBRch),numel(listHBRch),size(rDtp,1));
    %     for f=1:size(rDtp,1) %Loop over all files of a NIRS.mat
    %         d1 = fopen_NIR(rDtp{f,1},NC);
    %         id = 1;
    %         idok = find(NIRS.Cf.H.C.ok(listHBRch,f));
    %         listHBR = listHBRch(idok);
    %         for i=1:numel(listHBR)
    %             j = 1;
    %             while j<i %1:numel(listelectrode)
    %                 option{id}.matposition = [i,j];
    %                 d1ok = d1(listHBR(i,1),:);
    %                 d2ok = d1(listHBR(j,1),:);
    %                 option{id}.corr= corr(d1ok',d2ok');
    %                 %         option{id}.label = [listname{i,1},listname{j,1}];
    %                 matcorr(i,j,f)=option{id}.corr;
    %                 matcorr(j,i,f)=option{id}.corr;
    %                 j = j + 1;
    %                 id = id+1;
    %             end
    %         end
    %     end
    %     %   [path, fname, extension]=fileparts(job.NIRSmat{filenb,1});
    %
    %     ZoneList  = listname;
    %     meancorrPearson = nanmean(matcorr,3);
    %     meancorrPearsonFisher = 1/2*log((1+nanmean(matcorr,3))./(1-nanmean(matcorr,3)));
    %     save(fullfile(pathout,[filloutput, 'HBR','Pearson', '.mat']),'ZoneList','matcorr','meancorrPearson','meancorrPearsonFisher');
    %
end
out.NIRSmat = job.NIRSmat;
end
%WAVELET  1D Wavelet transform with optional singificance testing
%
%   [WAVE,PERIOD,SCALE,COI] = wavelet(Y,DT,PAD,DJ,S0,J1,MOTHER,PARAM)
%
%   Computes the wavelet transform of the vector Y (length N),
%   with sampling rate DT.
%
%   By default, the Morlet wavelet (k0=6) is used.
%   The wavelet basis is normalized to have total energy=1 at all scales.
%
%
% INPUTS:
%
%    Y = the time series of length N.
%    DT = amount of time between each Y value, i.e. the sampling time.
%
% OUTPUTS:
%
%    WAVE is the WAVELET transform of Y. This is a complex array
%    of dimensions (N,J1+1). FLOAT(WAVE) gives the WAVELET amplitude,
%    ATAN(IMAGINARY(WAVE),FLOAT(WAVE) gives the WAVELET phase.
%    The WAVELET power spectrum is ABS(WAVE)^2.
%    Its units are sigma^2 (the time series variance).
%
%
% OPTIONAL INPUTS:
%
% *** Note *** setting any of the following to -1 will cause the default
%               value to be used.
%
%    PAD = if set to 1 (default is 0), pad time series with enough zeroes to get
%         N up to the next higher power of 2. This prevents wraparound
%         from the end of the time series to the beginning, and also
%         speeds up the FFT's used to do the wavelet transform.
%         This will not eliminate all edge effects (see COI below).
%
%    DJ = the spacing between discrete scales. Default is 0.25.
%         A smaller # will give better scale resolution, but be slower to plot.
%
%    S0 = the smallest scale of the wavelet.  Default is 2*DT.
%
%    J1 = the # of scales minus one. Scales range from S0 up to S0*2^(J1*DJ),
%        to give a total of (J1+1) scales. Default is J1 = (LOG2(N DT/S0))/DJ.
%
%    MOTHER = the mother wavelet function.
%             The choices are 'MORLET', 'PAUL', or 'DOG'
%
%    PARAM = the mother wavelet parameter.
%            For 'MORLET' this is k0 (wavenumber), default is 6.
%            For 'PAUL' this is m (order), default is 4.
%            For 'DOG' this is m (m-th derivative), default is 2.
%
%
% OPTIONAL OUTPUTS:
%
%    PERIOD = the vector of "Fourier" periods (in time units) that corresponds
%           to the SCALEs.
%
%    SCALE = the vector of scale indices, given by S0*2^(j*DJ), j=0...J1
%            where J1+1 is the total # of scales.
%
%    COI = if specified, then return the Cone-of-Influence, which is a vector
%        of N points that contains the maximum period of useful information
%        at that particular time.
%        Periods greater than this are subject to edge effects.
%        This can be used to plot COI lines on a contour plot by doing:
%
%              contour(time,log(period),log(power))
%              plot(time,log(coi),'k')
%
%----------------------------------------------------------------------------
%   Copyright (C) 1995-1998, Christopher Torrence and Gilbert P. Compo
%   University of Colorado, Program in Atmospheric and Oceanic Sciences.
%   This software may be used, copied, or redistributed as long as it is not
%   sold and this copyright notice is reproduced on each copy made.  This
%   routine is provided as is without any express or implied warranties
%   whatsoever.
%
% Notice: Please acknowledge the use of this program in any publications:
%   ``Wavelet software was provided by C. Torrence and G. Compo,
%     and is available at URL: http://paos.colorado.edu/research/wavelets/''.
%
% Notice: Please acknowledge the use of the above software in any publications:
%    ``Wavelet software was provided by C. Torrence and G. Compo,
%      and is available at URL: http://paos.colorado.edu/research/wavelets/''.
%
% Reference: Torrence, C. and G. P. Compo, 1998: A Practical Guide to
%            Wavelet Analysis. <I>Bull. Amer. Meteor. Soc.</I>, 79, 61-78.
%
% Please send a copy of such publications to either C. Torrence or G. Compo:
%  Dr. Christopher Torrence               Dr. Gilbert P. Compo
%  Advanced Study Program                 NOAA/CIRES Climate Diagnostics Center
%  National Center for Atmos. Research    Campus Box 216
%  P.O. Box 3000                          University of Colorado at Boulder
%  Boulder CO 80307--3000, USA.           Boulder CO 80309-0216, USA.
%  E-mail: torrence@ucar.edu              E-mail: gpc@cdc.noaa.gov
%----------------------------------------------------------------------------
function [wave,period,scale,coi] = ...
    wavelet(Y,dt,pad,dj,s0,J1,mother,param)

if (nargin < 8), param = -1; end
if (nargin < 7), mother = -1; end
if (nargin < 6), J1 = -1; end
if (nargin < 5), s0 = -1; end
if (nargin < 4), dj = -1; end
if (nargin < 3), pad = 0; end
if (nargin < 2)
    error('Must input a vector Y and sampling time DT')
end

n1 = length(Y);

if (s0 == -1), s0=2*dt; end
if (dj == -1), dj = 1./4.; end
if (J1 == -1), J1=fix((log(n1*dt/s0)/log(2))/dj); end
if (mother == -1), mother = 'MORLET'; end

%....construct time series to analyze, pad if necessary
x(1:n1) = Y - mean(Y);
if (pad == 1)
    base2 = fix(log(n1)/log(2) + 0.4999);   % power of 2 nearest to N
    x = [x,zeros(1,2^(base2+1)-n1)];
end
n = length(x);

%....construct wavenumber array used in transform [Eqn(5)]
k = [1:fix(n/2)];
k = k.*((2.*pi)/(n*dt));
k = [0., k, -k(fix((n-1)/2):-1:1)];

%....compute FFT of the (padded) time series
f = fft(x);    % [Eqn(3)]

%....construct SCALE array & empty PERIOD & WAVE arrays
scale = s0*2.^((0:J1)*dj);
period = scale;
wave = zeros(J1+1,n);  % define the wavelet array
wave = wave + i*wave;  % make it complex

% loop through all scales and compute transform
for a1 = 1:J1+1
    [daughter,fourier_factor,coi,dofmin]=wave_bases(mother,k,scale(a1),param);
    wave(a1,:) = ifft(f.*daughter);  % wavelet transform[Eqn(4)]
end

period = fourier_factor*scale;
coi = coi*dt*[1E-5,1:((n1+1)/2-1),fliplr((1:(n1/2-1))),1E-5];  % COI [Sec.3g]
wave = wave(:,1:n1);  % get rid of padding before returning

return
end
%WAVE_BASES  1D Wavelet functions Morlet, Paul, or DOG
%
%  [DAUGHTER,FOURIER_FACTOR,COI,DOFMIN] = ...
%      wave_bases(MOTHER,K,SCALE,PARAM);
%
%   Computes the wavelet function as a function of Fourier frequency,
%   used for the wavelet transform in Fourier space.
%   (This program is called automatically by WAVELET)
%
% INPUTS:
%
%    MOTHER = a string, equal to 'MORLET' or 'PAUL' or 'DOG'
%    K = a vector, the Fourier frequencies at which to calculate the wavelet
%    SCALE = a number, the wavelet scale
%    PARAM = the nondimensional parameter for the wavelet function
%
% OUTPUTS:
%
%    DAUGHTER = a vector, the wavelet function
%    FOURIER_FACTOR = the ratio of Fourier period to scale
%    COI = a number, the cone-of-influence size at the scale
%    DOFMIN = a number, degrees of freedom for each point in the wavelet power
%             (either 2 for Morlet and Paul, or 1 for the DOG)
%
%----------------------------------------------------------------------------
%   Copyright (C) 1995-1998, Christopher Torrence and Gilbert P. Compo
%   University of Colorado, Program in Atmospheric and Oceanic Sciences.
%   This software may be used, copied, or redistributed as long as it is not
%   sold and this copyright notice is reproduced on each copy made.  This
%   routine is provided as is without any express or implied warranties
%   whatsoever.
%----------------------------------------------------------------------------
function [daughter,fourier_factor,coi,dofmin] = ...
    wave_bases(mother,k,scale,param)

mother = upper(mother);
n = length(k);

if (strcmp(mother,'MORLET'))  %-----------------------------------  Morlet
    if (param == -1), param = 6.; end
    k0 = param;
    expnt = -(scale.*k - k0).^2/2.*(k > 0.);
    norm = sqrt(scale*k(2))*(pi^(-0.25))*sqrt(n);    % total energy=N   [Eqn(7)]
    daughter = norm*exp(expnt);
    daughter = daughter.*(k > 0.);     % Heaviside step function
    fourier_factor = (4*pi)/(k0 + sqrt(2 + k0^2)); % Scale-->Fourier [Sec.3h]
    coi = fourier_factor/sqrt(2);                  % Cone-of-influence [Sec.3g]
    dofmin = 2;                                    % Degrees of freedom
elseif (strcmp(mother,'PAUL'))  %--------------------------------  Paul
    if (param == -1), param = 4.; end
    m = param;
    expnt = -(scale.*k).*(k > 0.);
    norm = sqrt(scale*k(2))*(2^m/sqrt(m*prod(2:(2*m-1))))*sqrt(n);
    daughter = norm*((scale.*k).^m).*exp(expnt);
    daughter = daughter.*(k > 0.);     % Heaviside step function
    fourier_factor = 4*pi/(2*m+1);
    coi = fourier_factor*sqrt(2);
    dofmin = 2;
elseif (strcmp(mother,'DOG'))  %--------------------------------  DOG
    if (param == -1), param = 2.; end
    m = param;
    expnt = -(scale.*k).^2 ./ 2.0;
    norm = sqrt(scale*k(2)/gamma(m+0.5))*sqrt(n);
    daughter = -norm*(i^m)*((scale.*k).^m).*exp(expnt);
    fourier_factor = 2*pi*sqrt(2./(2*m+1));
    coi = fourier_factor/sqrt(2);
    dofmin = 1;
else
    error('Mother must be one of MORLET,PAUL,DOG')
end

return
end