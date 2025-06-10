#!/usr/local/bin/perl
# edit_virt.cgi
# Display a form for editing some kind of per-server

require './apache-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
@dirs = &editable_directives($in{'type'}, 'virtual');
$desc = &text('virt_header', &virtual_name($v));
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

if ($in{'type'} == 8 && !$access{'vuser'}) {
	print "$text{'virt_euser'} <p>\n";
	&ui_print_footer("virt_index.cgi?virt=$in{'virt'}",
			 $text{'virt_return'});
	exit;
	}

if (!$in{'virt'}) {
	@dirs = grep { !$_->{'virtualonly'} } @dirs;
	}

print &ui_form_start("save_virt.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("type", $in{'type'});
print &ui_table_start(&text('virt_header2', $text{"type_$in{'type'}"},
                               &virtual_name($v)), "width=100%", 4);
if ($in{'type'} == 5 && &is_virtualmin_domain($v)) {
	@dirs = grep { $_->{'name'} ne 'DocumentRoot' &&
		       $_->{'name'} ne 'ServerPath' } @dirs;
	}
elsif ($in{'type'} == 1 && &is_virtualmin_domain($v)) {
	@dirs = grep { $_->{'name'} ne 'ServerName' &&
		       $_->{'name'} ne 'ServerAlias' } @dirs;
	}
&generate_inputs(\@dirs, $conf, \@skip);
print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'});


