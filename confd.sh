#!/bin/bash
#
# confd        Manage the confd agent
#       
# chkconfig:   2345 95 95
# description: confd is a tool for service discovery and configuration
# processname: confd
# config: /etc/confd/confd.conf
# pidfile: /var/run/confd.pid

### BEGIN INIT INFO
# Provides:       confd
# Required-Start: $local_fs $network
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:  0 1 6
# Short-Description: Manage the confd agent
# Description: confd is a tool for service discovery and configuration
### END INIT INFO

# source function library
. /etc/rc.d/init.d/functions

prog="confd"
user="root"
exec="/usr/local/bin/$prog"
pidfile="/var/run/$prog.pid"
lockfile="/var/lock/subsys/$prog"
logfile="/var/log/$prog"
conffile="/etc/confd/confd.conf"
confdir="/etc/confd/confd.d"

# pull in sysconfig settings
[ -e /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog

export GOMAXPROCS=${GOMAXPROCS:-2}

start() {
    [ -x $exec ] || exit 5
    
    [ -f $conffile ] || exit 6
    [ -d $confdir ] || exit 6

    umask 077

    touch $logfile $pidfile
    chown $user:$user $logfile $pidfile

    echo -n $"Starting $prog: "
    
    ## holy shell shenanigans, batman!
    ## daemon can't be backgrounded.  we need the pid of the spawned process,
    ## which is actually done via runuser thanks to --user.  you can't do "cmd
    ## &; action" but you can do "{cmd &}; action".
    daemon \
        --pidfile=$pidfile \
        --user=$user \
        " { $exec -config-file=$conffile -confdir=$confdir &>> $logfile & } ; echo \$! >| $pidfile "
    
    RETVAL=$?
    echo
    
    [ $RETVAL -eq 0 ] && touch $lockfile
    
    return $RETVAL
}

stop() {
    echo -n $"Shutting down $prog: "
    ## graceful shutdown with SIGINT
    killproc -p $pidfile $exec -INT
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f $lockfile
    return $RETVAL
}

restart() {
    stop
    start
}

reload() {
    echo -n $"Reloading $prog: "
    killproc -p $pidfile $exec -HUP
    echo
}

force_reload() {
    restart
}

rh_status() {
    status -p "$pidfile" -l $prog $exec
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
        restart
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload}"
        exit 2
esac

exit $?
