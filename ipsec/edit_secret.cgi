#!/usr/local/bin/perl
# Show one secret key

require './ipsec-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'secret_title1'}, "");
	$sec = { 'type' => $in{'type'} };
	}
else {
	&ui_print_header(undef, $text{'secret_title2'}, "");
	@secs = &list_secrets();
	$sec = $secs[$in{'idx'}];
	}

print &ui_form_start("save_secret.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("type", $sec->{'type'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'secret_header'}, "100%", 2);

print &ui_table_row($text{'secret_name'},
		    &ui_radio("name_def", $sec->{'name'} ? 0 : 1,
			      [ [ 1, $text{'secrets_any'} ],
				[ 0, $text{'secret_for'} ] ])."\n".
		    &ui_textbox("name", $sec->{'name'}, 30));

print &ui_table_row($text{'secret_type'},
		    $text{'secrets_'.lc($sec->{'type'})} || uc($sec->{'type'}));

if (lc($sec->{'type'}) eq "psk") {
	# Shared key, with a password
	$pass = $sec->{'value'} =~ /"(.*)"/ ? $1 : $sec->{'value'};
	print &ui_table_row($text{'secret_pass'},
			    &ui_textbox("pass", $pass, 20));
	}
elsif (lc($sec->{'type'}) eq "rsa") {
	# RSA key .. show all editable parts
	$val = $sec->{'value'};
	$val =~ s/^\s*{//;
	$val =~ s/{\s*$//;
	while($val =~ /^\s*(\S+):\s+(\S+)((.|\n)*)/) {
		$rsa{$1} = $2;
		$val = $3;
		}
	foreach $p (&unique(@rsa_attribs, keys(%rsa))) {
		print &ui_table_row(&text('secret_rsa', $p),
		    $p eq "PublicExponent" ?
			&ui_textbox("rsa_$p", $rsa{$p}, 10) :
			&ui_textarea("rsa_$p", &split_line($rsa{$p}, 60),5,60));
		}
	}
else {
	# Unknown!!
	print &ui_table_row($text{'secret_value'},
			    &ui_textarea("value", $sec->{'value'},
					 20, 60));
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ], 100);
	}

&ui_print_footer("list_secrets.cgi", $text{'secrets_return'},
		 "", $text{'index_return'});

sub split_line
{
local $str = $_[0];
local $rv;
while(length($str) > $_[1]) {
	$rv .= substr($str, 0, $_[1])."\n";
	$str = substr($str, $_[1]);
	}
$rv .= $str."\n";
return $rv;
}

