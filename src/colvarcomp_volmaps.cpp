// -*- c++ -*-

// This file is part of the Collective Variables module (Colvars).
// The original version of Colvars and its updates are located at:
// https://github.com/Colvars/colvars
// Please update all Colvars source files before making any changes.
// If you wish to distribute your changes, please submit them to the
// Colvars repository at GitHub.

#include "colvarmodule.h"
#include "colvarvalue.h"
#include "colvar.h"
#include "colvarcomp.h"



colvar::map_total::map_total()
{
  set_function_type("mapTotal");
  x.type(colvarvalue::type_scalar);
}


int colvar::map_total::init(std::string const &conf)
{
  int error_code = cvc::init(conf);
  colvarproxy *proxy = cvm::main()->proxy;

  // Identifiers for maps loaded by the MD engine
  get_keyval(conf, "mapName", volmap_name, volmap_name);
  get_keyval(conf, "mapID", volmap_id, volmap_id);
  register_param("mapID", reinterpret_cast<void *>(&volmap_id)); // Used in script API for VMD

  // Load a new map from Colvars
  std::string volmap_filename;
  get_keyval(conf, "mapFile", volmap_filename, volmap_filename);

  cvm::main()->cite_feature("Volumetric map-based collective variables");

  if ( ((volmap_name.size() > 0) && (volmap_id >= 0)) ||
       ((volmap_filename.size() > 0) && (volmap_id >= 0)) ||
       ((volmap_name.size() > 0) && (volmap_filename.size() > 0)) ) {
    error_code |=
        cvm::error("Error: mapName, mapID and mapFile are all mutually exclusive.\n", COLVARS_INPUT_ERROR);
  }

  // Parse optional group
  atoms = parse_group(conf, "atoms", true);
  if (atoms) {

    // Using internal atom selection
    if (volmap_name.size() > 0) {
      volmap_index = proxy->init_internal_volmap_by_name(volmap_name);
    }
    if (volmap_id >= 0) {
      volmap_index = proxy->init_internal_volmap_by_id(volmap_id);
    }
    if (volmap_filename.size() > 0) {
      volmap_index = proxy->load_internal_volmap_from_file(volmap_filename);
    }

  } else {

    // Using selection from the MD engine
    if (volmap_name.size() > 0) {
      volmap_index = proxy->request_engine_volmap_by_name(volmap_name);
    }
    if (volmap_id >= 0) {
      volmap_index = proxy->request_engine_volmap_by_id(volmap_id);
    }

    if (volmap_filename.size() > 0) {
      error_code |=
          cvm::error("Error: mapFile requires that an atom group is selected internally.\n",
                     COLVARS_INPUT_ERROR);
    }
  }

  error_code |= (volmap_index >= 0) ? COLVARS_OK : COLVARS_INPUT_ERROR;

  if (get_keyval(conf, "atomWeights", atom_weights, atom_weights)) {
    if (!atoms) {
      error_code |= cvm::error("Error: weights can only be assigned when atoms "
                               "are selected explicitly in Colvars.\n",
                               COLVARS_INPUT_ERROR);
    } else {
      if (atoms->size() != atom_weights.size()) {
        error_code |= cvm::error("Error: if defined, the number of weights ("+
                                 cvm::to_str(atom_weights.size())+
                                 ") must equal the number of atoms ("+
                                 cvm::to_str(atoms->size())+
                                 ").\n", COLVARS_INPUT_ERROR);
      }
    }
  }

  // if (cvm::debug()) {
  cvm::log("Map has index "+cvm::to_str(volmap_index)+" in the proxy arrays and ID + " + cvm::to_str(proxy->get_volmap_id(volmap_index)) + " for NAMD.\n");
  // }

  return error_code;
}


void colvar::map_total::calc_value()
{
  colvarproxy *proxy = cvm::main()->proxy;
  int flags = is_enabled(f_cvc_gradient) ? colvarproxy::volmap_flag_gradients :
    colvarproxy::volmap_flag_null;

  if (atoms != NULL) {
    // Compute the map inside Colvars
    x.real_value = 0.0;

    cvm::real *w = NULL;
    if (atom_weights.size() > 0) {
      flags |= colvarproxy::volmap_flag_use_atom_field;
      w = &(atom_weights[0]);
    }
    proxy->compute_volmap(flags, volmap_index, atoms->begin(), atoms->end(), &(x.real_value), w);
  } else {
    // Get the externally computed value
    x.real_value = proxy->get_engine_volmap_value(volmap_index);
  }
}


void colvar::map_total::calc_gradients()
{
  // Computed in calc_value() or by the MD engine
}


void colvar::map_total::apply_force(colvarvalue const &force)
{
  if (atoms) {
    cvc::apply_force(force);
  } else {
    cvm::main()->proxy->apply_engine_volmap_force(volmap_index, force.real_value);
  }
}
