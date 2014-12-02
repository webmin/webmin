#!/usr/local/bin/perl
# virt_index.cgi
# Display a menu for some specific virtual server, or the default server

require './apache-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$desc = &text('virt_header', &virtual_name($v));
&ui_print_header($desc, $text{'virt_title'}, "", undef, undef, undef, undef, &restart_button());

# Display header and icons
$sw_icon = { "icon" => "images/show.gif",
	     "name" => $text{'virt_show'},
	     "link" => "show.cgi?virt=$in{'virt'}" };
if ($in{'virt'} && $access{'types'} eq '*') {
	$ed_icon = { "icon" => "images/edit.gif",
		     "name" => $text{'virt_edit'},
		     "link" => "manual_form.cgi?virt=$in{'virt'}" };
	}
if ($v->{'value'} =~ /:80/ && $v->{'value'} !~ /:443/) {
	# Hide SSL icon for non-SSL sites
	$access_types{14} = 0;
	}
&config_icons("virtual", "edit_virt.cgi?virt=$in{'virt'}&", $sw_icon,
	      $ed_icon ? $ed_icon : ());

# Display per-directory options
@dir = ( &find_directive_struct("Directory", $conf) ,
         &find_directive_struct("DirectoryMatch", $conf),
	 &find_directive_struct("Files", $conf),
	 &find_directive_struct("FilesMatch", $conf),
	 &find_directive_struct("Location", $conf),
	 &find_directive_struct("LocationMatch", $conf),
	 &find_directive_struct("Proxy", $conf) );
if (@dir) {
	print &ui_hr();
	print &ui_subheading($text{'dir_title'});
	foreach $d (@dir) {
		$what = &dir_name($d);
		substr($what, 0, 1) = uc(substr($what, 0, 1));
		push(@links, "dir_index.cgi?idx=".&indexof($d, @$conf).
			     "&virt=$in{'virt'}");
		push(@titles, $what);
		push(@icons, "images/dir.gif");
		push(@types, $d->{'name'});
		}
	if ($config{'show_list'}) {
		# Show as list
		print &ui_columns_start([ $text{'virt_path'},
					  $text{'virt_type'} ]);
		for($i=0; $i<@links; $i++) {
			print &ui_columns_row([
			  &ui_link($links[$i], $titles[$i]),
			  $text{'virt_'.$types[$i]} ]);
			}
		print &ui_columns_end();
		}
	else {
		# Show as icons
		&icons_table(\@links, \@titles, \@icons, 3);
		}
	print "<p>\n";
	}

# Show form to create a dir
print &ui_form_start("create_dir.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_table_start($text{'virt_adddir'}, undef, 2);

print &ui_table_row($text{'virt_type'},
	&ui_select("type", undef,
	  [ map { [ $_, $text{'virt_'.$_} ] }
		  $httpd_modules{'core'} >= 2.0 ?
			( "Directory", "Files", "Location", "Proxy" ) :
		  $httpd_modules{'core'} >= 1.2 ?
			( "Directory", "Files", "Location" ) :
			( "Directory", "Location" ) ]));

if ($httpd_modules{'core'} >= 1.2) {
	print &ui_table_row($text{'virt_regexp'},
		&ui_radio("regexp", 0, [ [ 0, $text{'virt_exact'} ],
					 [ 1, $text{'virt_re'} ] ]));
	}

print &ui_table_row($text{'virt_path'},
	&ui_textbox("path", undef, 50));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'create'} ] ]);

$d = &is_virtualmin_domain($v);
if ($in{'virt'} && $access{'vaddr'} && !$d) {
	# Show form for changing virtual server
	print &ui_hr();
	print &ui_form_start("save_vserv.cgi");
	print &ui_hidden("virt", $in{'virt'});
	print &ui_table_start($text{'virt_opts'}, undef, 2);

	$val = $v->{'value'};
	if ($val =~ /\s/) {
		$addrs = $val;
		}
	if ($val =~ /^\[(\S+)\]:(\d+)$/) {
		# IPv6 address and port
		$addr = $1; $port = $2;
		}
	elsif ($val =~ /^\[(\S+)\]$/) {
		# IPv6 address
		$addr = $1;
		}
	elsif ($val =~ /^(\S+):(\d+)$/) {
		# IPv4 address or hostname and port
		$addr = $1; $port = $2;
		}
	else {
		# IPv4 address or hostname
		$addr = $val;
		}

	if ($addrs) {
		# Multiple addresses and ports
		print &ui_table_row($text{'vserv_addrs'},
			&ui_textarea("addrs", join("\n", split(/\s+/, $addrs)),
				    4, 30));
		}
	else {
		# Address and port
		print &ui_table_row($text{'vserv_addr'},
			&ui_radio("addr_def", $addr eq "_default_" ? 1 :
					      $addr eq "*" ? 2 : 0,
			  [ [ 1, $text{'vserv_addr1'} ],
			    [ 2, $text{'vserv_any'} ],
			    [ 0, &ui_textbox("addr",
					$addr eq "*" || $addr eq "_default_" ?
						"" : $addr, 40) ] ]));

		print &ui_table_row($text{'vserv_port'},
		     &choice_input($port eq "*" ? 1 : $port > 0 ? 2 : 0,
				   "port_mode", "0", "$text{'vserv_default'},0",
				   "$text{'vserv_any'},1", ",2").
		     &ui_textbox("port", $port > 0 ? $port : "", 5));
		}

	# Document directory
	$root = &find_directive_struct("DocumentRoot", $v->{'members'});
	print &ui_table_row($text{'vserv_root'},
		&opt_input($root->{'words'}->[0], "root",
					  $text{'vserv_default'}, 50).
		&file_chooser_button("root", 1, 1));
	print &ui_hidden("old_root", $root->{'words'}->[0]);

	# Server name
	$name = &find_directive("ServerName", $v->{'members'});
	print &ui_table_row($text{'vserv_name'},
		&opt_input($name, "name", $text{'vserv_default'}, 30));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
elsif ($in{'virt'} && $access{'vaddr'} && $d) {
	print "<b>",&text('vserv_virtualmin', $d->{'dom'}),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

