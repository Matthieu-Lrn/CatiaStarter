# launch_catia_auto.tcl
#
# Starts CATIA headlessly by reusing the deployed CATStart logic WITHOUT
# any GUI interaction (no button clicking, no widget polling).
#
#   - sources the deployed V5StartInt*.tcl unchanged (no edits to I:\)
#     so it builds the granted-environment list and pre-selects the
#     last-used environment from catia.envV5 (same default the GUI shows)
#   - calls the V5Start proc directly with that pre-selected environment
#     and an explicit application mode (CATIA=1 by default)
#
# Level : PLMSTART_AUTO_LEVEL   (default prd)
# Mode  : V5START_AUTO_MODE     (default 1 = CATIA; 3 = Enovia, 5 = DMU)

set level prd
if {[info exists env(PLMSTART_AUTO_LEVEL)] && $env(PLMSTART_AUTO_LEVEL) ne ""} {
    set level [string tolower $env(PLMSTART_AUTO_LEVEL)]
}

set auto_mode 1
if {[info exists env(V5START_AUTO_MODE)] && $env(V5START_AUTO_MODE) ne ""} {
    set auto_mode $env(V5START_AUTO_MODE)
}

set root_data "I:/$level"

# The Chooser prefers V5StartInt.tcl, then falls back to V5StartInt17.tcl.
# Source whichever exists; set argv0 so the sourced script's [info script]
# root_data derivation still works.
set candidates [list \
    "$root_data/cecc/bin/V5StartInt.tcl" \
    "$root_data/cecc/bin/V5StartInt17.tcl"]

set sourced ""
foreach f $candidates {
    if {[file readable $f]} {
        set argv0 $f
        set argv [list $level $root_data]
        if {[catch {source $f} err]} {
            puts stderr "Error sourcing $f: $err"
            continue
        }
        set sourced $f
        break
    }
}

if {$sourced eq ""} {
    puts stderr "Could not source any V5StartInt script under $root_data/cecc/bin"
    exit 2
}

# The sourced main body ran at global scope, so these globals are now set:
#   sgrantedenv  - sorted list of environments the user is allowed
#   selecteditem - index of the last-used env (from catia.envV5), or -1
# Hide any window the script created so nothing flashes on screen.
foreach top [concat . [winfo children .]] {
    if {[winfo toplevel $top] eq $top} {
        catch {wm withdraw $top}
    }
}

if {![info exists sgrantedenv] || [llength $sgrantedenv] == 0} {
    puts stderr "No environments are granted for this user - cannot auto-start."
    exit 3
}

if {![info exists selecteditem] || $selecteditem < 0} {
    puts stderr "Last-used environment from catia.envV5 was not found in the\
                 granted list. Run the CATStart GUI once to set a valid default."
    exit 4
}

set autoEnv [lindex $sgrantedenv $selecteditem]

# Launch directly - same call the Start button makes, with explicit mode.
if {[catch {V5Start $autoEnv $auto_mode} err]} {
    puts stderr "V5Start failed for \"$autoEnv\" mode $auto_mode: $err"
    exit 5
}

exit 0
