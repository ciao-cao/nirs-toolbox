% Example of Estimating CMRO2 using the toolbox
% The CMRO2 model is based on
% Neuroimage. 2004 Feb;21(2):547-67.
% A state-space model of the hemodynamic approach: nonlinear filtering of BOLD signals.
% Riera JJ1, Watanabe J, Kazuki I, Naoki M, Aubert E, Ozaki T, Kawashima R.

Fs=10;
nlgr = WKM_idnl_vs2;

% Generate a response model
ntps=2000;
u=zeros(ntps+1,2);
for i=200:600:ntps
    u(i+[1:100],1)=.1; 
    u(i+[1:100],2)=.05; 
end

% u is the flow inducing signal.  
% This is an diffusion limited model of CMRO2 (e.g. Buxton 1998).  For now,
% there are only one input

% This simulates the HbO/Hb data
u=iddata([],u,1/Fs);
set(u,'InputName', {'flow-inducing','CMRO2-inducing'}, 'InputUnit', {'%','%'}); 
opt = simOptions('InitialCondition',cell2mat(getinit(nlgr)));
data=sim(nlgr,u,opt); 

% RUn the fitting model
[CMRO2,CBF]=kalman_fit(nlgr,data);


Fs=10;
nlgr = WKM_idnl;

ntps=2000;
u=zeros(ntps+1,1);
for i=200:600:ntps
    u(i+[1:100],1)=.1; 
   end
% u is the flow inducing signal.  
% This is an diffusion limited model of CMRO2 (e.g. Buxton 1998).  For now,
% there are only one input

% This simulates the HbO/Hb data
u=iddata([],u,1/Fs);
set(u,'InputName', {'flow-inducing'}, 'InputUnit', {'%'}); 
opt = simOptions('InitialCondition',cell2mat(getinit(nlgr)));
data=sim(nlgr,u,opt); 

% RUn the fitting model
[CMRO2,CBF]=kalman_fit(nlgr,data);


% In the toolbox
raw = nirs.testing.simData;
j=nirs.modules.OpticalDensity;
j=nirs.modules.BeerLambertLaw(j);
j.PPF=1;  
hb=j.run(raw);

% This doesn't quite work yet.  I need to add CMRO2 as an independent
% regressor
j=nirs.modules.CalculateCMRO2;
cmro2=j.run(hb);

j=nirs.modules.AR_IRLS;
Stats=j.run(cmro2);




% We can also do model fitting
nlgr = setpar(nlgr, 'Fixed', {0,1,1,1,1,1,1});  % fit only the gain on the flow-inducing signal (a0)
y=[dd z];
opt = nlgreyestOptions('Display', 'on');
nlgr = nlgreyest(y, nlgr, opt);

present(nlgr);


% Compare to AR model
na = [2 2; 2 2];
nb = [2; 2];
nk = [1; 1];
dcarx = arx(y, [na nb nk]);
compare(y, nlgr, dcarx);


% prediction error
pe(y, nlgr);

figure('Name',[nlgr.Name ': residuals of estimated model']);
resid(y,nlgr);



Xo=findstates(nlgr,y,Inf);
opt = simOptions('InitialCondition',Xo);
sim(nlgr,z,opt);

