#!/usr/local/bin/perl
# index.cgi
# Redirect to another URL

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$url = $access{'link'} || $config{'link'};
$host = $ENV{'HTTP_HOST'};
$host =~ s/:.*$//;
$url =~ s/\$\{REMOTE_USER\}/$remote_user/g ||
	$url =~ s/\$REMOTE_USER/$remote_user/g;
$url =~ s/\$\{HTTP_HOST\}/$host/g ||
	$url =~ s/\$HTTP_HOST/$host/g;
if (($url =~ /\$VIRTUALSERVER_/ || $url =~ /\$\{VIRTUALSERVER_/) &&
    &foreign_check("virtual-server")) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	$dom = &virtual_server::get_domain_by("user", $remote_user,
					      "parent", "");
	if ($dom) {
		foreach $k (keys %$dom) {
			$uck = "VIRTUALSERVER_".uc($k);
			$url =~ s/\$\{$uck\}/$dom->{$k}/g ||
				$url =~ s/\$$uck/$dom->{$k}/g;
			}
		}
	else {
		&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
		&error($text{'index_evirtualmin'});
		}
	}
if ($url && $config{'immediate'}) {
	&redirect($url);
	}
else {
	# Show a link page
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	if ($url) {
		$desc = $access{'desc'} || $config{'desc'} ||
			"Open URL $url";
		$target = $config{'window'} ? "target=$module_name" : "";
		print "<font size=+1><a href='$url' $target>$desc</a></font><p>\n";
		}
	else {
		print &text('index_econfig', "../config.cgi?$module_name"),"<p>\n";
		}
	&ui_print_footer("/", $text{'index'});
	}

