
sub mod_tls_directives
{
local $rv = [
	[ 'TLSEngine', 0, 7, 'virtual global', 1.27, 10 ],
	[ 'TLSRequired', 0, 7, 'virtual global', 1.27, 1 ],
	[ 'TLSRSACertificateFile', 0, 7, 'virtual global', 1.27, 8 ],
	[ 'TLSRSACertificateKeyFile', 0, 7, 'virtual global', 1.27, 7 ],
	[ 'TLSCACertificateFile', 0, 7, 'virtual global', 1.27, 6 ],
	];
return &make_directives($rv, $_[0], "mod_tls");
}

sub edit_TLSEngine
{
my ($p) = grep { defined $_} @_;
return (2, $text{'mod_tls_engine'},
	&choice_input($p->{'value'}, "TLSEngine", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_TLSEngine
{
return &parse_choice("TLSEngine", "");
}

sub edit_TLSRequired
{
my ($p) = grep { defined $_} @_;
return (2, $text{'mod_tls_required'},
	&select_input($p->{'value'}, "TLSRequired", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'mod_tls_ctrl'},ctrl",
		      "$text{'mod_tls_auth'},auth",
		      "$text{'mod_tls_authdata'},auth+data",
		      "$text{'default'},"));
}
sub save_TLSRequired
{
return &parse_choice("TLSRequired", "");
}

sub edit_TLSRSACertificateFile
{
my ($p) = grep { defined $_} @_;
my $n = $p->{'name'};
return (2, $text{'mod_tls_file'},
	&ui_opt_textbox($n, $p->{'value'}, 60, $text{'mod_tls_none'})." ".
	&file_chooser_button($n));
}
sub save_TLSRSACertificateFile
{
my ($p) = grep { defined $_} @_;
my $n = $p->{'name'};
if ($in{$n."_def"}) {
	return ( [ ] );
	}
else {
	-r $in{$n} || &error($text{'mod_tls_efile'});
	return ( [ $in{$n} ] );
	}
}

sub edit_TLSRSACertificateKeyFile
{
my ($p) = grep { defined $_} @_;
my $n = $p->{'name'};
return (2, $text{'mod_tls_key'},
	&ui_opt_textbox($n, $p->{'value'}, 60, $text{'mod_tls_none'})." ".
	&file_chooser_button($n));
}
sub save_TLSRSACertificateKeyFile
{
my ($p) = grep { defined $_} @_;
my $n = $p->{'name'};
if ($in{$n."_def"}) {
	return ( [ ] );
	}
else {
	-r $in{$n} || &error($text{'mod_tls_ekey'});
	return ( [ $in{$n} ] );
	}
}

sub edit_TLSCACertificateFile
{
my ($p) = grep { defined $_} @_;
my $n = $p->{'name'};
return (2, $text{'mod_tls_ca'},
	&ui_opt_textbox($n, $p->{'value'}, 60, $text{'mod_tls_none'})." ".
	&file_chooser_button($n));
}
sub save_TLSCACertificateFile
{
my ($p) = grep { defined $_} @_;
my $n = $p->{'name'};
if ($in{$n."_def"}) {
	return ( [ ] );
	}
else {
	-r $in{$n} || &error($text{'mod_tls_eca'});
	return ( [ $in{$n} ] );
	}
}

1;
