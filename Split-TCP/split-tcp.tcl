#Create a simulator object
set ns [new Simulator]

#Define different colors for data flows (for NAM)
$ns color 1 Blue
$ns color 2 Red

#Open the NAM trace file
set nf [open out.nam w]
set f0 [open reno.tr w]
set f1 [open reno-cong.tr w]
$ns namtrace-all $nf

#Define a 'finish' procedure
proc finish {} {
        global ns f0 nf f1
        $ns flush-trace
	close $f0
	close $f1
        #Close the NAM trace file
        close $nf
        #Execute NAM on the trace file
        exec nam out.nam &
	exec xgraph -x "Time in seconds" -y "CONGWND" -t "CONGESTION" reno-cong.tr -geometry 1000x1000 &
	#exec xgraph reno.tr -geometry 800x800 &
       
        exit 0
}


#record

proc record {} {
        global sink f0 
	set ns [Simulator instance]
        set time 0.5

        set bw0 [$sink set bytes_]
       # set bw1 [$sink1 set bytes_]
       # set bw2 [$sink2 set bytes_]
	
        set now [$ns now]

        puts $f0 "$now [expr $bw0/$time*8/1000000]"
      #  puts $f1 "$now [expr $bw1/$time*8/1000000]"
      #  puts $f2 "$now [expr $bw2/$time*8/1000000]"
	
        $sink set bytes_ 0
       # $sink1 set bytes_ 0
       # $sink2 set bytes_ 0
	
        $ns at [expr $now+$time] "record"
}

#set cubic_tcp_mode 1
#Create four nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]

#Create links between the nodes
$ns duplex-link $n0 $n2 10b 50ms DropTail
$ns duplex-link $n1 $n2 5Mb 10ms DropTail
$ns duplex-link $n2 $n3 1Mb 1000ms DropTail

#creating lossy link between n2 and n3
#set loss_module [new ErrorModel]
#$loss_module set rate_ 0.5
#$loss_module ranvar [new RandomVariable/Uniform]
#$loss_module drop-target [new Agent/Null]
#$ns lossmodel $loss_module $n2 $n3

#Agent/TCP set cubic_beta_ 0.8
#Agent/TCP set cubic_max_increment_ 16
#Agent/TCP set cubic_fast_convergence_ 1
#Agent/TCP set cubic_scale_ 0.4
#Agent/TCP set cubic_tcp_friendliness_ $cubic_tcp_mode
#Agent/TCP set cubic_low_utilization_threshold_ 0 
#Agent/TCP set cubic_low_utilization_checking_period_ 2
#Agent/TCP set cubic_delay_min_ 0
#Agent/TCP set cubic_delay_avg_ 0
#Agent/TCP set cubic_delay_max_ 0
#Agent/TCP set cubic_low_utilization_indication_ 0

#Set Queue Size of link (n2-n3) to 100
$ns queue-limit $n2 $n3 100

#Give node position (for NAM)
$ns duplex-link-op $n0 $n2 orient right
$ns duplex-link-op $n1 $n2 orient right-up
$ns duplex-link-op $n2 $n3 orient right

#Monitor the queue for link (n2-n3). (for NAM)
$ns duplex-link-op $n2 $n3 queuePos 0.5

Agent/TCP set nam_tracevar_ true        
#Agent/TCP set window_ 20
#Agent/TCP set ssthresh_ 20

#Setup a TCP connection
set tcp [new Agent/TCP/Newreno]
$tcp set class_ 2
$tcp set window_ 2000
$ns attach-agent $n0 $tcp
set sink [new Agent/TCPSink]
$ns attach-agent $n3 $sink
$ns connect $tcp $sink
$tcp set fid_ 1

#Setup a FTP over TCP connection
set ftp [new Application/FTP]
$ftp attach-agent $tcp
$ftp set type_ FTP

#monitor the TCP connection
$ns add-agent-trace $tcp tcp
$ns monitor-agent-trace $tcp
$tcp tracevar cwnd_
$tcp tracevar ssthresh_
$tcp tracevar maxseq_     ;# max seq number sent.
$tcp tracevar ack_        ;# highest ACK received.
$tcp tracevar dupacks_    ;# duplicate ACK counter.

#Setup a UDP connection
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
set pfd [open reno-cong.tr w]
$ns at 1.0 "plot $tcp $pfd"

proc plot { tcpsrc fd } {
global ns
set interval 0.5
set wnd [$tcpsrc set cwnd_]
set time [$ns now]
puts $fd "$time $wnd"
$ns at [expr $time+$interval] "plot $tcpsrc $fd"
}

#Schedule events for the CBR and FTP agents
$ns at 0.1 "$cbr start"
$ns at 0.0 "record"
$ns at 1.0 "$ftp start"
$ns at 99.5 "$ftp stop"
$ns at 99.0 "$cbr stop"

#Detach tcp and sink agents (not really necessary)
$ns at 99.5 "$ns detach-agent $n0 $tcp ; $ns detach-agent $n3 $sink"

#Call the finish procedure after 5 seconds of simulation time
$ns at 100.0 "finish"

#Print CBR packet size and interval
#puts "CBR packet size = [$cbr set packet_size_]"
#puts "CBR interval = [$cbr set interval_]"

#Run the simulation
$ns run

