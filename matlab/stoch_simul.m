function info=stoch_simul(var_list)

% Copyright (C) 2001-2009 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

   global M_ options_ oo_ it_

  options_old = options_;
  if options_.linear
      options_.order = 1;
  end
  if options_.order == 1
      options_.replic = 1;
  elseif options_.order == 3
      options_.simul = 1;
      options_.k_order_solver = 1;
  end
  

  TeX = options_.TeX;

  iter_ = max(options_.periods,1);
  if M_.exo_nbr > 0
    oo_.exo_simul= ones(iter_ + M_.maximum_lag + M_.maximum_lead,1) * oo_.exo_steady_state';
  end

  check_model;

  [oo_.dr, info] = resol(oo_.steady_state,0);

  if info(1)
    options_ = options_old;
    print_info(info, options_.noprint);
    return
  end  

  if ~options_.noprint
    disp(' ')
    disp('MODEL SUMMARY')
    disp(' ')
    disp(['  Number of variables:         ' int2str(M_.endo_nbr)])
    disp(['  Number of stochastic shocks: ' int2str(M_.exo_nbr)])
    disp(['  Number of state variables:   ' ...
	  int2str(length(find(oo_.dr.kstate(:,2) <= M_.maximum_lag+1)))])
    disp(['  Number of jumpers:           ' ...
	  int2str(length(find(oo_.dr.kstate(:,2) == M_.maximum_lag+2)))])
    disp(['  Number of static variables:  ' int2str(oo_.dr.nstatic)])
    my_title='MATRIX OF COVARIANCE OF EXOGENOUS SHOCKS';
    labels = deblank(M_.exo_names);
    headers = strvcat('Variables',labels);
    lh = size(labels,2)+2;
    dyntable(my_title,headers,labels,M_.Sigma_e,lh,10,6);
    disp(' ')
    if options_.order <= 2
        disp_dr(oo_.dr,options_.order,var_list);
    end
  end

  if options_.simul == 0 & options_.nomoments == 0
    disp_th_moments(oo_.dr,var_list); 
  elseif options_.simul == 1
    if options_.periods == 0
      error('STOCH_SIMUL error: number of periods for the simulation isn''t specified')
    end
    if options_.periods < options_.drop
      disp(['STOCH_SIMUL error: The horizon of simulation is shorter' ...
	    ' than the number of observations to be DROPed'])
      options_ =options_old;
      return
    end
    oo_.endo_simul = simult(repmat(oo_.dr.ys,1,M_.maximum_lag),oo_.dr);
    dyn2vec;
    if options_.nomoments == 0
      disp_moments(oo_.endo_simul,var_list);
    end
  end



  if options_.irf 
    if size(var_list,1) == 0
      var_list = M_.endo_names(1:M_.orig_endo_nbr, :);
      if TeX
	var_listTeX = M_.endo_names_tex(1:M_.orig_endo_nbr, :);
      end
    end

    n = size(var_list,1);
      ivar=zeros(n,1);
      if TeX
	var_listTeX = [];
      end
      for i=1:n
	i_tmp = strmatch(var_list(i,:),M_.endo_names,'exact');
	if isempty(i_tmp)
	  error (['One of the specified variables does not exist']) ;
	else
	  ivar(i) = i_tmp;
	  if TeX
	    var_listTeX = strvcat(var_listTeX,deblank(M_.endo_names_tex(i_tmp,:)));
	  end
	end
      end

    if TeX
      fidTeX = fopen([M_.fname '_IRF.TeX'],'w');
      fprintf(fidTeX,'%% TeX eps-loader file generated by stoch_simul.m (Dynare).\n');
      fprintf(fidTeX,['%% ' datestr(now,0) '\n']);
      fprintf(fidTeX,' \n');
    end
    olditer = iter_;% Est-ce vraiment utile ? Il y a la m�me ligne dans irf... 
    SS(M_.exo_names_orig_ord,M_.exo_names_orig_ord)=M_.Sigma_e+1e-14*eye(M_.exo_nbr);
    cs = transpose(chol(SS));
    tit(M_.exo_names_orig_ord,:) = M_.exo_names;
    if TeX
      titTeX(M_.exo_names_orig_ord,:) = M_.exo_names_tex;
    end
    for i=1:M_.exo_nbr
      if SS(i,i) > 1e-13
	y=irf(oo_.dr,cs(M_.exo_names_orig_ord,i), options_.irf, options_.drop, ...
	      options_.replic, options_.order);
	if options_.relative_irf
	  y = 100*y/cs(i,i); 
	end
	irfs   = [];
	mylist = [];
	if TeX
	  mylistTeX = [];
	end
	for j = 1:n
	  assignin('base',[deblank(M_.endo_names(ivar(j),:)) '_' deblank(M_.exo_names(i,:))],...
		   y(ivar(j),:)');
	  eval(['oo_.irfs.' deblank(M_.endo_names(ivar(j),:)) '_' ...
			     deblank(M_.exo_names(i,:)) ' = y(ivar(j),:);']); 
	  if max(y(ivar(j),:)) - min(y(ivar(j),:)) > 1e-10
	    irfs  = cat(1,irfs,y(ivar(j),:));
	    mylist = strvcat(mylist,deblank(var_list(j,:)));
	    if TeX
	      mylistTeX = strvcat(mylistTeX,deblank(var_listTeX(j,:)));
	    end
	  end
	end
	if options_.nograph == 0
	  number_of_plots_to_draw = size(irfs,1);
	  [nbplt,nr,nc,lr,lc,nstar] = pltorg(number_of_plots_to_draw);
	  if nbplt == 0
	  elseif nbplt == 1
	    if options_.relative_irf
	      hh = figure('Name',['Relative response to' ...
				  ' orthogonalized shock to ' tit(i,:)]);
	    else
	      hh = figure('Name',['Orthogonalized shock to' ...
				  ' ' tit(i,:)]);
	    end
	    for j = 1:number_of_plots_to_draw
	      subplot(nr,nc,j);
	      plot(1:options_.irf,transpose(irfs(j,:)),'-k','linewidth',1);
	      hold on
	      plot([1 options_.irf],[0 0],'-r','linewidth',0.5);
	      hold off
	      xlim([1 options_.irf]);
	      title(deblank(mylist(j,:)),'Interpreter','none');
	    end
	    eval(['print -depsc2 ' M_.fname '_IRF_' deblank(tit(i,:)) '.eps']);
      if ~exist('OCTAVE_VERSION')
        eval(['print -dpdf ' M_.fname  '_IRF_' deblank(tit(i,:))]);
        saveas(hh,[M_.fname  '_IRF_' deblank(tit(i,:)) '.fig']);
      end
	    if TeX
	      fprintf(fidTeX,'\\begin{figure}[H]\n');
	      for j = 1:number_of_plots_to_draw
		fprintf(fidTeX,['\\psfrag{%s}[1][][0.5][0]{$%s$}\n'],deblank(mylist(j,:)),deblank(mylistTeX(j,:)));
	      end
	      fprintf(fidTeX,'\\centering \n');
	      fprintf(fidTeX,'\\includegraphics[scale=0.5]{%s_IRF_%s}\n',M_.fname,deblank(tit(i,:)));
	      fprintf(fidTeX,'\\caption{Impulse response functions (orthogonalized shock to $%s$).}',titTeX(i,:));
	      fprintf(fidTeX,'\\label{Fig:IRF:%s}\n',deblank(tit(i,:)));
	      fprintf(fidTeX,'\\end{figure}\n');
	      fprintf(fidTeX,' \n');
	    end
	    %	close(hh)
	  else
	    for fig = 1:nbplt-1
	      if options_.relative_irf == 1
		hh = figure('Name',['Relative response to orthogonalized shock' ...
				    ' to ' tit(i,:) ' figure ' int2str(fig)]);
	      else
		hh = figure('Name',['Orthogonalized shock to ' tit(i,:) ...
				    ' figure ' int2str(fig)]);
	      end
	      for plt = 1:nstar
		subplot(nr,nc,plt);
		plot(1:options_.irf,transpose(irfs((fig-1)*nstar+plt,:)),'-k','linewidth',1);
		hold on
		plot([1 options_.irf],[0 0],'-r','linewidth',0.5);
		hold off
		xlim([1 options_.irf]);
		title(deblank(mylist((fig-1)*nstar+plt,:)),'Interpreter','none');
	      end
	      eval(['print -depsc2 ' M_.fname '_IRF_' deblank(tit(i,:)) int2str(fig) '.eps']);
        if ~exist('OCTAVE_VERSION')
          eval(['print -dpdf ' M_.fname  '_IRF_' deblank(tit(i,:)) int2str(fig)]);
          saveas(hh,[M_.fname  '_IRF_' deblank(tit(i,:)) int2str(fig) '.fig']);
        end
	      if TeX
		fprintf(fidTeX,'\\begin{figure}[H]\n');
		for j = 1:nstar
		  fprintf(fidTeX,['\\psfrag{%s}[1][][0.5][0]{$%s$}\n'],deblank(mylist((fig-1)*nstar+j,:)),deblank(mylistTeX((fig-1)*nstar+j,:)));
		end
		fprintf(fidTeX,'\\centering \n');
		fprintf(fidTeX,'\\includegraphics[scale=0.5]{%s_IRF_%s%s}\n',M_.fname,deblank(tit(i,:)),int2str(fig));
		if options_.relative_irf
		  fprintf(fidTeX,['\\caption{Relative impulse response' ...
				  ' functions (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
		else
		  fprintf(fidTeX,['\\caption{Impulse response functions' ...
				  ' (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
		end
		fprintf(fidTeX,'\\label{Fig:BayesianIRF:%s:%s}\n',deblank(tit(i,:)),int2str(fig));
		fprintf(fidTeX,'\\end{figure}\n');
		fprintf(fidTeX,' \n');
	      end
	      %					close(hh);
	    end
	    hh = figure('Name',['Orthogonalized shock to ' tit(i,:) ' figure ' int2str(nbplt) '.']);
	    m = 0; 
	    for plt = 1:number_of_plots_to_draw-(nbplt-1)*nstar;
	      m = m+1;
	      subplot(lr,lc,m);
	      plot(1:options_.irf,transpose(irfs((nbplt-1)*nstar+plt,:)),'-k','linewidth',1);
	      hold on
	      plot([1 options_.irf],[0 0],'-r','linewidth',0.5);
	      hold off
	      xlim([1 options_.irf]);
	      title(deblank(mylist((nbplt-1)*nstar+plt,:)),'Interpreter','none');
	    end
	    eval(['print -depsc2 ' M_.fname '_IRF_' deblank(tit(i,:)) int2str(nbplt) '.eps']);
      if ~exist('OCTAVE_VERSION')
        eval(['print -dpdf ' M_.fname  '_IRF_' deblank(tit(i,:)) int2str(nbplt)]);
        saveas(hh,[M_.fname  '_IRF_' deblank(tit(i,:)) int2str(nbplt) '.fig']);
      end
	    if TeX
	      fprintf(fidTeX,'\\begin{figure}[H]\n');
	      for j = 1:m
		fprintf(fidTeX,['\\psfrag{%s}[1][][0.5][0]{$%s$}\n'],deblank(mylist((nbplt-1)*nstar+j,:)),deblank(mylistTeX((nbplt-1)*nstar+j,:)));
	      end
	      fprintf(fidTeX,'\\centering \n');
	      fprintf(fidTeX,'\\includegraphics[scale=0.5]{%s_IRF_%s%s}\n',M_.fname,deblank(tit(i,:)),int2str(nbplt));
	      if options_.relative_irf
		fprintf(fidTeX,['\\caption{Relative impulse response functions' ...
				' (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
	      else
		fprintf(fidTeX,['\\caption{Impulse response functions' ...
				' (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
	      end
	      fprintf(fidTeX,'\\label{Fig:IRF:%s:%s}\n',deblank(tit(i,:)),int2str(nbplt));
	      fprintf(fidTeX,'\\end{figure}\n');
	      fprintf(fidTeX,' \n');
	    end
	    %				close(hh);
	  end
	end
      end
      iter_ = olditer;
      if TeX
	fprintf(fidTeX,' \n');
	fprintf(fidTeX,'%% End Of TeX file. \n');
	fclose(fidTeX);
      end
    end
  end

  if options_.SpectralDensity == 1
      [omega,f] = UnivariateSpectralDensity(oo_.dr,var_list);
  end


options_ = options_old;
