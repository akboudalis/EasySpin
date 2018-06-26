% startvec takes the Hilbert space spin operator Sx as input and returns as
% output the vector representation of the Sx operator in Liouville space

function StartingVector = startvec_LMK(basis,lambda,SxH)

if isfield(basis,'jK') && ~isempty(basis.jK) && any(basis.jK)
  error('This function expects an LMK basis, without jK.');
end

L = basis.L;
M = basis.M;
K = basis.K;
nOriBasis = numel(L);

if ~any(lambda)
  idx0 = find(L==0 & M==0 & K==0);
  if numel(idx0)~=1
    error('Exactly one orientational basis function with L=M=K=0 is allowed.');
  end
  nSpinBasis = numel(SxH);
  idx = (idx0-1)*nSpinBasis + (1:nSpinBasis);
  nBasis = nOriBasis*nSpinBasis;
  StartingVector = sparse(idx,1,SxH(:),nBasis,nBasis);
  StartingVector = StartingVector/sqrt(sum(StartingVector.^2));
  return
end

c20 = lambda(1);
c22 = lambda(2);
c40 = lambda(3);
c42 = lambda(4);
c44 = lambda(5);

% set up starting vector in orientational basis
oriVector = zeros(nOriBasis,1);
for b = 1:numel(oriVector)
  L_ = L(b);
  M_ = M(b);
  K_ = K(b);
  if mod(L_,2)==0 && M_==0 && mod(K_,2)==0
    % numerically integrate
    fun = @(a,b,c) wignerd([L_ M_ K_],a,b,c) .* exp(-U(a,b,c)/2) .* sin(b);
    Int = integral3(fun,0,2*pi,0,pi,0,2*pi);
    oriVector(b) = Int;
  end
end
oriVector = oriVector/norm(oriVector);

% form starting vector in direct product basis
StartingVector = real(kron(SxH(:),oriVector));
StartingVector = StartingVector/norm(StartingVector);
StartingVector = sparse(StartingVector);

  function u = U(a,b,c)
    u = 0;
    if c20~=0, u = u + c20*wignerd([2 0 0],a,b,c); end
    if c22~=0, u = u + c22*(wignerd([2 0 2],a,b,c) + wignerd([2 0 -2],a,b,c)); end
    if c40~=0, u = u + c40*wignerd([4 0 0],a,b,c); end
    if c42~=0, u = u + c42*(wignerd([4 0 2],a,b,c) + wignerd([4 0 -2],a,b,c)); end
    if c44~=0, u = u + c44*(wignerd([4 0 4],a,b,c) + wignerd([4 0 -4],a,b,c)); end
  end

end
