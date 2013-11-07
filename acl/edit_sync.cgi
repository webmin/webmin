#!/usr/local/bin/perl
# edit_sync.cgi
# Display unix/webmin user synchronization

require './acl-lib.pl';
$access{'sync'} && $access{'create'} && $access{'delete'} ||
	&error($text{'sync_ecannot'});
&ui_print_header(undef, $text{'sync_title'}, "");

@glist = &list_groups();
if (!@glist) {
	print "<p>$text{'sync_nogroups'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<form action=save_sync.cgi>\n";
print "<b>$text{'sync_desc'}</b><p>\n";
printf "<input type=checkbox name=create value=1 %s> %s<p>\n",
	$config{'sync_create'} ? "checked" : "", $text{'sync_create'};
printf "<input type=checkbox name=delete value=1 %s> %s<p>\n",
	$config{'sync_delete'} ? "checked" : "", $text{'sync_delete'};
printf "<input type=checkbox name=unix value=1 %s> %s<p>\n",
	$config{'sync_unix'} ? "checked" : "", $text{'sync_unix'};

print "$text{'sync_group'} <select name=group>\n";
foreach $g (@glist) {
	printf "<option %s>%s\n",
		$g->{'name'} eq $config{'sync_group'} ? "selected" : "",
		$g->{'name'},
		"</option>";
	}
print "</select><p>\n";

print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

