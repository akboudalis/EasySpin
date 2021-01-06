% sphgrid  Spherical grid
%
%   grid = sphgrid(Symmetry,nKnots)
%   [grid,tri] = sphgrid(Symmetry,nKnots)
%
%   Returns a set of unique orientations together with
%   the covered solid angle by each, for a given symmetry.
%
%   Input:
%   - Symmetry: the point group in Schoenflies notation
%                  ('Ci', 'Dinfh', 'C2h', etc.)
%               only centrosymmetric point groups and C1 are supported.
%   - nKnots:   number of knots along a quarter of a meridian, at least 2
%
%   Output:
%   - grid: a structure with fields
%      .Symmetry     input symmetry
%      .nKnots       input number of knots
%      .phi,.theta:  m-element arrays of polar angles, in radians
%      .vecs:        3xm array of orientations (unit column vectors)
%      .weights:     m-element array of associated weights, sum is 4*pi
%   - tri: a structure with fields
%      .idx          triangulation array, one triangle per row
%      .areas        triangle areas (solid angles), sum is 4*pi
%

% The grid implemented in this function is often called SOPHE grid, after
%   D. Wang, G. R. Hanson
%   J.Magn.Reson. A, 117, 1-8 (1995)
%   https://doi.org/10.1006/jmra.1995.9978
% It was already described in a much earlier paper
%   Y. Kurihara
%   Monthly Weather Review 93(7), 399-415 (July 1965)
%   https://doi.org/10.1175/1520-0493(1965)093<0399:NIOTPE>2.3.CO;2

%--------------------------------------------------------------------------
% Undocumented:
% - 'c' option for closed phi interval
% - nOctants as first input (instead of Symmetry)
%--------------------------------------------------------------------------

% grid.weights are approximate, tri.areas are accurate

function [grid,tri] = sphgrid(Symmetry,nKnots,Options)

if nargin==0, help(mfilename); return; end

if nargin<2 || nargin>3, error('Wrong number of input arguments!'); end

if nargin<3
  Options = '';
end

% Determine computation options
%--------------------------------------------------------------------------
% explicitClosedPhi: force closed phi interval computation
% computeWeights: compute weights or not

explicitClosedPhi = any(Options=='c');
calculateTriangulation = nargout>1;

% Initializations
%--------------------------------------------------------------------------

% Determine maximum phi and open/closed interval from symmetry specification.
if ischar(Symmetry)
  [maxPhi,closedPhi,nOctants] = gridparam(Symmetry);
else
  nOctants = Symmetry;
  switch nOctants
    case {-1, 0}, maxPhi = 0;
    case 1, maxPhi = pi/2;
    case 2, maxPhi = pi;
    case 4, maxPhi = 2*pi;
    case 8, maxPhi = 2*pi;
    otherwise
      error('Wrong number of octants, must be -1, 0, 1, 2, 4, or 8.');
  end
  closedPhi = false;
end

% Force closed phi interval if requested.
if explicitClosedPhi
  % Disallow closed phi interval for Ci and C1
  if nOctants==4 || nOctants==8
    %error('Cannot use closed phi interval for this symmetry (%d octants).',nOctants);
  end
  closedPhi = true;
end

% Now we have maxPhi, closedPhi, nOctants and nKnots.
% These parameters fully specify the requested grid.

% Calculate grid vectors and weights
%--------------------------------------------------------------------------
[phi,theta,Weights] = sphgrid_(nOctants,maxPhi,nKnots,closedPhi);
vecs = ang2vec(phi,theta);

% Store in output structure
grid.Symmetry = Symmetry;
grid.nKnots = nKnots;

grid.closedPhi = closedPhi;
grid.nOctants = nOctants;
grid.maxPhi = maxPhi;

grid.phi = phi;
grid.theta = theta;
grid.vecs = vecs;
grid.weights = Weights;


% Triangulation
%--------------------------------------------------------------------------
if calculateTriangulation
  
  switch nOctants
    
    case {0,-1} % 'Dinfh','O3'
      Tri = [];
      
    case 1 % 'D6h','D4h','Oh','D3d','Th','D2h'; 'C4h','C6h'; 1 octant
      if closedPhi % 'D6h','D4h','Oh','D3d','Th','D2h'; closed phi
        % coding idea of David Goodmanson, comp.soft-sys.matlab
        a = 1:nKnots*(nKnots+1)/2;
        a((2:nKnots+1).*(1:nKnots)/2) = [];
        k = 1:(nKnots-1)*(nKnots-2)/2;
        b = a(k);
        Tri = [[1:nKnots*(nKnots-1)/2; a; a+1],[b; 2*(b+1)-k; b+1]].';
      else % 'C4h','C6h'; open phi
        phx = grid.phi*4;
        thx = grid.theta;
        Tri = delaunay(thx.*cos(phx), thx.*sin(phx));
      end
      
    case 2 % 'C2h','S6'; 2 octants, open phi
      phx = grid.phi*2;
      thx = grid.theta;
      Tri = delaunay(thx.*cos(phx), thx.*sin(phx));      
      
    case 4  % 'Ci'; 4 octants, open phi
      phx = grid.phi;
      thx = grid.theta;
      Tri = delaunay(thx.*cos(phx),thx.*sin(phx));
      
    case 8 % 'C1'; 8 octants, open phi
      [phx,thx] = sphgrid_(4,2*pi,nKnots,false);
      phx = phx(:);
      thx = thx(:);
      triUpper = delaunay(thx.*cos(phx), thx.*sin(phx));
      nTotal = 4*nKnots^2 - 8*nKnots + 6; % total number of knots for full sphere
      triLower = nTotal + 1 - triUpper;
      nEquator = 4*(nKnots-1); % number of knots on equator
      idxEquator = triUpper > numel(thx)-nEquator;
      triLower(idxEquator) = triUpper(idxEquator);
      Tri = [triUpper; triLower];
    
    otherwise
      error('Triangulation for this symmetry not supported!');
  end
  
  Tri = sort(Tri,2);
  Tri = uint32(Tri);
  
else
  
  Tri = [];
  
end

% Store in output structure
tri.idx = Tri;


% Compute areas of spherical triangles
%--------------------------------------------------------------------------
if calculateTriangulation && ~isempty(Tri)
  
  % Vertex vectors
  x1 = vecs(:,Tri(:,1).');
  x2 = vecs(:,Tri(:,2).');
  x3 = vecs(:,Tri(:,3).');
  
  % Edge arc lengths
  a1 = acos(sum(x2.*x3));
  a2 = acos(sum(x3.*x1));
  a3 = acos(sum(x1.*x2));
  
  % Formula of d'Huilier
  s = (a1+a2+a3)/2; % triangle perimeter half
  Areas = 4*atan(sqrt(tan(s/2).*tan((s-a1)/2).*tan((s-a2)/2).*tan((s-a3)/2)));
  
  % Normalize to sum 4*pi
  Areas = Areas/sum(Areas) * 4*pi;
  
  if ~isreal(Areas)
    error('Complex triangle areas encountered! (symmetry %s, nKnots %d, option %s)!',Symmetry,nKnots,Options);
  end
  
else
  
  Areas = [];
  
end

% Store in output structure
tri.areas = Areas;


% Output
%-------------------------------------------------------------------------------
switch nargout
  case 1
  case 2
  case 0
    v = ang2vec(phi,theta);
    plot3(v(1,:),v(2,:),v(3,:),'.')
    axis equal
    xlabel('x');
    ylabel('y');
    zlabel('z');
  otherwise
    error('Wrong number of output arguments!');
end

end

function [phi,theta,Weights] = sphgrid_(nOctants,maxPhi,nKnots,closedPhi)
dtheta = (pi/2)/(nKnots-1);
if nOctants > 0 % if not Dinfh or O3 symmetry
  
  % Initializations
  %nOct = ceil(maxPhi/(pi/2));
  if nOctants==8
    nOct = 4;
  else
    nOct = nOctants;
  end
  nPoints = nKnots + nOct*nKnots*(nKnots-1)/2;
  
  phi = zeros(1,nPoints);
  theta = zeros(1,nPoints);
  Weights = zeros(1,nPoints);
  
  sindth2 = sin(dtheta/2);
  w1 = 0.5;
  if ~closedPhi, w1 = w1 + 1/2; end
  
  % North pole (z orientation)
  phi(1) = 0;
  theta(1) = 0;
  Weights(1) = maxPhi*(1-cos(dtheta/2));
  
  % All but equatorial slice
  Start = 2;
  for iSlice = 2:nKnots-1
    nPhi = nOct*(iSlice-1)+1;
    dPhi = maxPhi/(nPhi-1);
    idx = Start+(0:nPhi-1);
    Weights(idx) = 2*sin((iSlice-1)*dtheta)*sindth2*dPhi*...
      [w1 ones(1,nPhi-2) .5];
    phi(idx) = linspace(0,maxPhi,nPhi);
    theta(idx) = (iSlice-1)*dtheta;
    Start = Start + nPhi;
  end
  
  % Equatorial slice
  nPhi = nOct*(nKnots-1)+1;
  dPhi = maxPhi/(nPhi-1);
  idx = Start + (0:nPhi-1);
  phi(idx) = linspace(0,maxPhi,nPhi);
  theta(idx) = pi/2;
  Weights(idx) = sindth2*dPhi*[w1 ones(1,nPhi-2) .5];
  
  % Border removal
  if ~closedPhi
    rmv = cumsum(nOct*(1:nKnots-1)+1)+1;
    phi(rmv) = [];
    theta(rmv) = [];
    Weights(rmv) = [];
  end
  
  % For C1, add lower hemisphere
  if nOctants==8
    idx = length(theta)-nPhi+1:-1:1;
    phi = [phi phi(idx)];
    theta = [theta pi-theta(idx)];
    Weights(idx) = Weights(idx)/2; % half of real value
    Weights = [Weights Weights(idx)];
  end
  
  Weights = 2*(2*pi/maxPhi)*Weights;
  
elseif nOctants==0 % Dinfh symmetry (quarter of meridian in xz plane)
  
  phi = zeros(1,nKnots);
  theta = linspace(0,pi/2,nKnots);
  Weights = -2*(2*pi)*diff(cos([0 dtheta/2:dtheta:pi/2 pi/2]));
  
else % O3 symmetry (z orientation only)
  
  phi = 0;
  theta = 0;
  Weights = 4*pi;
  
end
end
