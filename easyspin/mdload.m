%  mdload  Load data generated by molecular dynamics simulations.
%
%   MD = mdload(TrajFile, AtomInfo);
%   MD = mdload(TrajFile, AtomInfo, OutOpt);
%
%   Input:
%     TrajFile       character array
%                    Name of trajectory output file.
%
%     AtomInfo       structure array containing the following fields
%
%                    TopFile    character array
%                               Name of topology input file used for 
%                               molecular dynamics simulations.
%
%                    SegName    character array
%                               Name of segment in the topology file
%                               assigned to the spin-labeled protein.
%
%                    ResName    character array
%                               Name of residue assigned to spin label side 
%                               chain, e.g. "CYR1" is the default used by 
%                               CHARMM-GUI.
%
%                    AtomNames  structure array
%                               Contains the atom names used in the PSF to 
%                               refer to the following atoms in the 
%                               nitroxide spin label molecule model:
%
%                                    ON (ONname)
%                                    |
%                                    NN (NNname)
%                                  /   \
%                        (C1name) C1    C2 (C2name)
%                                 |     |
%                       (C1Rname) C1R = C2R (C2Rname)
%                                 |
%                       (C1Lname) C1L
%                                 |
%                       (S1Lname) S1L
%                                /
%                      (SGname) SG
%                               |
%                      (CBname) CB
%                               |
%                   (Nname) N - CA (CAname)
%
%     OutOpt         structure array containing the following fields
%
%                    Verbosity 0: no display, 1: (default) show info
%
%                    keepProtCA  0: (default) delete protein alpha carbon 
%                                   coordinates
%                                1: keep them
%
%
%   Output:
%     MD             structure array containing the following fields:
%
%                    nSteps      integer
%                                total number of steps in trajectory
%
%                    dt          double
%                                size of time step (in s)
%
%                    FrameTraj   numeric array, size = (3,3,nTraj,nSteps)
%                                xyz coordinates of coordinate frame axis
%                                vectors, x-axis corresponds to
%                                FrameTraj(:,1,nTraj,:), y-axis corresponds to
%                                FrameTraj(:,2,nTraj,:), etc.
%
%             FrameTrajwrtProt   numeric array, size = (3,3,nTraj,nSteps)
%                                same as FrameTraj, but with global
%                                rotational diffusion of protein removed
%
%                    RProtDiff   numeric array, size = (3,3,nTraj,nSteps)
%                                trajectories of protein global rotational
%                                diffusion represented by rotation matrices
%
%
%   Supported formats are identified via the extension
%   in 'TrajFile' and 'TopFile'. Extensions:
%
%     NAMD, CHARMM:        .DCD, .PSF
%

%                    dihedrals   numeric array, size = (5,nTraj,nSteps)
%                                dihedral angles of spin label side chain
%                                bonds

function MD = mdload(TrajFile, AtomInfo, OutOpt)

switch nargin
  case 0
    help(mfilename); return;
  case 2 % TrajFile and AtomInfo specified, initialize Opt
    OutOpt = struct;
  case 3 % TrajFile, AtomInfo, and Opt provided
  otherwise
    error('Incorrect number of input arguments.')
end

% if ~isfield(OutOpt,'Type'), OutOpt.Type = 'Protein+Frame'; end
if ~isfield(OutOpt,'Verbosity'), OutOpt.Verbosity = 1; end
if ~isfield(OutOpt,'keepProtCA'), OutOpt.keepProtCA = 0; end
% OutType = OutOpt.Type;

% supported file types
supportedTrajFileExts = {'.DCD'};
supportedTopFileExts = {'.PSF'};

if isfield(AtomInfo,'TopFile')
  TopFile = AtomInfo.TopFile;
else
  error('AtomInfo.TopFile is missing.')
end

if isfield(AtomInfo,'ResName')
  ResName = AtomInfo.ResName;
else
  error('AtomInfo.ResName is missing.')
end

if isfield(AtomInfo,'AtomNames')
  AtomNames = AtomInfo.AtomNames;
else
  error('AtomInfo.AtomNames is missing.')
end

if isfield(AtomInfo,'SegName')
  SegName = AtomInfo.SegName;
else
  error('AtomInfo.SegName is missing.')
end

if ~ischar(TopFile)||regexp(TopFile,'\w+\.\w+','once')<1
  error('TopFile must be given as a character array, including the filename extension.')
end

% if numel(regexp(TopFile,'\.'))>1
%   error('Only one period (".") can be included in TopFile as part of the filename extension. Remove the others.')
% end

if exist(TopFile,'file')>0
  [TopFilePath, TopFileName, TopFileExt] = fileparts(TopFile);
  TopFile = fullfile(TopFilePath, [TopFileName, TopFileExt]);
else
  error('TopFile "%s" could not be found.', TopFile)
end

if ischar(TrajFile)
  % single trajectory file
  
  if exist(TrajFile,'file')>0
    % extract file extension and file path
    [TrajFilePath, TrajFileName, TrajFileExt] = fileparts(TrajFile);
    % add full file path to TrajFile
    TrajFile = fullfile(TrajFilePath, [TrajFileName, TrajFileExt]);
  else
    error('TrajFile "%s" could not be found.', TrajFile)
  end
  
  TrajFile = {TrajFile};
  TrajFilePath = {TrajFilePath};
  TrajFileExt = {TrajFileExt};
  nTrajFiles = 1;
elseif iscell(TrajFile)
  % multiple trajectory files
  if ~all(cellfun('isclass', TrajFile, 'char'))
    error('If TrajFile is a cell array, each element must be a character array.')
  end
  nTrajFiles = numel(TrajFile);
  TrajFilePath = cell(nTrajFiles,1);
  TrajFileName = cell(nTrajFiles,1);
  TrajFileExt = cell(nTrajFiles,1);
  for k=1:nTrajFiles
    if exist(TrajFile{k},'File')>0
      [TrajFilePath{k}, TrajFileName{k}, TrajFileExt{k}] = fileparts(TrajFile{k});
      TrajFile{k} = fullfile(TrajFilePath{k}, [TrajFileName{k}, TrajFileExt{k}]);
    else
      error('TrajFile "%s" could not be found.', TrajFile{k})
    end
  end
  % make sure that all file extensions are identical
  if ~all(strcmp(TrajFileExt,TrajFileExt{1}))
    error('At least two of the TrajFile file extensions are not identical.')
  end
  if ~all(strcmp(TrajFilePath,TrajFilePath{1}))
    error('At least two of the TrajFilePath locations are not identical.')
  end
else
  error(['Please provide ''TrajFile'' as a single character array ',...
         '(single trajectory file) or a cell array whose elements are ',...
         'character arrays (multiple trajectory files).'])
end

TrajFileExt = upper(TrajFileExt{1});
TopFileExt = upper(TopFileExt);

% check if file extensions are supported

if ~any(strcmp(TrajFileExt,supportedTrajFileExts))
  error('The TrajFile extension "%s" is not supported.', TrajFileExt)
end

if ~any(strcmp(TopFileExt,supportedTopFileExts))
  error('The TopFile extension "%s" is not supported.', TopFileExt)
end

ExtCombo = [TrajFileExt, ',', TopFileExt];

if OutOpt.Verbosity==1, tic; end

% parse through list of trajectory output files
for iTrajFile=1:nTrajFiles
  [temp,psf] = processMD(TrajFile{iTrajFile}, TopFile, SegName, ResName, AtomNames, ExtCombo);
  if iTrajFile==1
    MD = temp;
  else
    % combine trajectories through array concatenation
    if MD.dt~=temp.dt
      error('Time steps of trajectory files %s and %s are not equal.',TrajFile{iTrajFile},TrajFile{iTrajFile-1})
    end
    MD.nSteps = MD.nSteps + temp.nSteps;
    MD.ProtCAxyz = cat(1, MD.ProtCAxyz, temp.ProtCAxyz);
    MD.Labelxyz = cat(1, MD.Labelxyz, temp.Labelxyz);
  end
  % this could take a long time, so notify the user of progress
  if OutOpt.Verbosity
    updateuser(iTrajFile,nTrajFiles)
  end
end

clear temp

% initialize big arrays here for efficient memory usage
MD.FrameTraj = zeros(MD.nSteps,3,3);
MD.FrameTrajwrtProt = zeros(3,3,1,MD.nSteps);
MD.dihedrals = zeros(MD.nSteps,5);

% filter out spin label atomic coordinates
ONxyz = MD.Labelxyz(:,:,psf.idx_ON);
NNxyz = MD.Labelxyz(:,:,psf.idx_NN);
C1xyz = MD.Labelxyz(:,:,psf.idx_C1);
C2xyz = MD.Labelxyz(:,:,psf.idx_C2);
C1Rxyz = MD.Labelxyz(:,:,psf.idx_C1R);
C2Rxyz = MD.Labelxyz(:,:,psf.idx_C2R);
C1Lxyz = MD.Labelxyz(:,:,psf.idx_C1L);
S1Lxyz = MD.Labelxyz(:,:,psf.idx_S1L);
SGxyz = MD.Labelxyz(:,:,psf.idx_SG);
CBxyz = MD.Labelxyz(:,:,psf.idx_CB);
CAxyz = MD.Labelxyz(:,:,psf.idx_CA);
Nxyz = MD.Labelxyz(:,:,psf.idx_N);

MD = rmfield(MD,'Labelxyz');

% Calculate frame vectors

% N-O bond vector
NO_vec = ONxyz - NNxyz;

% N-C1 bond vector
NC1_vec = C1xyz - NNxyz;

% N-C2 bond vector
NC2_vec = C2xyz - NNxyz;

% Normalize vectors
NO_vec = bsxfun(@rdivide,NO_vec,sqrt(sum(NO_vec.*NO_vec,2)));
NC1_vec = bsxfun(@rdivide,NC1_vec,sqrt(sum(NC1_vec.*NC1_vec,2)));
NC2_vec = bsxfun(@rdivide,NC2_vec,sqrt(sum(NC2_vec.*NC2_vec,2)));

% z-axis
vec1 = cross(NC1_vec, NO_vec, 2);
vec2 = cross(NO_vec, NC2_vec, 2);
MD.FrameTraj(:,:,3) = vec1 + vec2;
MD.FrameTraj(:,:,3) = bsxfun(@rdivide,MD.FrameTraj(:,:,3),sqrt(sum(MD.FrameTraj(:,:,3).*MD.FrameTraj(:,:,3),2)));

% x-axis
MD.FrameTraj(:,:,1) = NO_vec;

% y-axis
MD.FrameTraj(:,:,2) = cross(MD.FrameTraj(:,:,3), MD.FrameTraj(:,:,1), 2);

% find rotation matrix to align protein alpha carbons with inertia 
% tensor in first snapshot
MD.RProtDiff = findproteinorient(MD.ProtCAxyz);

if ~OutOpt.keepProtCA
  % we don't need this anymore and it could be huge
  MD = rmfield(MD,'ProtCAxyz');
end

MD.FrameTraj = permute(MD.FrameTraj, [2, 3, 4, 1]);

% find frame trajectory without protein's rotational diffusion
for iStep = 1:MD.nSteps
  R = MD.RProtDiff(:,:,iStep);
  thisStep = MD.FrameTraj(:,:,1,iStep);
  MD.FrameTrajwrtProt(:,1,1,iStep) = thisStep(:,1).'*R;
  MD.FrameTrajwrtProt(:,2,1,iStep) = thisStep(:,2).'*R;
  MD.FrameTrajwrtProt(:,3,1,iStep) = thisStep(:,3).'*R;
end

% % Calculate side chain dihedral angles
% MD.dihedrals(:,1) = dihedral(Nxyz,CAxyz,CBxyz,SGxyz);
% MD.dihedrals(:,2) = dihedral(CAxyz,CBxyz,SGxyz,S1Lxyz);
% MD.dihedrals(:,3) = dihedral(CBxyz,SGxyz,S1Lxyz,C1Lxyz);
% MD.dihedrals(:,4) = dihedral(SGxyz,S1Lxyz,C1Lxyz,C1Rxyz);
% MD.dihedrals(:,5) = dihedral(S1Lxyz,C1Lxyz,C1Rxyz,C2Rxyz);
% 
% MD.dihedrals = permute(MD.dihedrals,[2,3,1]);

end

function [Traj,psf] = processMD(TrajFile, TopFile, SegName, ResName, AtomNames, ExtCombo, OutType)
% 

switch ExtCombo
  case '.DCD,.PSF'
    % obtain atom indices of nitroxide coordinate atoms
    psf = md_readpsf(TopFile, SegName, ResName, AtomNames);  % TODO perform consistency checks between topology and trajectory files
    
    Traj = md_readdcd(TrajFile, psf.idx_ProteinLabel);

    % protein alpha carbon atoms
    Traj.ProtCAxyz = Traj.xyz(:,:,psf.idx_ProteinCA);

    % spin label atoms
    Traj.Labelxyz = Traj.xyz(:,:,psf.idx_SpinLabel);
%     Traj.ONxyz = Traj.xyz(:,:,psf.idx_ON==psf.idx_SpinLabel);
%     Traj.NNxyz = Traj.xyz(:,:,psf.idx_NN==psf.idx_SpinLabel);
%     Traj.C1xyz = Traj.xyz(:,:,psf.idx_C1==psf.idx_SpinLabel);
%     Traj.C2xyz = Traj.xyz(:,:,psf.idx_C2==psf.idx_SpinLabel);
%     Traj.C1Rxyz = Traj.xyz(:,:,psf.idx_C1R==psf.idx_SpinLabel);
%     Traj.C2Rxyz = Traj.xyz(:,:,psf.idx_C2R==psf.idx_SpinLabel);
%     Traj.C1Lxyz = Traj.xyz(:,:,psf.idx_C1L==psf.idx_SpinLabel);
%     Traj.S1Lxyz = Traj.xyz(:,:,psf.idx_S1L==psf.idx_SpinLabel);
%     Traj.SGxyz = Traj.xyz(:,:,psf.idx_SG==psf.idx_SpinLabel);
%     Traj.CBxyz = Traj.xyz(:,:,psf.idx_CB==psf.idx_SpinLabel);
%     Traj.CAxyz = Traj.xyz(:,:,psf.idx_CA==psf.idx_SpinLabel);
%     Traj.Nxyz = Traj.xyz(:,:,psf.idx_N==psf.idx_SpinLabel);
    
    % remove the rest
    Traj = rmfield(Traj, 'xyz');
  otherwise
    error('TrajFile type "%s" and TopFile "%s" type combination is either ',...
          'not supported or not properly entered. Please see documentation.', TrajFileExt, TopFileExt)
end

end

function updateuser(iter,totN)
% Update user on progress

persistent reverseStr

if isempty(reverseStr), reverseStr = ''; end

avg_time = toc/iter;
secs_left = (totN - iter)*avg_time;
mins_left = floor(secs_left/60);

msg1 = sprintf('Iteration: %d/%d\n', iter, totN);
if avg_time<1.0
  msg2 = sprintf('%2.1f it/s\n', 1/avg_time);
else
  msg2 = sprintf('%2.1f s/it\n', avg_time);
end
msg3 = sprintf('Time left: %d:%2.0f\n', mins_left, mod(secs_left,60));
msg = [msg1, msg2, msg3];

fprintf([reverseStr, msg]);
reverseStr = repmat(sprintf('\b'), 1, length(msg));

end

function DihedralAngle = dihedral(a1Traj,a2Traj,a3Traj,a4Traj)
% function DihedralAngle = dihedral(traj,atomlist)
% calculate dihedral angle given 4 different atom indices and a trajectory
% idx_atom1 = atomlist{1};
% idx_atom2 = atomlist{2};
% idx_atom3 = atomlist{3};
% idx_atom4 = atomlist{4};

% a1 = traj(:, :, idx_atom1) - traj(:, :, idx_atom2);
a1 = a1Traj - a2Traj;
a1 = bsxfun(@rdivide,a1,sqrt(sum(a1.*a1, 2)));
% a2 = traj(:, :, idx_atom3) - traj(:, :, idx_atom2);
a2 = a3Traj - a2Traj;
a2 = bsxfun(@rdivide,a2,sqrt(sum(a2.*a2, 2)));
% a3 = traj(:, :, idx_atom3) - traj(:, :, idx_atom4);
a3 = a3Traj - a4Traj;
a3 = bsxfun(@rdivide,a3,sqrt(sum(a3.*a3, 2)));

b1 = cross(a2, a3, 2);
b2 = cross(a1, a2, 2);

vec1 = dot(a1, b1, 2);
vec1 = vec1.*sum(a2.*a2, 2).^0.5;
vec2 = dot(b1, b2, 2);

DihedralAngle = atan2(vec1, vec2);

end

function rotmat = findproteinorient(traj)
% orient protein along the principal axes of inertia
%

% setup
nSteps = size(traj, 1);
nAtoms = size(traj, 3);
mass = 1;
rotmat = zeros(3,3,nSteps);

% subtract by the geometric center
traj = bsxfun(@minus,traj,mean(traj,3));

for iStep = 1:nSteps
  % calculate the principal axis of inertia
  thisStep = squeeze(traj(iStep,:,:));
  x = thisStep(1,:);
  y = thisStep(2,:);
  z = thisStep(3,:);

  I = zeros(3,3);

  I(1,1) = sum(mass.*(y.^2 + z.^2));
  I(2,2) = sum(mass.*(x.^2 + z.^2));
  I(3,3) = sum(mass.*(x.^2 + y.^2));

  I(1,2) = - sum(mass.*(x.*y));
  I(2,1) = I(1,2);

  I(1,3) = - sum(mass.*(x.*z));
  I(3,1) = I(1,3);

  I(2,3) = - sum(mass.*(y.*z));
  I(3,2) = I(2,3);

  % scale I for better performance
  I = I./norm(I);

  [~, ~, a] = svd(I); %a is already sorted by descending order
%   p_axis = a(:, end:-1:1); %z-axis has the largest inertia
  p_axis = a;

  % check reflection
  if det(p_axis) < 0
    p_axis(:,1) = - p_axis(:,1);
  end

%   % project onto the principal axis of inertia
%   proj = thisStep.' * p_axis;
%   traj(iStep, 1, :) = proj(:, 1).';
%   traj(iStep, 2, :) = proj(:, 2).';
%   traj(iStep, 3, :) = proj(:, 3).';
  
  rotmat(:,:,iStep) = p_axis;
end

end

%                    Format    'Protein+Frame': (default) xyz coordinates 
%                                of alpha carbon atoms in the protein and 
%                                coordinate frame vector trajectories given
%                                as output
%                              'Frame': coordinate frame vector 
%                                trajectories given as output
%                              'Dihedrals': spin label side chain dihedrals 
%                                given as output

%     switch OutType
%       case 'Protein+Frame'
%       case 'Frame'
%       case 'Dihedrals'

% function status = FileExist(FileName)
% 
% 
% 
% end