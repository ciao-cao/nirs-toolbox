function varargout = depthmap(label,headshape)

if(nargin==0)
    if(nargout==0)
        disp(nirs.util.listAtlasRegions)
    else
        varargout{1}=nirs.util.listAtlasRegions;
    end
    return
end

if(~iscellstr(label))
    label=cellstr(label);
end
label=lower(label);

aal=load(which('ROI_MNI_V5_Border.mat'));
aalLabels=load(which('ROI_MNI_V5_List.mat'));
aal.BORDER_XYZ(1,:)=aal.BORDER_XYZ(1,:)*2-90;
aal.BORDER_XYZ(2,:)=aal.BORDER_XYZ(2,:)*2-126;
aal.BORDER_XYZ(3,:)=aal.BORDER_XYZ(3,:)*2-72;
aal.BORDER_XYZ=icbm_spm2tal(aal.BORDER_XYZ')';

aal.BORDER_XYZ(1,:)=aal.BORDER_XYZ(1,:)-2.5;
aal.BORDER_XYZ(2,:)=aal.BORDER_XYZ(2,:)+17.5;
aal.BORDER_XYZ(3,:)=aal.BORDER_XYZ(3,:)-20;

T =[ 0.9964    0.0178    0.0173   -0.0000
   -0.0169    0.9957   -0.0444   -0.0000
   -0.0151    0.0429    1.0215    0.0000
   -0.4232  -17.5022   11.6967    1.0000];


aal.BORDER_XYZ(4,:)=1;
aal.BORDER_XYZ=(aal.BORDER_XYZ'*T)';
aal.BORDER_XYZ=aal.BORDER_XYZ(1:3,:);

if(nargin>1)
    if(isa(headshape,'nirs.core.Probe1020'))
        probe1020=headshape;
        headshape=probe1020.get_headsize;
    else
        probe1020=nirs.core.Probe1020([],headshape);
    end
    
    tbl=nirs.util.list_1020pts('?');
    Pos2=[tbl.X tbl.Y tbl.Z];
    
    tbl= nirs.util.register_headsize(headshape,tbl);
    Pos=[tbl.X tbl.Y tbl.Z];
    T=Pos2\Pos;
    aal.BORDER_XYZ=(aal.BORDER_XYZ'*T)';
    
else
    probe1020=nirs.core.Probe1020;
    tbl=nirs.util.list_1020pts('?');
    Pos=[tbl.X tbl.Y tbl.Z];
end

alllabels=label;
for idx=1:length(label)
    if(isempty(strfind(label{idx},'_r')) & isempty(strfind(label{idx},'_l')))
        alllabels={alllabels{:} [label{idx} '_l'] [label{idx} '_r']};
    end
end


Labels=lower(strvcat(aalLabels.ROI.Nom_L));
Idx=vertcat(aalLabels.ROI.ID);
if(strcmp(label,'?') | strcmp(label,'*') | strcmp(label,'any'))
    lst=[1:size(Labels,1)];
else
    lst=find(ismember(Labels,lower(alllabels)));
end
if(isempty(lst))
    disp('region not found');
    disp('use command:')
    disp(' >> nirs.util.listAtlasRegions')
    depth=[];
    return
end

lstNodes=find(ismember(aal.BORDER_V,Idx(lst)));
[k,depth] = dsearchn(aal.BORDER_XYZ(:,lstNodes)',Pos);

[~,regionIdx]=ismember(aal.BORDER_V(lstNodes(k)),Idx);
region=cellstr(Labels(regionIdx,:));

if(nargout>0)
    if(~isempty(probe1020.optodes_registered))
        
        %Add the link points too (since these are more useful in labels)
        ml=unique([probe1020.link.source probe1020.link.detector],'rows');
        for id=1:size(ml)
            sIdx=['0000' num2str(ml(id,1))];
            sIdx=sIdx(end-3:end);
            dIdx=['0000' num2str(ml(id,2))];
            dIdx=dIdx(end-3:end);
            Name{id,1}=['Source' sIdx ':Detector' dIdx]; 
            X(id,1)=.5*(probe1020.swap_reg.srcPos(ml(id,1),1)+...
                probe1020.swap_reg.detPos(ml(id,2),1));
            Y(id,1)=.5*(probe1020.swap_reg.srcPos(ml(id,1),2)+...
                probe1020.swap_reg.detPos(ml(id,2),2));
            Z(id,1)=.5*(probe1020.swap_reg.srcPos(ml(id,1),3)+...
                probe1020.swap_reg.detPos(ml(id,2),3));
            
            
            %Correct for the curvature
            r=.5*(norm(probe1020.swap_reg.srcPos(ml(id,1),:))+norm(probe1020.swap_reg.detPos(ml(id,2),:)));
            theta=acos(dot(probe1020.swap_reg.srcPos(ml(id,1),:),probe1020.swap_reg.detPos(ml(id,2),:))/...
                (norm(probe1020.swap_reg.srcPos(ml(id,1),:))*norm(probe1020.swap_reg.detPos(ml(id,2),:))));
            d=r*(1-cos(theta/2));
            n=norm([X(id,1) Y(id,1) Z(id,1)]);
            X(id,1)=X(id,1)+d*X(id,1)/n;
            Y(id,1)=Y(id,1)+d*Y(id,1)/n;
            Z(id,1)=Z(id,1)+d*Z(id,1)/n;
            
            Type{id,1}='Link';
            Units{id,1}=probe1020.optodes_registered.Units{1};
        end
    	probe1020.optodes_registered=[probe1020.optodes_registered;...
            table(Name,X,Y,Z,Type,Units)];
        Pts=[probe1020.optodes_registered.X ...
            probe1020.optodes_registered.Y probe1020.optodes_registered.Z];
        
        
        [k,depth] = dsearchn(aal.BORDER_XYZ(:,lstNodes)',Pts);
        
        [~,regionIdx]=ismember(aal.BORDER_V(lstNodes(k)),Idx);
        region=cellstr(Labels(regionIdx,:));
        
        depth=[probe1020.optodes_registered table(depth,region)];
    else
        depth=[tbl table(depth,region)];
    end
    
    varargout{1}=depth;
    return;
end

    figure;
    
    [xy(:,1),xy(:,2)]=probe1020.convert2d(Pos);
    probe1020.draw1020([],[],gca);
    
    dx=mean(diff(sort(xy(:,1))));
    dy=mean(diff(sort(xy(:,2))));
    [X,Y]=meshgrid(min(xy(:,1)):dx:max(xy(:,1)),min(xy(:,2)):dy:max(xy(:,2)));
    warning('off','MATLAB:griddata:DuplicateDataPoints');
    IM = griddata(xy(:,1),xy(:,2),depth,X,Y,'cubic');
    
    h=imagesc(min(xy(:,1)):dx:max(xy(:,1)),min(xy(:,2)):dy:max(xy(:,2)),...
        IM,[0 max(abs(IM(:)))]);
    set(h,'alphaData',1*(~isnan(IM)));
    
    hold on;
    l=probe1020.draw1020([],[],gca);
    set(l,'LineStyle', '-', 'LineWidth', 2)
   
    set(gcf,'color','w');
    
    
    
%     
%     for i=1:size(xy,1)
%         s(i)=scatter(xy(i,1),xy(i,2),'filled','MarkerFaceColor',[.8 .8 .8]);
%         set(s(i),'Userdata',tbl.Name{i});
%         set(s(i),'ButtonDownFcn',@displabel);
%     end
%     
    axis tight;
    axis equal;
    axis off;
    
    cb=colorbar('SouthOutside');
    caxis([0 30])
    l=get(cb,'TickLabels');
    l{end}=['>' num2str(l{end})];
    set(cb,'TickLabels',l);



end

function displabel(varargin)

legend(get(varargin{1},'Userdata'))

end
