#!/usr/local/bin/perl
# Display NDC control interface options
use strict;
use warnings;
# Globals
our (%text, %access); 

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'controls_ecannot'});
&ui_print_header(undef, $text{'controls_title'}, "",
		 undef, undef, undef, undef, &restart_links());

my $conf = &get_config();
my $controls = &find("controls", $conf);
my $inet = &find("inet", $controls->{'members'});
my $unix = &find("unix", $controls->{'members'});

print &ui_form_start("save_controls.cgi", "post");
print &ui_table_start($text{'controls_header'}, undef, 2);

# Show options for inet control
my $ip;
my $port;
if ($inet) {
	my @v = @{$inet->{'values'}};
	$ip = shift(@v);
	while(@v) {
		my $n = shift(@v);
		if ($n eq "port") { $port = shift(@v); }
		}
	}
print &ui_table_row($text{'controls_inetopt'},
	    &ui_radio("inet", $inet ? 1 : 0,
		      [ [ 0, $text{'no'} ],
			[ 1, &text('controls_inetyes',
				   &ui_textbox("ip", $ip, 15),
				   &ui_textbox("port", $port, 6)) ] ]));

# Show allowed addresses for inet control
print &ui_table_row($text{'controls_allowips'},
	    &ui_textarea("allow",
			join("\n", map { $_->{'name'} }
				@{$inet->{'members'}->{'allow'}}), 5, 20));

# Show keys for inet control
print &ui_table_row($text{'controls_keys'},
	    &ui_textarea("keys",
			join("\n", map { $_->{'name'} }
				@{$inet->{'members'}->{'keys'}}), 3, 20));

print &ui_table_hr();

# Show options for local, socket control
my ($path, $perm, $owner, $group);
if ($unix) {
	my @v = @{$unix->{'values'}};
	$path = shift(@v);
	while(@v) {
		my $n = shift(@v);
		if ($n eq "perm") { $perm = shift(@v); }
		elsif ($n eq "owner") { $owner = getpwuid(shift(@v)); }
		elsif ($n eq "group") { $group = getgrgid(shift(@v)); }
		}
	}
print &ui_table_row($text{'controls_unixopt'},
	    &ui_radio("unix", $unix ? 1 : 0,
		      [ [ 0, $text{'no'} ],
			[ 1, &text('controls_unixyes',
				   &ui_textbox("path", $path, 30)) ] ]));
print &ui_table_row($text{'controls_unixperm'},
		    &ui_textbox("perm", $perm, 4));
print &ui_table_row($text{'controls_unixowner'},
		    &ui_user_textbox("owner", $owner, 4));
print &ui_table_row($text{'controls_unixgroup'},
		    &ui_group_textbox("group", $group, 4));


print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

