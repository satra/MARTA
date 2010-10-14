function F0 = ComputeF0(s, varargin);%COMPUTEF0  - continous pitch estimator%%	usage:  F0 = ComputeF0(s, ...)%% This procedure is an implementation of Alain de Cheveigné's YIN algorithm % for estimating a continuous pitch contour F0 from speech vector S%% S may be an AUDIO object, a MAVIS-compatible array of structs (first element % assumed to be audio), or a {S,SRATE} cell object%% cf. de Cheveigné, A., & Kawahara, H. (2002) 'YIN, a fundamental frequency% estimator for speech and music,' JASA, 111, 1917-1930.%% see also COMPUTEF01% Alain de Cheveigné, CNRS/Ircam, 2002.% Copyright (c) 2002 Centre National de la Recherche Scientifique.% mkt 01/08 from yin, yink, etc.% parse argsif nargin < 1,	eval('help ComputeF0');	return;end;if isa(s,'audio'),	sr = s.SRATE;	s = double(s);elseif isstruct(s),	sr = s.SRATE;	s = s.SIGNAL;elseif iscell(s),	sr = s{2};	s = s{1};else,	error('argument error (signal)');end;if exist('ComputeF0_helper') ~= 3,	error('missing compiled ComputeF0_helper.mex');end;F0thr = 0.2;for ai = 1 : 2 : length(varargin),	switch upper(varargin{ai}),		case 'F0THR', F0thr = varargin{ai+1};		otherwise, error('argument error:  %s', varargin{ai});	end;end;% defaultsminf0 = 30;			% Hz - minimum frequencymaxf0 = [];			% Hz - maximum frequencywsize = []; 		% s - integration window sizelpf = [];			% Hz - lowpass prefiltering cutoffthresh = 0.1;		% difference function thresholdrelflag = 1;		% if true threshold is relative to global min of difference functionbufsize = 50000;	% computation buffer sizehop = 32;			% samples - interval between estimatesrange=[];			% range of file samples to processshift=0;			% flag to control the temporal shift of analysis windows (left/sym/right)% load param structureif isempty(maxf0), maxf0 = floor(sr/4); end;if isempty(wsize), wsize = ceil(sr/minf0); end;if isempty(lpf), lpf = sr/4; end;p = struct('sr',sr, ...			'range', [1 length(s)], ...			'minf0', minf0, ...			'thresh', thresh, ...			'relflag', relflag, ...			'bufsize', bufsize, ...			'hop', hop, ...			'maxf0', maxf0, ...			'wsize', wsize, ...			'lpf', lpf, ...			'shift', shift);			% process signal a chunk at a timeidx=p.range(1)-1;totalhops=round((p.range(2)-p.range(1)+1) / p.hop);r1=nan*zeros(1,totalhops);r2=nan*zeros(1,totalhops);r3=nan*zeros(1,totalhops);r4=nan*zeros(1,totalhops);idx2=0+round(p.wsize/2/p.hop);while 1,	start = idx+1;	stop = idx+p.bufsize;	stop=min(stop, p.range(2));	xx = s(start:stop);	[prd,ap0,ap,pwr]=yin_helper(xx,p);	n=size(prd ,2);	if (~n) break; end;	idx=idx+n*p.hop;	r1(idx2+1:idx2+n)= prd;		% period estimate	r2(idx2+1:idx2+n)= ap0;		% gross aperiodicity measure	r3(idx2+1:idx2+n)= ap;		% fine aperiodicity measure	r4(idx2+1:idx2+n)= pwr;		% period-smoothed instantaneous power	idx2=idx2+n;	endF0 = p.sr ./ r1(:);F0(find(r2>F0thr)) = NaN;F0(find(F0<80 | F0>300)) = NaN;%==============================================================================% Estimate F0 of a chunk of signalfunction [prd,ap0,ap,pwr]=yin_helper(x,p,dd)smooth=ceil(p.sr/p.lpf);%x=rsmooth(x,smooth); 	% light low-pass smoothing%x = ComputeF0_helper('RSMOOTH',x,smooth);	% crashes under Windoze%x=x(smooth:end-smooth+1);%x = filter(rectwin(smooth)/smooth,1,x);%x = x(smooth:end);% mkt - 800 Hz LP works much better[b,a] = cheby2(6,30,1600/p.sr);x = filtfilt(b,a, x);[m,n]=size(x);maxlag = ceil(p.sr/p.minf0); 	minlag = floor(p.sr/p.maxf0);mxlg = maxlag+2; % +2 to improve interp near maxlaghops=floor((m-mxlg-p.wsize)/p.hop);prd=zeros(1,hops);ap0=zeros(1,hops);ap=zeros(1,hops);pwr=zeros(1,hops);if hops<1; return; end% difference function matrixdd=zeros(floor((m-mxlg-p.hop)/p.hop),mxlg);if p.shift == 0		 % windows shift both ways	lags1=round(mxlg/2) + round((0:mxlg-1)/2); 	lags2=round(mxlg/2) - round((1:mxlg)/2);	lags=[lags1; lags2];elseif p.shift == 1 % one window fixed, other shifts right	lags=[zeros(1,mxlg); 1:mxlg]; elseif p.shift == -1 % one window fixed, other shifts right	lags=[mxlg-1:-1:0; mxlg*ones(1,mxlg)]; else	error (['unexpected shift flag: ', num2str(p.shift)]);end%rdiff_inplace(x,x,dd,lags,p.hop);if any(lags(:) < 0), error('found negative lag'); end;ComputeF0_helper('RDIFF_INPLACE',x,x,dd,lags,p.hop);%rsum_inplace(dd,round(p.wsize/p.hop));ComputeF0_helper('RSUM_INPLACE',dd,round(p.wsize/p.hop));dd=dd';%[dd,ddx]=minparabolic(dd); 	% parabolic interpolation near min[dd,ddx] = ComputeF0_helper('MINPARABOLIC',dd);%cumnorm_inplace(dd);;		% cumulative mean-normalizeComputeF0_helper('CUMNORM_INPLACE',dd);% first period estimate%global jj;for j=1:hops	d=dd(:,j);	if p.relflag%		pd=dftoperiod2(d,[minlag,maxlag],p.thresh);		pd = ComputeF0_helper('DFTOPERIOD2',d,[minlag,maxlag],p.thresh);	else%		pd=dftoperiod(d,[minlag,maxlag],p.thresh); 		pd = ComputeF0_helper('DFTOPERIOD',d,[minlag,maxlag],p.thresh); 	end	ap0(j)=d(pd+1);	prd(j)=pd;end% replace each estimate by best estimate in rangerange = 2*round(maxlag/p.hop);%if hops>1; prd=prd(mininrange(ap0,range*ones(1,hops))); endif hops>1; prd=prd(ComputeF0_helper('MININRANGE',ap0,range*ones(1,hops))); end%prd=prd(mininrange(ap0,prd)); 	% refine estimate by constraining search to vicinity of best local estimatemargin1=0.6; 		margin2=1.8; 		for j=1:hops	d=dd(:,j);	dx=ddx(:,j);	pd=prd(j);	lo=floor(pd*margin1); lo=max(minlag,lo);	hi=ceil(pd*margin2); hi=min(maxlag,hi);%	pd=dftoperiod(d,[lo,hi],0); 	pd=ComputeF0_helper('DFTOPERIOD',d,[lo,hi],0); 	ap0(j)=d(pd+1);	pd=pd+dx(pd+1)+1;	% fine tune based on parabolic interpolation	prd(j)=pd;% power estimates	idx=(j-1)*p.hop;	k=(1:ceil(pd))';	x1=x(k+idx);	x2=k+idx+pd-1;%	interp_inplace(x,x2);	ComputeF0_helper('INTERP_INPLACE',x,x2);	x3=x2-x1;	x4=x2+x1;%	x1=x1.^2; rsum_inplace(x1,pd);%	x3=x3.^2; rsum_inplace(x3,pd);%	x4=x4.^2; rsum_inplace(x4,pd);	x1=x1.^2; ComputeF0_helper('RSUM_INPLACE',x1,pd);	x3=x3.^2; ComputeF0_helper('RSUM_INPLACE',x3,pd);	x4=x4.^2; ComputeF0_helper('RSUM_INPLACE',x4,pd);		x1=x1(1)/pd;	x2=x2(1)/pd;	x3=x3(1)/pd;	x4=x4(1)/pd;		pwr(j)=x1;		% total power	% fine aperiodicity	ap(j)=(eps+x3)/(eps+(x3+x4)); % accurate, only for valid min	prd(j)=pd;end