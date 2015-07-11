#!/usr/local/bin/perl
# edit_ext.cgi
# Display a form for creating or editing an external ACL type

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
my $conf = &get_config();

my ($ext, $ea);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'ext_title1'}, "", undef, 0, 0, 0, &restart_button());
	$ea = { 'args' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'ext_title2'}, "", undef, 0, 0, 0, &restart_button());
	$ext = $conf->[$in{'index'}];
	$ea = &parse_external($ext);
	}

print &ui_form_start("save_ext.cgi", "post");
print &ui_hidden("index", $in{'index'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'ext_header'}, undef, 2);

print &ui_table_row($text{'ext_name'},
	&ui_textbox("name", $ea->{'name'}, 20));

print &ui_table_row($text{'ext_format'},
	&ui_textbox("format", $ea->{'format'}, 60));

my $o = $ea->{'opts'};
foreach my $on ('ttl', 'negative_ttl', 'children', 'cache') {
	print &ui_table_row($text{'ext_'.$on},
		&ui_opt_textbox($on, $o->{$on}, 6, $text{'default'})." ".
		$text{'ext_'.$on.'_u'});
	}

print &ui_table_row($text{'ext_program'},
	&ui_textbox("program",
		    join(" ", $ea->{'program'}, @{$ea->{'args'}}), 60));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'acl_buttsave'} ],
		     $in{'new'} ? ( ) : ( [ 'delete', $text{'acl_buttdel'} ] ),
		   ]); 

&ui_print_footer("edit_acl.cgi?mode=external", $text{'acl_return'});

