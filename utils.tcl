#!/usr/bin/tclsh

set title [list "Vendor" "Device" "Total Cells" "Supported Cells" "Unsupported Cells"  "Supported Cells Names" "Unsupported Cells Names "]
set data  [list "--" "--" "--" "--" "--"  "--" "--" ]
set dupls_t [list "Module" "Dupl path1" "Dupl path2"]
set dupls_d [list "--" "--" "--" ]
set dupls {} 
set duplicates ""
set result_file 0
set supported_cells 0
set unsupported_cells 0
set total_mods [dict create] 
set empty_dict [dict create]

set path_vendor "vendor"

proc remspaces { line } {
	set line [string trim $line]
	set line [regsub -all {\s+} $line { }]
	return $line
}

proc uncomment_specify_blk { dir mask  } {
	set files [exec find $dir -name "*.v"]
	set tmpfile "tmp.inc"
	foreach file $files {
		puts "Adapting file $file"
		set linelist {}
		set outfile [open $tmpfile "w"]		
		set infile [open $file "r"]
		set sflag 0
		set eflag 0
		set esline ""
		set oline ""
		while { [gets $infile line1] >= 0 } {
			set line [remspaces $line1]
			if { [ regexp "^`ifndef ONESPIN$" $line ] } {
				set sflag 1
				set oline $line1
				continue
			}
			if { $sflag } {
				set sflag 0
				if { [ regexp "^specify$" $line ]  } {
					puts $outfile $line1
				} else {
					puts $outfile "$oline\n$line1"
				}
				continue
			}
			
			if { [ regexp "^endspecify$" $line ] } {
				puts $outfile $line1
				set eflag 1
				continue
			}

			if { [ regexp "^`endif // ONESPIN" $line ] && $eflag} {
				set eflag 0
				continue
			}

			puts $outfile $line1
		}
		close $infile		
		close $outfile		
		file rename -force $tmpfile $file
	}
}

proc get_lib_files { path_v } {
	global data
    global result_file	
	global supported_cells
	global unsupported_cells
	global title
	global total_mods
    global empty_dict
	global duplicates
	global dupls_t
	set f "result_file.csv"
 	set f1 "supported_cells.csv"
 	set f2 "unsupported_cells.csv"
	set dupl "dupl.csv"
	catch {
		exec rm $dupl
		exec rm $f 
		exec rm $f1
		exec rm $f2
	}

	set  duplicates         [ open $dupl "a+" ]
	puts $duplicates        [ join $dupls_t ","]
	set result_file         [ open $f "a+" ]
	puts $result_file       [ join [lrange $title 0 end-2] "," ]
	set supported_cells     [ open $f1 "a+" ]
	puts $supported_cells   [ join [lrange $title 0 1 ] "," ]
	set unsupported_cells   [ open $f2 "a+" ]
	puts $unsupported_cells [ join [ lrange $title 0 1 ] "," ]
	
	set mask "*.v"
	set dirs [ glob -directory $path_v -type d *]
	foreach d $dirs {
		set dir [split $d "/"]
		set vendor [lindex $dir end]
		puts "Vendor is "
		puts $vendor
			
		if { $vendor == "microsemi"} {
			get_bb_mods "$d/verilog/onespin" $mask $vendor
		}
	#    if { $vendor == "lattice" } {
	#		set total_mods $empty_dict 
	#		set l_elems [glob -directory $d/verilog -type d *]
	#		foreach l $l_elems {
	#			lset data 1 [ lindex [ split $l "/" ] end ]
	#			get_bb_mods $l $mask $vendor
	#		}
	#	} else {
	#		set devs [list "vivado" "rtf" "ise" ]
	#		foreach dev $devs {
	#			set total_mods $empty_dict
	#			set elems [ exec find $d -name $dev -type d ]
	#			foreach l $elems {
	#				set xilinx [ lindex [ split $l "/"]  end-1 ]
	#				lset data 1 "$xilinx/$dev"
	#				get_bb_mods $l $mask $vendor
	#			}
	#		}
	#	}
	}
	
}

proc get_bb_mods { dir mask vendor } {
	global result_file
	global supported_cells
	global unsupported_cells
	global title
	global data
 	global total_mods
    global empty_dict
	global dupls_t
	global dupls_d
	set files ""
	global duplicates	
	
	set files [ exec find $dir -name $mask ]
	#if { $vendor != "microsemi" } { 
		set mods {}
		set cells {}
		#set files [ exec find $dir -name $mask ]
		if { $vendor == "lattice" } {
			set total_mods $empty_dict 
		}
	#}
       	#else {
	#	set files [glob -nocomplain $dir/$mask ] 
	#}
	
	lset data 0 $vendor 
	foreach file $files {
		#if { $vendor == "microsemi" } {
		#	set mods {}
		#	set cells {}
		#	set total_mods $empty_dict
		#} 
		set infile [open $file "r"]
		set module ""
		set mflag 0
		
		while { [gets $infile line1] >= 0 } {
			set line [remspaces $line1]
			#if { [ regexp "^`ifndef ONESPIN" $line ] && $mflag } {
			#	if { $module != {}} {
			#		if {[lsearch $mods $module] < 0} {
			#			lappend mods $module
			#		}
			#	}
			#	continue
			#}
			if { [ regexp "`else // ! ONESPIN" $line ] } {
				puts $line
				set mflag 1
				#if { $module != {}} {
				#	puts "1"
				#	if {[lsearch $mods $module] < 0} {
				#		lappend mods $module
				#	}
				#}
				continue
			}
			if { [ regexp "^module" $line ] } {
				set module [ lindex [split $line " ("] 1 ]
				lappend cells $module
				if { $mflag } {
					if {[lsearch $mods $module] < 0} {
						lappend mods $module
					}
				}
				if {[ lsearch [dict key $total_mods] $module ] < 0 }  {
					if {[ lsearch $mods $module ] < 0} {
						dict append total_mods $module $file
					}
				} else {
					lset dupls_d 0 $module
					lset dupls_d 1 $file
					lset dupls_d 2 [dict get $total_mods $module]
					puts $duplicates [ join $dupls_d "," ]
				}
				continue
			}
			if { [ regexp "^endmodule" $line ] } {
				set mflag 0
				#set module ""
				continue
			}
	
			if { [ regexp "^`endif" $line ]} {
				set mflag 0
				continue
			}

		}
		close $infile
		
		#if { $vendor == "microsemi" } {
		#	set top [regsub -all {.v} [file tail $file] {}]
		#	lset data 1 $top
		#	lset data 2 [ dict size $total_mods ]
		#	lset data 3 [ expr [ dict size $total_mods ] - [ llength $mods ]]
		#	lset data 4 [ llength $mods ]
		#	lset data 5 [ dict key $total_mods ] 
		#	lset data 6 $mods
		#    
		#	data_collection $data	
		#}
	}
#	if { $vendor != "microsemi" } {
		set m [expr [ dict size $total_mods ] - [ llength $mods ] ]
		lset data 2 [ dict size $total_mods ]
		lset data 3 $m
		lset data 4 [ llength $mods ]
		puts $mods
		lset data 5 [ dict key $total_mods ]
		lset data 6 $mods
		
		data_collection $data		
#	}
}

proc data_collection { datas } {
		global result_file
		global supported_cells
		global unsupported_cells

		puts $result_file       [ join [lrange $datas 0 end-2 ]  "," ]
		puts $supported_cells   [ join [lrange $datas 0 2] ","]
		puts $supported_cells   [ join [lindex $datas 5] "\n"]
		puts $unsupported_cells [ join [lrange $datas 0 1] ","]
		puts $unsupported_cells [ join [lindex $datas 6] "\n"]
}

get_lib_files $path_vendor
