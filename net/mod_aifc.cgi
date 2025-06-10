#!/usr/local/bin/perl
# mod_aifc.cgi
# Show info about some interface that is being used by another module

require './net-lib.pl';
$access{'ifcs'} || &error($text{'ifcs_ecannot'});
&ReadParse();
@act = &active_interfaces();
$a = $act[$in{'idx'}];
$mod = &module_for_interface($a);
$mod || &error($text{'mod_egone'});

&ui_print_header(undef, $text{'mod_title'}, "");

print "<p>\n";
print &text('mod_desc', "<tt>$a->{'fullname'}</tt>", $mod->{'desc'}),"\n";
&read_acl(\%acl);
if ($acl{$base_remote_user,$mod->{'module'}}) {
	%minfo = &get_module_info($mod->{'module'});
	print &text('mod_link', "../$mod->{'module'}/", $minfo{'desc'});
	}
print "<p>\n";

&ui_print_footer("list_ifcs.cgi?mode=active", $text{'ifcs_return'});

