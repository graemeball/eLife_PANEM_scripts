 %
%
%  Surfaces Convex Hull Function for Imaris 7.3.0
%   from Filaments Convex Hull Function for Imaris 7.3.0
%
%  Copyright Bitplane AG 2011
%  Copyright Graeme Ball, Dundee Imaging Facility 2021
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory.
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="Surfaces Convex Hull" icon="Matlab" tooltip="Create a Surface which contains the convex hull of the Surfaces points.">
%          <Command>MatlabXT::XTSurfacesConvexHull(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Convex Hull">
%            <Command>MatlabXT::XTSurfacesConvexHull(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%
%   Create a Surface which contains the convex hull of the Surfaces points.
%
%

function XTSurfacesConvexHull(aImarisApplicationID)

% connect to Imaris interface
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

% get the surfaces object
vFactory = vImarisApplication.GetFactory;
vSurfaces = vFactory.ToSurfaces(vImarisApplication.GetSurpassSelection);

% search the surfaces if not selected
vSurpassScene = vImarisApplication.GetSurpassScene;
if ~vFactory.IsSurfaces(vSurfaces)        
    for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
        vDataItem = vSurpassScene.GetChild(vChildIndex - 1);
        if vFactory.IsSurfaces(vDataItem)
            vSurfaces = vFactory.ToSurfaces(vDataItem);
            break;
        end
    end
    % did we find the surface?
    if isequal(vSurfaces, [])
        msgbox('Please create a surfaces object!');
        return;
    end
end

vCountDegeneratedData = 0;
% create result object
vSurfaceHull = vFactory.CreateSurfaces;
for vSurfaceIndex = 0:vSurfaces.GetNumberOfSurfaces - 1
  % get the points coordinates
  %vSurfacesXYZ = vSurfaces.GetPositionsXYZ(vSurfaceIndex);
  vSurfacesXYZ = vSurfaces.GetVertices(vSurfaceIndex);
  
  try
    % calculate points in convex hull
    vConvexHull = convhulln(double(vSurfacesXYZ));
  catch er
      er.message; % suppress warning
      vCountDegeneratedData = vCountDegeneratedData + 1;
      continue
  end
  % select the necessary points
  vNumberOfPoints = size(vSurfacesXYZ, 1);
  vPoints = false(vNumberOfPoints, 1);
  vPoints(vConvexHull(:)) = true;
  vPoints = find(vPoints);
  vVertices = vSurfacesXYZ(vPoints, :);

  % remap vertex indices to our selection
  % and reorder triangle vertices (clockwise to counter)
  vPointsMap = zeros(vNumberOfPoints, 1);
  vPointsMap(vPoints) = 1:numel(vPoints);
  vTriangles = vPointsMap(vConvexHull(:, [1, 3, 2]));

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

  
  % get time point
  vIndexT = vSurfaces.GetTimeIndex(vSurfaceIndex);

  vTriangles = vTriangles - 1;
  vSurfaceHull.AddSurface(vVertices, vTriangles, vNormals, vIndexT);
end

vSurfaceHull.SetName(['Convex Hull of ', char(vSurfaces.GetName)]);
vSurfaceHull.SetColorRGBA(vSurfaces.GetColorRGBA);
vSurfaces.GetParent.AddChild(vSurfaceHull, -1);

if vCountDegeneratedData > 0
  msgbox(['Could not create convex hull for some of the surfaces. ', ...
    'Surface points must not lie on a plane to build a valid convex hull.'])
end
