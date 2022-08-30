% classdef RR_tf
%
% This class defines a set of operations on transfer functions, each given by a pair of 
% numerator and denominator polynomials of the RR_poly class, and the equivalent (z,p,K) representation.
% In contrast to the Matlab 'tf' command, the RR_tf class definition automatically performs pole/zero cancellations,
% and can robustly handle a mixture of numeric and symbolic data.
% Try, for example, syms z1, G=RR_tf([z1 z1 3 4],[4 5 6 z1],1), T=G./(1+G)
% DEFINITION:
%   G=RR_tf(num)      1 argument  defines an RR_tf object G from a numerator polynomial, setting denominator=1
%   G=RR_tf(num,den)  2 arguments defines an RR_tf object from numerator and denominator polynomials
%   G=RR_tf(z,p,K)    3 arguments defines an RR_tf object from vectors of zeros and poles, z and p, and the gain K
%   Note that any RR_tf object G has two RR_poly fields, G.num and G.den
% STANDARD OPERATIONS (overloading the +, -, *, ./ operators):
%   plus:     G1+G2  gives the sum of two transfer functions        (or, a transfer functions and a scalar)
%   minus:    G1-G2  gives the difference of two transfer functions (or, a transfer functions and a scalar)
%   mtimes:   G1*G2  gives the product of two transfer functions    (or, a transfer functions and a scalar)
%   rdivide:  G1./G2 divides two transfer functions
% SOME TESTS:  [Try them! Change them!]
%   G=RR_tf([1.1 10 110],[0 1 10 100],1), D=RR_tf([1 2],[4 5])       % Define a couple of test transfer functions
%   T=G*D./(1+G*D)
% Renaissance Robotics codebase, Appendix A, https://github.com/tbewley/RR
% Copyright 2022 by Thomas Bewley, distributed under BSD 3-Clause License.

classdef RR_tf < matlab.mixin.CustomDisplay
    properties
    	num  % num and den are of type RR_poly 
    	den
        h    % timestep for discrete-time TF representations (empty for continuous-time TF representations)
        z    % z and k are row vectors, and K is an ordinary scalar
        p
        K    % Note that the (num,den) and (z,p,K) representations of the transfer function are equivalent
    end
    methods
    	function obj = RR_tf(a,b,c)
            % Generate an RR_tf object:
            %   called with 1 argument,  generates from a numerator polynomial a, setting denominator=1
            %   called with 2 arguments, generates from a numerator polynomial a and a denominator polynomial b
            %   called with 3 arguments, generates from vectors of zeros and poles, a and b, and the overall gain c
            % Automatically performs pole/zero cancellations as necessary
    		switch nargin
    			case 1  
    				if ~isa(a,'RR_poly'), a=RR_poly(a); end, obj = RR_tf(a,RR_poly(1));
    			case 2 	
     				if  isa(a,'RR_poly'), obj.num=a; else, obj.num=RR_poly(a); end
   					if  isa(b,'RR_poly'), obj.den=b; else, obj.den=RR_poly(b); end
   					t=1/obj.den.poly(1); obj.den=obj.den*t; obj.num=obj.num*t;  % Make denominator monic
                    obj.z=roots(obj.num); obj.p=roots(obj.den);
                    % if  obj.num.s, obj.z=sym('z',[1 obj.num.n]); else, obj.z=roots(obj.num); end
                    % if  obj.den.s, obj.p=sym('p',[1 obj.den.n]); else, obj.p=roots(obj.den); end
                    obj.K=obj.num.poly(1); 
   				case 3	
                    obj.z=a; obj.p=b; obj.K=c;
    	    		obj.num=RR_poly(a,'roots'); obj.num.poly=c*obj.num.poly;
                    obj.den=RR_poly(b,'roots');
    	    end
            G.h=[];
     	    if obj.num.poly==0, obj.den=RR_poly(1); fprintf('Simplifying the zero transfer function\n'), end 
            if obj.num.n>0 & obj.den.n>0
                for i=1:obj.num.n        % Perform pole/zero cancellations!
                    TF=RR_eq(obj.z(i),obj.p,1e-3); modified=false;
                    for j=1:obj.den.n, if TF(j)
                        fprintf('Performing pole/zero cancellation at s='), disp(obj.z(i))
                        obj.z=obj.z([1:i-1,i+1:obj.num.n]);
                        obj.p=obj.p([1:j-1,j+1:obj.den.n]);
                        obj=RR_tf(obj.z,obj.p,obj.K); modified=true; break
                    end, end
                    if modified, break, end
                end
            if ~isnumeric(obj.z), obj.z=simplify(obj.z); obj.num.poly=simplify(obj.num.poly); end
            if ~isnumeric(obj.p), obj.p=simplify(obj.p); obj.den.poly=simplify(obj.den.poly); end
            end
    	end
    	function sum = plus(G1,G2)          
            % Defines G1+G2, where G1 and/or G2 are of class RR_tf
            % If G1 or G2 is a scalar, vector, or of class RR_poly, it is first converted to class RR_tf   
            [G1,G2]=check(G1,G2); sum  = RR_tf(G1.num*G2.den+G2.num*G1.den,G1.den*G2.den);
        end
        function diff = minus(G1,G2)       
            % Defines G1-G2, where G1 and/or G2 are of class RR_tf
            % If G1 or G2 is a scalar, vector, or of class RR_poly, it is first converted to class RR_tf   
            [G1,G2]=check(G1,G2); diff = RR_tf(G1.num*G2.den-G2.num*G1.den,G1.den*G2.den);
        end    
        function prod = mtimes(G1,G2)       
            % Defines G1*G2, where G1 and/or G2 are of class RR_tf
            % If G1 or G2 is a scalar, vector, or of class RR_poly, it is first converted to class RR_tf   
            [G1,G2]=check(G1,G2); prod = RR_tf(G1.num*G2.num,G1.den*G2.den);
        end
        function quo = rdivide(G1,G2)
            % Defines G1./G2, where G1 and/or G2 are of class RR_tf
            % If G1 or G2 is a scalar, vector, or of class RR_poly, it is first converted to class RR_tf   
            [G1,G2]=check(G1,G2); quo  = RR_tf(G1.num*G2.den,G1.den*G2.num);
        end
        function [G1,G2]=check(G1,G2)
            % Converts G1 or G2, as necessary, to the class RR_tf
            if ~isa(G1,'RR_tf'), G1=RR_tf(G1); end,  if ~isa(G2,'RR_tf'), G2=RR_tf(G2); end
        end
        function z = evaluate(G,s)
            for i=1:length(s)
                n=0; for k=1:G.num.n+1; n=n+G.num.poly(k)*s(i)^(G.num.n+1-k); end
                d=0; for k=1:G.den.n+1; d=d+G.den.poly(k)*s(i)^(G.den.n+1-k); end, z(i)=n/d;
            end
        end
        function [p,d,k,n]=PartialFractionExpansion(F,tol)
            % Compute {p,d,k,n} so that F(s)=num(s)/den(s)=d(1)/(s-p(1))^k(1) +...+ d(n)/(s-p(n))^k(n)
            % INPUTS:  F   a (proper or improper) rational polynomial of class RR_tf
            %          tol tolerance used when calculating repeated roots
            % OUTPUTS: p   poles of F (a row vector of length n)
            %          d   coefficients of the partial fraction expansion (a row vector of length n)
            %          k   powers of the denominator in each term (a row vector of length n)
            %          n   number of terms in the expansion
            % TESTS:   % The first example computes the Partial Fraction Expansion of a second-order strictly proper
            %          % TF that is only defined symbolically. (top that, Mathworks!) It then assigns some values.
            %          clear, syms c1 c0 a1 a0, F=RR_tf([c1 c0],[1 a1 a0])
            %          [p,d,k,n]=PartialFractionExpansion(F)
            %          c0=2; c1=1; a1=4; a0=3; eval(p), eval(d)
            %          % The second example generates an (improper) TF, computes its Partial Fraction Expansion,
            %          % then reconstructs the TF from this Partial Fraction Expansion.  Cool.
            %          F=RR_tf([1 2 2 3 5],[1 7 7],1), [p,d,k,n]=PartialFractionExpansion(F)
            %          F1=RR_tf(0); for i=1:n, if k(i)>0, F1=F1+RR_tf( d(i), RR_poly([1 -p(i)])^k(i) ); ...
            %             else, F1=F1+RR_tf([d(i) zeros(1,abs(k(i)))]); end, end  
            % Renaissance Robotics codebase, Appendix A (derivation in Appendix B), https://github.com/tbewley/RR
            % Copyright 2022 by Thomas Bewley, distributed under BSD 3-Clause License.
            m=F.num.n; n=F.den.n; flag=0; if m>=n, [div,rem]=F.num./F.den; flag=1; m=rem.n; else, rem=F.num; end
            k=ones(1,n); p=F.p; if nargin<2, tol=1e-3; end
            for i=1:n-1, if RR_eq(p(i+1),p(i),tol), k(i+1)=k(i)+1; end, end, k(n+1)=0;
            for i=n:-1:1
                if k(1,i)>=k(i+1), r=k(i); a=RR_poly(1);
                    for j=1:i-k(i),    a=a*[1 -p(j)]; end
                    for j=i+1:n,       a=a*[1 -p(j)]; end
                    for j=1:k(i)-1,    ad{j}=diff(a,j); end
                end
                q=r-k(i); d(i)=evaluate(diff(rem,q),p(i))/RR_Factorial(q);
                for j=q:-1:1, d(i)=d(i)-d(i+j)*evaluate(ad{j},p(i))/RR_Factorial(j); end
                d(i)=d(i)/evaluate(a,p(i));
            end, if ~flag, k=k(1:n); else
                 p(n+1:n+1+div.n)=0; d(n+1:n+div.n+1)=div.poly(end:-1:1); k(n+1:n+1+div.n)=-[0:div.n]; n=n+div.n+1;
            end
            % Remove all terms in the expansion with zero coefficients
            while 1, mask=RR_eq(d,0); i=find(mask,1); if isempty(i), break, else
                p=p([1:i-1,i+1:end]); d=d([1:i-1,i+1:end]);  k=k([1:i-1,i+1:end]); n=n-1;
            end, end
        end
        function bode(L,g)
            % function bode(L,g)
            % The continuous-time Bode plot of G(s)=num(s)/den(s) if nargin=3, with s=(i omega), or
            % the discrete-time   Bode plot of G(z)=num(z)/den(z) if nargin=4, with z=e^(i omega h).
            % Note: the (optional) derived type g is used to pass in various (optional) plotting parameters:
            %   {g.log_omega_min,g.log_omega_max,G.omega_N} define the set of frequencies used (logarithmically spaced)
            %   g.linestyle is the linestyle used
            %   g.lines is a logical flag turning on/off horizontal_lines at gain=1 and phase=-180 deg
            %   g.phase_shift is the integer multiple of 360 deg added to the phase in the phase plot.
            % Some convenient defaults are defined for each of these fields, but any may be overwritten. You're welcome.
            % Renaissance Robotics codebase, Appendix A (see Chapter 9), https://github.com/tbewley/RR
            % Copyright 2021 by Thomas Bewley, distributed under BSD 3-Clause License.


            if nargin==1, g=[]; end, p=[abs([L.z L.p])];  % Set up some convenient defaults for the plotting parameters
            if     ~isfield(g,'log_omega_min'), g.log_omega_min=floor(log10(min(p(p>0))/5)); end
            % (In DT, always plot the Bode plot up to the Nyquist frequency, to see what's going on!)
            if     ~isempty(L.h              ), Nyquist=pi/h; g.log_omega_max=log10(0.999*Nyquist);
            elseif ~isfield(g,'log_omega_max'), g.log_omega_max= ceil(log10(max(p     )*5)); end
            if     ~isfield(g,'omega_N'      ), g.omega_N      =500;                         end
            if     ~isfield(g,'linestyle'    ), g.linestyle    ='b-';                        end
            if     ~isfield(g,'lines'        ), g.lines        =false;                       end
            if     ~isfield(g,'phase_shift'  ), g.phase_shift  =0;                           end

            omega=logspace(g.log_omega_min,g.log_omega_max,g.omega_N);
            if     ~isempty(L.h), arg=exp(i*omega*h); else arg=i*omega; end

            mag=abs(evaluate(L,arg)); phase=RR_Phase(evaluate(L,arg))*180/pi+g.phase_shift*360;

            for k=1:g.omega_N-1; if (mag(k)  -1  )*(mag(k+1)  -1  )<=0;
                omega_c=(omega(k)+omega(k+1))/2, phase_margin=180+(phase(k)+phase(k+1))/2
            break, end, end
            for k=1:g.omega_N-1; if (phase(k)+180)*(phase(k+1)+180)<=0;
                omega_g=(omega(k)+omega(k+1))/2, gain_margin=1/(mag(k)+mag(k+1))/2
            break, end, end

            subplot(2,1,1),        loglog(omega,mag,g.linestyle), hold on, a=axis;
            if g.lines,              plot([a(1) a(2)],[1 1],'k:')
                if exist('omega_c'), plot([omega_c omega_c],[a(3) a(4)],'k:'), end
                if exist('omega_g'), plot([omega_g omega_g],[a(3) a(4)],'k:'), end, end
            if ~isempty(L.h),        plot([Nyquist Nyquist],[a(3) a(4)],'k-'), end, axis(a)

            subplot(2,1,2),      semilogx(omega,phase,g.linestyle), hold on, a=axis;
            if g.lines,              plot([a(1) a(2)],[-180 -180],'k:')
                if exist('omega_c'), plot([omega_c omega_c],[a(3) a(4)],'k:'), end
                if exist('omega_g'), plot([omega_g omega_g],[a(3) a(4)],'k:'), end, end
            if ~isempty(L.h),        plot([Nyquist Nyquist],[a(3) a(4)],'k:'), end, axis(a)

        end
        function rlocus(G,D)
        end 
    end
    methods(Access = protected)
        function displayScalarObject(obj)
            fprintf(getHeader(obj))
            fprintf('num:'), disp(obj.num.poly)
            fprintf('den:'), disp(obj.den.poly)
            if isempty(obj.h), fprintf('Continuous-time transfer function\n'), else
                fprintf('Discrete-time transfer function with h='), disp(obj.h), end
            nr=obj.den.n-obj.num.n;
            if nr>0, s='strictly proper'; elseif nr==0, s='semiproper'; else, s='improper'; end
            fprintf('  m=%d, n=%d, n_r=n-m=%d, %s, K=', obj.num.n, obj.den.n, nr, s), disp(obj.K)
            fprintf('  z:'), disp(obj.z)
            fprintf('  p:'), disp(obj.p)
            if obj.den.n==0, fprintf('\n'), end
        end
    end
end


% .ooo.
% .o...
% ....x
% oo..x
% oxx.x
% oxx.x

% .ooo.
% ...o.
% x....
% x..oo
% x.xxo
% x.xxo