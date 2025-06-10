#!/usr/local/bin/perl
# Display users in the .htpasswd file

require './htpasswd-file-lib.pl';
if ($access{'single'}) {
	&redirect("edit.cgi");
	exit;
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Check if file is set in config
if (!$config{'file'}) {
	print &text('index_econfig',
			  "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

if ($config{'md5'}) {
	# Check if MD5 perl module is installed, and offer to install
	&foreign_require("useradmin", "user-lib.pl");
	if (!defined(&useradmin::check_md5)) {
		print &text('index_eversion',
				  "../config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	elsif ($err = &useradmin::check_md5()) {
		print &text('index_emd5',
				  "../config.cgi?$module_name",
				  "<tt>$err</tt>",
				  "../cpan/download.cgi?source=3&cpan=Digest::MD5&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# Display list of users
print &ui_subheading(&text('index_file', "<tt>$config{'file'}</tt>"));
$users = &list_users();
if (@$users) {
	print &ui_link("edit.cgi?new=1",$text{'index_add'}),"<br>\n"
		if ($access{'create'});
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	for($i=0; $i<@$users; $i++) {
		$u = $users->[$i];
		$link = &ui_link("edit.cgi?idx=$u->{'index'}",$u->{'user'});
		print "<tr>\n" if ($i%4 == 0);
		if ($u->{'enabled'}) {
			print "<td width=25%>$link</td>\n";
			}
		else {
			print "<td width=25%><i>$link</i></td>\n";
			}
		print "</tr>\n" if ($i%4 == 3);
		}
	if ($i%4) {
		while($i++%4) { print "<td width=25%></td>\n"; }
		print "</tr>\n";
		}
	print "</table></td></tr></table>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print &ui_link("edit.cgi?new=1",$text{'index_add'}),"<p>\n"
	if ($access{'create'});

if ($access{'sync'}) {
	# Show sync options
	print "<hr>\n";
	print &ui_subheading($text{'index_sync'});
	print "<form action=save_sync.cgi>\n";
	printf "<input type=checkbox name=create value=1 %s> %s<p>\n",
		$config{'sync_create'} ? "checked" : "",
		$text{'index_synccreate'};
	printf "<input type=checkbox name=modify value=1 %s> %s<p>\n",
		$config{'sync_modify'} ? "checked" : "",
		$text{'index_syncmodify'};
	printf "<input type=checkbox name=delete value=1 %s> %s<p>\n",
		$config{'sync_delete'} ? "checked" : "",
		$text{'index_syncdelete'};
	print "<input type=submit value='$text{'index_ssave'}'></form>\n";
	}

&ui_print_footer("/", $text{'index'});

