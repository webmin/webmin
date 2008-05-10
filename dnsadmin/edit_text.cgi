#!/usr/local/bin/perl
# edit_text.cgi
# Display a form for manually editing a records file

require './dns-lib.pl';
&ReadParse();
%access = &get_module_acl();
$zconf = &get_config()->[$in{'index'}];
&can_edit_zone(\%access, $zconf->{'values'}->[0]) ||
	&error("You are not allowed to edit this zone");
$file = &absolute_path($zconf->{'values'}->[1]);
&header("Edit Records File", "");
print "<center><font size=+1>$file</font></center>\n";
print &ui_hr();

open(FILE, $file);
while(<FILE>) {
	push(@lines, &html_escape($_));
	}
close(FILE);

print "This form allows you to manually edit the DNS records file\n";
print "<tt>$file</tt>. No syntax checking will be done by webmin,\n";
print "and the zone serial number will not be automatically incremented. <p>\n";

print "<form action=save_text.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<textarea name=text rows=20 cols=80>",
	join("", @lines),"</textarea><p>\n";
print "<input type=submit value=Save> <input type=reset value=Undo></form>\n";

print &ui_hr();
&footer("edit_master.cgi?index=$in{'index'}", "record types");

