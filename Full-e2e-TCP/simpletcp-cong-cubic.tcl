
#Create a simulator object
set ns [new Simulator]

#Define different colors for data flows (for NAM)
$ns color 1 Blue
$ns color 2 Red

#Open the NAM trace file
set nf [open out.nam w]
set f0 [open cubic-cong.tr w]
$ns namtrace-all $nf

#Define a 'finish' procedure
proc finish {} {
        global ns nf f0
        $ns flush-trace
	close $f0
        #Close the NAM trace file
        close $nf
        #Execute NAM on the trace file
        exec nam out.nam &
	#exec xgraph newreno-cong.tr -geometry 800x400 &
	exec xgraph -x "Time in seconds" -y "CONGWND" -t "CONGESTION" cubic-cong.tr &
        exit 0
}

proc record {} {
        global sink f0 
	set ns [Simulator instance]
        set time 0.5

        set bw [$sink set bytes_]
	
        set now [$ns now]

        puts $f0 "$now [expr $bw/$time*8/1000000]"
	
        $sink set bytes_ 0
	
        $ns at [expr $now+$time] "record"
}

set cubic_tcp_mode 1

#Creating four nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]

#Create links between the nodes
$ns duplex-link $n0 $n2 10Mb 50ms DropTail
$ns duplex-link $n1 $n2 10Mb 50ms DropTail
$ns duplex-link $n2 $n3 1.7Mb 20ms DropTail


#Give node position (for NAM)
$ns duplex-link-op $n0 $n2 orient right
$ns duplex-link-op $n1 $n2 orient right-up
$ns duplex-link-op $n2 $n3 orient right

Agent/TCP set cubic_beta_ 0.8
Agent/TCP set cubic_max_increment_ 16
Agent/TCP set cubic_fast_convergence_ 1
Agent/TCP set cubic_scale_ 0.4
Agent/TCP set cubic_tcp_friendliness_ $cubic_tcp_mode
Agent/TCP set cubic_low_utilization_threshold_ 0 
Agent/TCP set cubic_low_utilization_checking_period_ 2
Agent/TCP set cubic_delay_min_ 0
Agent/TCP set cubic_delay_avg_ 0
Agent/TCP set cubic_delay_max_ 0
Agent/TCP set cubic_low_utilization_indication_ 0

#Setup a TCP connection
set tcp [new Agent/TCP]
$tcp set class_ 2
$ns attach-agent $n0 $tcp
set sink [new Agent/TCPSink]
$ns attach-agent $n3 $sink
$ns connect $tcp $sink
$tcp set fid_ 1

#Setup a FTP over TCP connection to create traffic
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ftp set type_ FTP

#Setup a UDP connection to create traffic
set udp [new Agent/UDP]
$ns attach-agent $n1 $udp
set null [new Agent/Null]
$ns attach-agent $n3 $null
$ns connect $udp $null
$udp set fid_ 2

#Setup a CBR over UDP connection
set cbr [new Application/Traffic/CBR]
$cbr attach-agent $udp
$cbr set type_ CBR
$cbr set packet_size_ 100
$cbr set rate_ 1mb
$cbr set random_ false

#plot graph
set pfd [open cubic-cong.tr w]
$ns at 10.1 "plot $tcp $pfd"

proc plot { tcpsrc fd } {
global ns
set interval 0.5
set wnd [$tcpsrc set cwnd_]
set time [$ns now]
puts $fd "$time $wnd"
$ns at [expr $time+$interval] "plot $tcpsrc $fd"
}


#Schedule events for the CBR and FTP agents
$ns at 0.0 "record"
$ns at 0.1 "$cbr start"
$ns at 1.0 "$ftp start"
$ns at 4.0 "$ftp stop"
$ns at 4.5 "$cbr stop"

#Detach tcp and sink agents (not really necessary)
$ns at 4.5 "$ns detach-agent $n0 $tcp ; $ns detach-agent $n3 $sink"

#Call the finish procedure after 5 seconds of simulation time
$ns at 5.0 "finish"

#Run the simulation
$ns run

