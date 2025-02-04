#!/bin/sh
address=$1
shift
grep '^service webminVNC' || cat >>/etc/xinetd.d/vnc <<@EOF@
# default: on
# description: This serves out a VNC connection which starts at a KDM login \
#	prompt. This VNC connection has a resolution of 16bit depth.
service webminVNC
{
	disable         = no
	socket_type     = stream
	protocol        = tcp
	wait            = no
	user            = vnc
	server          = /usr/bin/Xvnc
	server_args     = $@
	type		= UNLISTED
	port		= 5900
	bind		= $address
}
@EOF@
