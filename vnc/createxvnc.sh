#!/bin/sh
address=$1
shift
if [ -d /etc/xinetd.d ]
then
	grep '^service webminVNC' /etc/xinetd.d/vnc || cat >>/etc/xinetd.d/vnc <<@EOF@
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
else
	if [ -d /etc/systemd/system ]
	then
		if [ ! -e /etc/systemd/system/vnc.socket  -a ! -e /etc/systemd/system/vnc@.service ]
		then
			cat >>/etc/systemd/system/vnc.socket <<@EOF@
[Unit]
Description=VNC local Socket

[Socket]
ListenStream=$address:5900
Accept=yes

[Install]
WantedBy=sockets.target
@EOF@
			XVNC=`which Xvnc`
			cat >>/etc/systemd/system/vnc@.service <<@EOF@
[Unit]
Description=VNC Per-Connection Server

[Service]
ExecStart=-$XVNC $@
User=nobody
#Group=nogroup
StandardInput=socket
@EOF@
			systemctl daemon-reload
			systemctl enable vnc.socket
			systemctl start vnc.socket
		fi
	fi
fi
if [ -f /etc/gdm/custom.conf ]
then
	grep -Pzo '\n\[xdmcp\]\nEnable=true' /etc/gdm/custom.conf  >/dev/null 2>&1 || (
		grep -v '\[xdmcp\]' /etc/gdm/custom.conf >/tmp/gdm$$
		echo '[xdmcp]' >>/tmp/gdm$$
		echo 'Enable=true' >>/tmp/gdm$$
		if [ ! -e /etc/gdm/custom.conf.bak ]
		then
			mv /etc/gdm/custom.conf /etc/gdm/custom.conf.bak
		fi
		cp /tmp/gdm$$ /etc/gdm/custom.conf
		systemctl is-active --quiet gdm && systemctl restart gdm

	)
fi
