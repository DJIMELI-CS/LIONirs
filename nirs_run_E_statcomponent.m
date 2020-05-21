function out = nirs_run_E_statcomponent(job)

if isfield(job.c_statcomponent,'b_TtestOneSample')
    AllC = [];
    for i=1:numel(job.c_statcomponent.b_TtestOneSample.f_component)
        load(job.c_statcomponent.b_TtestOneSample.f_component{i},'-mat');
        [dir1,file1,ext1]=fileparts(job.c_statcomponent.b_TtestOneSample.f_component{i})
        AllC = [AllC,A];
    end
    A = A';

     for ich=1:size(AllC,1)
       % [h,p,ci,stats] = ttest(AllC(ich,:)); %do not suport nan 
        tval(ich) =  nanmean(AllC(ich,:))./        (nanstd(AllC(ich,:)./sqrt(sum(~isnan(AllC(ich,:))))));
        df = sum(~isnan(AllC(ich,:)))-1;
        if job.c_statcomponent.b_TtestOneSample.m_TtestOneSample == 1
            pval(ich) = 2 * tcdf(-abs(tval(ich)), df);
            option = 'twotail';
        elseif job.c_statcomponent.b_TtestOneSample.m_TtestOneSample == 2
             pval(ich) = tcdf(+tval(ich), df);   
            option = 'lefttail';
        elseif job.c_statcomponent.b_TtestOneSample.m_TtestOneSample == 3
            pval(ich) = tcdf(-tval(ich), df);
            option = 'righttail';
        end
        mval(ich) = nanmean(AllC(ich,:));
     end
     dir1 = job.e_STATCOMPPath{1};
     A = mval;
     save(fullfile(dir1,['ONESAMPLE_Mean n=',num2str(df+1),'.mat']),'A','zonelist','option')     
     A = tval;
     save(fullfile(dir1,['ONESAMPLE_Tmap n=',num2str(df+1),'.mat']),'A','zonelist','option')

     A = mval.*double(pval<0.05);
     save(fullfile(dir1,['ONESAMPLE__mean05unc.mat']), 'A','zonelist','option')
     A = mval.*double(pval<0.01);
     save(fullfile(dir1,['ONESAMPLE__mean01unc.mat']),'A','zonelist','option')
     A = mval.*double(pval<0.001);
     save(fullfile(dir1,['ONESAMPLE__mean001unc.mat']),'A','zonelist','option')
    
     
     [FDR,Q] = mafdr(pval);         
     A = mval.*double(Q<0.05);
     save(fullfile(dir1,['ONESAMPLE__mean05fdr.mat']),'A','zonelist','option')
    [FDR,Q] = mafdr(pval);
     A = mval.*double(Q<0.01);
     save(fullfile(dir1,['ONESAMPLE__mean01fdr.mat']),'A','zonelist','option')
    [FDR,Q] = mafdr(pval);
     A = mval.*double(Q<0.001);
     save(fullfile(dir1,['ONESAMPLE__mean001fdr.mat']),'A','zonelist','option')

     
elseif isfield(job.c_statcomponent,'b_TtestUnpaired')
    
    
    
        if job.c_statcomponent.b_TtestUnpaired.m_TtestOneSample == 1
            option = 'twotail';
        elseif job.c_statcomponent.b_TtestUnpaired.m_TtestOneSample == 2  
            option = 'lefttail';
        elseif job.c_statcomponent.b_TtestUnpaired.m_TtestOneSample == 3
            option = 'righttail';
        end
    
      AllG1 = [];
    for i=1:numel(job.c_statcomponent.b_TtestUnpaired.f_componentG1)
        load(job.c_statcomponent.b_TtestUnpaired.f_componentG1{i},'-mat');
        [dir1,file1,ext1]=fileparts(job.c_statcomponent.b_TtestUnpaired.f_componentG1{i});
        AllG1 = [AllG1,A];
    end 
    
     AllG2 = [];
    for i=1:numel(job.c_statcomponent.b_TtestUnpaired.f_componentG2)
        load(job.c_statcomponent.b_TtestUnpaired.f_componentG2{i},'-mat');
        [dir1,file1,ext1]=fileparts(job.c_statcomponent.b_TtestUnpaired.f_componentG2{i});
        AllG2 = [AllG2,A];
    end
    
     for ich=1:size(AllG1,1)
        stats = testt(AllG1(ich,:),AllG2(ich,:)); %do not suport nan 
        tval(ich) =   stats.tvalue;
        df = stats.tdf;
        pval(ich)=stats.tpvalue;      
        mval(ich) =  nanmean(AllG1(ich,:)) - nanmean(AllG2(ich,:));
     end
     dir1 = job.e_STATCOMPPath{1};
     A = nanmean(AllG1);
     save(fullfile(dir1,['TWOSAMPLE_Mean G1 n=',num2str(df+1),'.mat']),'A','zonelist','option')
     A = nanmean(AllG2);
     save(fullfile(dir1,['TWOSAMPLE_Mean G2 n=',num2str(df+1),'.mat']),'A','zonelist','option')
     
     
     A = mval;
     save(fullfile(dir1,['TWOSAMPLE_Mean G1-G2 n=',num2str(df+1),'.mat']),'A','zonelist','option')

     A = tval;
     save(fullfile(dir1,['TWOSAMPLE_Tmap n=',num2str(df+1),'.mat']),'A','zonelist','option')
     
     A = tval.*double(pval<0.05);
     save(fullfile(dir1,['TWOSAMPLE_Tmap_05unc.mat']), 'A','zonelist','option')
     A = mval.*double(pval<0.05);
     save(fullfile(dir1,['TWOSAMPLE__mean05unc.mat']),'A','zonelist','option')
     
     A = mval.*double(pval<0.01);
     save(fullfile(dir1,['TWOSAMPLE__mean01unc.mat']),'A','zonelist','option')
     A = mval.*double(pval<0.001);
     save(fullfile(dir1,['TWOSAMPLE__mean001unc.mat']),'A','zonelist','option')
    
     
     [FDR,Q] = mafdr(pval);         
     A = mval.*double(Q<0.05);
     save(fullfile(dir1,['TWOSAMPLE__mean05fdr.mat']),'A','zonelist','option')
    [FDR,Q] = mafdr(pval);
     A = mval.*double(Q<0.01);
     save(fullfile(dir1,['TWOSAMPLE__mean01fdr.mat']),'A','zonelist','option')
    [FDR,Q] = mafdr(pval);
     A = mval.*double(Q<0.001);
     save(fullfile(dir1,['TWOSAMPLE_mean001fdr.mat']),'A','zonelist','option')
     
elseif isfield(job.c_statcomponent,'b_ANOVAN')     
     [filepath,name,ext] = fileparts(job.c_statcomponent.b_ANOVAN.f_anovan{1});
     if strcmp(ext,'.xlsx')|strcmp(ext,'.xls')
            [num,txt,raw] = xlsread(job.c_statcomponent.b_ANOVAN.f_anovan{1});
     elseif  strcmp(ext,'.txt')
          [num,txt,raw] = readtxtfile_asxlsread(job.c_statcomponent.b_ANOVAN.f_anovan{1});
     end
     
     %Case anovan each ch save each average and pval add fdr correction! 
     %load the observation if 
    [pathstr, name, ext]=fileparts(raw{2,3});
    if strcmp(ext,'.txt')
     AllCOM = [];
     for i=2:size(raw,1)         
      tmp= load(fullfile(raw{i,1},raw{i,2}),'-mat');      
         fid = fopen(fullfile(raw{i,1},raw{i,3}));
         chlist = textscan(fid, '%s%s');
         fclose(fid); 
         %find zone list index
         srs = chlist{1};
         det = chlist{2};
         idactual = [];
        for ichlist = 1:numel(chlist{1})       
           id= strmatch([srs{ichlist},' ', det{ichlist}],tmp.zonelist,'exact');
           if ~isempty(id)
               idactual =  [idactual,id];
           end
        end
        AllCOM = [AllCOM,tmp.A(idactual)];
     end
     
     zonelist = tmp.zonelist(idactual);
     
     
     groupcell =raw(2:end, 4:end);
     name = raw(1, 4:end);%conditioni  could be a number or a zone label to identify region if zone ! 
     groupe = cell2mat(groupcell); 
     for i = 1:size(groupe,2)
        groupedef{i}=( groupe(:,i));
     end
    dir1 = job.e_STATCOMPPath{1}; 
    for ich = 1:size(AllCOM,1)         
         y =  AllCOM(ich,:);         
         [p,tbl,stats,terms] = anovan(y',groupedef,'model','interaction','varnames',name,'display','off' );
         for idim = 1:numel(p)
            pval(ich,idim)=p(idim);
            Fval(ich,idim)=tbl{idim+1,6};
         end 
       save(fullfile(dir1,['anovan', zonelist{ich},'stat.mat']), 'stats');
        % results = multcompare(stats,'Dimension',[1 2]);
    end 
    [FDR,Q] = mafdr(pval(:));
    FDR = reshape(FDR, size(pval));
    for idim = 1:size(pval,2)
        A = double( pval(:,idim)<0.05);
        save(fullfile( dir1,['anovan_p0.05 ',name{idim},'.mat']),'A','zonelist') 
         A = double(1- pval(:,idim));
        save(fullfile( dir1,['anovan_1-p',name{idim},'.mat']),'A','zonelist') 
         A = double( Fval(:,idim));
        save(fullfile( dir1,['anovan_F ',name{idim},'.mat']),'A','zonelist') 
          A = double(FDR(:,idim)<0.05);
        save(fullfile( dir1,['anovan_FDRq0.05 ',name{idim},'.mat']),'A','zonelist') 
         A = double(1- FDR(:,idim));
        save(fullfile( dir1,['anovan_FDR1-q ',name{idim},'.mat']),'A','zonelist') 
    end
    
elseif strcmp(ext,'.zone')
    
    
     AllCOM = [];
    
     for i=2:size(raw,1)         
      tmp= load(fullfile(raw{i,1},raw{i,2}),'-mat');       
      try
          zone = load(fullfile(raw{i,1},raw{i,3}),'-mat'); 
      catch
          disp(['File ',fullfile(raw{i,1},raw{i,3}),' could not be load'])
          return
      end
        labelzone = raw{i,4};
        for izone=1:numel(zone.zone.label)
            if strcmp(zone.zone.label{izone}, labelzone)
                goodzone = izone;
                %zoneidnum{i-1,1} = izone;
                zoneid{i-1,1} = labelzone;
            end
        end
        plotLst = zone.zone.plotLst{goodzone};
        AllCOM = [AllCOM,nanmax(tmp.A(plotLst))];
     end
     
     groupcell = raw(2:end, 5:end);
     name = raw(1, 4:end);%conditioni  could be a number or a zone label to identify region if zone ! 
     groupe = cell2mat(groupcell); 
      groupedef{1} =  zoneid;
     for i = 1:size(groupe,2)
        groupedef{i+1}=( groupe(:,i));
     end
    dir1 = job.e_STATCOMPPath{1}; 
    for ich = 1:size(AllCOM,1)         
         y =  AllCOM(ich,:);         
         [p,tbl,stats,terms] = anovan(y',groupedef,'model','interaction','varnames',name,'display','off' );
         for idim = 1:numel(p)
            pval(ich,idim)=p(idim);
            Fval(ich,idim)=tbl{idim+1,6};
         end 
       save(fullfile(dir1,['anovan', 'REGION','stat.mat']), 'stats');
%        results = multcompare(stats,'Dimension',[1 2]);
    end 
     % tablevalue =raw(2:end, 5:end) AllCOM
  %  results = multcompare(stats,'dimension',[1,2])
    

    

    end
end
try
    out = {srsfile};
catch
    out = 'no dependancy';
end


