#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Edit a mapping

require './postfix-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'edit_map_title'}, "");

my $new_one = 0;
my $num;
## added to split main_parameter:sub_parameter
my ($mainparm,$subparm)=split /:/,$in{'map_name'};

if (!exists($in{'num'}))
{
    $num = &init_new_mapping($in{'map_name'});
    $new_one = 1;
}
else
{
    $num = $in{'num'};
}

my $maps = &get_maps($in{'map_name'});
my %map;

foreach $trans (@{$maps})
{
    if ($trans->{'number'} == $num) { %map = %{$trans}; }
}    

print &ui_form_start("save_map.cgi");
print &ui_hidden("num", $num),"\n";
print &ui_hidden("map_name", $in{'map_name'}),"\n";
print &ui_table_start($text{'edit_map_title'}, "width=100%", 2);

# Show map comment
if (&can_map_comments($in{'map_name'})) {
	print &ui_table_row($text{'mapping_cmt'},
			    &ui_textbox("cmt", $map{'cmt'}, 50));
	}

##$nfunc = "edit_name_".$in{'map_name'};
## modified to capture subparameters
$nfunc="edit_name_"; $nfunc.=($subparm)? $subparm : $mainparm;
if (defined(&$nfunc)) {
	print &$nfunc(\%map);
	}
else {
	print &ui_table_row($text{'mapping_name'},
			    &ui_textbox("name", $map{'name'}, 40));
	}

##$vfunc = "edit_value_".$in{'map_name'};
## modified to capture subparameters
$vfunc="edit_value_"; $vfunc.=($subparm)? $subparm : $mainparm;
if (defined(&$vfunc)) {
	print &$vfunc(\%map);
	}
else {
	print &ui_table_row($text{'mapping_value'},
			    &ui_textbox("value", $map{'value'}, 40));
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'map_save'} ],
	     $new_one ? ( ) : ( [ "delete", $text{'delete_map'} ] )
	     ]);

if ($in{'map_name'} eq $virtual_maps) {
	&ui_print_footer("virtual.cgi", $text{'virtual_return'});
	}
elsif ($in{'map_name'} eq 'canonical_maps') {
	&ui_print_footer($ENV{'HTTP_REFERER'},
			 $text{'canonical_return'});
	}
elsif ($in{'map_name'} eq 'sender_canonical_maps') {
	&ui_print_footer($ENV{'HTTP_REFERER'},
			 $text{'canonical_return_sender'});
	}
elsif ($in{'map_name'} eq 'recipient_canonical_maps') {
	&ui_print_footer($ENV{'HTTP_REFERER'},
			 $text{'canonical_return_recipient'});
	}
elsif ($in{'map_name'} eq 'transport_maps') {
	&ui_print_footer("transport.cgi", $text{'transport_return'});
	}
elsif ($in{'map_name'} eq 'relocated_maps') {
	&ui_print_footer("relocated.cgi", $text{'relocated_return'});
	}
elsif ($in{'map_name'} eq 'header_checks') {
	&ui_print_footer("header.cgi", $text{'header_return'});
	}
elsif ($in{'map_name'} eq 'body_checks') {
	&ui_print_footer("body.cgi", $text{'body_return'});
	}
elsif ($in{'map_name'} =~ /^smtpd_client_restrictions:/) {
	&ui_print_footer("client.cgi", $text{'client_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

