% Single-crystal spectra of inter-system crossing spin-polarized triplet
%==========================================================================
clear, clf, clc
  
% Experimental parameters and simulation options
%------------------------------------------------------------------
Exp.mwFreq = 9.7;
Exp.Range = [0 450];
Exp.Harmonic = 0;

% Orientation of the crystal frame in the lab frame.
% Change this value to turn the crystal in the spectrometer.
Exp.CrystalOrientation = pi/180*[0 0 0];

Opt.Verbosity = 0;

% Defining two spin systems, one with axial and one with orthorhombic D
%-----------------------------------------------------------------------
D_cm = 0.06;  % cm^-1
D = unitconvert(D_cm,'cm^-1->MHz');  % cm^-1 -> MHz
Sys = struct('S',1,'g',2,'lw',5);
Sys.initState = {[0 1 0],'xyz'};  % selective population ot the Ty state

Sys1 = Sys;
Sys1.D = D*[1 0];
Sys2 = Sys;
Sys2.D = D*[1 -0.1];

% Simulations & Graphical rendering
%-------------------------------------------------------------
subplot(3,2,1);
levelsplot(Sys1,Exp.CrystalOrientation,Exp.Range,Exp.mwFreq);
title('Axial D tensor');

subplot(3,2,3);
pepper(Sys1,Exp,Opt);

subplot(3,2,2);
levelsplot(Sys2,Exp.CrystalOrientation,Exp.Range,Exp.mwFreq);
title('Non-axial D tensor');

subplot(3,2,4);
pepper(Sys2,Exp,Opt);

Exp.CrystalOrientation = [];

subplot(3,2,5);
pepper(Sys1,Exp,Opt);

subplot(3,2,6);
pepper(Sys2,Exp,Opt);
