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

# ---- file logging (wish has no console on Windows) ----
set ::LOGFILE "C:/temp/auto_plmstart.$env(USERNAME).log"
catch {file delete -force $::LOGFILE}
proc Log {msg} {
    catch {
        set fh [open $::LOGFILE a]
        puts $fh "[clock format [clock seconds] -format %H:%M:%S] $msg"
        close $fh
    }
}
Log "=== auto_plmstart start ==="

set level "prd"
if {[llength $argv] >= 1 && [lindex $argv 0] ne ""} {
    set level [string tolower [lindex $argv 0]]
}

# ---- Hardcoded environment to select (independent of catia.envV5) ----
# This is the listbox entry text from $sgrantedenv. Matched as a glob prefix,
# so "V5R21 sp2f M170" is enough. Override via env var PLMSTART_ENV if needed.
set ::target_env "V5R21 sp2f M170"
if {[info exists env(PLMSTART_ENV)] && $env(PLMSTART_ENV) ne ""} {
    set ::target_env $env(PLMSTART_ENV)
}
set ::target_mode 1   ;# 1 = CATIA (connects to the ENOVIA DB via EnoStart)
if {[info exists env(PLMSTART_MODE)] && $env(PLMSTART_MODE) ne ""} {
    set ::target_mode $env(PLMSTART_MODE)
}
set ::target_profile "DESIGN"
if {[info exists env(PLMSTART_PROFILE)] && $env(PLMSTART_PROFILE) ne ""} {
    set ::target_profile $env(PLMSTART_PROFILE)
}
set ::_selected 0

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

# Keep the default window hidden from the very start, and re-hide it the
# instant Tk tries to map it, so the real PLMStart panel never visibly flashes.
catch {wm withdraw .}
bind . <Map> {catch {wm withdraw .}}

Log "sourcing $REAL_GUI  argv={$argv}"
if {[catch {source $REAL_GUI} err]} {
    Log "ERROR sourcing real GUI: $err"
    Log "errorInfo: $::errorInfo"
    # Don't exit immediately - the GUI may have redefined exit / thrown late.
}
Log "source returned"

# ---------------------------------------------------------------------------
# Once the panel has finished building (and pre-selected the last-used env),
# hide it and trigger its own Start button. Poll because init contacts the
# daemon and can take a couple of seconds.
# ---------------------------------------------------------------------------
set ::_auto_tries 0

proc DoExit {} {
    Log "=== auto_plmstart exiting ==="
    catch {org_exit}
    catch {exit}
}

proc AutoStart {} {
    incr ::_auto_tries

    # Aggressively keep every window hidden so nothing flashes.
    foreach top [concat . [winfo children .]] {
        if {[winfo toplevel $top] eq $top} { catch {wm withdraw $top} }
    }

    # Force the hardcoded environment selection (once the listbox is populated),
    # so we don't depend on the last-used entry in catia.envV5.
    if {!$::_selected && [winfo exists .func.env1.env1] && [info exists ::sgrantedenv]} {
        set idx [lsearch -glob $::sgrantedenv "$::target_env*"]
        if {$idx >= 0} {
            catch {.func.env1.env1 selection clear 0 end}
            catch {.func.env1.env1 selection set $idx}
            catch {.func.env1.env1 activate $idx}
            catch {.func.env1.env1 see $idx}
            catch {UpdAppli}
            set ::smode $::target_mode
            catch {set ::USER_V5_PROFILE $::target_profile}
            set ::_selected 1
            Log "hardcoded selection: idx=$idx -> '[lindex $::sgrantedenv $idx]' smode=$::smode profile=$::USER_V5_PROFILE"
        } else {
            Log "target env '$::target_env' NOT FOUND in sgrantedenv: $::sgrantedenv"
        }
    }

    if {[winfo exists .buttons.start]} {
        # Only fire if the Start button is actually enabled (env selected,
        # profile resolved). If it's disabled, wait a bit longer.
        set st "unknown"
        catch {set st [.buttons.start cget -state]}
        set sel "none"
        catch {set sel [.func.env1.env1 curselection]}
        Log "try $::_auto_tries: .buttons.start state=$st  env curselection=$sel  selected=$::_selected"
        if {$st eq "normal" && $::_selected} {
            Log "invoking Start (env sel=$sel, smode=[expr {[info exists ::smode] ? $::smode : {?}}])"
            if {[catch {.buttons.start invoke} e]} {
                Log "Start invoke raised: $e"
                Log "errorInfo: $::errorInfo"
            } else {
                Log "Start invoke returned OK"
            }
            # Give exec time to spawn V5StartApp17.tclsh before we quit.
            after 8000 DoExit
            return
        }
    } else {
        Log "try $::_auto_tries: .buttons.start does not exist yet"
    }

    if {$::_auto_tries >= 120} {   ;# ~60s
        Log "GAVE UP: Start button never became ready (.buttons.start)."
        DoExit
        return
    }

    after 500 AutoStart
}

# Give the panel a moment to build + do its daemon lookup, then start polling.
after 2500 AutoStart
