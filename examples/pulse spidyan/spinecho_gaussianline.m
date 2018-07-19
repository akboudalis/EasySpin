% spin echo of a Gaussian line (spidyan)
%==========================================================================
% this demonstrates how to simulate the spin echo of a gaussian line.
% simulating a gaussian line instead of spectrum, which can be done with 
% saffront. this might be advantageous for example when you are only 
% interested in the dynamics during your pulse sequence and dont need to 
% simulate an entire spectrum. or it can help you speed up simulations
% This script calculates two echos:
%  - first with rectangular pulses
%  - second with frequency-swept pulses.

clear

% Sets up a Gaussian Distribution of spin packets
CenterFrequency = 9.5; % center frequency of Gaussian distribution, GHz
GWidth = 0.01;     % width of Gaussian distribution, GHz
FreqStart = 9.45;  % starting value for sampling
FreqEnd = 9.55;  % final value for sampling
Sampling = 0.0005;   % stepsize for sampling
ZeemanFreqVec = FreqStart:Sampling:FreqEnd; % vector with resonance frequencies
P = exp(-((CenterFrequency-ZeemanFreqVec)/GWidth).^2); % probabilities
P = P/trapz(P); % normalization
nSpinpackets = length(ZeemanFreqVec);

%% refocused echo with monochromatic pulses

% Experiment definition
Pulse90.Type = 'rectangular';
Pulse90.tp = 0.025; % pulse length, mus
Pulse90.Flip = pi/2; % flip angle, rad

Pulse180.Type = 'rectangular';
Pulse180.tp = 0.025; % pulse length, mus
Pulse180.Flip = pi;  % flip angle, rad

Exp.Sequence = {Pulse90 0.25 Pulse90 0.5}; 
Exp.mwFreq = 9.5; % GHz

% If you want to see only the free evolution after the second pulse use:
Exp.DetSequence = [0 0 0 1]; % detect the last event
% remove the above line or comment it out, the observe the entire sequence

Exp.DetOperator = {'+1'}; % detect electron coherence
Exp.DetFreq = 9.5; % GHz

Signal = 0; % initialize the signal

% Loop over the spinpackets and sum up the traces ------------
for i = 1 : nSpinpackets
  
  Sys_.ZeemanFreq = ZeemanFreqVec(i); % Set Zeeman frequency
  
  [t, signal] = spidyan(Sys_,Exp);
  
  Signal = Signal + signal*P(i); % cummulate signals
  
end

% plotting
figure(1)
clf
plot(t,real(Signal));
xlabel('t (\mus)')
axis tight


%% Echo with linear chirps

% Experiment definition
Chirp90.Type = 'quartersin/linear';
Chirp90.trise = 0.005; % rise time in us
Chirp90.tp = 0.05; % pulse length, us
Chirp90.Frequency = [-80 80]; % frequency band
Chirp90.Flip = pi/2; % flip angle in rad

Chirp180.Type = 'quartersin/linear';
Chirp180.trise = 0.005; % rise time in us
Chirp180.tp = 0.025; % pulse length, us
Chirp180.Frequency = [-80 80]; % frequency band
Chirp180.Flip = pi; % flip angle in rad

Exp.Sequence = {Chirp90 0.25 Chirp180 0.5}; % free evolution events in us

% Loop over the spinpackets and sum up the traces
for i = 1 : nSpinpackets
  
  Sys_.ZeemanFreq = ZeemanFreqVec(i); % Set Zeeman frequency
  
  [t, signal] = spidyan(Sys_,Exp);
  if i == 1
    Signal = signal*P(i);
  else
    Signal = Signal + signal*P(i);
  end
  
end

figure(2)
clf
plot(t*1000,abs(Signal));
xlabel('t (\mus)')
axis tight