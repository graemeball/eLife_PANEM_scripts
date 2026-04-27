%
%
%  Surfaces Split By Poles Function for Imaris 7.3.0
%  Based on Surfaces Split and Filaments Convex Hull Imaris XTensions
%
%  Copyright Bitplane AG 2011
%  Copyright Graeme Ball, Dundee Imaging Facility 2024-2025
%
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="Surfaces Split by Poles" icon="Matlab">
%          <Command>MatlabXT::XTSurfacesSplitByPoles(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Surfaces Split by Poles" icon="Matlab">
%            <Command>MatlabXT::XTSurfacesSplitByPoles(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Split selected Surfaces object into 3 new: Inter, Extra1 and Extra2
%   according to selected Spots object representing a pair of poles.
% 
%

function XTSurfacesSplitByPoles(aImarisApplicationID)

% connect to Imaris interface & get factory
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end
vFactory = vImarisApplication.GetFactory;

%% get spots and surfaces objects for analysis
% based on XTSpotsCloseToSurface Function for Imaris 7.3.0

% the user has to create a scene with some spots and surface
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create Spots and Surface in the Surpass scene!')
    return
end

% get the spots and the surface object
vSpots = vFactory.ToSpots(vImarisApplication.GetSurpassSelection);
vSurfaces = vFactory.ToSurfaces(vImarisApplication.GetSurpassSelection);

vSpotsSelected = ~isequal(vSpots, []);
vSurfaceSelected = ~isequal(vSurfaces, []);
if vSpotsSelected
    vParent = vSpots.GetParent;
elseif vSurfaceSelected
    vParent = vSurfaces.GetParent;
else
    vParent = vSurpassScene;
end

% get the spots and surfaces
vSpotsSelection = 1;
vSurfaceSelection = 1;
vNumberOfSpots = 0;
vNumberOfSurfaces = 0;
vSpotsList = [];
vSurfacesList = [];
vSpotsName = {};
vSurfacesName = {};
for vIndex = 1:vParent.GetNumberOfChildren
    vItem = vParent.GetChild(vIndex-1);
    if vFactory.IsSpots(vItem)
        vNumberOfSpots = vNumberOfSpots + 1;
        vSpotsList(vNumberOfSpots) = vIndex;
        vSpotsName{vNumberOfSpots} = char(vItem.GetName);
        
        if vSpotsSelected && isequal(vItem.GetName, vSpots.GetName)
            vSpotsSelection = vNumberOfSpots; 
        end
    elseif vFactory.IsSurfaces(vItem)
        vNumberOfSurfaces = vNumberOfSurfaces + 1;
        vSurfacesList(vNumberOfSurfaces) = vIndex;
        vSurfacesName{vNumberOfSurfaces} = char(vItem.GetName);
        
        if vSurfaceSelected && isequal(vItem.GetName, vSurfaces.GetName)
            vSurfaceSelection = vNumberOfSurfaces;
        end
    end
end

if vNumberOfSpots == 0 || vNumberOfSurfaces == 0
    msgbox('XTsplitSurfacesByPoles requires Spots and Surfaces objects!')
    return
end

if vNumberOfSpots>1
    [vSpotsSelection,vOk] = listdlg('ListString',vSpotsName, ...
        'InitialValue', vSpotsSelection, 'SelectionMode','multiple', ...
        'ListSize',[300 300], 'Name','Split surfaces by poles', ...
        'PromptString',{'Please select the Spots (pairs of poles):'});
    if vOk<1, return, end
end
if vNumberOfSurfaces>1
    [vSurfaceSelection,vOk] = listdlg('ListString',vSurfacesName, ...
        'InitialValue', vSurfaceSelection, 'SelectionMode','multiple', ...
        'ListSize',[300 300], 'Name','Split surfaces by poles', ...
        'PromptString',{'Please select Surfaces object to split:'});
    if vOk<1, return, end
end

vIndexOfSpotsSelected = vSpotsList(vSpotsSelection);
vIndexOfSurfacesSelected = vSurfacesList(vSurfaceSelection);

%% check selected Spots object is suitable
% i.e. Spots object consists of a tracked pair of poles / centrosomes

vItemSpotsSelected = vParent.GetChild(vIndexOfSpotsSelected-1);
vSpots = vFactory.ToSpots(vItemSpotsSelected);

% spotIndicesT: Nx1 vector of T indices for all spots N
spotIndicesT = vSpots.GetIndicesT;
N = numel(spotIndicesT);

% spotPositions: Nx3 matrix of coords for all spots N
spotPositions = vSpots.GetPositionsXYZ;

% spotTrackEdges: Ex2 matrix of spot IDs for track edges E
spotTrackEdges = vSpots.GetTrackEdges;
E = size(spotTrackEdges,1);

% spotTrackIds: Ex1 vector of track IDs for edges E
spotTrackIds = vSpots.GetTrackIds;

% check Spots consists of a tracked spot pair at each timepoint of interest
if ~all(histcounts(spotIndicesT) == 2)
    msgbox('Found <2 or >2 spots for some timepoints!')
    return
end

%% assign pole1, pole2 identity, calculate interPolarXYZ vectors
% where rows of polesTimepoints, P1XYZ, P2XYZ, interpolarXYZ correspond

% assign spotTrackIds to pole1, pole2
poleIds = unique(spotTrackIds);
pole1Id = poleIds(1);
pole2Id = poleIds(2);

% generate spotSpotTrackIds: Nx1 vector of spotTrackIds per spot
spotTrackIds2 = repmat(spotTrackIds, 1, 2);  % shape as spotTrackEdges
spotTrackEdgesSpotTrackIds = [spotTrackEdges(:), spotTrackIds2(:)];
spotSpotTrackIds = unique(spotTrackEdgesSpotTrackIds, 'rows');
% update so Nx2 spotSpotTrackIds rows are: 1-based spot index, spotTrackId
spotSpotTrackIds(:,1) = spotSpotTrackIds(:,1) + 1;

% generate Nx2 matrix with rows: spotIndicesT, spotTrackId
spotIndicesTandTrackIds = ones(N,2);
spotIndicesTandTrackIds(:,1) = spotIndicesT;
% N.B. loop since not sure spotSpotTrackIds order same as spotIndicesT
for s=1:N
    spotIndex = spotSpotTrackIds(s,1);
    spotIndicesTandTrackIds(spotIndex,1) = spotIndicesT(s);
    spotIndicesTandTrackIds(spotIndex,2) = spotSpotTrackIds(s,2);
end
spotIndicesTandTrackIds = int32(spotIndicesTandTrackIds);

polesTimepoints = unique(spotIndicesTandTrackIds(:,1));  %  column vector
interpolarXYZ = zeros(numel(polesTimepoints), 3);
P1XYZ = zeros(numel(polesTimepoints), 3);
P2XYZ = zeros(numel(polesTimepoints), 3);
for t=1:numel(polesTimepoints)
    timepoint = polesTimepoints(t);
    rows = find(spotIndicesTandTrackIds(:,1)==timepoint);
    trackIds = spotIndicesTandTrackIds(rows, 2);
    pole1Index = rows(trackIds==pole1Id);
    pole2Index = rows(trackIds==pole2Id);
    pole1XYZ = spotPositions(pole1Index,:);
    pole2XYZ = spotPositions(pole2Index,:);
    pole1to2vector = pole2XYZ - pole1XYZ;
    P1XYZ(t, :) = pole1XYZ;
    P2XYZ(t, :) = pole2XYZ;
    interpolarXYZ(t, :) = pole1to2vector;
end

%% get selected Surfaces object, IndicesT, TrackEdges and TrackIds

vItemSurfacesSelected = vParent.GetChild(vIndexOfSurfacesSelected-1);
vSurfaces = vFactory.ToSurfaces(vItemSurfacesSelected);

% numberOfSurfaces: number of surface elements in Surfaces object
numberOfSurfaces = vSurfaces.GetNumberOfSurfaces;

surfaceIndicesT = zeros(numberOfSurfaces,1);
for i=0:numberOfSurfaces-1
    surfaceIndicesT(i+1) = vSurfaces.GetTimeIndex(i);
end

% surfacesTrackEdges: Ex2 matrix of surface IDs for track edges E
surfacesTrackEdges = vSurfaces.GetTrackEdges;

% surfacesTrackIds: Ex1 vector of track IDs for edges E
surfacesTrackIds = vSurfaces.GetTrackIds;


%% split Surfaces object into: inter-polar, extra-polar1 and extra-polar2;
% according to planes at pole1, pol2 perpendicular to pole1-pole2 vector

vSurfaceInter = vFactory.CreateSurfaces;
vSurfaceExtra1 = vFactory.CreateSurfaces;
vSurfaceExtra2 = vFactory.CreateSurfaces;

% iterate over surfaces and split where indexT found in poleTimepoints
for vSurfaceIndex=1:numel(surfaceIndicesT)
    vIndexT = surfaceIndicesT(vSurfaceIndex);
    if any(polesTimepoints == vIndexT)
        vVertices = vSurfaces.GetVertices(vSurfaceIndex-1);
        V = unique(vVertices, 'rows');  % surf vertices, remove duplicates
        
        polesTimepoint = find(polesTimepoints==vIndexT);
        P1 = P1XYZ(polesTimepoint, :);
        P2 = P2XYZ(polesTimepoint, :);
        normal = interpolarXYZ(polesTimepoint, :);
        
        % split vertices V into 3: inter-polar and extra-pole1 and -pole2
        % calculate sign (side) of planes through P1, P2 for all V points
        S1 = (V - P1) * normal';  % dot product of V-P1 with normal
        S2 = (V - P2) * normal';  % dot product of V-P2 with normal
        V_inner = V(S1.*S2<0,:);  % opposite signs between planes
        V_outer = V(S1.*S2>=0,:);  % same sign when outside a plane
        ix_outer1 = sum(abs(V_outer - P1),2) < sum(abs(V_outer - P2),2);
        V_outer1 = V_outer(ix_outer1,:);
        V_outer2 = V_outer(~ix_outer1,:);
        MIN_VERTICES_3D_SHAPE = 4;
        % calculate facets for 'inner' and add surface
        if size(V_inner, 1) >= MIN_VERTICES_3D_SHAPE
            [vertInner, triInner, normInner] = calcFacets(V_inner);
            if ~isempty(vertInner)
                vSurfaceInter.AddSurface(vertInner, triInner-1, normInner, vIndexT);
            end
        end
        % calculate facets for 'extra1' and add surface
        if size(V_outer1, 1) >= MIN_VERTICES_3D_SHAPE
            [vertExtra1, triExtra1, normExtra1] = calcFacets(V_outer1);
            if ~isempty(vertExtra1)
                vSurfaceExtra1.AddSurface(vertExtra1, triExtra1-1, normExtra1, vIndexT);
            end
        end
        % calculate facets for 'extra2' and add surface
        if size(V_outer2, 1) >= MIN_VERTICES_3D_SHAPE
            [vertExtra2, triExtra2, normExtra2] = calcFacets(V_outer2);
            if ~isempty(vertExtra2)
                vSurfaceExtra2.AddSurface(vertExtra2, triExtra2-1, normExtra2, vIndexT);
            end
        end
    end
end

% update new surfaces position in hierarchy, appearance
vSurfaceInter.SetName(['Inter-polar of ', char(vSurfaces.GetName)]);
vSurfaceInter.SetColorRGBA(vSurfaces.GetColorRGBA);
vSurfaces.GetParent.AddChild(vSurfaceInter, -1);
vSurfaceExtra1.SetName(['Extra-polar1 of ', char(vSurfaces.GetName)]);
vSurfaceExtra1.SetColorRGBA(vSurfaces.GetColorRGBA);
vSurfaces.GetParent.AddChild(vSurfaceExtra1, -1);
vSurfaceExtra2.SetName(['Extra-polar2 of ', char(vSurfaces.GetName)]);
vSurfaceExtra2.SetColorRGBA(vSurfaces.GetColorRGBA);
vSurfaces.GetParent.AddChild(vSurfaceExtra2, -1);

end


%% local function definitions

function[vVertices, vTriangles, vNormals] = calcFacets(vVerticesIn)

    % method 1: use alphaShape to find boundary facets
    vShape3D1 = alphaShape(double(vVerticesIn(:, [1 2 3])));
    volume1 = vShape3D1.volume;
    alpha1 = vShape3D1.Alpha;
    % increase alpha and hole thresh after first pass to avoid holes
    vShape3D = alphaShape(double(vVerticesIn(:, [1 2 3])), alpha1*2, 'HoleThreshold', volume1);
    [vTriangles, vVertices] = boundaryFacets(vShape3D);
    MIN_VERTICES_3D_SHAPE = 4;
    if size(vVertices, 1) >= MIN_VERTICES_3D_SHAPE
    
        % method 2: pick facets from delaunay tetrahedrons
        % DT = delaunayTriangulation(double(vVerticesIn(:, [1 2 3])));
        % vVertices = DT.Points;
        % tet = DT.ConnectivityList;
        % tri = [tet(:,[1 2 3]); tet(:,[1 2 4]); tet(:,[1 3 4]); tet(:, [2 3 4])];
        % vTriangles = unique(tri, 'rows');  % remove duplicates
    
        % reorder triangle vertices (clockwise to counter) ?
        %vTriangles = vTriangles(:, [1, 3, 2]);
    
        % calculate normals (do not normalize them, imaris will do it)
        % follow rays from center to vertices
        
        vNbTriangles = size(vTriangles,1);
        vTrianglesNormals = zeros(size(vTriangles));
        vNbVertices = size(vVertices,1);
        vNormals = zeros(size(vVertices));
        
        % Vectors containing the first, second and third vertices of the triangles
        vTriangleVertices1 = vVertices(vTriangles(:,1),:);
        vTriangleVertices2 = vVertices(vTriangles(:,2),:);
        vTriangleVertices3 = vVertices(vTriangles(:,3),:);
        
        % Calculate the cross product for each triangle --> give the normals per triangle
        vTrianglesNormals = cross(vTriangleVertices2-vTriangleVertices1,vTriangleVertices3-vTriangleVertices1);
        
        % Pair triangle number / vertice number
        vNbTrianglesElements = 1:numel(vTriangles);  
        vTrianglesElementsIndices = mod(vNbTrianglesElements-1,vNbTriangles)+1;
        
        % Map representing in which triangle each vertice appears ("1" if it appears and "0" otherwise)
        % The third dimension is used to store a normal (on X, Y and Z axis)
        vMappingTrianglesVertices = zeros(vNbVertices,vNbTriangles, 3);
        vMappingTrianglesVertices(sub2ind(size(vMappingTrianglesVertices),vTriangles(vNbTrianglesElements),vTrianglesElementsIndices)) = 1;
        
        % Copy the same map for the Y and the Z
        vMappingTrianglesVertices(:,:,2) = vMappingTrianglesVertices(:,:,1);
        vMappingTrianglesVertices(:,:,3) = vMappingTrianglesVertices(:,:,1);
        
        % Set the triangle normal for each triangle in which the vertice appears (on X, Y and Z axis)
        vMappingTrianglesVertices(:,:,1) = bsxfun(@times, vMappingTrianglesVertices(:,:,1), vTrianglesNormals(:,1)');
        vMappingTrianglesVertices(:,:,2) = bsxfun(@times, vMappingTrianglesVertices(:,:,2), vTrianglesNormals(:,2)');
        vMappingTrianglesVertices(:,:,3) = bsxfun(@times, vMappingTrianglesVertices(:,:,3), vTrianglesNormals(:,3)');
        
        % Sum all the triangle normals to have a mean normal
        vNormals3D = sum(vMappingTrianglesVertices,2);
        
        % Reshape into a 2D matrice to match with Imaris Interface
        vNormals(:,1) = vNormals3D(:,:,1);
        vNormals(:,2) = vNormals3D(:,:,2);
        vNormals(:,3) = vNormals3D(:,:,3);
    else
        vVertices = [];
        vTriangles = [];
        vNormals = [];
    end
end
