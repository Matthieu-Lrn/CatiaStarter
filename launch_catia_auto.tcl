set level prd
if {[info exists env(PLMSTART_AUTO_LEVEL)] && $env(PLMSTART_AUTO_LEVEL) ne ""} {
    set level [string tolower $env(PLMSTART_AUTO_LEVEL)]
}

set root_data "I:/$level"
set argv0 "$root_data/cecc/bin/V5StartInt17.tcl"
set argv [list $level $root_data]

source $argv0

set auto_start_attempts 0

proc AutoStartCatia {} {
    global auto_start_attempts

    incr auto_start_attempts

    if {[winfo exists .func.button.start]} {
        catch {wm withdraw .}
        .func.button.start invoke
        after 2000 exit
        return
    }

    if {$auto_start_attempts >= 120} {
        puts stderr "Could not find the PLMStart Start button."
        exit 2
    }

    after 500 AutoStartCatia
}

after 500 AutoStartCatia
