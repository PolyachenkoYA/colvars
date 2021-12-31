#################################################################
# Editor window: CVs
#################################################################


# Edit new colvar config
proc ::cv_dashboard::add_cv {} {
  edit_cv true
}


# Colvar config editor window
proc ::cv_dashboard::edit_cv { {add false} {cvs ""} } {
  # If a non-default unit system is in use, recall it in the config string
  refresh_units
  if { $::cv_dashboard::units == "" } {
    set cfg ""
  } else {
    set cfg "units $::cv_dashboard::units\n\n"
  }

  if $add {
    # do not remove existing vars
    set cvs {}
    set ::cv_dashboard::backup_cfg ""
    if { [info exists ::cv_dashboard::template_base_dir] } {
      # Open "official" colvar template
      set in [open ${::cv_dashboard::template_base_dir}/colvar/basic_colvar.in r]
      set cfg [read $in]
      close $in
    } else {
      # Provide simple template
      set cfg "# You can edit or replace the example colvar config below.\n\
  colvar {\n  name d\n  distance {\n    group1 { atomNumbers 1 2 }\n    group2 { atomNumbers 3 4 }\n  }\n}\n"
    }
  } else {
    if {[llength $cvs] < 1} {
      # if not provided, try selection
      set cvs [selected_colvars]
    }
    if {[llength $cvs] == 0} {
      # If no selection, edit all variables
      set cvs $::cv_dashboard::cvs
    }
    foreach c $cvs {
      append cfg "colvar {[get_cv_config $c]}\n\n"
    }
    set ::cv_dashboard::backup_cfg $cfg
  }
  set w .cv_dashboard_window

  catch { destroy $w.editor }
  set editor [toplevel $w.editor]
  wm title $editor "Colvar config editor"

  # Left frame: utility buttons
  frame $w.editor.fl
  set gridrow 0

  labelframe  $w.editor.fl.docs -bd 2 -text "Online documentation" -padx 2 -pady 2
  set docs $w.editor.fl.docs
  ttk::button $docs.onlinedoc1 -text "Collective variables" -padding "4 2 4 2"\
    -command [list ::cv_dashboard::invokeBrowser "http://colvars.github.io/colvars-refman-vmd/colvars-refman-vmd.html#sec:colvar"]
  ttk::button $docs.onlinedoc3 -text "Basis functions (components)" -padding "4 2 4 2"\
    -command [list ::cv_dashboard::invokeBrowser "http://colvars.github.io/colvars-refman-vmd/colvars-refman-vmd.html#sec:cvc_list"]
  ttk::button $docs.onlinedoc2 -text "Atom groups" -padding "4 2 4 2"\
    -command [list ::cv_dashboard::invokeBrowser "http://colvars.github.io/colvars-refman-vmd/colvars-refman-vmd.html#sec:colvar_atom_groups"]

  grid $docs.onlinedoc1 -row $gridrow -column 0 -pady 5 -padx 2 -sticky nsew
  grid $docs.onlinedoc2 -row $gridrow -column 1 -pady 5 -padx 2 -sticky nsew
  grid $docs.onlinedoc3 -row $gridrow -column 2 -pady 5 -padx 2 -sticky nsew
  grid columnconfigure $docs 0 -weight 1
  grid columnconfigure $docs 1 -weight 1
  grid columnconfigure $docs 2 -weight 1

  ############# Templates #########################################
  labelframe  $w.editor.fl.templates -bd 2 -text "Templates" -padx 2 -pady 2
  set templates $w.editor.fl.templates

  # One line per subdirectory
  foreach d { colvar component other } {
    set ::cv_dashboard::templates_$d [dict create]

    foreach f [lsort -dictionary [glob -nocomplain "${::cv_dashboard::template_dir}/$d/*.in"]] {
      # Map pretty template name to file name
      dict set ::cv_dashboard::templates_$d [regsub -all {_} [file rootname [file tail $f]] " "] $f
    }
    tk::label $templates.template_label_$d -text "$d templates:"
    ttk::combobox $templates.pick_template_$d -justify left -state readonly -exportselection no
    $templates.pick_template_$d configure -values [dict keys [set ::cv_dashboard::templates_$d]]
    bind $templates.pick_template_$d <<keyb_enter>> \
      "::cv_dashboard::insert_template $templates.pick_template_$d [list [set ::cv_dashboard::templates_$d]]"
    ttk::button $templates.insert_template_$d -text "Insert \[Enter\]" \
      -command "::cv_dashboard::insert_template $templates.pick_template_$d [list [set ::cv_dashboard::templates_$d]]" \
      -padding "2 0 2 0"

    grid $templates.template_label_$d -row $gridrow -column 0 -pady 2 -padx 2
    grid $templates.pick_template_$d -row $gridrow -sticky ew -column 1 -pady 2 -padx 2
    grid $templates.insert_template_$d -row $gridrow -column 2 -pady 2 -padx 2
    incr gridrow
  }

  grid columnconfigure $templates 0 -weight 0
  grid columnconfigure $templates 1 -weight 1
  grid columnconfigure $templates 2 -weight 0

  ############# Various helpers ###################################
  labelframe  $w.editor.fl.helpers -bd 2 -text "Editing helpers" -padx 2 -pady 2
  set helpers $w.editor.fl.helpers

  ############# Atoms from seltext ################################
  tk::label $helpers.seltext_label -text "Atoms from selection text:"
  tk::entry $helpers.seltext -bg white
  # Bind Return key in seltext entry to proc creating the atomNumbers line
  bind $helpers.seltext <<keyb_enter>> "::cv_dashboard::atoms_from_sel textbox"
  ttk::button $helpers.fromsel -text "Insert \[Enter\]" \
    -command "::cv_dashboard::atoms_from_sel textbox" -padding "2 0 2 0"

  grid $helpers.seltext_label -row $gridrow -column 0 -pady 2 -padx 2
  grid $helpers.seltext -row $gridrow -column 1 -sticky ew -pady 2 -padx 2
  grid $helpers.fromsel -row $gridrow -column 2 -pady 2 -padx 2
  incr gridrow

  ############# Atoms from representation ################################
  tk::label $helpers.rep_label -text "Atoms from representation:"
  ttk::combobox $helpers.reps -justify left -state readonly -exportselection no
  ttk::button $helpers.refresh_reps -text "Refresh list" -command ::cv_dashboard::refresh_reps
  bind $helpers.reps <<ComboboxSelected>> "::cv_dashboard::atoms_from_sel reps"

  grid $helpers.rep_label -row $gridrow -column 0 -pady 2 -padx 2
  grid $helpers.reps -row $gridrow -column 1 -pady 2 -padx 2 -sticky ew
  grid $helpers.refresh_reps -row $gridrow -column 2 -pady 2 -padx 2
  incr gridrow

  # Populate initial list of selection texts from reps
  refresh_reps

  ############# Atoms from atom, bond, angle, dihedral labels ####################
  ttk::button $helpers.labeled_atoms -text "Insert labeled atoms" -command {::cv_dashboard::insert_labels Atoms}
  ttk::button $helpers.labeled_var -text "Insert labeled..." -command {::cv_dashboard::insert_labels combo}
  ttk::combobox $helpers.labels -justify left -state readonly -exportselection no
  $helpers.labels configure -values [list Bonds Angles Dihedrals]
  $helpers.labels set Bonds

  grid $helpers.labeled_atoms -row $gridrow -column 0 -pady 2 -padx 2
  grid $helpers.labeled_var -row $gridrow -column 1 -pady 2 -padx 2 -sticky ew
  grid $helpers.labels -row $gridrow -column 2 -pady 2 -padx 2
  incr gridrow

  ################# Insert file name from file picker ###########################
  ttk::radiobutton $helpers.files1 -variable ::cv_dashboard::filetype -text "atomsFile" -value "atomsFile"
  ttk::radiobutton $helpers.files2 -variable ::cv_dashboard::filetype -text "refPositionsFile" -value "refPositionsFile"
  ttk::button $helpers.insert_file -text "Pick file" \
    -command [list ::cv_dashboard::insert_filename] -padding "2 0 2 0"

  grid $helpers.files1 -row $gridrow -column 0 -pady 2 -padx 2
  grid $helpers.files2 -row $gridrow -column 1 -pady 2 -padx 2
  grid $helpers.insert_file -row $gridrow -column 2 -pady 2 -padx 2
  incr gridrow

  grid columnconfigure $helpers 0 -weight 0
  grid columnconfigure $helpers 1 -weight 1
  grid columnconfigure $helpers 2 -weight 0

  # Layout of all frames
  grid $docs -sticky ew
  grid $templates -sticky ew
  grid $helpers -sticky ew
  grid columnconfigure $w.editor.fl 0 -weight 1


  # Right frame: text widget w scrollbar and Apply/Cancel buttons
  frame $w.editor.fr
  tk::text $w.editor.fr.text -undo 1 -yscrollcommand [list $w.editor.fr.vsb set] -background white -font "Helvetica -14"
  ttk::scrollbar $w.editor.fr.vsb -orient vertical -command [list $w.editor.fr.text yview]
  $w.editor.fr.text insert 1.0 $cfg
  set ::cv_dashboard::being_edited $cvs
  grid $w.editor.fr.text -row 0 -columnspan 3 -sticky nsew
  grid $w.editor.fr.vsb -row 0 -column 3 -sticky nsew

  # Ctrl-s anywhere in the window saves/applies
  bind $w.editor <Control-s> {::cv_dashboard::edit_apply colvar}
  # Custom bindings for the text widget
  bind $w.editor.fr.text <Control-a> "$w.editor.fr.text tag add sel 1.0 end-1c; break"
  bind $w.editor.fr.text <Tab> "::cv_dashboard::tab_pressed $w.editor.fr.text"
  # Bind several possible mappings for Shift-Tab
  # ISO_Left_Tab is undefined on some platforms and will fail
  catch { bind $w.editor.fr.text <ISO_Left_Tab> "::cv_dashboard::tab_pressed $w.editor.fr.text true" }
  bind $w.editor.fr.text <Shift-Tab> "::cv_dashboard::tab_pressed $w.editor.fr.text true"

  set gridrow 1
  ttk::button $w.editor.fr.apply -text "Apply \[Ctrl-s\]" -command {::cv_dashboard::edit_apply colvar} -padding "2 0 2 0"
  ttk::button $w.editor.fr.cancel -text "Cancel" -command {::cv_dashboard::edit_cancel colvar} -padding "2 0 2 0"
  ttk::button $w.editor.fr.clear -text "Clear" -command "$w.editor.fr.text delete 1.0 end" -padding "2 0 2 0"

  grid $w.editor.fr.apply -row $gridrow -column 0 -sticky e -pady 2 -padx 2
  grid $w.editor.fr.cancel -row $gridrow -column 1 -sticky w -pady 2 -padx 2
  grid $w.editor.fr.clear -row $gridrow -column 2 -sticky w -pady 2 -padx 2

  grid columnconfigure $w.editor.fr 0 -weight 1
  grid columnconfigure $w.editor.fr 1 -weight 1
  grid columnconfigure $w.editor.fr 2 -weight 1
  grid rowconfigure $w.editor.fr 0 -weight 1

  pack $w.editor.fl -fill both -side left
  pack $w.editor.fr -fill both -expand yes -padx 2 -pady 2
}


#################################################################
# Helper functions for editor
#################################################################


# Process tab presses to indent/unindent text
# t is the text widget
# shift is true if Shift key is pressed

proc ::cv_dashboard::tab_pressed { t {shift false} } {
  set s [$t tag ranges sel]
  set indent $::cv_dashboard::indent

  if { $s == "" } {
    # No selection
    if { $shift == false } {
      # Just insert spaces at cursor
      $t insert insert $indent
      return -code break
    } else {
      # Shift-tab without selection will unindent current line
      # Select line of cursor
      set s [list "insert linestart" "insert lineend"]
    }
  } else {
    # Extend selection to whole lines to (un)indent
    set s [list "sel.first linestart" "sel.last lineend"]
  }

  set current_sel [$t get {*}$s]
  if { $shift } {
    regsub -all -lineanchor "^${indent}" $current_sel {} new_sel
  } else {
    regsub -all -lineanchor "^" $current_sel $indent new_sel
  }
  $t replace {*}$s $new_sel sel
  return -code break
}


# Multi-platform solution from http://wiki.tcl.tk/557
proc ::cv_dashboard::invokeBrowser {url} {
  # open is the OS X equivalent to xdg-open on Linux, start is used on Windows
  set commands {xdg-open open start}
  foreach browser $commands {
    if {$browser eq "start"} {
      set command [list {*}[auto_execok start] {}]
    } else {
      set command [auto_execok $browser]
    }
    if {[string length $command]} {
      break
    }
  }

  if {[string length $command] == 0} {
    return -code error "couldn't find browser"
  }
  if {[catch {exec {*}$command $url &} error]} {
    return -code error "couldn't execute '$command': $error"
  }
}


# Insert atomNumbers command for given selection text
proc ::cv_dashboard::atoms_from_sel { source } {
  set w .cv_dashboard_window
  set indent ${::cv_dashboard::indent}
  set indent3 "${indent}${indent}${indent}"

  # Called from textbox
  switch $source {
    textbox { set seltext [$w.editor.fl.helpers.seltext get] }
    reps    { set seltext [$w.editor.fl.helpers.reps get] }
  }

  if {[llength $seltext] == 0 } {
    return
  }
  set sel [atomselect $::cv_dashboard::mol $seltext]
  set serials [$sel get serial]
  $sel delete

  if {[llength $serials] == 0 } {
    tk_messageBox -icon error -title "Colvars error" -parent .cv_dashboard_window\
      -message "Selection text \"${seltext}\" matches zero atoms."
    return
  }
  # set auto to "" if not requested
  set auto " auto-updating"
  # Insert magic comment line followed by atomNumbers line
  editor_replace $w.editor.fr.text \
"${indent3}# \"auto-updating\" keyword updates atom IDs when applying cfg or changing molecule
${indent3}#$auto selection: \"$seltext\"
${indent3}atomNumbers $serials\n"
}


# Replace selection in editor with given string
proc ::cv_dashboard::editor_replace { t text } {
  if {[$t tag ranges sel] != ""} {
    $t delete sel.first sel.last
  }
  $t insert insert $text
}


# Insert atom numbers or components from currently labeled objects in VMD
proc ::cv_dashboard::insert_labels {obj} {
  set w .cv_dashboard_window
  set indent ${::cv_dashboard::indent}
  set indent2 "${indent}${indent}"

  if {$obj == "combo"} {
    set obj [$w.editor.fl.helpers.labels get]
  }

  if { $obj == "Atoms" } {
    set serials [list]
    foreach l [label list $obj] {
      # Skip hidden labels
      if { [lindex $l 2] == "hide" } { continue }
      set a [lindex $l 0]
      lappend serials [expr [lindex $a 1] + 1] ;# going from VMD 0-based to 1-based atomNumbers
    }
    if {[llength $serials] > 0} {
      editor_replace $w.editor.fr.text "${indent2}# Atom labels\n${indent2}atomNumbers $serials\n"
    }
  } else {
    set n(Bonds) 2
    set n(Angles) 3
    set n(Dihedrals) 4
    set cvc(Bonds) distance
    set cvc(Angles) angle
    set cvc(Dihedrals) dihedral
    foreach l [label list $obj] {
      # Skip hidden labels
      if { [lindex $l 2] == "hide" } { continue }
      set cfg "${indent}$cvc($obj) \{\n"
      for {set i 0} { $i < $n($obj) } {incr i} {
        set a [lindex $l $i]
        set serial [expr [lindex $a 1] + 1]
        append cfg "${indent2}group[expr $i+1] \{\n${indent2}${indent}atomNumbers $serial\n${indent2}\}\n"
      }
      append cfg "${indent}\}\n"
      editor_replace $w.editor.fr.text $cfg
    }
  }
}


# Insert contents of template file
proc ::cv_dashboard::insert_template { source map } {
  set w .cv_dashboard_window
  set path [dict get $map [$source get]]
  set in [open $path r]
  editor_replace $w.editor.fr.text [read $in]
  close $in
}


# Insert filename
proc ::cv_dashboard::insert_filename {} {
  variable ::cv_dashboard::filetype
  set w .cv_dashboard_window
  set indent ${::cv_dashboard::indent}
  set indent2 "${indent}${indent}"

  if { [info exists ::cv_dashboard::atomfile_dir] } {
    set path [tk_getOpenFile -filetypes {{"PDB" .pdb} {"XYZ" .xyz} {"All files" *}} \
        -initialdir $::cv_dashboard::atomfile_dir]
  } else {
    set path [tk_getOpenFile -filetypes {{"PDB" .pdb} {"XYZ" .xyz} {"All files" *}} -initialdir [pwd]]
  }
  if [string compare $path ""] {
    # Save directory for next invocation of this dialog
    set ::cv_dashboard::atomfile_dir [file dirname $path]
    set coltype [string range $filetype 0 end-4]
    editor_replace $w.editor.fr.text "${indent2}$filetype $path
${indent2}# ${coltype}Col O
${indent2}# ${coltype}ColValue 1\n"
  }
}


# Submit current config text from editor to cvm
proc ::cv_dashboard::edit_apply { type } {
  # type: colvar or bias
  set w .cv_dashboard_window
  if { $type == "colvar" } {
    set window $w.editor
    set text $w.editor.fr.text
  } elseif { $type == "bias" } {
    set window $w.bias_editor
    set text $w.bias_editor.fr.text
  } else {
    puts "Error: called edit_apply $type"
    return
  }
  set biases_before [run_cv list biases]
  set bias_cfg_before $::cv_dashboard::bias_configs
  foreach i $::cv_dashboard::being_edited {
    catch {cv $type $i delete}
  }
  set cfg [$text get 1.0 end-1c]
  set res [apply_config $cfg]
  if { [string compare $res ""] } {
    # error: restore backed up cfg
    foreach i $::cv_dashboard::being_edited {
      # Delete again any object that might have been successfully recreated
      catch {cv $type $i delete}
    }
    apply_config $::cv_dashboard::backup_cfg
    # The bias names being edited might have changed here
    # Do not destroy editor window (give user a chance to fix input)
    if { $type == "colvar" } {
      restore_biases $biases_before $bias_cfg_before
    }
    return
  }
  if { $type == "colvar" } {
    restore_biases $biases_before $bias_cfg_before
  }
  set ::cv_dashboard::being_edited {}
  destroy $window
}


# Restore biases that were deleted after editing colvars
proc ::cv_dashboard::restore_biases { biases_before bias_cfg_before } {

  set indent $::cv_dashboard::indent

  # Detect biases that were deleted
  set biases_now [run_cv list biases]
  foreach b $biases_before {
    if {[lsearch $biases_now $b] == -1 && [dict exists $bias_cfg_before $b] } {
      set key_cfg [dict get $bias_cfg_before $b]
      lassign $key_cfg keyword config

      # Enforce bias name if not specified, to avoid re-numbering
      if { [regexp -line -nocase {^\s*name\s+[^\s{}#]+} $config] } {
        set name_cfg ""
      } else {
        set name_cfg "${indent}name $b\n"
      }

      apply_config "$keyword {${name_cfg}$config}"
    }
  }
}


# Close editor without applying
proc ::cv_dashboard::edit_cancel { type } {

  set w .cv_dashboard_window
  set ::cv_dashboard::being_edited {}

  if { $type == "colvar" } {
    destroy $w.editor
  } elseif { $type == "bias" } {
    destroy $w.bias_editor
  }
}


proc ::cv_dashboard::refresh_reps {} {
  set w .cv_dashboard_window
  set numreps [molinfo $::cv_dashboard::mol get numreps]
  set reps [list]
  for {set i 0} {$i < $numreps} {incr i} {
    lappend reps [lindex [molinfo $::cv_dashboard::mol get [list [list selection $i]]] 0]
  }
  $w.editor.fl.helpers.reps configure -values $reps
}


proc ::cv_dashboard::editor_help {} {
  set w .cv_dashboard_window
  help_window $w.editor "Help on colvars config editor" "Colvars Dashboard: the editor window" \
{Help text}
}



#################################################################
# Editor window: Biases
#################################################################


# Edit new bias config
proc ::cv_dashboard::add_bias {} {
  edit_bias true
}


# Bias config editor window
proc ::cv_dashboard::edit_bias { {add false} {biases ""} } {

  if { [llength $::cv_dashboard::cvs] == 0 } {
    tk_messageBox -icon error -title "Colvars Dashboard Error"\
    -message "Cannot create a bias when no collective variables are defined.\n"
    return
  }

  if $add {
    # do not remove existing biases
    set biases {}
    set ::cv_dashboard::backup_cfg ""

    set cvs [selected_colvars]
    if { [llength $cvs] > 0 } {
      # Use any selected colvars
      set centers ""
      foreach cv $cvs { append centers " [format_value [run_cv colvar $cv value]]" }
    } else {
      # Or the first colvar if none is selected
      set cvs [lindex $::cv_dashboard::cvs 0]
      set centers " [format_value [run_cv colvar $cvs value]]"
    }
    set indent ${::cv_dashboard::indent}

    # Provide simple template
    set cfg "# You can edit or replace the example bias configuration below.\n\
harmonic {\n${indent}colvars $cvs\n${indent}forceConstant 10.0\n${indent}centers$centers\n}"
  } else {
    if {[llength $biases] < 1} {
      # if not provided, try selection
      set biases [selected_biases]
    }
    if {[llength $biases] == 0} {
      # If no selection, edit all variables
      set biases $::cv_dashboard::biases
    }
    set cfg ""
    foreach bias $biases {
      lassign [get_bias_keyword_config $bias] keyword config
      # Skip if bias config was not found
      if { $keyword == {} } { continue }
      append cfg "$keyword {$config}\n\n"
    }
    set ::cv_dashboard::backup_cfg $cfg
  }
  set w .cv_dashboard_window

  catch { destroy $w.bias_editor }
  set bias_editor [toplevel $w.bias_editor]
  wm title $bias_editor "Bias config editor"

  # Left frame: utility buttons - TODO possibly, low priority
  # frame $w.bias_editor.fl
  # set gridrow 0

  # labelframe  $w.bias_editor.fl.docs -bd 2 -text "Online documentation" -padx 2 -pady 2
  # set docs $w.bias_editor.fl.docs
  # ttk::button $docs.onlinedoc1 -text "Collective variables" -padding "4 2 4 2"\
  #   -command [list ::cv_dashboard::invokeBrowser "http://colvars.github.io/colvars-refman-vmd/colvars-refman-vmd.html#sec:colvar"]
  # ttk::button $docs.onlinedoc3 -text "Basis functions (components)" -padding "4 2 4 2"\
  #   -command [list ::cv_dashboard::invokeBrowser "http://colvars.github.io/colvars-refman-vmd/colvars-refman-vmd.html#sec:cvc_list"]
  # ttk::button $docs.onlinedoc2 -text "Atom groups" -padding "4 2 4 2"\
  #   -command [list ::cv_dashboard::invokeBrowser "http://colvars.github.io/colvars-refman-vmd/colvars-refman-vmd.html#sec:colvar_atom_groups"]

  # grid $docs.onlinedoc1 -row $gridrow -column 0 -pady 5 -padx 2 -sticky nsew
  # grid $docs.onlinedoc2 -row $gridrow -column 1 -pady 5 -padx 2 -sticky nsew
  # grid $docs.onlinedoc3 -row $gridrow -column 2 -pady 5 -padx 2 -sticky nsew
  # grid columnconfigure $docs 0 -weight 1
  # grid columnconfigure $docs 1 -weight 1
  # grid columnconfigure $docs 2 -weight 1

 
  # Right frame: text widget w scrollbar and Apply/Cancel buttons
  frame $w.bias_editor.fr
  tk::text $w.bias_editor.fr.text -undo 1 -yscrollcommand [list $w.bias_editor.fr.vsb set] -background white -font "Helvetica -14"
  ttk::scrollbar $w.bias_editor.fr.vsb -orient vertical -command [list $w.bias_editor.fr.text yview]
  $w.bias_editor.fr.text insert 1.0 $cfg
  set ::cv_dashboard::being_edited $biases
  grid $w.bias_editor.fr.text -row 0 -columnspan 3 -sticky nsew
  grid $w.bias_editor.fr.vsb -row 0 -column 3 -sticky nsew

  # Ctrl-s anywhere in the window saves/applies
  bind $w.bias_editor <Control-s> {::cv_dashboard::edit_apply bias}
  # Custom bindings for the text widget
  bind $w.bias_editor.fr.text <Control-a> "$w.bias_editor.fr.text tag add sel 1.0 end-1c; break"
  bind $w.bias_editor.fr.text <Tab> "::cv_dashboard::tab_pressed $w.bias_editor.fr.text"
  # Bind several possible mappings for Shift-Tab
  # ISO_Left_Tab is undefined on some platforms and will fail
  catch { bind $w.bias_editor.fr.text <ISO_Left_Tab> "::cv_dashboard::tab_pressed $w.bias_editor.fr.text true" }
  bind $w.bias_editor.fr.text <Shift-Tab> "::cv_dashboard::tab_pressed $w.bias_editor.fr.text true"

  set gridrow 1
  ttk::button $w.bias_editor.fr.apply -text "Apply \[Ctrl-s\]" -command {::cv_dashboard::edit_apply bias} -padding "2 0 2 0"
  ttk::button $w.bias_editor.fr.cancel -text "Cancel" -command {::cv_dashboard::edit_cancel bias} -padding "2 0 2 0"
  ttk::button $w.bias_editor.fr.clear -text "Clear" -command "$w.bias_editor.fr.text delete 1.0 end" -padding "2 0 2 0"

  grid $w.bias_editor.fr.apply -row $gridrow -column 0 -sticky e -pady 2 -padx 2
  grid $w.bias_editor.fr.cancel -row $gridrow -column 1 -sticky w -pady 2 -padx 2
  grid $w.bias_editor.fr.clear -row $gridrow -column 2 -sticky w -pady 2 -padx 2

  grid columnconfigure $w.bias_editor.fr 0 -weight 1
  grid columnconfigure $w.bias_editor.fr 1 -weight 1
  grid columnconfigure $w.bias_editor.fr 2 -weight 1
  grid rowconfigure $w.bias_editor.fr 0 -weight 1

  # No left frame for now
  # pack $w.bias_editor.fl -fill both -side left
  pack $w.bias_editor.fr -fill both -expand yes -padx 2 -pady 2
}
