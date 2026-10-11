foreach required_var {KAMERA_PROJECT KAMERA_MODE} {
    if {![info exists ::env($required_var)] || $::env($required_var) eq ""} {
        error "Required environment variable $required_var is not set"
    }
}

set project_file $::env(KAMERA_PROJECT)
set mode $::env(KAMERA_MODE)
set implementation impl1

if {![file isfile $project_file]} {
    error "Diamond project does not exist: $project_file"
}

prj_project open $project_file
if {[catch {
    prj_strgy set_value -strategy Strategy1 lse_vhdl2008=True
    prj_strgy set_value -strategy Strategy1 lse_frequency=48
    if {$mode eq "Synthesis"} {
        prj_run Synthesis -impl $implementation -forceAll
    } elseif {$mode eq "Full"} {
        foreach stage {Synthesis Translate Map PAR} {
            prj_run $stage -impl $implementation -forceAll
        }
        prj_run Export -impl $implementation -task Jedecgen -forceAll
    } else {
        error "Unsupported build mode: $mode"
    }
} build_error]} {
    catch {prj_project close}
    error $build_error
}
prj_project close
