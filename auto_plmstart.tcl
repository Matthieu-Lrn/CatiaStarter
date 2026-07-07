# auto_plmstart.tcl
#
# Drives the REAL PLMStart env panel (V5StartInt17.tcl) headlessly:
#   - sources the deployed script unchanged (no edits on I:\)
#   - it builds its GUI, contacts the ENOVIA daemon, and pre-selects your
#     last-used environment exactly as it does for a normal launch
#   - we keep the window hidden and invoke its own Start button in-process,
#     so the real PLMStart -> EnoStart -> LOGINv1 daemon handshake ->
#     V5StartApp17.tclsh path runs (ENOVIA V5 VPM included)
#
# Usage:  wish auto_plmstart.tcl [prd|vld|crt|trn]     (default prd)

# ---- where the real 5.0.1 launcher lives ----
set REAL_GUI  "I:/V5Start/5.0.1/bin/V5StartInt17.tcl"

set level "prd"
if {[llength $argv] >= 1 && [lindex $argv 0] ne ""} {
    set level [string tolower [lindex $argv 0]]
}

if {![file readable $REAL_GUI]} {
    puts stderr "auto_plmstart: cannot read $REAL_GUI (is I: mapped?)"
    exit 2
}

# PLMStart.Chooser normally launches V5StartInt17.tcl with THREE args:
#   <level> <root_data> <root_data_csv>
# We skip the Chooser, so supply them here.
set root_data "I:/$level"
set rootdfile "I:/V5Start/5.0.1/env/root_data_mtl.csv"
if {![file readable $rootdfile]} {
    set rootdfile "I:/V5Start/5.0.1/env/root_data_all.csv"
}

# The real script derives its script/lib/env dirs from argv0. Set argv0 +
# argv/argc before sourcing so its own arg parsing sees the level/root_data.
set argv0 $REAL_GUI
set argv  [list $level $root_data $rootdfile]
set argc  [llength $argv]

# Keep the default window hidden from the very start.
catch {wm withdraw .}

if {[catch {source $REAL_GUI} err]} {
    puts stderr "auto_plmstart: error sourcing real GUI: $err"
    # Don't exit immediately - the GUI may have redefined exit / thrown late.
}

# ---------------------------------------------------------------------------
# Once the panel has finished building (and pre-selected the last-used env),
# hide it and trigger its own Start button. Poll because init contacts the
# daemon and can take a couple of seconds.
# ---------------------------------------------------------------------------
set ::_auto_tries 0

proc AutoStart {} {
    incr ::_auto_tries

    # Aggressively keep every window hidden so nothing flashes.
    foreach top [concat . [winfo children .]] {
        if {[winfo toplevel $top] eq $top} { catch {wm withdraw $top} }
    }

    if {[winfo exists .buttons.start]} {
        # Only fire if the Start button is actually enabled (env selected,
        # profile resolved). If it's disabled, wait a bit longer.
        set st "normal"
        catch {set st [.buttons.start cget -state]}
        if {$st eq "normal"} {
            puts stdout "auto_plmstart: invoking Start for level $::level"
            catch {.buttons.start invoke} e
            if {$e ne ""} { puts stderr "auto_plmstart: Start invoke said: $e" }
            # Give exec time to spawn V5StartApp17.tclsh before we quit.
            after 4000 { catch {org_exit} ; catch {exit} }
            return
        }
    }

    if {$::_auto_tries >= 120} {   ;# ~60s
        puts stderr "auto_plmstart: Start button never became ready (.buttons.start)."
        catch {org_exit} ; catch {exit}
        return
    }

    after 500 AutoStart
}

# Give the panel a moment to build + do its daemon lookup, then start polling.
after 2500 AutoStart
