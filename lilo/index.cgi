#!/usr/local/bin/perl
# index.cgi
# Display all the boot partitions

require './lilo-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("lilo", "man", "doc", "howto"));

# Check for non-intel architecture
#if (!&is_x86()) {
#	print "<p>$text{'index_earch'}<p>\n";
#	&ui_print_footer("/", $text{'index'});
#	exit;
#	}

# Check if lilo.conf exists
if (!-r $config{'lilo_conf'}) {
	print "<p>",&text('index_econf',
			  "<tt>$config{'lilo_conf'}</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Get the lilo version
$out = `$config{'lilo_cmd'} -V 2>&1`;
if ($out =~ /lilo\s+version\s+([0-9\.]+)/i) {
	$lilo_version = $1;
	}
else {
	$lilo_version = 1;
	}
open(VERSION, ">$module_config_directory/version");
print VERSION $lilo_version,"\n";
close(VERSION);

$conf = &get_lilo_conf();
@images = sort { $a->{'index'} <=> $b->{'index'} }
	       ( &find("image", $conf), &find("other", $conf) );

$default = &find_value("default", $conf);
foreach $i (@images) {
	local $n = $i->{'name'};
	push(@icons, $n eq "image" ? "images/image.gif" : "images/other.gif");
	$l = &find_value("label", $i->{'members'});
	push(@titles, !$default && $i eq $images[0] ? "<b>$l</b>" :
		      $default && $default eq $l ? "<b>$l</b>" : $l);
	push(@links, "edit_$n.cgi?idx=$i->{'index'}");
	}
print &ui_link("edit_image.cgi?new=1",$text{'index_addk'}),"&nbsp;\n";
print &ui_link("edit_other.cgi?new=1",$text{'index_addp'}),"<br>\n";
&icons_table(\@links, \@titles, \@icons, 4);
print &ui_link("edit_image.cgi?new=1",$text{'index_addk'}),"&nbsp;\n";
print &ui_link("edit_other.cgi?new=1",$text{'index_addp'}),"<p>\n";
print &ui_hr();

print "<table width=100%>\n";
print "<form action=edit_global.cgi>\n";
print "<tr><td><input type=submit value=\"$text{'index_global'}\"></td>\n";
print "<td>$text{'index_globalmsg'}</td></tr></form>\n";

%flang = &load_language('fdisk');
$text{'select_part'} = $flang{'select_part'};
$text{'select_device'} = $flang{'select_device'};
$text{'select_fd'} = $flang{'select_fd'};
$dev = &find_value("boot", $conf);
print "<form action=apply.cgi>\n";
print "<tr><td><input type=submit value=\"$text{'index_apply'}\"></td> <td>\n";
if ($dev) {
	print &text('index_applymsg1',
	  $dev =~ /fd(\d+)$/ ? &text('select_fd', $1) :
	  $dev =~ /hd([a-z])(\d+)$/ ? &text('select_part', 'IDE', uc($1), $2) :
	  $dev =~ /sd([a-z])(\d+)$/ ? &text('select_part', 'SCSI', uc($1), $2) :
	  $dev =~ /hd([a-z])$/ ? &text('select_device', 'IDE', uc($1)) :
	  $dev =~ /sd([a-z])$/ ? &text('select_device', 'SCSI', uc($1)) : $dev);
	}
else {
	print $text{'index_applymsg2'};
	}
print "\n",$text{'index_applymsg3'},"</td></tr></form>\n";
print "</table>\n";

&ui_print_footer("/", $text{'index'});

