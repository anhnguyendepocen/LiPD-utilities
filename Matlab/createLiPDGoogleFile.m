function L=createLiPDGoogleFile(L,overwrite)
%create lipd-web (google spreadsheet) files, L=single lipd hierarchical
%object
% % % deal with authorization on google
checkGoogleTokens;

%overwrite will delete the old file
if nargin<2
    overwrite=0;
end
%check to see if L already has a google file
if isfield(L,'googleSpreadSheetKey')
    if overwrite
        deleteSpreadsheet(L.googleSpreadSheetKey,aTokenDocs);
        display('deleted old google spreadsheet');
        L=rmfield(L,'googleSpreadSheetKey');
        if isfield(L,'googleMetadataWorksheet')
            L=rmfield(L,'googleMetadataWorksheet');
        end
        %also remove paleodata and chrondata worksheet keys

        pStructs=structFieldNames(L.paleoData);
        for p=1:length(pStructs)
            if isfield(L.paleoData.(pStructs{p}),'googWorkSheetKey');
            L.paleoData.(pStructs{p})=rmfield(L.paleoData.(pStructs{p}),'googWorkSheetKey');
            end
            ppstructs=structFieldNames(L.paleoData.(pStructs{p}));
            for pp=1:length(ppstructs)
               if isfield(L.paleoData.(pStructs{p}).(ppstructs{pp}),'googWorkSheetKey')
                   L.paleoData.(pStructs{p}).(ppstructs{pp})=rmfield(L.paleoData.(pStructs{p}).(ppstructs{pp}),'googWorkSheetKey');
               end
            end
            
            
        end
        if isfield(L,'chronData')
            cStructs=structFieldNames(L.chronData);
            for p=1:length(cStructs)
                L.chronData.(cStructs{p})=rmfield(L.chronData.(cStructs{p}),'googWorkSheetKey');
                
            end
        end
    else
        error([L.dataSetName ' already has a google spreadsheet, you should use updateLiPDGoogleFile instead'])
    end
end

%paleoData

%this will create a new spreadsheet, with a useless first worksheet.
%We'll delete it later
spreadSheetNew=createSpreadsheet(L.dataSetName,aTokenDocs,'default.csv','text/csv');
L.googleSpreadSheetKey=spreadSheetNew.spreadsheetKey;

%now create a worksheet for each paleoDataTable
pdNames=fieldnames(L.paleoData);
for pd=1:length(pdNames)
    P=L.paleoData.(pdNames{pd});
    %get the names of the columns
    colNames=structFieldNames(P);
    nCol=length(colNames);
    nRow=length(P.(colNames{1}).values)+2;
    %create a new spreadsheet, with two extra rows (for variable name
    %and TSID)
    display('creating new worksheet')
    newWS=createWorksheet(spreadSheetNew.spreadsheetKey,nRow,nCol,['paleoData-' pdNames{pd}],aTokenSpreadsheet);
    display(['created new worksheet ' newWS.worksheetKey])
    
    P.googWorkSheetKey=newWS.worksheetKey;
    
    %go through the columns and populate the cells
    for c=1:nCol
        %check for TSid
        if ~isfield(P.(colNames{c}),'TSid')
            %create one - check against master list
            P.(colNames{c}).TSid=createTSID(P.(colNames{c}).variableName,L.dataSetName,L.googleSpreadSheetKey,P.googWorkSheetKey);
        end
        
        if ~iscell(P.(colNames{c}).values)
            colData=[P.(colNames{c}).variableName; P.(colNames{c}).TSid; cellstr(num2str(P.(colNames{c}).values))];
        else
            colData=[P.(colNames{c}).variableName; P.(colNames{c}).TSid; P.(colNames{c}).values];
        end
        %figure out what column to put it in
        if isfield(P.(colNames{c}),'number')
            colNum=P.(colNames{c}).number;
        else
            colNum=c;
        end
        editWorksheetColumn(spreadSheetNew.spreadsheetKey,newWS.worksheetKey,colNum,1:nRow,colData,aTokenSpreadsheet);
    end
    L.paleoData.(pdNames{pd})=P;
    
end

['L key-' L.paleoData.(pdNames{pd}).googWorkSheetKey]

%chronData
%if there's chrondata, write that too.
if isfield(L,'chronData')
    %now create a worksheet for each chronDataTable
    pdNames=fieldnames(L.chronData);
    for pd=1:length(pdNames)
        P=L.chronData.(pdNames{pd});
        %get the names of the columns
        colNames=structFieldNames(P);
        nCol=length(colNames);
        P.(colNames{1}).values;
        nRow=length(P.(colNames{1}).values)+2;%

        %create a new spreadsheet, with two extra rows (for variable name
        %and TSID)
        display('creating new worksheet')
        newWS=createWorksheet(spreadSheetNew.spreadsheetKey,nRow,nCol,['chronData-' pdNames{pd}],aTokenSpreadsheet);
        display(['created new worksheet ' newWS.worksheetKey])
        P.googWorkSheetKey=newWS.worksheetKey;
        
        
        %go through the columns and populate the cells
        for c=1:nCol
            %check for TSid
            if ~isfield(P.(colNames{c}),'TSid')
                P.(colNames{c}).TSid=createTSID(P.(colNames{c}).variableName,L.dataSetName,L.googleSpreadSheetKey,P.googWorkSheetKey);
            end
            
            if ~iscell(P.(colNames{c}).values)
                colData=[P.(colNames{c}).variableName; P.(colNames{c}).TSid; cellstr(num2str(P.(colNames{c}).values))];
            else
                colData=[P.(colNames{c}).variableName; P.(colNames{c}).TSid; P.(colNames{c}).values];
            end
            %figure out what column to put it in
            if isfield(P.(colNames{c}),'number')
                colNum=P.(colNames{c}).number;
            else
                colNum=c;
            end
            editWorksheetColumn(spreadSheetNew.spreadsheetKey,newWS.worksheetKey,colNum,1:nRow,colData,aTokenSpreadsheet);
        end
        L.chronData.(pdNames{pd})=P;%write it back into the main structure
    end
end
%get the names of the worksheets
wsNames=getWorksheetList(spreadSheetNew.spreadsheetKey,aTokenSpreadsheet);
L.googleMetadataWorksheet=wsNames(1).worksheetKey;



%metadata
%edit that first sheet to become the metadatasheet

%extract timeseries
TS=structord(extractTimeseriesLiPD(L,1));

%get rid of unnecessary metadata
torem={'age','ageUnits','chronData','depth','depthUnits','year','yearUnits','geo_type','geo_geometry_coordinates','paleoData_values','chronData_values','pub1_abstract','pub2_abstract','paleoData_dataType','paleoData_missingValue'};
f=fieldnames(TS);
pid=f(find(~cellfun(@isempty,(strfind(f,'identifier')))&strncmpi('pub',f,3)));
if ~isempty(pid)%remove any pub identifiers, if there are any
    TS=rmfield(TS,pid);
end
for i=1:length(torem)
    if isfield(TS,torem{i})
        TS=rmfield(TS,torem{i});
    end
end
f=fieldnames(TS);
%make chunks.
baseNames=f(find(cellfun(@isempty,(strfind(f,'_')))));
geoNames=f(find(strncmpi('geo_',f,4)));

pubNames=f(find(strncmpi('pub',f,3)));
fundNames=f(find(strncmpi('fund',f,4)));
% paleoDataNames=f(find(strncmpi('paleoData_',f,10)));
% paleoDatai=(find(strncmpi('paleoData_',f,10)));
% 
% cii=(find(strncmpi('climateInterpretation_',f,22)));
% cali=(find(strncmpi('calibration_',f,12)));

%instead can we grab everything with _ except chron?
underscoreI=find(~cellfun(@isempty,(strfind(f,'_'))));
chronDatai=(find(strncmpi('chronData_',f,10)));


%create top chunk, includes, base, pub and geo metadata
%how big to make it?
tcr=max([length(geoNames) length(pubNames) length(baseNames) length(fundNames)]);

if isempty(fundNames)%if no funding then
%8columns (2 and an empty one for each
topChunk=cell(tcr,8);
else %include 3 more for funding
topChunk=cell(tcr,11);
end

%base first
topChunk(1:length(baseNames),1)=baseNames;
for n=1:length(baseNames)
    topChunk{n,2}=TS(1).(baseNames{n});
end

%pub second
topChunk(1:length(pubNames),4)=pubNames;
for n=1:length(pubNames)
    topChunk{n,5}=TS(1).(pubNames{n});
end

%geo third
topChunk(1:length(geoNames),7)=geoNames;
for n=1:length(geoNames)
    topChunk{n,8}=TS(1).(geoNames{n});
end
%save topChunk.mat topChunk %TROUBLESHOOTING
%funding fourth
if ~isempty(fundNames)%
    topChunk(1:length(fundNames),10)=fundNames;
    for n=1:length(fundNames)
%         fN=TS(1).(fundNames{n}); %TROUBLESHOOTING
%         save fn.mat fN ; %TROUBLESHOOTING
        topChunk{n,11}=TS(1).(fundNames{n});
    end
end

%make header
if ~isempty(fundNames)%
header={'Base Metadata', ' ',' ','Publication Metadata','','','Geographic metadata','','','Funding metadata',''};
else
header={'Base Metadata', ' ',' ','Publication Metadata','','','Geographic metadata',''};
end
%add in header
topChunk=[header ; topChunk];




%now make the paleoData chunks
%make TSid first
tsi=find(strcmp('paleoData_TSid',f));
%make variableName second
vni=find(strcmp('paleoData_variableName',f));
%make description third
di=find(strcmp('paleoData_description',f));
%make units fourth
ui=find(strcmp('paleoData_units',f));

geoi=(find(strncmpi('geo_',f,4)));

pubi=(find(strncmpi('pub',f,3)));
fundi=(find(strncmpi('fund',f,4)));

pdCi=[tsi; vni; di; ui;  setdiff(underscoreI,[tsi vni di ui chronDatai' pubi' geoi' fundi']')];
midChunk=cell(length(TS),length(pdCi));

for p=1:length(pdCi)
    midChunk(:,p)={TS.(f{pdCi(p)})};
end

%add in the headers
h1=cell(1,size(midChunk,2));
h1{1}='paleoData column metadata';
midChunk=[h1; f(pdCi)';midChunk];

%Chron metadatdata
if isfield(L,'chronData')
LC=L;
LC.paleoData=L.chronData;
LC=rmfield(LC,'chronData');
CTS=extractTimeseriesLiPD(LC,1);
torem={'age','ageUnits','chronData','depth','depthUnits','year','yearUnits','geo_type','geo_geometry_coordinates','paleoData_values','chronData_values','pub1_abstract','pub2_abstract','paleoData_dataType','paleoData_missingValue'};
f=fieldnames(CTS);
pid=f(find(~cellfun(@isempty,(strfind(f,'identifier')))&strncmpi('pub',f,3)));
if ~isempty(pid)%remove any pub identifiers, if there are any
    CTS=rmfield(CTS,pid);
end
for i=1:length(torem)
    if isfield(CTS,torem{i})
        CTS=rmfield(CTS,torem{i});
    end
end
cfnames =fieldnames(CTS);
pdi=(find(strncmpi('paleoData_',cfnames,10)));
for cp = 1:length(pdi)
    curname=cfnames{pdi(cp)};
    newname=['chron' curname(6:end)];
    [CTS.(newname)]=CTS.(curname);
    CTS=rmfield(CTS,curname);
end
f=fieldnames(CTS);


%now make chron data chunk
tsi=find(strcmp('chronData_TSid',f));
%make variableName second
vni=find(strcmp('chronData_variableName',f));
%make description third
di=find(strcmp('chronData_description',f));
%make units fourth
ui=find(strcmp('chronData_units',f));


pdCi=[tsi; vni; di; ui;  setdiff(chronDatai,[tsi vni di ui])];
botChunk=cell(length(CTS),length(pdCi));

for p=1:length(pdCi)
    botChunk(:,p)={CTS.(f{pdCi(p)})};
end

%add in the headers
h1=cell(1,size(botChunk,2));
h1{1}='chronData column metadata';
botChunk=[h1; f(pdCi)';botChunk];
else
   %create an empty bottom chunk
   
    botChunk=cell(1,size(midChunk,2));

    
end
%NOW COMBINE!!!!!!!!!
%combine the two chunks
nrow=size(topChunk,1)+size(botChunk,1)+size(midChunk,1)+2;

ncol=max([size(topChunk,2),size(midChunk,2),size(botChunk,2)]);

%make final cell to be written to google
metadataCell=cell(nrow,ncol);
metadataCell(1:size(topChunk,1),1:size(topChunk,2))=topChunk;
metadataCell((size(topChunk,1)+2):(size(topChunk,1)+2+size(midChunk,1)-1),1:size(midChunk,2))=midChunk;
metadataCell((nrow-size(botChunk,1)+1):end,1:size(botChunk,2))=botChunk;

%make all the cell entries strings
 save dum.mat metadataCell %troubleshooting
metadataCell4Goog=stringifyCells(metadataCell);

%now write this into the first worksheet
changeWorksheetNameAndSize(spreadSheetNew.spreadsheetKey,wsNames(1).worksheetKey,nrow,ncol,'metadata',aTokenSpreadsheet);

for m=1:ncol
    editWorksheetColumn(spreadSheetNew.spreadsheetKey,wsNames(1).worksheetKey,m,1:nrow,metadataCell4Goog(:,m),aTokenSpreadsheet);
end

