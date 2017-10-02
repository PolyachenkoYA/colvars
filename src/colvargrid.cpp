// -*- c++ -*-

#include "colvarmodule.h"
#include "colvarvalue.h"
#include "colvarparse.h"
#include "colvar.h"
#include "colvarcomp.h"
#include "colvargrid.h"


colvar_grid_count::colvar_grid_count()
  : colvar_grid<size_t>()
{
  mult = 1;
}

colvar_grid_count::colvar_grid_count(std::vector<int> const &nx_i,
                                     size_t const           &def_count)
  : colvar_grid<size_t>(nx_i, def_count, 1)
{}

colvar_grid_count::colvar_grid_count(std::vector<colvar *>  &colvars,
                                     size_t const           &def_count)
  : colvar_grid<size_t>(colvars, def_count, 1)
{}

colvar_grid_scalar::colvar_grid_scalar()
  : colvar_grid<cvm::real>(), samples(NULL), grad(NULL)
{}

colvar_grid_scalar::colvar_grid_scalar(colvar_grid_scalar const &g)
  : colvar_grid<cvm::real>(g), samples(NULL), grad(NULL)
{
  grad = new cvm::real[nd];
}

colvar_grid_scalar::colvar_grid_scalar(std::vector<int> const &nx_i)
  : colvar_grid<cvm::real>(nx_i, 0.0, 1), samples(NULL), grad(NULL)
{
  grad = new cvm::real[nd];
}

colvar_grid_scalar::colvar_grid_scalar(std::vector<colvar *> &colvars, bool margin)
  : colvar_grid<cvm::real>(colvars, 0.0, 1, margin), samples(NULL), grad(NULL)
{
  grad = new cvm::real[nd];
}

colvar_grid_scalar::~colvar_grid_scalar()
{
  if (grad) {
    delete [] grad;
    grad = NULL;
  }
}

cvm::real colvar_grid_scalar::maximum_value() const
{
  cvm::real max = data[0];
  for (size_t i = 0; i < nt; i++) {
    if (data[i] > max) max = data[i];
  }
  return max;
}


cvm::real colvar_grid_scalar::minimum_value() const
{
  cvm::real min = data[0];
  for (size_t i = 0; i < nt; i++) {
    if (data[i] < min) min = data[i];
  }
  return min;
}

cvm::real colvar_grid_scalar::minimum_pos_value() const
{
  cvm::real minpos = data[0];
  size_t i;
  for (i = 0; i < nt; i++) {
    if(data[i] > 0) {
      minpos = data[i];
      break;
    }
  }
  for (i = 0; i < nt; i++) {
    if (data[i] > 0 && data[i] < minpos) minpos = data[i];
  }
  return minpos;
}

cvm::real colvar_grid_scalar::minimum_pos_value(int const &ndata, std::vector<int> const &which) const
{
  size_t i;
  size_t j;
  cvm::real minpos = data[which[0]];
  for (j = 0; j < ndata; j++) {
    i=which[j];
    if(data[i] > 0) {
      minpos = data[i];
      break;
    }
  }
  for (j = 0; j < ndata; j++) {
    i=which[j];
    if (data[i] > 0 && data[i] < minpos) minpos = data[i];
  }
  return minpos;
}

cvm::real colvar_grid_scalar::integral() const
{
  cvm::real sum = 0.0;
  for (size_t i = 0; i < nt; i++) {
    sum += data[i];
  }
  cvm::real bin_volume = 1.0;
  for (size_t id = 0; id < widths.size(); id++) {
    bin_volume *= widths[id];
  }
  return bin_volume * sum;
}

cvm::real colvar_grid_scalar::integral(int const &ndata, std::vector<int> const &which) const
{
  cvm::real sum = 0.0;
  for (size_t j = 0; j < ndata; j++) {
    size_t i=which[j];
    sum += data[i];
  }
  cvm::real bin_volume = 1.0;
  for (size_t id = 0; id < widths.size(); id++) {
    bin_volume *= widths[id];
  }
  return bin_volume * sum;
}

cvm::real colvar_grid_scalar::entropy() const
{
  cvm::real sum = 0.0;
  for (size_t i = 0; i < nt; i++) {
    if (data[i] >0) {
      sum += -1.0 * data[i] * std::log(data[i]);
    } 
  }
  cvm::real bin_volume = 1.0;
  for (size_t id = 0; id < widths.size(); id++) {
    bin_volume *= widths[id];
  }
  return bin_volume * sum;
}

cvm::real colvar_grid_scalar::entropy(int const &ndata, std::vector<int> const &which) const
{
  cvm::real sum = 0.0;
  for (size_t j = 0; j < ndata; j++) {
    size_t i=which[j];
    if (data[i] >0) {
      sum += -1.0 * data[i] * std::log(data[i]);
    }
  }
  cvm::real bin_volume = 1.0;
  for (size_t id = 0; id < widths.size(); id++) {
    bin_volume *= widths[id];
  }
  return bin_volume * sum;
}

void colvar_grid_scalar::simplexproj()
{
  // remove zeros and assign probability vectors
  int countbins=0;
  for (size_t i = 0; i < nt; i++) {
    if (data[i]!=0.0) {
      countbins++;
    }
  }
  std::vector<cvm::real> prob(countbins);
  std::vector<cvm::real> probold(countbins);

  countbins=0;
  for (size_t i = 0; i < nt; i++) {
    if (data[i]!=0.0) {
      prob[countbins]=data[i];
      probold[countbins]=data[i];
      countbins++;
    }
  }

  // Now use algorithm from Wang, Perpinan 2003

  std::sort(prob.begin(), prob.end());
  std::reverse(prob.begin(), prob.end());

  cvm::real sump=0.0;
  int rho=0;
  cvm::real rhovec=0.0;
  cvm::real lambdav=0.0;
  for (size_t i = 0; i < countbins; i++) {
    sump=sump+prob[i];
    rhovec=prob[i]+(1.0/(i+1))*(1.0-sump);
    if (rhovec>0) {
      rho=i+1;
    }
  }
  sump=0.0;
  for (size_t i = 0; i < rho; i++) {
    sump=sump+prob[i];
  }
  lambdav=(1.0/rho)*(1.0-sump);
  for (size_t i = 0; i < countbins; i++) {
    prob[i]=probold[i]+lambdav;
    if (prob[i]<0) {
      prob[i]=0.0;
    }
  }

  countbins=0;
  for (size_t i = 0; i < nt; i++) {
    if (data[i]!=0.0) {
      data[i]=prob[countbins];
      countbins++;
    }
  }

}

void colvar_grid_scalar::simplexproj(int const &ndata, std::vector<int> const &which)
{
  size_t i;
  int countbins=0;
  for (size_t j = 0; j < ndata; j++) {
    i=which[j];
    if (data[i]!=0.0) {
      countbins++;
    }
  }
  std::vector<cvm::real> prob(countbins);
  std::vector<cvm::real> probold(countbins);

  countbins=0;
  for (size_t j = 0; j < ndata; j++) {
    i=which[j];
    if (data[i]!=0.0) {
      prob[countbins]=data[i];
      probold[countbins]=data[i];
      countbins++;
    }
  }


  std::sort(prob.begin(), prob.end());
  std::reverse(prob.begin(), prob.end());

  cvm::real sump=0.0;
  int rho=0;
  cvm::real rhovec=0.0;
  cvm::real lambdav=0.0;
  for (i = 0; i < countbins; i++) {
    sump=sump+prob[i];
    rhovec=prob[i]+(1.0/(i+1))*(1.0-sump);
    if (rhovec>0) {
      rho=i+1;
    }
  }
  sump=0.0;
  for (i = 0; i < rho; i++) {
    sump=sump+prob[i];
  }
  lambdav=(1.0/rho)*(1.0-sump);
  for (i = 0; i < countbins; i++) {
    prob[i]=probold[i]+lambdav;
    if (prob[i]<0) {
      prob[i]=0.0;
    }
  }

  countbins=0;
  for (size_t j = 0; j < ndata; j++) {
    i=which[j];
    if (data[i]!=0.0) {
      data[i]=prob[countbins];
      countbins++;
    }
  }

}

colvar_grid_gradient::colvar_grid_gradient()
  : colvar_grid<cvm::real>(), samples(NULL)
{}

colvar_grid_gradient::colvar_grid_gradient(std::vector<int> const &nx_i)
  : colvar_grid<cvm::real>(nx_i, 0.0, nx_i.size()), samples(NULL)
{}

colvar_grid_gradient::colvar_grid_gradient(std::vector<colvar *> &colvars)
  : colvar_grid<cvm::real>(colvars, 0.0, colvars.size()), samples(NULL)
{}

void colvar_grid_gradient::write_1D_integral(std::ostream &os)
{
  cvm::real bin, min, integral;
  std::vector<cvm::real> int_vals;

  os << "#       xi            A(xi)\n";

  if ( cv.size() != 1 ) {
    cvm::error("Cannot write integral for multi-dimensional gradient grids.");
    return;
  }

  integral = 0.0;
  int_vals.push_back( 0.0 );
  min = 0.0;

  // correction for periodic colvars, so that the PMF is periodic
  cvm::real corr;
  if ( periodic[0] ) {
    corr = average();
  } else {
    corr = 0.0;
  }

  for (std::vector<int> ix = new_index(); index_ok(ix); incr(ix)) {

    if (samples) {
      size_t const samples_here = samples->value(ix);
      if (samples_here)
        integral += (value(ix) / cvm::real(samples_here) - corr) * cv[0]->width;
    } else {
      integral += (value(ix) - corr) * cv[0]->width;
    }

    if ( integral < min ) min = integral;
    int_vals.push_back( integral );
  }

  bin = 0.0;
  for ( int i = 0; i < nx[0]; i++, bin += 1.0 ) {
    os << std::setw(10) << cv[0]->lower_boundary.real_value + cv[0]->width * bin << " "
       << std::setw(cvm::cv_width)
       << std::setprecision(cvm::cv_prec)
       << int_vals[i] - min << "\n";
  }

  os << std::setw(10) << cv[0]->lower_boundary.real_value + cv[0]->width * bin << " "
     << std::setw(cvm::cv_width)
     << std::setprecision(cvm::cv_prec)
     << int_vals[nx[0]] - min << "\n";

  return;
}



