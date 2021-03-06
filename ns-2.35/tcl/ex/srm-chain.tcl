#
# Copyright (C) 1997 by USC/ISI
# All rights reserved.                                            
#                                                                
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation, advertising
# materials, and other materials related to such distribution and use
# acknowledge that the software was developed by the University of
# Southern California, Information Sciences Institute.  The name of the
# University may not be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 

#
# Maintainer: Kannan Varadhan <kannan@isi.edu>
# Version Date: $Date: 1999/09/10 22:08:46 $
#
# @(#) $Header: /cvsroot/nsnam/ns-2/tcl/ex/srm-chain.tcl,v 1.11 1999/09/10 22:08:46 haoboy Exp $ (USC/ISI)
#
# updated to use -multicast on and allocaddr by Lloyd Wood
#

if [string match {*.tcl} $argv0] {
    set prog [string range $argv0 0 [expr [string length $argv0] - 5]]
} else {
    set prog $argv0
}

if {[llength $argv] > 0} {
    set srmSimType [lindex $argv 0]
} else {
    set srmSimType Deterministic
}

source ../mcast/srm-nam.tcl		;# to separate control messages.
#source ../mcast/srm-debug.tcl		;# to trace delay compute fcn. details.

set ns [new Simulator -multicast on]

$ns trace-all [open out.tr w]
$ns namtrace-all [open out.nam w]

$ns color 0 white		;# data source
$ns color 40 blue		;# session
$ns color 41 red		;# request
$ns color 42 green		;# repair
$ns color 1 Khaki		;# source node
$ns color 2 goldenrod
$ns color 3 sienna
$ns color 4 HotPink
$ns color 5 maroon
$ns color 6 orchid
$ns color 7 purple
$ns color 8 snow4
$ns color 9 PeachPuff1

# make the nodes
set nmax 5
for {set i 0} {$i <= $nmax} {incr i} {
    set n($i) [$ns node]
}

# now the links
set chainMax [expr $nmax - 1]
set j 0
for {set i 1} {$i <= $chainMax} {incr i} {
    $ns duplex-link $n($i) $n($j) 1.5Mb 10ms DropTail
    $ns duplex-link-op $n($j) $n($i) orient right
    set j $i
}
$ns duplex-link $n([expr $nmax - 2]) $n($nmax) 1.5Mb 10ms DropTail
$ns duplex-link-op $n([expr $nmax - 2]) $n($nmax) orient right-up
$ns duplex-link-op $n([expr $nmax - 2]) $n([expr $nmax-1]) orient right-down

$ns queue-limit $n(0) $n(1) 2	;# q-limit is 1 more than max #packets in q.
$ns queue-limit $n(1) $n(0) 2

set group [Node allocaddr]
set mh [$ns mrtproto CtrMcast {}]
$ns at 0.3 "$mh switch-treetype $group"

# now the multicast, and the agents
set srmStats [open srmStats.tr w]
set srmEvents [open srmEvents.tr w]

set fid 0
for {set i 0} {$i <= 5} {incr i} {
    set srm($i) [new Agent/SRM/$srmSimType]
    $srm($i) set dst_addr_ $group
    $srm($i) set dst_port_ 0
    $srm($i) set fid_ [incr fid]
    $srm($i) trace $srmEvents
    $srm($i) log $srmStats
    $ns at 1.0 "$srm($i) start"
    $ns attach-agent $n($i) $srm($i)
}

# Attach a data source to srm(1)
set packetSize 800
set s [new Application/Traffic/CBR]
$s set packetSize_ $packetSize
$s set interval_ 0.04
$s attach-agent $srm(0)
$srm(0) set tg_ $s
$srm(0) set app_fid_ 0
$srm(0) set packetSize_ $packetSize
$ns at 3.5 "$srm(0) start-source"

#$ns rtmodel-at 3.519 down $n(0) $n(1)	;# this ought to drop exactly one
#$ns rtmodel-at 3.521 up   $n(0) $n(1)	;# data packet?
set loss_module [new SRMErrorModel]
$loss_module drop-packet 2 10 1
$loss_module drop-target [$ns set nullAgent_]
$ns at 1.25 "$ns lossmodel $loss_module $n(0) $n(1)"

proc distDump {} {
    global srm
    foreach i [array names srm] {
	puts "distances [$srm($i) distances?]"
    }
    puts "---"
}
$ns at 3.3 "distDump"

proc finish src {
    $src stop

    global prog ns srmStats srmEvents srm nmax
    $ns flush-trace		;# NB>  Did not really close out.tr...:-)
    close $srmStats
    close $srmEvents

    set avg_info [open srm-avg-info w]
    puts $avg_info "avg:\trep-delay\treq-delay\trep-dup\t\treq-dup"
    foreach index [lsort -integer [array name srm]] {
	set tmplist [$srm($index) array get stats_]
	puts $avg_info "$index\t[format %7.4f [lindex $tmplist 1]]\t\t[format %7.4f [lindex $tmplist 5]]\t\t[format %7.4f [lindex $tmplist 9]]\t\t[format %7.4f [lindex $tmplist 13]]"
    }
    flush $avg_info
    close $avg_info

    puts "running nam..."
    exec nam out.nam &
    exit 0
}
$ns at 4.0 "finish $s"
$ns run 
