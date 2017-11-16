function [err,data] = test(opt,olddata)

Freq = 1500;
DetectionOperators = {'+1'};

TimeAxis = 0:0.0001:0.2;
Cos = cos(2*pi*Freq*TimeAxis);
Sin = sin(2*pi*Freq*TimeAxis);

RawSignal1 = Cos;

RawSignal2(1,:,:) = [Cos; Cos + 1i*Sin; ones(1,length(TimeAxis)); ones(1,length(TimeAxis))];
RawSignal2(2,1:2,:) = [Cos + 1i*Sin*1e-10; Cos*1e-10 + 1i*Sin];

[ProcessedSignal1] = signalprocessing(TimeAxis,RawSignal1,DetectionOperators,-Freq/1000);

data.ProcessedSignal1 = ProcessedSignal1;

DetectionOperators = {'+1','x2','x2','x2'};
[ProcessedSignal2] = signalprocessing(TimeAxis,RawSignal2,DetectionOperators,[-Freq/1000 -Freq/1000 0]);

data.ProcessedSignal2 = ProcessedSignal2;


if ~isempty(olddata)
  err = [~areequal(ProcessedSignal1,olddata.ProcessedSignal1,1e-4) ~areequal(ProcessedSignal2,olddata.ProcessedSignal2,1e-4)];
else
  err = [];
end

