#!/usr/local/bin/perl
# Show all drives and their SMART status

require './smart-status-lib.pl';
&ReadParse();

# Make sure SMART commands are installed
if (!&has_command($config{'smartctl'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_ecmd',
		        [ "<tt>$config{'smartctl'}</tt>", undef ]));
	}

# Show the version
$ver = &get_smart_version();
if (!$ver) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_ecmd2',
		        [ "<tt>$config{'smartctl'}</tt>", undef ]));
	}
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("smartctl", "man", "doc", "google"),
		 undef, undef,
		 &text('index_version', $ver));

# Get list of drives
@drives = &list_smart_disks_partitions();
if (!@drives) {
	&ui_print_endpage($text{'index_eidescsi'});
	}

if ($config{'mode'} == 1 || $in{'drive'}) {
	# Just show one drive, selected from menu
	print &ui_form_start("index.cgi");
	print "<b>$text{'index_show'}</b>\n";
	print &ui_select("drive", $in{'drive'},
			 [ map { [ $_->{'device'}.":".$_->{'subdisk'},
				   $_->{'desc'}.($_->{'model'} ? " ($_->{'model'})" : "") ] } @drives ],
			 1, 0, 0, 0, "onChange='form.submit()'");
	print &ui_submit($text{'index_ok'}),"\n";
	print &ui_form_end();

	if ($in{'drive'}) {
		($device, $subdisk) = split(/:/, $in{'drive'});
		($d) = grep { $_->{'device'} eq $device &&
			      $_->{'subdisk'} == $subdisk } @drives;
		&show_drive($d);
		}
	}
else {
	# Show all IDE drives
	foreach $d (@drives) {
		&show_drive($d);
		}
	}

&ui_print_footer("/", $text{'index'});

# show_drive(&drive)
sub show_drive
{
print &ui_form_start("action.cgi");
print &ui_hidden("drive", $_[0]->{'device'});
print &ui_hidden("subdisk", $_[0]->{'subdisk'});
local $h = defined($_[0]->{'subdisk'}) ?
	&text('index_drivesub', "<tt>$_[0]->{'device'}</tt>",
				$_[0]->{'subdisk'}) :
	&text('index_drive', "<tt>$_[0]->{'device'}</tt>");
print &ui_table_start($h, "width=100%", 4,
		      [ "width=30%", undef, "width=30%", undef ]);
local $st = &get_drive_status($_[0]->{'device'}, $_[0]);
print &ui_table_row($text{'index_desc'},
		    $_[0]->{'desc'});
if ($_[0]->{'cylsize'}) {
	print &ui_table_row($text{'index_size'},
		    &nice_size($_[0]->{'cylinders'}*$_[0]->{'cylsize'}));
	}
if ($_[0]->{'model'}) {
	print &ui_table_row($text{'index_model'},
			    $_[0]->{'model'});
	}
print &ui_table_row($text{'index_support'},
		    $st->{'support'} ? $text{'yes'} : $text{'no'});
print &ui_table_row($text{'index_enabled'},
		    $st->{'enabled'} ? $text{'yes'} : $text{'no'});
if ($st->{'support'} && $st->{'enabled'}) {
	if ($st->{'errors'}) {
		print &ui_table_row($text{'index_errors'},
				    "<font color=#ff0000>".
				    &text('index_ecount', $st->{'errors'}).
				    "</font>");
		}
	print &ui_table_row($text{'index_check'},
			    $st->{'check'} ? $text{'yes'} :
				"<font color=#ff0000>$text{'no'}</font>");
	}
if ($st->{'family'}) {
	print &ui_table_row($text{'index_family'}, $st->{'family'});
	}
if ($st->{'model'}) {
	print &ui_table_row($text{'index_model'}, $st->{'model'});
	}
if ($st->{'serial'}) {
	print &ui_table_row($text{'index_serial'}, $st->{'serial'});
	}
if ($st->{'capacity'}) {
	print &ui_table_row($text{'index_capacity'}, $st->{'capacity'});
	}
print &ui_table_end();

# Show extra attributes
if ($config{'attribs'} && @{$st->{'attribs'}}) {
	$attrs_count++;
	print &ui_hidden_table_start($text{'index_attrs'}, "width=100%", 2,
				     "attrs".$attrs_count, 1, [ "width=30%" ]);
	foreach my $a (@{$st->{'attribs'}}) {
		next if ($a->[0] =~ /UDMA CRC Error Count/i); # too long
		print &ui_table_row($a->[0],
			($a->[2] =~ /^\s*(seconds|minutes|hours|days|months|years|weeks)\s*/i || !$a->[2] ? $a->[1]." ".$a->[2] : $a->[2]).
			($a->[3] ? " ($text{'index_norm'} $a->[3])" : ""));
		}
	print &ui_hidden_table_end();
	}

# Show raw data from smartctl
if ($config{'attribs'} && $st->{'raw'}) {
	$raw_count++;
	print &ui_hidden_table_start($text{'index_raw'}, "width=100%", 2,
			     "raw".$raw_count, @{$st->{'attribs'}} ? 0 : 1);
	print &ui_table_row(undef,
		"<pre>".&html_escape($st->{'raw'})."</pre>", 2);
	print &ui_hidden_table_end();
	}

if ($st->{'support'} && $st->{'enabled'}) {
	print &ui_form_end([ [ "short", $text{'index_short'} ],
			     [ "ext", $text{'index_ext'} ],
			     [ "data", $text{'index_data'} ] ]);
	}
else {
	print &ui_form_end();
	}
}

