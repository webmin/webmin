#!/usr/local/bin/perl
# Show a form for editing or creating a log destination

require './syslog-ng-lib.pl';
&ReadParse();

# Show title and get the destination
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'destination_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'destination_title2'}, "");
	@dests = &find("destination", $conf);
	($dest) = grep { $_->{'value'} eq $in{'name'} } @dests;
	$dest || &error($text{'destination_egone'});
	}

# Form header
print &ui_form_start("save_destination.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'destination_header'}, undef, 2);

# Destination name
print &ui_table_row($text{'destination_name'},
		    &ui_textbox("name", $dest->{'value'}, 20));

# Work out type
$file = &find("file", $dest->{'members'});
$usertty = &find("usertty", $dest->{'members'});
$program = &find("program", $dest->{'members'});
$pipe = &find("pipe", $dest->{'members'});
$udp = &find("udp", $dest->{'members'});
$tcp = &find("tcp", $dest->{'members'});
$dgram = &find("unix-dgram", $dest->{'members'});
$stream = &find("unix-stream", $dest->{'members'});
$type = $file ? 0 :
	$usertty ? 1 :
	$program ? 2 :
	$pipe ? 3 :
	$tcp ? 4 :
	$udp ? 5 :
	$dgram ? 6 :
	$stream ? 7 : 0;

$dtable = "<table>\n";

# File destination
if ($file) {
	$file_name = $file->{'value'};
	$file_owner = &find_value("owner", $file->{'members'});
	$file_group = &find_value("group", $file->{'members'});
	$file_perm = &find_value("perm", $file->{'members'});
	$file_create_dirs = &find_value("create_dirs", $file->{'members'});
	$file_dir_perm = &find_value("dir_perm", $file->{'members'});
	$file_fsync = &find_value("fsync", $file->{'members'});
	$file_sync_freq = &find_value("sync_freq", $file->{'members'});
	}
$dtable .= "<tr> <td valign=top>".&ui_oneradio("type", 0, "<b>$text{'destinations_typef'}</b>", $type == 0)."</td> <td valign=top><table>\n";
$dtable .= "<tr> <td>$text{'destination_file'}</td> <td>".
	   &ui_textbox("file_name", $file_name, 35)." ".
	   &file_chooser_button("file_name")."</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_owner'}</td> <td>".
	   &ui_opt_textbox("file_owner", $file_owner, 15, $text{'default'})." ".
	   &user_chooser_button("file_owner").
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_group'}</td> <td>".
	   &ui_opt_textbox("file_group", $file_group, 15, $text{'default'})." ".
	   &group_chooser_button("file_owner").
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_perm'}</td> <td>".
	   &ui_opt_textbox("file_perm", $file_perm, 5, $text{'default'}).
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_create_dirs'}</td> <td>".
	   &ui_radio("file_create_dirs", $file_create_dirs,
		     [ [ 'yes', $text{'yes'} ],
		       [ 'no', $text{'no'} ],
		       [ '', $text{'default'} ] ]).
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_dir_perm'}</td> <td>".
	   &ui_opt_textbox("file_dir_perm", $file_dir_perm, 5,$text{'default'}).
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_fsync'}</td> <td>".
	   &ui_radio("file_fsync", $file_fsync,
		     [ [ 'yes', $text{'yes'} ],
		       [ 'no', $text{'no'} ],
		       [ '', $text{'default'} ] ]).
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_sync_freq'}</td> <td>".
	   &ui_opt_textbox("file_sync_freq", $file_sync_freq, 5, $text{'default'}).
	   "</td> </tr>\n";
$dtable .= "</table></td> </tr>";

# User TTY destination
if ($usertty) {
	$usertty_user = $usertty->{'value'};
	}
$dtable .= "<tr> <td valign=top>".&ui_oneradio("type", 1, "<b>$text{'destinations_typeu'}</b>", $type == 1)."</td> <td valign=top>\n";
$dtable .= &ui_opt_textbox("usertty_user", $usertty_user eq "*" ? undef : $usertty_user, 20, $text{'destinations_allusers'}, $text{'destination_users'})." ".&user_chooser_button("usertty_user", 1);
$table .= "</td> </tr>";

# Program destination
if ($program) {
	$program_prog = $program->{'value'};
	}
$dtable .= "<tr> <td valign=top>".&ui_oneradio("type", 2, "<b>$text{'destinations_typep'}</b>", $type == 2)."</td> <td valign=top>\n";
$dtable .= &ui_textbox("program_prog", $program_prog, 50);
$table .= "</td> </tr>";

# Pipe destination
if ($pipe) {
	$pipe_name = $pipe->{'value'};
	}
$dtable .= "<tr> <td valign=top>".&ui_oneradio("type", 3, "<b>$text{'destinations_typei'}</b>", $type == 3)."</td> <td valign=top>\n";
$dtable .= &ui_textbox("pipe_name", $pipe_name, 30)." ".
	   &file_chooser_button("pipe_name");
$dtable .= "</td> </tr>";

# TCP or UDP socket
$net = $tcp || $udp;
if ($net) {
	$net_host = $net->{'value'};
	$net_port = &find_value("port", $net->{'members'});
	$net_localip = &find_value("localip", $net->{'members'});
	$net_localport = &find_value("localport", $net->{'members'});
	}
$dtable .= "<tr> <td valign=top>".&ui_oneradio("type", 4, "<b>$text{'destination_net'}</b>", $type == 4 || $type == 5)."</td> <td valign=top><table>\n";
$dtable .= "<tr> <td>$text{'destination_proto'}</td> ".
	   "<td>".&ui_select("net_proto", $type == 5 ? "udp" : "tcp",
		     [ [ "tcp", "TCP" ], [ "udp", "UDP" ] ])."</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_host'}</td> ".
	   "<td>".&ui_textbox("net_host", $net_host, 20)."</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_port'}</td> ".
	   "<td>".&ui_opt_textbox("net_port", $net_port, 5, "$text{'default'} (514)")."</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_localip'}</td> ".
	   "<td>".&ui_opt_textbox("net_localip", $net_localip, 15, $text{'default'})."</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_localport'}</td> ".
	   "<td>".&ui_opt_textbox("net_localport", $net_localport, 5, $text{'default'})."</td> </tr>\n";
$dtable .= "</table></td> </tr>";

# Datagram or stream socket
$unix = $dgram || $stream;
if ($unix) {
	$unix_name = $unix->{'value'};
	}
$dtable .= "<tr> <td valign=top>".&ui_oneradio("type", 6, "<b>$text{'destination_unix'}</b>", $type == 6 || $type == 7)."</td> <td valign=top><table>\n";
$dtable .= "<tr> <td>$text{'destination_utype'}</td> ".
	   "<td>".&ui_select("unix_type",
		     $type == 6 ? "unix-dgram" : "unix-stream",
		     [ [ "unix-stream", $text{'destinations_types'} ],
		       [ "unix-dgram", $text{'destinations_typeg'} ] ]).
	   "</td> </tr>\n";
$dtable .= "<tr> <td>$text{'destination_socket'}</td> ".
	   "<td>".&ui_textbox("unix_name", $unix_name, 30)."\n".
		  &file_chooser_button("unix_name")."</td> </tr>\n";
$dtable .= "</table></td> </tr>";

# Actually show the destination
$dtable .= "</table>\n";
print &ui_table_row($text{'destination_type'}, $dtable);

# Form footer and buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_destinations.cgi", $text{'destinations_return'});

