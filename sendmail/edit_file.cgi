#!/usr/local/bin/perl
# edit_file.cgi
# Display the contents of a file for editing

require './sendmail-lib.pl';
&error_setup($text{'file_err'});
$access{'manual'} || &error($text{'file_ecannot'});
&ReadParse();
$conf = &get_sendmailcf();
if ($in{'mode'} eq 'aliases') {
	require './aliases-lib.pl';
	$file = &aliases_file($conf)->[$in{'idx'}];
	$return = "list_aliases.cgi";
	$rmsg = $text{'aliases_return'};
	$access{'amode'} == 1 && $access{'aedit_1'} && $access{'aedit_2'} &&
	    $access{'aedit_3'} && $access{'aedit_4'} && $access{'aedit_5'} &&
	    $access{'amax'} == 0 && $access{'apath'} eq '/' ||
	    &error($text{'file_ealiases'});
	}
elsif ($in{'mode'} eq 'virtusers') {
	require './virtusers-lib.pl';
	$file = &virtusers_file($conf);
	$return = "list_virtusers.cgi";
	$rmsg = $text{'virtusers_return'};
	$access{'vmode'} == 1 && $access{'vedit_0'} && $access{'vedit_1'} &&
	    $access{'vedit_2'} && $access{'vmax'} == 0 ||
	    &error($text{'file_evirtusers'});
	}
elsif ($in{'mode'} eq 'mailers') {
	require './mailers-lib.pl';
	$file = &mailers_file($conf);
	$return = "list_mailers.cgi";
	$rmsg = $text{'mailers_return'};
	$access{'mailers'} || &error($text{'file_emailers'});
	}
elsif ($in{'mode'} eq 'generics') {
	require './generics-lib.pl';
	$file = &generics_file($conf);
	$return = "list_generics.cgi";
	$rmsg = $text{'generics_return'};
	$access{'omode'} == 1 || &error($text{'file_egenerics'});
	}
elsif ($in{'mode'} eq 'domains') {
	require './domain-lib.pl';
	$file = &domains_file($conf);
	$return = "list_domains.cgi";
	$rmsg = $text{'domains_return'};
	$access{'domains'} || &error($text{'file_edomains'});
	}
elsif ($in{'mode'} eq 'access') {
	require './access-lib.pl';
	$file = &access_file($conf);
	$return = "list_access.cgi";
	$rmsg = $text{'access_return'};
	$access{'access'} || &error($text{'file_eaccess'});
	}
else { &error($text{'file_emode'}); }

&ui_print_header(undef, $text{'file_title'}, "");
open(FILE, $file);
@lines = <FILE>;
close(FILE);

print "<b>",&text('file_desc', "<tt>$file</tt>"),"</b><p>\n";

print "<form action=save_file.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=mode value=\"$in{'mode'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<textarea name=text rows=20 cols=80>",
	join("", @lines),"</textarea><p>\n";
print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'file_undo'}\">\n";
print "</form>\n";

&ui_print_footer($return, $rmsg);

